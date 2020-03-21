setopt prompt_subst

git_branch_prompt() {
  local git_branch
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n $git_branch ]]; then
    echo -n " [${git_branch}]"
  fi
}

hostname_prompt() {
  echo -n '@%U%m%u'
}

export PROMPT='%B%(?..[%?] )%b%n$(hostname_prompt)> '
export RPROMPT='%F{green}%~$(git_branch_prompt)%f'
