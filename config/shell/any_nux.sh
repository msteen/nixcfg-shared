
nux() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<EOF
Nix User eXperience.

Usage:
  nux <command> [<argument>]...
  nux -h | --help

Options:
  -h, --help  Show help message.

Commands:
$(nux-list > >(sed 's/^/  /'))
EOF
    return
  fi
  local cmd="nux-$1"
  shift
  if is_command_or_function "$cmd"; then
    "$cmd" "$@"
  else
    echo "Command '$cmd' is neither a command (executable file found on PATH) nor shell function." >&2
    return 1
  fi
}

nux-list() {
  if [[ $1 =~ ^(-h|--help)$ ]]; then
    print_help <<'EOF'
List all Nux commands.

Usage: nux list [-h | --help]

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local nux_cmds
  if [[ -v BASH_VERSION ]]; then
    nux_cmds=$(compgen -A command nux- | awk "NR > $(compgen -A alias nux- | wc -l)")
  elif [[ -v ZSH_VERSION ]]; then
    nux_cmds=$(printf '%s\n' ${(kM)functions:#nux-*} ${(kM)commands:#nux-*})
  else
    shell_unsupported
  fi
  (
    while IFS= read -r nux_cmd; do
      if ! nux_cmd_help=$("$nux_cmd" --help 2>/dev/null); then
        echo "The Nux command '$nux_cmd' should support an '--help' option." >&2
        continue
      fi
      if ! [[ $nux_cmd_help =~ Usage:[[:space:]]+nux' ' ]]; then
        echo "The Nux command '$nux_cmd' should correspond to the Nux help format." >&2
        continue
      fi
      echo "${nux_cmd#nux-}$(perl -0pe 's/[[:space:]]*Usage:.*//s' <<< "$nux_cmd_help" > >(sed 's/^/\t/'))"
    done
  ) <<< "$(sort --unique <<< "$nux_cmds")" > >(column --table --separator $'\t')
}

nux-path() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Lookup NIX_PATH prefixes.

Usage:
  nux path <prefix>...
  nux path -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  [[ -n $NIX_PATH ]] || return 1
  local ret=0 prefix found item nix_path
  for prefix in "$@"; do
    found=0
    while IFS= read -rd ':' nix_path; do
      IFS='=' read -r item nix_path <<< "$nix_path"
      if [[ $item == "$prefix" ]]; then
        found=1
        echo "$nix_path"
        break
      fi
    done <<< "$NIX_PATH:"
    (( found )) || ret=1
  done
  return $ret
}

nux-nixos-config() {
  if [[ $1 =~ ^(-h|--help)$ ]]; then
    print_help <<'EOF'
Print the NixOS configuration path.

Usage: nux nixos-config [-h | --help]

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local nixos_config
  if [[ -n $NIXOS_CONFIG ]]; then
    nixos_config=$NIXOS_CONFIG
  elif ! nixos_config=$(nux-path nixos-config); then
    nixos_config=/etc/nixos/configuration.nix
  fi
  echo "$nixos_config"
}

nux-store-path() {
  local help_ret=1 unresolved_flag=0 drv_flag=0
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      while (( $# > 1 )); do
        case $1 in
          --unresolved) unresolved_flag=1;;
          --drv) drv_flag=1;;
          *) break;;
        esac
        shift
      done
      ! (( $# > 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Print the resolved store paths.

Usage:
  nux store-path [--unresolved] [--drv] <store-path-like>...
  nux store-path -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local ret=0 store_path resolved tmp
  for store_path in "$@"; do
    resolved=1
    if [[ $store_path == /nix/store/* ]]; then
      :
    elif [[ $store_path =~ ^[a-z0-9]{32} ]]; then
      (( ${#store_path} == 32 )) &&
      # https://unix.stackexchange.com/questions/198254/make-find-fail-when-nothing-was-found
      { store_path=$(find /nix/store -maxdepth 1 -name "$store_path-*" -print -quit | grep '^') || resolved=0; } ||
      store_path=/nix/store/$store_path
    elif tmp=$(readlink -f "$store_path") && [[ $tmp == /nix/store/* ]]; then
      store_path=$tmp
    elif
      tmp=$(nix-instantiate '<nixpkgs>' --quiet --attr "$store_path" 2>/dev/null) &&
      { (( drv_flag )) || tmp=$(nix-store --query --outputs "$tmp" > >(tail -1) 2>/dev/null); }
    then
      store_path=$tmp
    else
      resolved=0
    fi
    (( ! unresolved_flag && resolved || unresolved_flag && ! resolved )) && echo "$store_path" || ret=1
  done
  return $ret
}

nux-outs() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# == 1 )); then
    print_help $help_ret <<'EOF'
Print the output store paths of the store derivation.

Usage:
  nux outs <store-derivation>
  nux outs -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local store_drv
  store_drv=$(nux-drv "$1") &&
  nix-store --query --outputs "$store_drv"
}

nux-out() {
  local help_ret=1 unresolved_flag=0
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      [[ $1 == --unresolved ]] && unresolved_flag=1 && shift
      ! (( $# > 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Print the main output store path of the derivations.

Usage:
  nux out [--unresolved] <store-path-like>...
  nux out -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local ret=0
  if (( ! unresolved_flag )); then
    local store_path store_paths
    store_paths=$(nux-store-path "$@") || ret=1
    while IFS= read -r store_path; do
      [[ $store_path != *.drv ]] &&
      echo "$store_path" ||
      nix-store --query --outputs "$store_path" > >(tail -1) 2>/dev/null || ret=1
    done <<< "$store_paths"
  else
    local store_path_like store_path
    for store_path_like in "$@"; do
      store_path=$(nux-store-path "$store_path_like") &&
      { [[ $store_path != *.drv ]] || nix-store --query --outputs "$store_path" &>/dev/null; } &&
      ret=1 || echo "$store_path_like"
    done
  fi
  return $ret
}

nux-hash() {
  local help_ret=1 unresolved_flag=0
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      [[ $1 == --unresolved ]] && unresolved_flag=1 && shift
      ! (( $# > 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Print the hash of the store paths.

Usage:
  nux hash [--unresolved] <store-path-like>...
  nux hash -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  nux-out $( (( unresolved_flag )) && echo --unresolved) "$@" > >(sed 's|/nix/store/\([a-z0-9]\{32\}\).*|\1|')
}

nux-drv() {
  local help_ret=1 unresolved_flag=0
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      [[ $1 == --unresolved ]] && unresolved_flag=1 && shift
      ! (( $# > 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Print the derivation of the store paths.

Usage:
  nux drv <store-path-like>...
  nux drv -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local ret=0
  if (( ! unresolved_flag )); then
    local store_path store_paths
    store_paths=$(nux-store-path --drv "$@") || ret=1
    while IFS= read -r store_path; do
      if [[ $store_path == *.drv ]]
      then [[ -e $store_path ]]
      else store_path=$(nix-store --query --deriver "$store_path" 2>/dev/null) && [[ $store_path != unknown-deriver ]]
      fi && echo "$store_path" || ret=1
    done <<< "$store_paths"
  else
    local store_path_like store_path
      for store_path_like in "$@"; do
      store_path=$(nux-store-path --drv "$store_path_like") &&
      if [[ $store_path == *.drv ]]
      then [[ -e $store_path ]]
      else store_path=$(nix-store --query --deriver "$store_path" 2>/dev/null) && [[ $store_path != unknown-deriver ]]
      fi && ret=1 || echo "$store_path_like"
    done
  fi
  return $ret
}

nux-drv-name() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Print the safe version of the derivation names.

Usage:
  nux drv-name <derivation-name>...
  nux drv-name -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local drv_name
  for drv_name in "$@"; do
    drv_name=${drv_name%$'\n'}
    drv_name=$(sed 's/^\.*//' <<< "$drv_name")
    printf '%s' "$drv_name" | tr --complement --squeeze-repeats '+-._?=[:alnum:]' -
  done
}

nux-pkg() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Print the package of the store paths.

Usage:
  nux pkg <store-path-like>...
  nux pkg -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local ret=0 hash result
  while IFS= read -r hash; do
    result=$(nix-locate -1 --at-root / --hash "$hash")
    [[ -n $result ]] && { [[ $result == *.out ]] && echo "${result%.out}" || echo "$result"; } || ret=1
  done < <(nux-hash "$@")
  return $ret
}

nux-which() {
  if [[ $1 =~ ^(-h|--help)$ ]]; then
    print_help <<'EOF'
Print the packages containing the executables.

Usage:
  nux which <executable>...
  nux which -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local exe
  while IFS= read -r exe; do
    nux-pkg "$exe"
  done < <(which "$@")
}

# TODO: Allow looking up multiple package files at the same time.
nux-pkg-file() {
  local help_ret=1 cfg pkg
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! {
      (( $# >= 2 )) && [[ $1 == --configuration ]] && cfg=$2 && shift && shift || cfg=$(nux-nixos-config)
      [[ -e $cfg ]] && cfg="import $cfg" || cfg="'$cfg'"
      (( $# == 1 )) && pkg=$1 && shift
      (( $# == 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Print the file defining the package.

Usage:
  nux pkg-file [--configuration <configuration>] <package>
  nux pkg-file -h | --help

Options:
  --configuration <configuration>  The NixOS configuration used to determine the packages set.
  -h, --help                       Show help message.
EOF
    return
  fi
  local nixpkgs
  if ! nixpkgs=$(nux-path nixpkgs); then
    echo "The prefix 'nixpkgs' could not be found on NIX_PATH, which is needed to locate package files." >&2
    return 1
  fi
  local call_pkg pkg_path
  if
    call_pkg=$(grep -E --ignore-case --max-count=1 --only-matching $'[ \t]'"$pkg = callPackage [^ ]*" "$nixpkgs/pkgs/top-level/all-packages.nix") &&
    pkg_path=$(realpath -e "$nixpkgs/pkgs/top-level/$(sed 's/.*callPackage \(.*\)/\1/' <<< "$call_pkg")")
  then
    [[ -d $pkg_path ]] && echo "$pkg_path/default.nix" || echo "$pkg_path"
  else
    local result
    if
      result=$(nix-instantiate --eval --strict --json --expr '
        with builtins;
        with import <nixpkgs/lib>;
        let
          inherit (import <nixpkgs/nixos> { configuration = '"$cfg"'; }) pkgs;
          pkgPath = splitString "." "'"$pkg"'";
          pkg = getAttrFromPath pkgPath pkgs;
          attrFiles = attrs: map (name: (unsafeGetAttrPos name attrs).file) (attrNames attrs);
          uniqueFiles = unique (attrFiles pkg ++ attrFiles pkg.meta);
          customisationFiles = filter (hasSuffix "/lib/customisation.nix") uniqueFiles;
          nixpkgs = removeSuffix "/lib/customisation.nix" (head customisationFiles);
          isPkgFile = file: !(
            hasPrefix "/nix/store" file ||
            hasPrefix ("${nixpkgs}/lib") file ||
            hasPrefix ("${nixpkgs}/pkgs/build-support") file ||
            hasPrefix ("${nixpkgs}/pkgs/stdenv/generic") file ||
            hasPrefix ("${nixpkgs}/pkgs/stdenv/") file && builtins.match ".*/.*" (removePrefix ("${nixpkgs}/pkgs/stdenv/") file) == null);
          posFile = head (split ":" pkg.meta.position);
          pkgFiles = filter isPkgFile uniqueFiles;
          findSingle = list: default: if length list == 1 then list else default;
        in if !(hasAttrByPath pkgPath pkgs) then [] else if pkg ? meta.position && isPkgFile posFile
          then [ posFile ]
          else if length customisationFiles == 1 && length pkgFiles > 0
            then findSingle pkgFiles (findSingle (filter (file: !(hasPrefix nixpkgs file)) pkgFiles) pkgFiles)
            else []
      ' > >(jq --raw-output '.[]')) && [[ -n $result ]]
    then
      echo "$result"
      (( $(wc -l <<< "$result") == 1 ))
    else
      return 1
    fi
  fi
}

nux-system-pkgs() {
  local help_ret=1 user_name cfg
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! {
      (( $# >= 2 )) && [[ $1 == --user ]] && user_name=$2 && shift && shift || user_name=$(id --user --name)
      (( $# == 1 )) && cfg=$1 && shift || cfg=$(nux-nixos-config)
      (( $# == 0 ))
    }
  then
    print_help $help_ret <<'EOF'
List the system packages.

Usage:
  nux system-pkgs [--user <user-name>] [<configuration>]
  nux system-pkgs -h | --help

Options:
  --user <user-name>  Include the system packages of this user.
  -h, --help          Show help message.
EOF
    return
  fi
  nix-instantiate --eval --strict --json --expr '
    map (pkg: pkg.name) (with import <nixpkgs/nixos> { configuration = '"$cfg"'; }; with pkgs.lib;
      config.environment.systemPackages ++ optionals (config.users.users ? "'"$user_name"'") config.users.users."'"$user_name"'".packages)
    ' > >(jq --raw-output 'unique | sort_by(ascii_downcase) | .[]')
}
