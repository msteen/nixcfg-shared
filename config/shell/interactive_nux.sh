
if [[ -v ZSH_VERSION ]]; then
  _zsh_nux() {
    if (( CURRENT != 2 )); then
      _default
      return 0
    fi

    local commands=() cmd
    while IFS= read -r line; do
      if [[ $line =~ ^' ' ]]; then
        cmd+=$'\n'$line
      else
        if [[ -n $cmd ]]; then commands+=( "$cmd" ); fi
        cmd=$(sed 's/ \+/:/' <<< "$line")
      fi
    done < <(nux-list)
    if [[ -n $cmd ]]; then commands+=( "$cmd" ); fi
    _describe 'commands' commands
  }
  compdef _zsh_nux nux
fi

if [[ -v BASH_VERSION ]]; then
  _bash_nux() {
    COMPREPLY=()

    if (( COMP_CWORD != 1 )); then
      if [[ -v COMPLETION_DISPLAY_WIDTH ]]; then
        bind "set completion-display-width $COMPLETION_DISPLAY_WIDTH"
        unset -v COMPLETION_DISPLAY_WIDTH
      fi
      return 0
    fi

    local -A cmds
    local cmd desc
    while IFS= read -r line; do
      if [[ $line =~ ^' ' ]]; then
        desc+=$(sed 's/^ */ /' <<< "$line")
      else
        if [[ -n $desc ]]; then cmds[$cmd]=$desc; fi
        IFS=':' read -r cmd desc < <(sed 's/ \+/:/' <<< "$line")
      fi
    done < <(nux-list)
    if [[ -n $desc ]]; then cmds[$cmd]=$desc; fi

    local matches=( $(compgen -W "${!cmds[*]}" -- "${COMP_WORDS[1]}") )
    (( ${#matches[@]} == 0 )) && return
    (( ${#matches[@]} == 1 )) && COMPREPLY+=( "${matches[@]}" ) && return

    local width=$(bind -v | sed -n 's/^set completion-display-width //p')
    if (( width != 0 )); then
      bind 'set completion-display-width 0'
      PROMPT_COMMAND=PROMPT_COMMAND=$(printf %q "$PROMPT_COMMAND")
      PROMPT_COMMAND+="; bind 'set completion-display-width $width'"
      COMPLETION_DISPLAY_WIDTH=$width
    fi

    local table
    for cmd in "${matches[@]}"; do
      table+="${cmd}"$'\t'"${cmds[$cmd]}"$'\n'
    done
    mapfile -t COMPREPLY < <(column --table --separator $'\t' <<< "$table")
  }
  complete -o bashdefault -o default -F _bash_nux nux
fi

nux-edit-config() {
  if [[ $1 =~ ^(-h|--help)$ ]]; then
    print_help <<'EOF'
Edit the Nix configuration in $EDITOR.
The edits will become undone after rebuilding NixOS.

Usage: nux edit-config [-h | --help]

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  sudo cp /etc/nix/nix.conf{,.tmp} &&
  sudo mv /etc/nix/nix.conf{.tmp,} &&
  sudo $(echo $EDITOR) /etc/nix/nix.conf &&
  sudo systemctl restart nix-daemon
}

nux-grep-store() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Run grep on the Nix store top-level.

Usage:
  nux grep-store <grep-argument>...
  nux grep-store -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local paths sed_expr
  paths=$(grep "$@" --color=never <(find /nix/store -maxdepth 1)) &&
  sed_expr=$(grep "$@" --color=never --line-number <(cut -d '-' -f2- <<< "$paths") > >(paste --serial -d ';' <(awk -F ':' '{ print $1 "p" }'))) &&
  grep "$@" <(sed -n "$sed_expr" <<< "$paths")
}

nux-du() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Summarize the disk usage of the store paths and their requisites.

Usage:
  nux du <store-path-like>...
  nux -h | --help

Options:
  -h, --help  Show help message.
EOF
    return
  fi
  local store_paths
  if ! store_paths=$(nux-out "$@"); then
    echo "The following store paths could not be resolved:" >&2
    nux-out --unresolved "$@" >&2
    return 1
  fi
  du --human-readable --total --summarize $(nix-store --query --requisites $(echo $store_paths)) > >(sort --human-numeric-sort)
}

_nux_call() {
  call=$1
  shift
  if [[ $1 =~ ^(-h|--help)$ ]]; then
    print_help <<EOF
Run \`nix-$call\` for the called package.

Usage:
  nux $call-call <call-package>
  nux $call-call -h | --help

Options:
  -h, --help  Show help message.

Usage
  nux $call-call package.nix
  nux $call-call 'package.nix { arg = value; }'
EOF
    return
  fi
  local pkg_path pkg_args
  if (( $# == 0 )); then
    pkg_path=./.
    pkg_args='{ }'
  else
    for pkg_path in "$@"; do :; done # last argument
    if [[ $pkg_path == *{* ]]; then
      pkg_args={${pkg_path#*\{}
      pkg_path=$(sed 's/\s*{.*//' <<< "$pkg_path")
    else
      pkg_args='{ }'
    fi
    if [[ ! -e $pkg_path ]]; then
      echo "Package file or directory '$pkg_path' does not exist." >&2
      return 1
    fi
    if [[ $pkg_path != */* ]]; then
      pkg_path=./$pkg_path
    fi
  fi
  nix-$call --expr "with import <nixpkgs> { }; callPackage $pkg_path $pkg_args"
}
nux-build-call() { _nux_call build "$@"; }
nux-shell-call() { _nux_call shell "$@"; }

nux-eval() {
  local help_ret=1
  if [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || ! (( $# > 0 )); then
    print_help $help_ret <<'EOF'
Evaluate the Nix expressions with <nixpkgs/nixos> and <nixpkgs/lib> in scope.

Usage:
  nux eval [--configuration <configuration>] <nix-expr>...
  nux eval -h | --help

Options:
  --configuration <configuration>  The NixOS configuration to bring into scope.
  -h, --help                       Show help message.
EOF
    return
  fi
  local configuration
  (( $# > 2 )) && [[ $1 == --configuration ]] && configuration=$2 && shift && shift || configuration=$(nux-nixos-config)
  [[ -e $configuration ]] && configuration="import $configuration" || configuration="'$configuration'"
  local ret=0 arg args=() expr= format=nix
  for arg in "$@"; do
    if [[ -n $expr ]]; then
      if [[ $expr == --json ]]; then
        format=json
      elif [[ $expr == --raw ]]; then
        format=raw
      fi
      args+=( "$expr" )
    fi
    expr=$arg
  done
  if [[ -n $expr ]]; then
    expr=$(nix eval "${args[@]}" "(with import <nixpkgs/nixos> { configuration = $configuration; }; with config.cfglib; $expr)") || return 1
    if [[ $format == nix ]]; then
      echo "$expr"
    elif [[ $format == json ]]; then
      echo "$expr" | jq
    elif [[ $format == raw ]]; then
      echo "$expr"
    fi
  fi
  return 0
}

nux-update-nixpkgs() {
  local help_ret=1 nixpkgs_stable nixpkgs_unstable
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      while (( $# >= 2 )); do
        case $1 in
          --stable) nixpkgs_stable=$2;;
          --unstable) nixpkgs_unstable=$2;;
          *) break;;
        esac
        shift
        shift
      done
      ! (( $# == 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Update the stable and unstable nixpkgs checkouts.

Usage:
  nux update-nixpkgs [--stable <nixpkgs>] [--unstable <nixpkgs>]
  nux update-nixpkgs -h | --help

Options:
  --stable <nixpkgs>    Path to the stable nixpkgs checkout.
  --unstable <nixpkgs>  Path to the stable nixpkgs checkout.
  -h, --help            Show help message.
EOF
    return
  fi
  { [[ -n $nixpkgs_stable ]] || nixpkgs_stable=$(nux-path nixpkgs); } &&
  git -C "$nixpkgs_stable" remote update channels &&
  git -C "$nixpkgs_stable" rebase channels/nixos-"$(< "$nixpkgs_stable"/.version)" &&
  { [[ -n $nixpkgs_unstable ]] || nixpkgs_unstable=$(nux-path nixpkgs-unstable || [[ -d $nixpkgs_stable/../nixpkgs-unstable ]] && echo "$nixpkgs_stable/../nixpkgs-unstable"); } &&
  git -C "$nixpkgs_unstable" rebase channels/nixos-unstable
}

nux-system-diff() {
  local help_ret=1 old_drv new_drv
  if
    [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0 || {
      while (( $# >= 2 )); do
        case $1 in
          --old) old_drv=$(nux-drv $2);;
          --new) new_drv=$(nux-drv $2);;
          *) break;;
        esac
        shift
        shift
      done
      ! (( $# == 0 ))
    }
  then
    print_help $help_ret <<'EOF'
Show the differences between the old and new system derivation.

Usage:
  nux system-diff [--old <system-drv>] [--new <system-drv>]
  nux system-diff -h | --help

Options:
  --old <system-drv>  The old system derivation [default: the current].
  --new <system-drv>  The new system derivation [default: the one to be built].
  -h, --help          Show help message.
EOF
    return
  fi
  if [[ -z $old_drv ]]; then
    old_drv=$(nix-store --query --deriver "$(readlink -e /nix/var/nix/profiles/system)") || return 1
  fi
  if [[ -z $new_drv ]]; then
    new_drv=$(nix-instantiate --quiet '<nixpkgs/nixos>' --attr system) || return 1
  fi
  nix-diff "$old_drv" "$new_drv"
}
