#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SOURCE="$DOTFILES_DIR/claude"
CLAUDE_TARGET="$HOME/.claude"

echo "==> Setting up ~/.claude..."
mkdir -p "$CLAUDE_TARGET"

for file in CLAUDE.md claude.json; do
  src="$CLAUDE_SOURCE/$file"
  dest="$CLAUDE_TARGET/$file"
  if [ -f "$src" ]; then
    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
      mv "$dest" "${dest}.backup.$(date +%s)"
      echo "Backed up existing $file"
    fi
    ln -sf "$src" "$dest"
    echo "Linked: $dest -> $src"
  fi
done

echo "Done. Verify with: ls -la ~/.claude/"