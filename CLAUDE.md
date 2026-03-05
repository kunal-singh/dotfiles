# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal dotfiles repo for macOS. It manages two things:
1. **Claude Code global config** (`claude/`) — CLAUDE.md, settings.json, and MCP servers, installed via symlinks.
2. **Editor tooling** (`editor/`) — Ghostty terminal and tmux configs, installed via symlinks.

## Install Scripts

Each subdirectory has its own `install.sh`. Run them from the repo root or from within the subdirectory:

```bash
# Claude Code setup (symlinks + MCP config generation)
./claude/install.sh

# Editor setup (Ghostty + tmux symlinks, zsh snippet)
./editor/install.sh
```

Both scripts are idempotent and back up existing files before overwriting.

## Architecture

### `claude/`
- `CLAUDE.md` → symlinked to `~/.claude/CLAUDE.md` (global instructions for every session)
- `settings.json` → symlinked to `~/.claude/settings.json` (permissions, env vars, statusLine config)
- `statusline-command.sh` → symlinked to `~/.claude/statusline-command.sh` (statusLine script: shows cwd, model, context % in Claude Code terminal)
- `claude.json.template` → processed with `envsubst` from `~/.env` (at repo root, gitignored), merged into `~/.claude.json` (MCP server config)
### `editor/`
- `ghostty/config` → symlinked to `~/.config/ghostty/config`
- `tmux/tmux.conf` → symlinked to `~/.tmux.conf`
- `install.sh` also writes `~/.config/zsh/tmux-attach.zsh` and adds a source line to `~/.zshrc` for auto-attaching to a tmux session named `main` when opening Ghostty

### Secrets
`~/.env` at the repo root holds API keys (gitignored). `envsubst` substitutes `${VAR}` patterns in `claude.json.template` during install. A `.env.example` should be kept for onboarding new machines.

## MCP Servers (configured in `claude.json.template`)
- `context7` — HTTP remote, requires `CONTEXT7_API_KEY` in `.env` (optional at lower rate limits)
- `sequential-thinking` — stdio via npx, no key required
- `memory` — stdio via npx, persists to `~/.claude/memory.jsonl`

## Adding a New Skill
Skills are managed via the `kunal-singh-plugins` marketplace (see `kunal-singh/claude-code-plugins`). This repo no longer manages skills directly.

## Prerequisites
- macOS, Homebrew
- `npm install -g @anthropic-ai/claude-code`
- `brew install gettext` (for `envsubst`)
- `jq` (for MCP config merging in `install.sh`)
