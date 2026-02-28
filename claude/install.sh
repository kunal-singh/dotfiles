#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SOURCE="$DOTFILES_DIR/claude"
CLAUDE_TARGET="$HOME/.claude"

echo "==> Setting up ~/.claude..."
mkdir -p "$CLAUDE_TARGET"

# Symlink safe files
for file in CLAUDE.md settings.json; do
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

# Generate claude.json from template + .env
TEMPLATE="$CLAUDE_SOURCE/claude.json.template"
ENV_FILE="$DOTFILES_DIR/.env"
DEST="$CLAUDE_TARGET/claude.json"

if [ -f "$TEMPLATE" ]; then
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi

  # Substitute ${VAR} and $VAR patterns from environment
  generated="$(envsubst < "$TEMPLATE")"

  # Warn if any placeholders remain unresolved
  if echo "$generated" | grep -qE '\$\{[A-Z_]+\}'; then
    echo "WARNING: Unresolved variables in claude.json — check your .env file"
  fi

  if [ -f "$DEST" ] && [ ! -L "$DEST" ]; then
    mv "$DEST" "${DEST}.backup.$(date +%s)"
    echo "Backed up existing claude.json"
  fi

  echo "$generated" > "$DEST"
  echo "Generated: $DEST from template"
else
  echo "No claude.json.template found, skipping MCP config"
fi

echo ""
echo "Done. Verify with: ls -la ~/.claude/"