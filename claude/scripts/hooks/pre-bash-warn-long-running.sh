#!/usr/bin/env bash
# Warns when long-running install/build commands are run without run_in_background.
# These commands flood the context window; they should be backgrounded.

input="$(cat)"
command="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"
run_in_background="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('run_in_background','false'))" 2>/dev/null)"

# Already backgrounded — no problem.
if [ "$run_in_background" = "True" ] || [ "$run_in_background" = "true" ]; then
  exit 0
fi

if echo "$command" | grep -qE '(^|[|;&\s])\s*(pnpm|npm|yarn)\s+(install|add|ci|update)\b'; then
  echo '{"decision":"warn","reason":"Long-running install detected. Set run_in_background: true to avoid blocking the context window. Only proceed inline if you need to inspect the output immediately."}'
  exit 0
fi

if echo "$command" | grep -qE '(^|[|;&\s])\s*pip\s+(install|download)\b|(^|[|;&\s])\s*pip3\s+(install|download)\b|(^|[|;&\s])\s*uv\s+(pip\s+)?install\b|(^|[|;&\s])\s*poetry\s+(install|add)\b'; then
  echo '{"decision":"warn","reason":"Long-running Python install detected. Set run_in_background: true to avoid blocking the context window. Only proceed inline if you need to inspect the output immediately."}'
  exit 0
fi

if echo "$command" | grep -qE '(^|[|;&\s])\s*docker\s+(build|compose\s+up|buildx)\b|(^|[|;&\s])\s*docker-compose\s+up\b'; then
  echo '{"decision":"warn","reason":"Long-running Docker build/up detected. Set run_in_background: true to avoid blocking the context window. Only proceed inline if you need to inspect the output immediately."}'
  exit 0
fi

if echo "$command" | grep -qE '(^|[|;&\s])\s*(cargo\s+build|go\s+build|mvn\s+(install|package)|gradle\s+(build|assemble))\b'; then
  echo '{"decision":"warn","reason":"Long-running build command detected. Set run_in_background: true to avoid blocking the context window. Only proceed inline if you need to inspect the output immediately."}'
  exit 0
fi
