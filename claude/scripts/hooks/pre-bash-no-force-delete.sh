#!/usr/bin/env bash
# Blocks rm -rf / rm -fr commands. Use `trash` instead.

input="$(cat)"
command="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"

if echo "$command" | grep -qE '\brm\b.*-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\b|\brm\b.*-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\b'; then
  echo '{"decision":"block","reason":"rm -rf is blocked. Use `trash <path>` instead (brew install trash)."}'
  exit 2
fi
