#!/usr/bin/env bash
# Blocks npm commands in projects that use pnpm (pnpm-lock.yaml present).

input="$(cat)"
command="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"

if echo "$command" | grep -qE '\bnpm\b' && [ -f "pnpm-lock.yaml" ]; then
  echo '{"decision":"block","reason":"This project uses pnpm (pnpm-lock.yaml detected). Use pnpm instead of npm."}'
  exit 2
fi
