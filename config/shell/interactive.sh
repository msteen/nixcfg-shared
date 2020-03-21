which() {
  command which --skip-alias --skip-functions -- "$@" > >(command xargs --no-run-if-empty readlink --canonicalize)
}

xargs() {
  command xargs --no-run-if-empty "$@"
}

systemctl() {
  if [[ $1 == '--user' || $1 == 'status' ]]; then
    command systemctl "$@"
  else
    command sudo systemctl "$@"
  fi
}

ip() {
  if [[ $1 == 'addr' ]]; then
    command ip "$@"
  else
    command sudo ip "$@"
  fi
}

# FIXME: This does not work well with `which`.
# xargs() {
#   local arg
#   for arg in "$@"; do
#     if [[ $arg != -* ]]; then
#       if type "$arg" | grep --quiet --word-regexp 'function'; then
#         fargs "$@"
#       else
#         command xargs --no-run-if-empty "$@"
#       fi
#       return $?
#     fi
#     (( i++ ))
#   done
#   command xargs "$@"
# }

for rq in poweroff reboot; do
  source /dev/stdin <<EOF
$rq() {
  if pgrep -c chrom >/dev/null || pgrep -c firefox >/dev/null; then
    echo "A browser is still running. Close these before shutting down." >&2
    echo "You probably mistakenly chose to shutdown this machine." >&2
    return 1
  fi
  if bash-confirm "Are you sure you want to $rq $(hostname)"; then
    systemctl $rq
  fi
}
EOF
done
unset -v rq

nano-readonly() {
  if (( $# < 1 )); then
    echo "Usage: nano-readonly <file>" >&2
    return 1
  fi
  local file=$1
  sudo cp "$file"{,~} &&
  sudo mv "$file"{~,} &&
  sudo nano "$file"
}

dsync() {
  if (( $# < 2 )); then
    echo "Usage: dsync [src-remote:]src-file/or/dir [dst-remote:]dst-file/or/dir" >&2
    return 1
  fi
  local src=$1 dst=$2
  if [[ ! $src =~ ':' && ! $dst =~ ':' ]]; then
    echo "At least one path should refer to a remote machine" >&2
    return 1
  fi
  if [[ $src != */ ]]; then
    src+=/
  fi
  if [[ $dst != */ ]]; then
    dst+=/
  fi
  rsync --verbose --archive --delete --rsh=ssh "$src" "$dst"
}

dd-iso() {
  if (( $# < 2 )); then
    echo "Usage: dd-iso /path/to/iso /dev/sdX" >&2
    return 1
  fi

  local src=$1 dst=$2

  if [[ -d $src ]]; then
    src=$(echo "$src"/iso/*.iso)
  fi

  if [[ ! -f $src ]]; then
    echo "The path '$src' does not refer to an existing file" >&2
    return 1
  fi

  local disk=$(readlink -f "$dst")
  local block=/sys/block/$(basename "$disk")
  if [[ ! -b $disk || ! -d $block ]]; then
    echo "The path '$dst' does not refer to a valid disk" >&2
    return 1
  fi

  if (( $(< "$block"/removable) == 0 )); then
    echo "The target disk '$dst' is not a removable device" >&2
    return 1
  fi

  local info=$(udevadm info --query=all --name="$disk")
  if ! echo "$info" | grep --quiet 'ID_BUS=usb'; then
    echo "The target disk '$dst' is not an USB device" >&2
    return 1
  fi

  local serial=$(echo "$info" | grep 'ID_SERIAL=' | sed 's/.*ID_SERIAL=//')

  # The reported size is always in blocks of 512 bytes, regardless of the real block size.
  # https://unix.stackexchange.com/questions/52215/determine-the-size-of-a-block-device#comment433709_52219
  local size=$(( 512 * $(< "$block"/size) / 1024 / 1024 / 1024 ))
  if (( size > 16 )); then
    echo "The target disk '$dst' has a size of roughly ${size}GB, you probably do not want to use it just to hold an iso" >&2
    return 1
  fi

  if ! bash-confirm "Are you sure you want to write the iso to target disk '$dst' with serial '$serial' and a size of roughly ${size}GB"; then
    return 1
  fi

  sudo dd bs=4M oflag=sync status=progress if="$src" of="$dst"
}

alias udevinfo='udevadm info --query=all'

udevtest() {
  sudo udevadm test $(udevadm info --query=path "$@") 2>&1
}

cert() {
  echo | openssl s_client -host "$1" -port 443 -showcerts > >(openssl x509 -outform PEM) 2>&1
}

lscert() {
  echo | openssl s_client -host "$1" -port 443 -showcerts > >(sed -n '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p') 2>&1
}

rsabits() {
  ssh-keygen -lf "$1" | awk '{ print $1 }'
}

realurl() {
  curl --silent --location --head --output /dev/null --write-out '%{url_effective}\n' "$1"
}

gkill() {
  matches=$(ps --no-headers -A -o pid,args | egrep "^ *[0-9]+ .*[${1:0:1}]${1:1}") &&
  echo "$matches" &&
  bash-confirm "Are you sure you want to kill all these processes" &&
  kill $(echo "$matches" | awk '{ print $1 }')
}

fwport() {
  if (( $# < 2 )); then
    echo "Usage: fwport {local (and remote, if omitted) port} [remote port] {ssh command}..." >&2
    return 1
  fi
  if [[ ! $1 =~ ^[0-9]+$ ]]; then
    echo "first argument, the local port, should be a natural number" >&2
    return 1
  fi
  local local_port=$1
  shift
  if [[ $1 =~ ^[0-9]+$ ]]; then
    local remote_port=$1
    shift
  else
    local remote_port=$local_port
  fi
  echo -L "$local_port:localhost:$remote_port" "$@"
}

mkinitrd() {
  local nixos_config
  (( $# < 1 )) && nixos_config=$(nixos-config) || nixos_config=$1
  NIXOS_CONFIG=$nixos_config nix-build '<nixpkgs/nixos>' --no-out-link --attr config.system.build.initialRamdisk
}

mkinstaller() {
  if (( $# < 1 )); then
    echo "Usage: mkinstaller /path/to/installer.nix [/dev/target]" >&2
    return 1
  fi
  local iso=$(NIXOS_CONFIG=$1 nix-build '<nixpkgs/nixos>' --no-out-link --attr config.system.build.isoImage) &&
  echo "$iso" &&
  if (( $# >= 2 )); then
    dd-iso "$iso" "$2"
  fi
}

fix-group-write() {
  if (( $# != 1 )); then
    echo "Usage: fix-group-write /path/to/search" >&2
    return 1
  fi
  find -L "$1" -type d -perm 2755 -printf '%p\0' | xargs -0rL 50 sudo chmod g+w
}

grep-exec() {
  if (( $# < 1 )); then
    echo "Usage: grep-exec <file>..." >&2
    return 1
  fi
  local ret=0 file exec_file
  for file in "$@"; do
    [[ -e $file ]] && exec_file=$(sed -n 's|exec.*"\(/[^"]\{1,\}\)".*|\1|p' "$file") &&
    [[ -n $exec_file ]] && echo "$exec_file" || ret=1
  done
  return $ret
}

grep-service-exec() {
  if (( $# < 1 )); then
    echo "Usage: grep-service-exec <file>" >&2
    return 1
  fi
  service=$1
  [[ $service == *.service ]] || service="$service.service"
  find -L /etc/systemd -name "$service" -exec sed -n 's/ExecStart=\(.*\)/\1/p' {} \; -quit
}

nixos-upgrade() {
  command nix-env --uninstall '.*' &&
  command sudo nix-env --uninstall '.*' &&
  nux-update-nixpkgs &&
  sudo nixos-rebuild boot
}

git() {
  if
    [[ $1 == commit ]] &&
    command git diff-index --cached --quiet HEAD -- &&
    command git status &&
    bash-confirm "No files added, do you want to add all"
  then
    command git add .
  fi
  command git "$@"
}
