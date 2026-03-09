#!/usr/bin/env bash
# Runs shellcheck on .sh files after Write or Edit.

input="$(cat)"
file_path="$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)"

# Only run on .sh files
[[ "$file_path" != *.sh ]] && exit 0

# Skip if shellcheck not installed
command -v shellcheck &>/dev/null || exit 0

output="$(shellcheck "$file_path" 2>&1)"
status=$?

if [ $status -ne 0 ]; then
  echo "{\"decision\":\"block\",\"reason\":\"shellcheck found issues in $file_path:\n$output\"}"
  exit 2
fi
