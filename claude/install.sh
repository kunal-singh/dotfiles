#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SOURCE="$DOTFILES_DIR"
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

# Merge mcpServers from template into ~/.claude.json (Claude Code's real config file)
TEMPLATE="$CLAUDE_SOURCE/claude.json.template"
ENV_FILE="$(dirname "$DOTFILES_DIR")/.env"
DEST="$HOME/.claude.json"

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

  # Merge mcpServers into ~/.claude.json using jq (preserves existing keys)
  updated="$(jq --argjson mcp "$(echo "$generated" | jq '.mcpServers')" \
    '.mcpServers = $mcp' "$DEST")"
  echo "$updated" > "$DEST"
  echo "Merged mcpServers into $DEST"
else
  echo "No claude.json.template found, skipping MCP config"
fi

echo ""
echo "Plugin marketplace (kunal-singh-plugins) should already be registered."
echo "Check with: cat ~/.claude/plugins/known_marketplaces.json | grep kunal"
echo "If missing: /plugin marketplace add kunal-singh-plugins"
echo ""
echo "Done. Verify with: ls -la ~/.claude/"