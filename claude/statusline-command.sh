#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
cwd="${cwd/#$HOME/~}"

parts=()

[ -n "$cwd" ] && parts+=("$(printf '\033[34m%s\033[0m' "$cwd")")
[ -n "$model" ] && parts+=("$(printf '\033[33m%s\033[0m' "$model")")
if [ -n "$used" ]; then
  used_int=${used%.*}
  if [ "$used_int" -ge 80 ]; then
    parts+=("$(printf '\033[31mctx:%s%%\033[0m' "$used_int")")
  elif [ "$used_int" -ge 50 ]; then
    parts+=("$(printf '\033[33mctx:%s%%\033[0m' "$used_int")")
  else
    parts+=("$(printf '\033[32mctx:%s%%\033[0m' "$used_int")")
  fi
fi

printf '%s' "$(IFS=' | '; echo "${parts[*]}")"
