/**
 * Retry + scope-budget helpers for multi-agent Workflow scripts.
 *
 * PASTE THE BLOCK BELOW verbatim near the top of every Workflow script body
 * (after `meta`). Workflow scripts have no module system — no `import`,
 * no `require` — so this file is a COPY SOURCE, not a module. Keeping the
 * canonical text here means a fix lands once and gets copied forward.
 *
 * ── WHY ──────────────────────────────────────────────────────────────────
 * Two distinct failure modes, two distinct fixes. Do not confuse them:
 *
 * 1. TRANSIENT — "API Error: Connection closed mid-response". `agent()` does
 *    NOT throw on a terminal API error; it resolves **null**. An unguarded
 *    stage therefore "succeeds" having written nothing, and the gap surfaces
 *    much later as a missing artifact (one program lost its keystone route
 *    manifest this way). FIX = `retryAgent` (below).
 *
 * 2. OVERSIZED SCOPE — an agent given too much work never reaches the
 *    authoring phase at all. One phase burned 47 dispatches and ~14 MB of
 *    transcripts across 8 modules and wrote ZERO files: the agents spent
 *    every run reading. Retry makes this WORSE, multiplying the waste by
 *    `tries`. FIX = `assertScopeBudget` + one-unit-per-agent prompts, plus
 *    the mid-run health check.
 *
 * `retryAgent` HARD BLOCKS after `tries` attempts: it throws, which fails the
 * stage loudly instead of letting a null flow downstream and corrupt later
 * phases with half-built inputs. Catch it only if you have a real fallback.
 */

// ---------------------------------------------------------------- COPY FROM HERE
/** Max prompt characters per authoring agent. Above this, DECOMPOSE. */
const MAX_PROMPT_CHARS = 12000

/**
 * Fail fast when a prompt is too large to be a single agent's job. A prompt
 * over the budget is the reliable early signal of the oversized-scope failure
 * mode: it means the task is a subsystem, not a unit. Split it before
 * spending tokens.
 */
function assertScopeBudget(label, prompt) {
  if (prompt.length > MAX_PROMPT_CHARS) {
    throw new Error(
      `SCOPE BUDGET EXCEEDED for "${label}": prompt is ${prompt.length} chars ` +
        `(max ${MAX_PROMPT_CHARS}). This task is a subsystem, not a unit — decompose it ` +
        `into one-unit-per-agent tasks with pre-resolved file paths. ` +
        `Do NOT raise the budget to make this pass.`,
    )
  }
}

const RETRY_NOTE = `

---
**RETRY NOTICE — attempt {N} of {MAX}.** A previous attempt at this exact task was cut off
mid-run by an API connection error. It may have left PARTIAL WORK ON DISK.

Before authoring: \`ls\` and read your target directory. If files from the previous attempt
exist, KEEP what is correct and CONTINUE from where it stopped — do not restart from scratch,
and do not create a second slightly-different copy. Re-read any file that looks truncated
(ends mid-statement, missing its barrel exports) and finish it.

**Write your FIRST file within the first few tool calls.** Do not explore broadly before
writing — a previous attempt at this task died before producing anything. Read only what you
must, author, then refine.`

/**
 * Dispatch an agent, retrying on the null that a terminal API error produces.
 * THROWS after `tries` failures — a hard block, not a silent null.
 */
async function retryAgent(prompt, opts, tries = 3) {
  const label = opts?.label ?? 'agent'
  assertScopeBudget(label, prompt)
  for (let attempt = 1; attempt <= tries; attempt++) {
    const p =
      attempt === 1
        ? prompt
        : prompt + RETRY_NOTE.replace('{N}', String(attempt)).replace('{MAX}', String(tries))
    const result = await agent(p, attempt === 1 ? opts : { ...opts, label: `${label}#r${attempt}` })
    if (result !== null && result !== undefined) {
      if (attempt > 1) log(`recovered: ${label} succeeded on attempt ${attempt}`)
      return result
    }
    if (attempt < tries) log(`retrying ${label} (attempt ${attempt} died mid-response)`)
  }
  throw new Error(
    `HARD BLOCK: "${label}" failed ${tries} consecutive attempts. Not continuing with a null ` +
      `result — a downstream stage would build on a missing artifact. Check the agent ` +
      `transcript: if Write/Edit calls are 0 while Bash/Read are high, the scope is too ` +
      `large and retrying will never help — decompose the task instead.`,
  )
}
// ------------------------------------------------------------------ COPY TO HERE
