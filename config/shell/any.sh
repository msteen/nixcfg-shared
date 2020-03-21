shell_unsupported() {
  echo "Only bash and zsh are supported." >&2
  return 1
}

is_command_or_function() {
  if [[ -v BASH_VERSION ]]; then
    [[ $(type -t "$1") =~ ^(file|function)$ ]]
  elif [[ -v ZSH_VERSION ]]; then
    local ty=$(whence -w "$1")
    [[ ${ty##* } =~ ^(command|function)$ ]]
  else
    shell_unsupported
  fi
}

is_command() {
  if [[ -v BASH_VERSION ]]; then
    [[ $(type -t "$1") == 'file' ]]
  elif [[ -v ZSH_VERSION ]]; then
    local ty=$(whence -w "$1")
    [[ ${ty##* } == 'command' ]]
  else
    shell_unsupported
  fi
}

is_function() {
  if [[ -v BASH_VERSION ]]; then
    [[ $(type -t "$1") == 'function' ]]
  elif [[ -v ZSH_VERSION ]]; then
    local ty=$(whence -w "$1")
    [[ ${ty##* } == 'function' ]]
  else
    shell_unsupported
  fi
}

in_array() {
  local -r needle=$1
  shift
  local elem
  for elem in "$@"; do
    if [[ $elem == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

fix() {
  if (( $# < 2 )); then
    echo "Usage: fix <command> <arg>..." >&2
    return 1
  fi
  local cmd=$1
  shift
  local ret=0 out prev_out args=( "$@" )
  while { out=$("$cmd" "${args[@]}") || { ret=$?; false; }; } && [[ $out != "$prev_out" ]]; do
    args=()
    while IFS= read -r arg; do
      args+=( "$arg" )
    done <<< "$out"
    (( ${#args} > 0 )) || return 1
    prev_out=$out
  done
  [[ -n $prev_out ]] && echo "$prev_out"
  return $ret
}

fargs() {
  local stdin_delim=$'\n' show_help=0
  while true; do
    case $1 in
      -0|--null)
        stdin_delim=
        ;;
      --)
        shift
        break
        ;;
      -*)
        show_help=1
        break
        ;;
      *)
        break
        ;;
    esac
    shift
  done
  if (( show_help )) || (( $# == 0 )); then
    echo "Usage: fargs [-0 | --null] [--help] <shell_function> [arg]..." >&2
    return
  fi
  local stdin_args=()
  while IFS= read -r -d "$stdin_delim" arg; do
    stdin_args+=( "$arg" )
  done < /dev/stdin
  (( ${#stdin_args} == 0 )) && return
  "$@" "${stdin_args[@]}"
}

# Some commands get expanded in the process list, others not,
# so we equate this by explicitly expanding them all before calling them.
already_spawned() {
  pgrep -cfx "$*" > /dev/null 2>&1 || {
    set -- $(command -v "$1") "${@:2}"
    pgrep -cfx "$*" > /dev/null 2>&1
  }
}

spawn_once() {
  if ! already_spawned "$@"; then
    # https://superuser.com/questions/172043/how-do-i-fork-a-process-that-doesnt-die-when-shell-exits/172476#172476
    ( setsid "$@" & )
  fi
}

print_help() {
  if ! (( $# <= 2 )); then
    print_help 1 <<'EOF'
Show help message from standard input.

Usage: print_help [<return>] (<message> | [-])
EOF
    return 1
  fi
  local ret msg
  if (( $# == 2 )); then
    ret=$1
    msg=$2
  elif (( $# == 0 )); then
    ret=0
    msg=$(< /dev/stdin)
  elif [[ $1 =~ ^[0-9]+$ ]]; then
    ret=$1
    msg=$(< /dev/stdin)
  else
    ret=0
    msg=$1
  fi
  (( ret == 0 )) && echo "$msg" || echo "$msg" >&2
  return $ret
}

tofu() {
  python -c 'print "0" * 52'
}
