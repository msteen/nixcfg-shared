# FIXME: This is not working correctly since it does not generate a proper squashfs with the nix store.
{ lib, pkgs, ... }:

with lib;

let
  build-rescue-nixos = pkgs.writeBashBin "build-rescue-nixos" ''
    ${ensureRoot}

    if (( $# < 1 )); then
      ${bashConfirm "Are you sure you want to use $NIXOS_CONFIG as your config" "exit 0" "exit 1"}
    else
      export NIXOS_CONFIG="$1"
    fi

    deps=$(nix-build --no-out-link ${../lib/bootloader-deps.nix})

    mkdir /boot/rescue
    cp -p $deps/{kernel,initrd,kernel-params} /boot/rescue
    $deps/append-initrd-secrets /boot/rescue/initrd

    echo "${''
      menuentry "Rescue NixOS" {
        linux ($drive1)/rescue/kernel $(< $deps/kernel-params)
        initrd ($drive1)/rescue/initrd
      }
    ''}" > /boot/rescue/grub-entry.cfg

    ${bashConfirm "Call 'nixos-rebuild boot' to update Grub" "exit 0" "exit 1"}
    sudo nixos-rebuild boot
  '';

  kexec-rescue = pkgs.writeShBin "kexec-rescue" ''
    ${ensureRoot}

    if ! { [ -f /boot/rescue/kernel ] && [ -f /boot/rescue/initrd ]; }; then
      echo 'Could not find the kernel image and intial ramdisk to kexec into' 1>&2
      exit 1
    fi

    if ! kexec --load /boot/rescue/kernel --initrd=/boot/rescue/initrd --command-line="$(cat /boot/rescue/kernel-params)"; then
      echo 'Could not load the kernel image and intial ramdisk with kexec' 1>&2
      exit 1
    fi

    ${syncUmountAll}

    kexec --exec
  '';

in {
  boot.loader.grub.extraEntries = mkIf (pathExists /boot/rescue/grub-entry.cfg) (readFile /boot/rescue/grub-entry.cfg);

  kexec.scripts.rescue = kexec-rescue;

  environment.systemPackages = [ build-rescue-nixos kexec-rescue ];
}
