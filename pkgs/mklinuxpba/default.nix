{ lib, writeBashBin, ensureRoot, bashConfirm, coreutils, utillinux, bash, gptfdisk, syslinux, dosfstools, nix }:

with lib;

# https://wiki.archlinux.org/index.php/syslinux
# https://aur.archlinux.org/cgit/aur.git/tree/mklinuxpba-diskimg?h=sedutil
writeBashBin "mklinuxpba" ''
  ${ensureRoot}

  if (( $# < 1 )); then
    ${bashConfirm "Are you sure you want to use '$NIXOS_CONFIG' as your config" "exit 0" "exit 1"}
  else
    export NIXOS_CONFIG="$1"
  fi

  export PATH=${makeBinPath [ coreutils utillinux gptfdisk syslinux dosfstools nix ]}

  deps=$(nix-build --no-out-link ${../../lib/bootloader-deps.nix} --show-trace)
  if (( $? > 0 )) || [[ -z $deps ]]; then
    echo "Failed to build the kernel or initial ramdisk." 1>&2
    exit 1
  fi

  img=$(mktemp --tmpdir=/tmp linuxpba-XXXXXXXXXX.img)
  mnt=$(mktemp --tmpdir=/tmp --directory linuxpba-XXXXXXXXXX)

  cp ${syslinux}/share/syslinux/gptmbr.bin "$img"
  truncate -s 32M "$img"
  sgdisk -n 1:0:0 -t 1:ef00 -A 1:set:2 "$img" > /dev/null

  loopdev="$(losetup --show -f "$img")"
  partx -a "$loopdev"

  mkfs.vfat -n SEDUTIL_PBA "''${loopdev}p1" > /dev/null
  syslinux --install "''${loopdev}p1"

  mount "''${loopdev}p1" "$mnt"

  cp $deps/{kernel,initrd} "$mnt"
  if [[ -f $deps/append-initrd-secrets ]]; then
    $(< $deps/append-initrd-secrets) "$mnt/initrd"
  fi

  # BIOS (the other files are installed via `syslinux --install`)
  echo "${''
    default linuxpba
    prompt 0
    noescape 1
    label linuxpba
      kernel /kernel
      initrd /initrd
      append ''$(< $deps/kernel-params)
  ''}" > "$mnt/syslinux.cfg"

  # EFI
  mkdir -p "$mnt/EFI/BOOT"
  cp ${./syslinux.efi} "$mnt/EFI/BOOT/bootx64.efi"
  cp ${./ldlinux.e64} "$mnt/EFI/BOOT/ldlinux.e64"
  cp "$mnt/syslinux.cfg" "$mnt/EFI/BOOT/syslinux.cfg"

  umount "$mnt"
  rmdir "$mnt"

  partx -d "$loopdev"
  losetup -d "$loopdev"

  echo "$img"
''
