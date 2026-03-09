#!/usr/bin/env bash
# Blocks bare grep/find commands. Use rg (ripgrep) and fd instead.

input="$(cat)"
command="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"

if echo "$command" | grep -qE '(^|[|;&\s])\s*grep\b'; then
  echo '{"decision":"block","reason":"Use `rg` (ripgrep) instead of grep — faster, gitignore-aware, better output."}'
  exit 2
fi

if echo "$command" | grep -qE '(^|[|;&\s])\s*find\b'; then
  echo '{"decision":"block","reason":"Use `fd` instead of find — faster, gitignore-aware, cleaner UX."}'
  exit 2
fi
