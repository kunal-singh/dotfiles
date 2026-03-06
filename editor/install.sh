#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EDITOR_DIR="$DOTFILES_DIR/editor"

# ── Prerequisites ──────────────────────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew is required. Install from https://brew.sh" >&2
  exit 1
fi

# ── Install packages ───────────────────────────────────────────────────────────

if ! command -v tmux &>/dev/null; then
  echo "Installing tmux..."
  brew install tmux
else
  echo "tmux already installed: $(tmux -V)"
fi

if ! command -v ghostty &>/dev/null && ! [ -d "/Applications/Ghostty.app" ]; then
  echo "Installing ghostty..."
  brew install --cask ghostty
else
  echo "ghostty already installed"
fi

if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  brew install gum
else
  echo "gum already installed: $(gum --version)"
fi

# ── Helper: symlink with optional backup ──────────────────────────────────────

symlink() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    echo "Symlink exists: $dst"
    return
  fi

  if [ -e "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing $dst → $backup"
    mv "$dst" "$backup"
  fi

  ln -s "$src" "$dst"
  echo "Linked: $dst → $src"
}

# ── Symlink configs ────────────────────────────────────────────────────────────

symlink "$EDITOR_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
symlink "$EDITOR_DIR/ghostty/config" "$HOME/.config/ghostty/config"

# ── Write zsh snippet ──────────────────────────────────────────────────────────

ZSH_SNIPPET_DIR="$HOME/.config/zsh"
ZSH_SNIPPET="$ZSH_SNIPPET_DIR/tmux-attach.zsh"

mkdir -p "$ZSH_SNIPPET_DIR"

cat > "$ZSH_SNIPPET" << 'EOF'
# Auto-attach to tmux session 'main' in interactive shells (Ghostty-aware)
if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
  tmux new-session -A -s main
fi
EOF

echo "Written: $ZSH_SNIPPET"

# ── Add source line to ~/.zshrc (idempotent) ───────────────────────────────────

ZSHRC="$HOME/.zshrc"
SOURCE_LINE='[ -f "$HOME/.config/zsh/tmux-attach.zsh" ] && source "$HOME/.config/zsh/tmux-attach.zsh"'

if ! grep -q "tmux-attach" "$ZSHRC" 2>/dev/null; then
  printf '\n# editor/tmux auto-attach\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added tmux-attach source line to $ZSHRC"
else
  echo "tmux-attach already in $ZSHRC"
fi

# ── LSP binaries for Claude Code ──────────────────────────────────────────────

echo "==> Installing LSP binaries..."
npm install -g typescript-language-server typescript
npm install -g pyright

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "Done. Restart your shell or run: source ~/.zshrc"
echo ""
echo "tmux cheatsheet (prefix = Ctrl+a):"
echo "  Ctrl+a c       new window"
echo "  Ctrl+a |       split right"
echo "  Ctrl+a -       split down"
echo "  Ctrl+a h/j/k/l navigate panes"
echo "  Ctrl+a z       zoom/unzoom pane"
echo "  Ctrl+a w       window list"
echo "  Ctrl+a d       detach session"
echo "  Ctrl+a [       scroll mode (q to exit, arrows/PgUp/PgDn)"
