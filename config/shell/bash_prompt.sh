# https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html
prompt() {
  # http://askubuntu.com/questions/24358/how-do-i-get-long-command-lines-to-wrap-to-the-next-line
  # \[ \] are necessary otherwise column counting will be off.

  # http://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash
  # http://stackoverflow.com/questions/19943482/configure-shell-to-always-print-prompt-on-new-line-like-zsh
  local newline_prompt
  if command -v stty >/dev/null && command -v tput >/dev/null; then
    # Reset the standard input to the terminal.
    exec < /dev/tty

    local stty_settings
    stty_settings=$(stty --save)

    # Raw data, do not echo input, no minimum characters for a complete read.
    stty raw -echo min 0

    # I could not find a document describing the values accepted by `tput`,
    # but they can be reversed engineered by calling `infocmp xterm`.
    # https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_codes
    # Reports the cursor position (CPR)
    tput u7 > /dev/tty

    # -s = secure input - don't echo input if on a terminal
    # -d = delimiter - use the delimiter as data-end rather than newline
    # -a = array - read word-wise into the specified array
    local pos
    IFS=';' read -s -d R -a pos

    local col
    col=$(( ${pos[1]} - 1 ))

    stty "$stty_settings"

    # http://wiki.bash-hackers.org/scripting/terminalcodes
    # 7m = set reserve attribute, reverses the foreground and background
    # 0m = reset all attributes
    if (( col > 0 )); then
      newline_prompt='\[\e[7m\]%\[\e[0m\]\n'
    fi
  fi

  local error_prompt='$(err=$?; (( err == 0 )) || echo "\[\e[1m\][${err}] \[\e[0m\]")'
  local hostname_prompt='@\[\e[4m\]\h\[\e[0m\]'

  # http://stackoverflow.com/questions/6245570/how-to-get-current-branch-name-in-git#19585361
  # The command `git symbolic-ref --short HEAD` is more recently introduced,
  # but it will error when there is no branch name to be had,
  # while this will return HEAD instead.
  # This is faster than the git-prompt script, because that will do a lot of additional checks,
  # and will write error messages to /dev/null just the same.
  local git_branch_prompt
  if command -v git >/dev/null; then
    local git_branch
    git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if test -n "$git_branch"; then
      git_branch_prompt=" [${git_branch}]"
    fi
  fi

  # http://askubuntu.com/questions/16728/hide-current-working-directory-in-terminal#18435
  export PS1="${newline_prompt}╭─╴ ${error_prompt}\u${hostname_prompt} \[\e[0;32m\]\w${git_branch_prompt}\[\e[0m\]\n╰─> "
}

case $- in
  (*r*)
    ;;
  *)
    export PROMPT_COMMAND=prompt
    ;;
esac
