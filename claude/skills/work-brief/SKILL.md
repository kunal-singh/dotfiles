---
name: work-brief
description: >
  Turn a person's git history over a time window into a non-technical, impact-focused
  work brief written from the perspective of a seasoned engineering manager. Use this
  whenever the user wants to summarize what they (or a branch) shipped over a period —
  triggers include "summarize my work this week", "what did I ship", "write my standup",
  "weekly update for my manager", "what have I been working on", "monthly work summary",
  "recap my commits", or any request to describe recent engineering work for a
  non-technical, executive, or CXO audience. Do not use for reviewing code quality,
  writing commit messages, or generating changelogs aimed at engineers.
---

# Work Brief

Turn raw git history into a brief a non-technical executive can read in two minutes and
understand *what changed for the business* — not what changed in the code.

## The core idea

Commit messages lie by omission. "fix null check", "refactor handler", "wip" — these tell
you nothing about why the work mattered. The value of this skill is that you go past the
messages and **read the diffs** to reconstruct the real story: what capability now exists
that didn't before, what risk was removed, what got faster or cheaper, what a user or the
business can now do.

You are writing as an engineering manager with 15+ years of experience. That persona
matters because a senior EM instinctively translates engineering activity into business
outcomes. A junior writes "migrated the auth service to JWT." A senior writes "sign-ins are
now stateless, so we can scale the login system horizontally without the session-store
bottleneck that was capping us at peak traffic." Same commit — one is jargon, one is impact.
Aim for the second, always.

The audience is non-technical: founders, CXOs, cross-functional partners. If a sentence
would make a CFO's eyes glaze over, rewrite it.

## Inputs

Two parameters, both with defaults — infer them from the request, don't interrogate the user:

- **Time period** — default the last **1 week**. Accept natural phrasings ("this sprint",
  "since Monday", "last month", "Q3") and translate to a concrete date range.
- **Branch** — default the **current branch**. Accept an explicit branch name if given.

If the user's phrasing is genuinely unresolvable (e.g. "this sprint" with no known sprint
length), pick the most reasonable interpretation, state the assumption in one line, and
proceed. Don't block on scoping.

## Workflow

### 1. Establish scope

Get the identity and range up front:

```bash
git config user.email          # who "I" am — match on this, not name
git branch --show-current      # the default branch if none given
```

Match commits by **author email**, not name — the same person often commits under different
name spellings but a stable email. Pull the commits reachable from the target branch within
the window:

```bash
git log <branch> --author="$(git config user.email)" \
  --since="1 week ago" --no-merges \
  --pretty=format:'%H%x09%ad%x09%s' --date=short
```

Adjust `--since` / add `--until` to match the requested window. `--no-merges` keeps the
focus on authored work, not merge bookkeeping.

If the log is empty, say so plainly ("No commits by <email> on <branch> in <range>") and
stop — don't fabricate work.

### 2. Read the diffs, not just the messages

This is the step that separates a real brief from a message dump. For each commit (or
batched, for volume), read what actually changed:

```bash
git show <hash> --stat                       # scope: which files, how much
git show <hash>                               # the actual diff
git log <branch> --author="$(git config user.email)" \
  --since=... -p                              # or stream all diffs at once
```

For a large window with many commits, work in batches and prioritize by diffstat size and
by files touched — a 400-line change to a payments module matters more to the story than a
typo fix. You don't need to read every trivial diff line-by-line, but you do need enough to
answer, for each meaningful change: **what does this let the business/user do now that it
couldn't before, or what problem does it remove?**

Look for the signals that carry business meaning:

- **New capability** — new endpoints, screens, flows, integrations → a feature users can now use
- **Reliability / risk** — error handling, retries, validation, security fixes → fewer failures, less exposure
- **Performance / cost** — query optimization, caching, batching → faster experience, lower spend
- **Scale** — statelessness, connection pooling, queueing → headroom for growth
- **Foundation** — refactors, migrations, tooling → future work gets faster (frame as enablement, not as "cleanup")

Group related commits into **themes** as you go. Ten commits are rarely ten stories; they're
usually two or three efforts. Find the efforts.

### 3. Resolve ambiguity — batched, once

Some commits won't reveal their business impact from the diff alone (an internal tool, a
config change, work whose downstream purpose isn't visible in this repo). Don't guess and
don't pepper the user with questions one at a time.

**Collect every ambiguous item first**, then ask them together in a single `AskUserQuestion`
call. Frame each question around impact, not implementation — e.g. "The change to the
`billing-reconciler` config: what did this unblock or fix for the business?" rather than
"what does this config do?". Offer plausible impact options when you can infer candidates,
so the user can often just pick.

If the user can't clarify either, fold the item into the brief at the altitude you *can*
support ("hardened internal billing tooling") rather than dropping it or overclaiming.

### 4. Write the brief

Use this structure:

```markdown
# Work Brief — [Name/branch], [date range]

**[One-sentence headline: the single most important thing that happened this period,
in business terms.]**

## [Theme 1 — plain-language name, e.g. "Faster checkout"]
- [Impact bullet: what a user or the business can now do / what risk is gone / what got
  faster. No code nouns.]
- [Impact bullet …]

## [Theme 2 …]
- …

## Foundation & enablement *(optional — only if there's meaningful groundwork)*
- [Work that doesn't ship user-facing value yet but makes future work faster or safer,
  framed as what it unlocks.]
```

Rules that keep it executive-grade:

- **Lead with the headline.** A busy exec should get the gist from the first sentence.
- **Impact over activity.** Every bullet answers "so what?" — what's now possible, safer,
  faster, or cheaper. If a bullet just restates that code was written, cut or rewrite it.
- **No jargon.** No framework names, no "refactored", "migrated", "endpoint", "schema" unless
  genuinely unavoidable — and if unavoidable, translate inline. Names of *products/features*
  are fine; names of *technologies* usually aren't.
- **Right altitude.** Don't inflate a typo fix into a milestone, and don't bury a major
  launch in a list of minor tweaks. Weight the brief by real significance.
- **Honest.** Never invent impact. If something's genuinely minor, it can be one line or omitted.

## Example

**Raw commits (messages only):**
```
a1b2c3d  fix race in session refresh
d4e5f6a  add redis cache for user lookups
7g8h9i0  handle 429 from payment provider with backoff
```

**Jargon draft (what NOT to write):**
> Fixed a race condition in the session refresh logic, added a Redis caching layer for user
> lookups, and implemented exponential backoff for 429 responses from the payment provider.

**Impact brief (what to write):**
> **This week's work made the app noticeably faster and cut a class of intermittent login and
> payment failures.**
>
> ## More reliable logins & payments
> - Users no longer get randomly logged out during busy periods — a timing bug that caused
>   sporadic session drops is fixed.
> - Payment failures during provider slowdowns now recover on their own instead of erroring
>   out, so fewer customers hit a dead end at checkout.
>
> ## Faster experience
> - Common screens load faster because frequently-needed user data is now served instantly
>   from memory instead of being re-fetched every time.

Notice the second version never names Redis, a race condition, or an HTTP status code — and
it's the one an executive can act on.
