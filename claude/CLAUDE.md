## Mindset

- Think before writing code. If ambiguous, state assumptions briefly, then proceed.
- Prefer surgical edits over rewrites unless a rewrite is clearly better.
- Do not repeat context back to me. Skip affirmations.
- Be terse in confirmations. One line is enough.
- **Bias toward action** — decide and move for anything easily reversed; state the assumption.
  Ask before committing to interfaces, data models, architecture, or destructive/write operations.
- **Replace, don't deprecate** — when a new implementation replaces an old one, remove the old one.
  No shims, no dual formats. Flag dead code — it misleads both developers and LLMs.
- **Finish the job** — handle the edge cases you can see, clean up what you touched, flag adjacent
  breakage. Don't invent new scope.

## Code Defaults

- Prefer explicit over clever.
- ≤100 lines/function, cyclomatic complexity ≤8, ≤5 positional params, 100-char line limit.
- No commented-out code — delete it. Comment *why*, never *what*.
- Write tests only when asked. When you do: test behavior not implementation, test edges and
  errors, mock only boundaries (network, filesystem, external services).
- **Zero warnings policy** — fix every warning from every tool. If truly unfixable, add an inline
  ignore with a justification comment. Clean output is the baseline.

## Error Handling

- Fail fast with clear, actionable messages.
- Never swallow exceptions silently.
- Include context: what operation, what input, suggested fix.

## Tool Use

- Explore before editing. Read relevant files first, don't assume structure.
- Don't make more than one speculative edit. If uncertain, ask a single focused question.
- Batch related file reads into one tool call where possible.
- Prefer `mcp__exa__web_search_exa` over WebSearch for all web searches.
- `rg` over grep · `fd` over find · `jq` for JSON in shell · `shellcheck` before finalizing scripts.

## Workflow

**Before committing:**
1. Re-read changes for unnecessary complexity, redundant code, unclear naming.
2. Run relevant tests (not the full suite).
3. Run linters and type checker — fix everything before committing.

**Commits** — imperative mood, ≤72 char subject, one logical change per commit.
Never amend/rebase commits already on shared branches. Never push directly to main.

**PRs** — describe what the code does now, not discarded approaches. Plain, factual language.

## Memory Protocol

### Session Start
Call `mcp__memory__search_nodes` with the current task topic before starting work.
Do NOT load the full graph — search only for relevant entities.

### During Session
Save to MCP memory (without asking) when:
- An architecture or tech stack decision is made
- A bug is fixed after non-trivial debugging (include what failed + why)
- A pattern or convention is established for this project

Do NOT save: things already in CLAUDE.md, transient outputs, anything auto-memory captures.

### Ownership
- **CLAUDE.md** — hard rules, conventions, things that must never change
- **MCP memory** — decisions with reasoning, cross-session history, "why we did X"
- **Auto memory (MEMORY.md)** — patterns Claude observed; leave it alone
