#!/usr/bin/env bash
# Blocks direct git push to main or master. Use feature branches.

input="$(cat)"
command="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"

if echo "$command" | grep -qE '\bgit\s+push\b' && echo "$command" | grep -qE '\b(main|master)\b'; then
  echo '{"decision":"block","reason":"Direct push to main/master is blocked. Use a feature branch and open a PR."}'
  exit 2
fi
