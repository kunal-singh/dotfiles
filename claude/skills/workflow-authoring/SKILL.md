---
name: workflow-authoring
description: Use when authoring, launching, or debugging a multi-agent Workflow script, fanning out subagents in parallel, orchestrating N agents over independent units of work, deciding whether a task needs a Workflow at all, or when a running workflow is stalling, "running" but producing no files, or burning tokens with nothing landed. Fire on parallel agent work even when the word "workflow" is never said — this covers scope calibration, retry vs decompose, prompt budgets, health checks, and file-contention ownership.
---

# Authoring Multi-Agent Workflows

A Workflow is a script that dispatches many `agent()` calls, in parallel, over independent
units of work. It buys fan-out and structured results. It costs a lot of tokens, and it fails
in ways a single agent doesn't — mostly silently. Every rule below is here because it already
cost real time; the evidence is kept alongside it.

## First: do you actually need a Workflow?

**The trigger for a Workflow is fan-out — N genuinely independent units you want running at
once.** N is roughly 5+ before the harness pays for itself.

If the work is a short sequential chain (agent B needs A's output, C needs B's), use plain
background subagents and sequence them yourself. You keep the transcripts in view, you can
course-correct between steps, and you skip the whole class of harness failures below.

A mistake worth not repeating: a 3-agent sequential chain got wrapped in a Workflow purely to
reuse the retry helper. The retry helper is 40 lines of JavaScript. It was not worth the
harness.

| Shape | Use |
|---|---|
| 1 unit, or a chain of 2–4 dependent steps | Background subagents, sequenced by you |
| N ≥ 5 independent units, same shape | Workflow |
| N independent units, each needing your judgment on its output | Subagents in waves |

## The two failure modes — the distinction that matters most

They look identical from outside: a workflow reporting "running" and producing nothing. They
have **opposite** fixes, and applying the wrong one makes it worse.

| | **Transient failure** | **Oversized scope** |
|---|---|---|
| Cause | Connection closed mid-response | Agent given more work than fits one run |
| Tell | Died *after* real progress — files on disk | Never writes anything; Read/Bash climb while Write/Edit stays 0 |
| `agent()` returns | `null` (it does **not** throw) | `null`, or a report describing files that don't exist |
| Fix | **Retry**, resuming from partial work | **Decompose.** Kill the run |
| Wrong fix costs | — | Retry multiplies the waste by `tries` |

The cautionary tale: 8 agents, each handed a whole subsystem plus a long reading list →
**47 dispatches, ~14 MB of transcripts, ZERO files written** over ~2 hours. The retry wrapper
faithfully re-ran agents that could never finish. The most active agent had 36 Bash + 16 Read
calls and 0 Writes. Re-run with one-unit-per-agent scoping: **114 files, first attempt.**

Retry and scope are independent fixes. You need both, applied to the right thing.

## Scope each agent to ONE unit it can finish in one run

The highest-leverage rule. An authoring agent must produce **files**, not understanding.

- One service / class / module / file-group per agent. "Author `ChatSessionService`", never
  "author the chat module".
- **Name the 2–4 specific files it should read, with paths pre-resolved.** A reading list the
  agent must explore in order to understand is not context — it's a second task hidden inside
  the first, and it's what eats the whole run.
- If a unit genuinely needs broad context, split it in two stages: one agent emits a short
  interface sketch, later agents implement against that sketch.

**Calibration — tokens per agent, measured across five real workflows:**

| Workflow | Agents | Tokens | Avg/agent | Outcome |
|---|---|---|---|---|
| Primitives | 18 | 1.96 M | 109 k | healthy |
| Repair pass | 6 | 0.61 M | 102 k | healthy |
| Core package | 12 | 3.66 M | **305 k** | completed, but agents were doing too much |
| Infra | 14 | 3.65 M | 261 k | 2 lost reports |
| Services (rescoped) | 23 | 3.90 M | 170 k | healthy |

**~100–150 k tokens/agent is the healthy band.** Above ~250 k the unit is too big — split it
before running, not after it fails. Note the shape: more agents at smaller scope came out
cheaper than fewer agents at larger scope.

## Enforce a prompt budget, and refuse to raise it

```js
const MAX_PROMPT_CHARS = 12000
function assertScopeBudget(label, prompt) {
  if (prompt.length > MAX_PROMPT_CHARS) throw new Error(`SCOPE BUDGET EXCEEDED for "${label}"…`)
}
```

Prompt size is the earliest available proxy for task size, and checking it costs nothing —
the throw happens before a single token is spent.

When it fires, **decompose the task**. Raising the ceiling to make it pass defeats the
instrument; you've deleted your only pre-flight signal and you'll rediscover the same problem
two hours later having paid for it.

## `agent()` resolves `null` on failure — it does not throw

This is the quiet one. A terminal API error makes `agent()` resolve `null`, so an unguarded
`await agent(...)` lets a stage "succeed" having written nothing. Nothing fails. The gap
surfaces much later as a missing artifact — one program lost its keystone route manifest this
way and only found out at the final gate, with several phases built on top of the hole.

- Wrap every authoring stage in `retryAgent` (see [Bundled helper](#bundled-helper)).
- **Retry N times (3 is a good default), then THROW.** Never let a `null` flow into a
  downstream stage: a later phase building on a missing input corrupts more than it reports.
- The retry prompt must say *a previous attempt may have left partial work on disk; read it,
  keep what's correct, continue* — never restart, never create a second slightly-different copy.

## Tell agents to write incrementally

Instruct every authoring agent to **land each file as it finishes**, and to write its first
file within the first few tool calls. This is what makes retry cheap: a crash becomes
resumable progress instead of lost work. Retry is only affordable because partial work
survives.

**Corollary, observed repeatedly: an agent that dies usually finished its writes and lost only
its report.** Check the disk before re-running anything. In one workflow, two "failed"
repository agents had written every single file.

## Health-check ~20 minutes in, and kill early

Do not trust the "running" status. Run this against the workflow's transcript directory:

```bash
for f in agent-*.jsonl; do
  w=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$f" | rg -c "^(Write|Edit)$")
  r=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$f" | rg -c "^(Read|Bash)$")
  echo "writes=$w reads=$r"
done | sort | uniq -c
```

**Write/Edit at 0 while Read/Bash is high ⇒ scope is too large ⇒ kill it now.** Those agents
are not close to writing; every extra minute is pure burn. Healthy looks like `writes=2
reads=22` within the first few minutes.

Two refinements, both learned by getting them wrong:

**Check `last-activity`, not just the counters.** An agent at `writes=0 reads=40` whose
transcript was touched *seconds* ago is working, not stalled — some units legitimately read a
lot before the first write (a family importing sibling-authored code, say). The stall signature
is high reads **plus** a transcript that hasn't moved in many minutes. Add
`stat -f %m` (or `%Y` on GNU) to the loop and print the age.

**Do not poll with a foreground `sleep`.** A blocking `sleep` that hits its own timeout can send
an interrupt that propagates to the running subagents and kills them mid-file — the workflow
then re-dispatches, and you pay for the same unit two or three times. In one run this killed 16
of 26 agents and produced 4 dispatches of a single task over 52 minutes, none of it visible as a
"retry" because the retry wrapper never fired. Wait on the workflow's own completion
notification, and check in only occasionally with a short, non-blocking command. Polling
frequently is not free — it is the one health-check that can cause the failure it's looking for.

## The orchestrator owns contended files

When N agents write sibling directories in parallel, any shared file is a race: `package.json`,
build configs, barrels, composition roots, route manifests, registries. In one run only 1 of
14 domains got its `exports` entry — each agent assumed another would do it.

Individual agents write **only inside their own directory**. One dedicated stage (or the
orchestrator) wires shared manifests in a single pass at the end. Say this explicitly in every
agent prompt, or they will helpfully edit it anyway.

**The deeper version — it isn't only shared files, it's shared *responsibility*.** Two routes
were mounted by nobody: agent A deferred them to agent B because their keys grouped that way;
agent B never saw them because their URLs grouped differently. Both agents were individually
reasonable. Both reported success. The routes were absent, and would have surfaced as a 404
two phases later.

No sum of per-agent self-reports can catch this — each agent's report is locally true. The only
thing that catches it is **an orchestrator-run mechanical set difference against a contract of
record** (the route table, the file inventory, the spec's list of units) run *after* the
fan-out. Build that contract before you launch, so you have something to diff against.

## Verify stages earn their cost — if you give them a checklist

Verifier agents repeatedly caught real defects that would otherwise have reached the gate: a
missing manifest, 13 unwired subpaths (silently dead code), raw errors leaking
provider-controlled strings across a service boundary.

Keep them — but they're agents too, and the scope rule applies. Give a verifier a **specific
checklist**, not "audit this package". Two verifiers with sharp lists beat one with a vague
mandate. For mechanical checks (greps, inventories, set differences), one is enough.

## Structured output, then verify on disk

Use the `schema` option so agents return validated objects rather than prose. Then:

- `.filter(Boolean)` before using any `parallel` / `pipeline` result array — nulls are in there.
- Never infer success from a report. **Verify on disk** (`ls`, `rg`, a typecheck).

Reports and reality diverge in *both* directions: agents have reported files they never wrote,
and written files they never reported.

## Gates belong to the orchestrator

Agents must not run installs, typechecks, or builds. They're slow, they race each other, and an
agent's local "it compiles" says nothing about the package as a whole. The orchestrator runs
the gate once, after the workflow lands. Tell agents this explicitly or they'll try.

Scope the gate to what changed (per-package typecheck, not workspace-wide) — a repo-wide gate
in a codebase with a pre-existing error backlog produces noise, not signal.

## Concurrency is not a cost lever

Lowering the concurrency cap does **not** reduce token spend — the same agents run, just queued
longer. Cost is `agents × tokens-per-agent`. The levers are **scope** and **avoided rework**.
Confirmed by the calibration table: one workflow spent ~2× another's tokens with a third fewer
agents, at identical concurrency.

## A shared lessons ledger pays for itself

Give agents an append-only `LESSONS.md`: read on start, append on finish. It measurably reduced
repeat defects — a library-version trap and an ORM type trap were each hit once, recorded, then
avoided by every later phase. Agents contributed most entries themselves, several catching bugs
the orchestrator hadn't seen.

Keep it **short** — every agent reads it, so its size is a per-agent tax. Entries in
`Symptom / Rule / Why` form stay actionable; narrative entries rot.

## Make agents research pinned third-party APIs

Require a documentation lookup before any agent uses a third-party API not already verified
against the version installed *here*, and require cross-checking the answer against that
installed version. The pattern to watch for: **the newest documented API is often not the
pinned one.** This caught a major-version function relocation (~60 deprecations), a validator
that silently changed from permissive to exhaustive, and an ORM type that genuinely rejects the
obvious input shape.

## Bundled helper

`scripts/workflow-retry-helper.js` holds the canonical `assertScopeBudget` + `retryAgent`
block. **Workflow scripts have no module system — no `import`, no `require`** — so it's a copy
source, not a module: paste the text between the `COPY FROM HERE` / `COPY TO HERE` markers
verbatim into the top of the script body, after `meta`. Keeping the canonical text in one
place means a fix lands once and gets copied forward into every script that follows.

## Pre-flight checklist

- [ ] Fan-out is real (N ≥ ~5 independent units) — otherwise use plain subagents
- [ ] Every authoring agent has ONE unit of work
- [ ] Every prompt names its 2–4 specific reads, paths pre-resolved
- [ ] `assertScopeBudget` present; no prompt over the ceiling, and the ceiling wasn't raised
- [ ] `retryAgent` wraps every authoring stage; hard-blocks after N
- [ ] Agents told to write incrementally and to check for partial work first
- [ ] Contended files (manifests, barrels, composition roots) owned by ONE stage
- [ ] A contract of record exists to set-difference against after the fan-out
- [ ] Agents told to read + append the lessons ledger
- [ ] Research policy in the prompt for unverified third-party APIs
- [ ] Verify stages have specific checklists, not vague mandates
- [ ] Agents told NOT to run install / typecheck / build
- [ ] A plan for the ~20-minute health check — via the completion notification, NOT a
      foreground `sleep` loop that can interrupt the agents you're checking on
