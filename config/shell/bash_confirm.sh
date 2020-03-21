#!/usr/bin/env bash
__bc_src=$( (return 2>/dev/null) && echo true || echo false)
__bc_set() {
  if [[ $1 == 'return' ]]; then
    if $__bc_src; then
      __bc_cmd=$1
      shift
    else
      echo "Can only 'return' when the script is sourced." >&2
      return 1
    fi
  elif [[ $1 == 'exit' ]]; then
    __bc_cmd=$1
    shift
  elif ! $__bc_src; then
    __bc_cmd='exit'
  else
    echo "Can both 'return' and 'exit' when the script is sourced, choose one." >&2
    return 1
  fi
  if [[ $1 =~ ^[0-9]+$ ]]; then
    __bc_no=$1
    shift
  else
    __bc_no=1
  fi
  if [[ $1 =~ ^[0-9]+$ ]]; then
    __bc_err=$1
    shift
  else
    __bc_err=1
  fi
  if (( $# == 1 )); then
    __bc_ask=$1
  else
    return 1
  fi
}

__bc_unset() {
  unset -v \
    __bc_src \
    __bc_cmd \
    __bc_no \
    __bc_err \
    __bc_ask \
    __bc_ans
  unset -f \
    __bc_set \
    __bc_unset
}

if __bc_set "$@"; then
  IFS= read -n 1 -r -p "${__bc_ask}? [Y/n] " __bc_ans
  if [[ -n $__bc_ans ]]; then
    echo
  fi
  if [[ $__bc_ans =~ ^(N|n)$ ]]; then
    $(echo "$__bc_cmd" "$__bc_no"; __bc_unset)
  elif ! [[ $__bc_ans =~ ^(Y|y| )$ || -z $__bc_ans ]]; then
    echo "Invalid answer, it should be either Y, y, <SPACE>, or <ENTER> for agreeing; and N or n for disagreeing." >&2
    $(echo "$__bc_cmd" "$__bc_err"; __bc_unset)
  else
    __bc_unset
  fi
else
  echo "Usage: bash_confirm.sh [return|exit] [no_ret] [err_ret] <prompt>" >&2
  __bc_unset
fi
