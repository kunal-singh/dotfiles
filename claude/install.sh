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

# Symlink individual skill directories (symlinking the parent dir breaks discovery)
SKILLS_SRC="$CLAUDE_SOURCE/skills"
SKILLS_DEST="$CLAUDE_TARGET/skills"
if [ -d "$SKILLS_SRC" ]; then
  mkdir -p "$SKILLS_DEST"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    dest_skill="$SKILLS_DEST/$skill_name"
    if [ -d "$dest_skill" ] && [ ! -L "$dest_skill" ]; then
      mv "$dest_skill" "${dest_skill}.backup.$(date +%s)"
      echo "Backed up existing skills/$skill_name"
    fi
    ln -sfn "$skill_dir" "$dest_skill"
    echo "Linked: $dest_skill -> $skill_dir"
  done
fi

# Generate claude.json from template + .env
TEMPLATE="$CLAUDE_SOURCE/claude.json.template"
ENV_FILE="$(dirname "$DOTFILES_DIR")/.env"
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