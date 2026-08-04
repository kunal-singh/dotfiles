#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SOURCE="$DOTFILES_DIR"
CLAUDE_TARGET="$HOME/.claude"

echo "==> Setting up ~/.claude..."
mkdir -p "$CLAUDE_TARGET"

# Symlink safe files
for file in CLAUDE.md settings.json statusline-command.sh; do
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

# Copy hook scripts and lib
mkdir -p "$CLAUDE_TARGET/scripts/hooks"
cp "$CLAUDE_SOURCE/scripts/hooks/post-edit-quality-gate.js" "$CLAUDE_TARGET/scripts/hooks/"
cp -r "$CLAUDE_SOURCE/scripts/hooks/lib" "$CLAUDE_TARGET/scripts/hooks/"
cp "$CLAUDE_SOURCE/scripts/hooks/"*.sh "$CLAUDE_TARGET/scripts/hooks/"
chmod +x "$CLAUDE_TARGET/scripts/hooks/"*.sh
echo "Copied: hooks (post-edit-quality-gate + lib + bash guards) -> $CLAUDE_TARGET/scripts/hooks/"

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


# Symlink skills into ~/.claude/skills/ (one symlink per skill subdirectory)
SKILLS_SRC="$CLAUDE_SOURCE/skills"
SKILLS_DEST="$CLAUDE_TARGET/skills"
if [ -d "$SKILLS_SRC" ]; then
  mkdir -p "$SKILLS_DEST"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    skill_src="${skill_dir%/}"  # strip trailing slash so ln -sf targets the dir, not inside it
    dest_link="$SKILLS_DEST/$skill_name"
    if [ -d "$dest_link" ] && [ ! -L "$dest_link" ]; then
      mv "$dest_link" "${dest_link}.backup.$(date +%s)"
      echo "Backed up existing skill: $skill_name"
    fi
    ln -sfn "$skill_src" "$dest_link"
    echo "Linked skill: $dest_link -> $skill_src"
  done
fi

# ── workmux status hooks + skills ───────────────────────────────────────────
# Installs agent status-tracking hooks (into ~/.claude/settings.json — a symlink
# back into this repo) and the bundled worktree/merge/coordinator skills.
# `workmux setup` needs a PTY, so wrap it with script(1) and feed the y/n prompt.
# Idempotent: skips when the workmux hook is already present in settings.json.
if command -v workmux &>/dev/null; then
  SETTINGS="$CLAUDE_TARGET/settings.json"
  if [ -f "$SETTINGS" ] && jq -e '.. | strings | select(test("workmux set-window-status"))' \
       "$SETTINGS" &>/dev/null; then
    echo "workmux hooks already configured"
  else
    echo "Installing workmux status hooks..."
    printf 'y\n' | script -q /dev/null workmux setup --hooks >/dev/null
  fi
  echo "Installing workmux skills..."
  printf 'y\n' | script -q /dev/null workmux setup --skills >/dev/null
else
  echo "workmux not found on PATH — run editor/install.sh first for status tracking"
fi

# ── CLI tools ─────────────────────────────────────────────────────────────────

for pkg in ripgrep fd jq shellcheck pipx; do
  if ! brew list "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    brew install "$pkg"
  else
    echo "$pkg already installed"
  fi
done

# Install cocoindex-code for semantic code search MCP
if ! command -v ccc &>/dev/null; then
  echo "Installing cocoindex-code..."
  pipx install cocoindex-code
else
  echo "Upgrading cocoindex-code..."
  pipx upgrade cocoindex-code
fi

# Install cocoindex-code skill for Claude Code (provides ccc slash commands)
echo "Installing cocoindex-code skill..."
npx -y skills add cocoindex-io/cocoindex-code --yes --global

# Install Matt Pocock's engineering skills (triage, to-prd, prototype, etc.).
# Excludes tdd/diagnose/review/write-a-skill — the Superpowers plugin already
# provides test-driven-development/systematic-debugging/*-code-review/writing-skills,
# so we keep one copy of each capability.
echo "Installing Matt Pocock skills..."
npx -y skills add mattpocock/skills --global --agent claude-code --yes --skill \
  caveman design-an-interface edit-article git-guardrails-claude-code grill-me \
  grill-with-docs handoff improve-codebase-architecture migrate-to-shoehorn \
  obsidian-vault prototype qa request-refactor-plan scaffold-exercises \
  setup-matt-pocock-skills setup-pre-commit teach to-issues to-prd triage \
  ubiquitous-language writing-beats writing-fragments writing-shape zoom-out

# ── Plugin marketplaces ───────────────────────────────────────────────────────
# Marketplace registrations live in ~/.claude/plugins/known_marketplaces.json,
# which is machine-local and not tracked here — so re-register on each install.
# Enabled/disabled state persists via settings.json (symlinked into this repo).
# Both subcommands are non-interactive and no-op when already present.

echo "Registering plugin marketplaces..."
claude plugin marketplace add DietrichGebert/ponytail || \
  echo "WARNING: could not add ponytail marketplace"
claude plugin install ponytail@ponytail || \
  echo "WARNING: could not install ponytail plugin"

echo ""
echo "Plugin marketplace (kunal-singh-plugins) should already be registered."
echo "Check with: cat ~/.claude/plugins/known_marketplaces.json | grep kunal"
echo "If missing: /plugin marketplace add kunal-singh-plugins"
echo ""
echo "Done. Verify with: ls -la ~/.claude/"
