{ config, lib, pkgs, ... }:

with lib;

let
  boot = if config.fileSystems ? "/boot" then config.fileSystems."/boot" else config.fileSystems."/";
  bootPathSuffix = if config.fileSystems ? "/boot" then "" else "/boot";
  bootTy = boot.fsType;
  bootOpts = concatStringsSep "," boot.options;
  bootDev = if boot.device != null then boot.device else "/dev/disk/by-label/${boot.label}";
  kexec-boot = pkgs.writeShBin "kexec-boot" ''
    if [ -d /boot ]; then
      boot=/boot
    else
      mkdir -p /kexec-boot
      if ! mount -t ${bootTy} -o ${bootOpts},ro ${bootDev} /kexec-boot; then
        echo 'Could not mount the boot partition' 1>&2
        exit 1
      fi
      boot=/kexec-boot${bootPathSuffix}
    fi

    cleanup() {
      if [ $boot = /kexec-boot${bootPathSuffix} ]; then
        umount /kexec-boot;
      fi
    }
    trap cleanup EXIT

    cfg=$boot/kexec
    if ! [ -d "$cfg" ]; then
      echo 'Could not find the kernel image and intial ramdisk to kexec into' 1>&2
      exit 1
    fi

    if [ -f "$boot/grub/secrets-initrd.gz" ]; then
      cat "$boot$(cat "$cfg/initrd")" "$boot/grub/secrets-initrd.gz" > final-initrd.gz
    fi

    if ! kexec --load "$boot$(cat "$cfg/kernel")" --initrd=final-initrd.gz --command-line="$(cat "$cfg/kernel-params")"; then
      echo 'Could not load the kernel image and intial ramdisk with kexec' 1>&2
      exit 1
    fi

    cleanup
    ${pkgs.syncUmountAll}

    kexec --exec
  '';

in {
  options.kexec.scripts = with types; mkOption {
    type = attrs;
    default = {};
  };

  config = mkIf (config.boot.loader.grub.enable && config.fileSystems ? "/") {
    assertions = [
      {
        assertion = config.boot.loader.grub.enable;
        message = ''
          The location of kernels and the initial ramdisks in the boot partition is not standardized and as such will differ between boot loaders.
          At the time of writing, Grub was used, so it has been specialized to Grub's conventions.
          Please update this module if you are going to use a different boot loader.
        '';
      }
    ];

    boot.initrd.supportedFilesystems = [ bootTy ];

    kexec.scripts = {
      boot = kexec-boot;
    };

    system.activationScripts.export-system-config = ''
      export systemConfig
    '';

    system.activationScripts.kexec-boot = stringAfter [ "export-system-config" ] "${pkgs.writeBash "kexec-boot.sh" ''
      PATH=${makeBinPath (with pkgs; [ coreutils gnused ])}

      if [[ -d /boot/kexec ]]; then
        rm -rf /boot/kexec
      fi
      mkdir /boot/kexec

      # The kernel and initial ramdisk location are dependent on which boot loader has been used.
      # This matches the format used by the Grub boot loader.
      echo "/kernels/$(readlink -f $systemConfig/kernel | sed -e 's|/nix/store/||' -e 's|/|-|')" > /boot/kexec/kernel
      echo "/kernels/$(readlink -f $systemConfig/initrd | sed -e 's|/nix/store/||' -e 's|/|-|')" > /boot/kexec/initrd

      # These are boot loader independent.
      echo "systemConfig=$systemConfig init=$systemConfig/init $(< $systemConfig/kernel-params)" > /boot/kexec/kernel-params
    ''}";
  };
}
