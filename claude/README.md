# Claude Code Setup

Global configuration for Claude Code, managed as dotfiles with symlinks and generated configs.

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- Node.js (via nvm recommended)

## Dependencies

Install these before running the install script.

**Claude Code**
```bash
npm install -g @anthropic-ai/claude-code
```

**envsubst** (for generating claude.json from template)
```bash
brew install gettext
```

Verify both are available:
```bash
claude --version
which envsubst
```

## Structure
```
claude/
├── CLAUDE.md                  # Global instructions injected into every session
├── settings.json              # Permissions, tool behavior, env vars
├── claude.json.template       # MCP server config template (safe to version control)
├── install.sh                 # Sets up symlinks and generates claude.json
└── README.md                  # This file
```

`~/.env` (at dotfiles root, gitignored) holds secrets used to populate the template.

## First-time Setup

**1. Copy the env example and fill in your keys**
```bash
cp ~/dotfiles/.env.example ~/dotfiles/.env
```

Edit `~/dotfiles/.env`:
```bash
CONTEXT7_API_KEY=ctx7sk_your_real_key_here
```

Get your Context7 API key at [context7.com/dashboard](https://context7.com/dashboard). The key is optional — Context7 works without one at lower rate limits.

**2. Run the install script**
```bash
cd ~/dotfiles/claude
chmod +x install.sh
./install.sh
```

This will:
- Symlink `CLAUDE.md` and `settings.json` into `~/.claude/`
- Generate `~/.claude/claude.json` from the template + your `.env`
- Back up any existing files before overwriting

**3. Verify**
```bash
ls -la ~/.claude/
claude mcp list
```

## Updating

After editing any config file, changes to `CLAUDE.md` and `settings.json` are live immediately (symlinked). If you change `claude.json.template` or rotate an API key in `.env`, re-run the install script:
```bash
~/dotfiles/claude/install.sh
```

## Adding a New Machine
```bash
git clone https://github.com/you/dotfiles ~/dotfiles
npm install -g @anthropic-ai/claude-code
brew install gettext
cp ~/dotfiles/.env.example ~/dotfiles/.env
# fill in keys, then:
~/dotfiles/claude/install.sh
```

## MCP Servers

| Server | Transport | Requires Key |
|---|---|---|
| context7 | HTTP (remote) | Yes (optional) |
| sequential-thinking | stdio (npx) | No |
| memory | stdio (npx) | No |

Memory is persisted to `~/.claude/memory.jsonl` across sessions.