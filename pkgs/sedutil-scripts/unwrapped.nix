{ lib, writeShBin, ensureRoot, buildEnv }:

with lib;

# https://github.com/Drive-Trust-Alliance/sedutil/wiki/Encrypting-your-disk
let
  writeSedutilScript = name: args: text:
    let realArgs = [ "/dev/sdX" ] ++ args; in writeShBin "sedutil-${name}" ''
    ${ensureRoot}

    if [ $# -lt ${toString (length realArgs)} ]; then
      echo 'Usage: sedutil-${name} ${concatStringsSep " " realArgs}' 1>&2
      exit 1
    fi

    ${text}
  '';

  sedutil-disk-unwrapped = writeSedutilScript "disk" [] ''
    path=$1
    disk=$(readlink -f "$path")
    if [ $? -gt 0 ]; then
      echo "The path $path does not refer to a valid disk" 1>&2
      exit 1
    fi
    if ! sedutil-cli --scan | awk '"'$disk'" ~ "^"$1 { if ($2 ~ 2) { found = 1; exit } } END { exit !found }'; then
      echo "The disk $path does not have OPAL 2 support" 1>&2
      exit 1
    fi

    if lsblk -no MOUNTPOINT "$disk" | grep -q -v '^$'; then
      echo "The disk $path is mounted somewhere, so it is unsafe to use sedutil" 1>&2
      exit 1
    fi

    set -- $(sedutil-cli --query "$disk" | awk 'NR==6 {gsub(",", "", $0); print $6}')
    lockingEnabled="$1"
    if [ "$lockingEnabled" = N ]; then
      echo "The disk $path has not yet been put into OPAL mode" 1>&2
      exit 1
    fi

    echo "$disk"
  '';

  writeSedutilDiskScript = name: args: text: writeSedutilScript name args ''
    path=$1
    disk=$(sedutil-disk "$path")
    if [ $? -gt 0 ]; then
      exit 1
    fi

    ${text}
  '';

  getpasswd = ''
    echo -n "Enter passphrase for $path: "
    passwd=$(getpasswd)
    echo
  '';

  rereadpt = ''
    # If re-reading would not work like this, removing and re-adding it might have:
    # http://www.sakana.fr/blog/2009/05/04/linux-sata-hot-plug-unplug/
    if ! blockdev --rereadpt "$disk"; then
      echo "Could not re-read the partition table of $path" 1>&2
      exit 1
    fi
    sleep 1 # re-reading the partition table does not block execution
  '';

  sedutil-enable-unwrapped = writeSedutilDiskScript "enable" [] ''
    ${getpasswd}

    if ! {
      sedutil-cli --enableLockingRange 0 "$passwd" "$disk" &&
      sedutil-cli --setMBREnable on "$passwd" "$disk";
    }; then
      echo "Could not enable encryption for disk $path with the given password" 1>&2
      exit 1
    fi
  '';

  sedutil-disable-unwrapped = writeSedutilDiskScript "disable" [] ''
    ${getpasswd}

    set -- $(sedutil-cli --query "$disk" | awk 'NR==6 {gsub(",", "", $0); print $12, $15}')
    mbrDone="$1" mbrEnabled="$2"

    # Locking will be marked as enabled no matter whether it is or not.
    if ! sedutil-cli --disableLockingRange 0 "$passwd" "$disk"; then
      echo "Could not disable encryption for disk $path with the given password" 1>&2
      exit 1
    fi

    if [ "$mbrEnabled" = Y ]; then
      if ! sedutil-cli --setMBREnable off "$passwd" "$disk"; then
        echo "Could not disable MBR for disk $path with the given password" 1>&2
        exit 1
      fi

      if [ "$mbrDone" = N ]; then
        ${rereadpt}
      fi
    fi
  '';

  sedutil-lock-unwrapped = writeSedutilDiskScript "lock" [] ''
    ${getpasswd}

    if ! {
      sedutil-cli --setLockingRange 0 LK "$passwd" "$disk" &&
      sedutil-cli --setMBRDone off "$passwd" "$disk";
    }; then
      echo "$1" 1>&2
      echo "Could not lock disk $path with the given password" 1>&2
      exit 1
    fi
  '';

  sedutil-unlock-unwrapped = writeSedutilDiskScript "unlock" [] ''
    set -- $(sedutil-cli --query "$disk" | awk 'NR==6 {gsub(",", "", $0); print $3, $12, $15}')
    locked="$1" mbrDone="$2" mbrEnabled="$3"

    if [ "$locked" = Y ] || [ "$mbrDone" = N ]; then
      ${getpasswd}
    fi

    if [ "$locked" = Y ] && ! sedutil-cli --setLockingRange 0 RW "$passwd" "$disk"; then
      echo "Could not unlock disk $path with the given password" 1>&2
      exit 1
    fi

    if [ "$mbrEnabled" = Y ] && [ "$mbrDone" = N ]; then
      if ! sedutil-cli --setMBRDone on "$passwd" "$disk"; then
        echo "Could not set MBR done for disk $path with the given password" 1>&2
        exit 1
      fi

      ${rereadpt}
    fi
  '';

  sedutil-pba-unwrapped = writeSedutilDiskScript "pba" [ "linuxpba.img" ] ''
    img=$2
    if [ ! -f "$img" ]; then
      echo 'The second argument should be a valid Linux PBA image' 1>&2
    fi

    ${getpasswd}

    if ! {
      sedutil-cli --enableLockingRange 0 "$passwd" "$disk" &&
      sedutil-cli --setLockingRange 0 LK "$passwd" "$disk" &&
      sedutil-cli --setMBRDone off "$passwd" "$disk" &&
      sedutil-cli --loadPBAimage "$passwd" "$img" "$disk" &&
      sedutil-cli --setMBREnable on "$passwd" "$disk" &&
      sedutil-cli --setMBRDone off "$passwd" "$disk";
    }; then
      echo "Could not load PBA image for disk $path with the given password" 1>&2
      exit 1
    fi
  '';

  sedutil-passwd-unwrapped = writeSedutilDiskScript "passwd" [] ''
    ${getpasswd}

    echo -n "Enter new passphrase for $path: "
    new_passwd=$(getpasswd)
    echo

    echo -n "Repeat new passphrase for $path: "
    if [[ $(getpasswd) != $new_passwd ]]; then
      echo 'The given new passwords are not equal' 1>&2
      exit 1
    fi
    echo

    if ! {
      sedutil-cli --setSIDPassword "$passwd" "$new_passwd" "$disk" &&
      sedutil-cli --setAdmin1Pwd "$passwd" "$new_passwd" "$disk";
    }; then
      echo "Could not set the new SID and new Admin1 password for disk $path with the given old password" 1>&2
      exit 1
    fi
  '';

in buildEnv {
  name = "sedutil-scripts-unwrapped";
  paths = [
    sedutil-disk-unwrapped
    sedutil-enable-unwrapped
    sedutil-disable-unwrapped
    sedutil-lock-unwrapped
    sedutil-unlock-unwrapped
    sedutil-pba-unwrapped
    sedutil-passwd-unwrapped
  ];
}
