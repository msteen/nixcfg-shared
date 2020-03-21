{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.initrd.sedutil;

  # https://github.com/gebart/opal-kexec-pba
  sedutil-kexec = pkgs.writeSh "sedutil-kexec" ''
    if ! sedutil-unlock ${cfg.disk}; then
      echo 'Could not unlock disk ${cfg.disk}' 1>&2
      exit 1
    fi

    kexec-boot
  '';

in {
  imports = [
    ./kexec.nix
    ../config/sedutil.nix
  ];

  options.boot.initrd.sedutil = with types; {
    enable = mkEnableOption "unlocking a disk with sedutil inside of the initial ramdisk";

    disk = mkOption {
      type = path;
      example = "/dev/sda";
      description = ''
        The disk to unlock with sedutil.
      '';
    };
  };

  config = mkIf cfg.enable {
    boot.initrd = {
      extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.sedutil}/bin/getpasswd
        copy_bin_and_libs ${pkgs.sedutil}/bin/sedutil-cli
        cp -Lpnv ${pkgs.sedutil-scripts-unwrapped}/bin/* $out/bin
        copy_bin_and_libs ${pkgs.kexectools}/bin/kexec
        cp -pv ${sedutil-kexec} $out/bin/sedutil-kexec
        cp -pv {${config.kexec.scripts.boot},$out}/bin/kexec-boot
        mkdir -p $out/etc/ssh
      '';

      preLVMCommands = ''
        disk=$(readlink -f ${cfg.disk})
        set -- $(sedutil-cli --query "$disk" | awk 'NR==6 {gsub(",", "", $0); print $3, $12, $15}')
        locked="$1" mbrDone="$2" mbrEnabled="$3"
        if [ "$mbrEnabled" = Y ] && [ "$mbrDone" = N ]; then
          if ! sedutil-kexec; then
            sh
          fi
        elif [ "$locked" = Y ]; then
          if ! sedutil-unlock; then
            sh
          fi
        fi
      '';

      network.ssh.shellInit = ''
        sedutil-kexec
      '';
    };
  };
}
