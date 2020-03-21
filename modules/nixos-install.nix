{ config, pkgs, ... }:

with import ../lib;

let
  kexec-nixos-install = pkgs.writeBash "kexec-nixos-install" ''
    ${pkgs.ensureRoot}

    export PATH=${makeBinPath (with pkgs; [
      coreutils
      cpio
      findutils
      gawk
      gnugrep
      gzip
      kexectools
      utillinux
    ])}

    deps=${import ../lib/bootloader-deps.nix {
      inherit config;
      inherit pkgs;
      initialRamdisk = config.system.build.netbootRamdisk;
    }}

    if ! kexec --load $deps/kernel --initrd=$($deps/make-secrets-initrd) --command-line="$(cat $deps/kernel-params)"; then
      echo 'Could not load the kernel image and intial ramdisk with kexec' 1>&2
      exit 1
    fi

    ${pkgs.syncUmountAll}

    kexec --exec
  '';

  buildInstaller = name: build: extraImports: pkgs.writeBashBin name ''
    (( $# >= 1 )) && config=$1 || config='${toString config.system.nixosConfig}'
    nix-build --no-out-link --expr '
      let
        toConfig = configuration: (import ${toString pkgs.path + "/nixos"} { inherit configuration; }).config;
        builder = toConfig "${toString config.system.nixosConfig}";
        target = toConfig "'$config'";
        installer = toConfig {
          imports = [
            ${extraImports}
          ] ++ map (f: f {
            inherit builder target;
          }) target.nixos-install.imports;
        };
      in installer.system.build.${build}
    ' --show-trace
  '';

  build-iso-image = buildInstaller "build-iso-image" "isoImage"
    (toString pkgs.path + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix");

  build-kexec-tarball = buildInstaller "build-kexec-tarball" "kexec-tarball" ''
    ${toString pkgs.path + "/nixos/modules/installer/netboot/netboot-minimal.nix"}
    {
      # Reboot on failure.
      boot.kernelParams = [ "boot.panic_on_fail" "panic=30" ];
    }
  '';

in {
  options = with types; {
    nixos-install.imports = mkOption {
      type = loeOf unspecified;
      default = [];
    };
  };

  config = {
    system.build.kexec-tarball = pkgs.callPackage (toString pkgs.path + "/nixos/lib/make-system-tarball.nix") {
      storeContents = singleton {
        object = kexec-nixos-install;
        symlink = "/kexec-nixos-install";
      };
      contents = [];
    };

    environment.systemPackages = [
      build-iso-image
      build-kexec-tarball
    ];
  };
}
