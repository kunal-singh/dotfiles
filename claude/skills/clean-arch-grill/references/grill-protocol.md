# Grill Protocol — how to ask

The grill exists to convert open architectural questions into locked decisions
with the least user time. Every rule here serves that.

## Round structure

A round = (restate locked decisions) → (new findings, if any) → (2–4 fork
questions) → (record answers, surface consequences) → (re-derive the remaining
fork list). Repeat until no forks remain.

- **Highest stakes first.** Round 1 carries the forks that reshape everything
  downstream (scope, sequencing, the seam that other seams depend on). A fork
  whose answer could invalidate other questions must precede them.
- **Restate the locked set each round** in one compact line-per-decision
  block. This is the anti-circling memory: it prevents re-litigating and shows
  the user their rulings were heard.
- **Re-derive between rounds.** Answers kill some pending questions and spawn
  new ones. Never march through a pre-written script after round 1.

## Question craft

Each question is a genuine fork — the user must be the right decider (product
direction, behavioral change, risk/cost appetite, scope). If you know the
right answer, it is not a question; state it as a position in the findings and
let the user object.

- **Phrase the stakes in the question itself.** Not "which option?" but what
  the choice costs/changes: blast radius, who breaks, what becomes possible or
  impossible. One or two sentences of framing maximum.
- **2–4 options, mutually exclusive**, each with a one-to-three-line
  description carrying the trade-off (not a repeat of the label).
- **Recommendation first, marked "(Recommended)"**, with the reasoning in its
  description. Always have a recommendation — "up to you" is an abdication.
  Include an honest option you'd reject if it's genuinely defensible; label
  the trade-off, don't strawman it.
- **Use structured multiple-choice** (the ask-user-question mechanism if
  available) rather than open prose questions — users answer faster and the
  answers are unambiguous. Leave room for free-text override; users often
  answer with a fourth option you didn't list. Treat that as the answer, not a
  deviation.
- **Multi-select only when options genuinely compose** (e.g., "which
  objectives are in scope"). Never for mutually exclusive designs.

## Handling answers

- **Lock immediately.** Every answer enters the decisions ledger verbatim
  enough to reconstruct intent.
- **Contradictions surface once, immediately.** If an answer contradicts an
  earlier locked decision, a stated constraint, or documented history (their
  own prior post-mortems, project rules), say so in one or two sentences and
  ask which gives way. Do not silently absorb the contradiction, and do not
  argue past one round — the user's resolution stands.
- **Against-recommendation answers get one consequence note**, then full
  commitment. Fold the choice into the design as if it were your own idea;
  a design that hedges against the user's decision is worse than either
  option.
- **Free-text answers that add constraints** (not just pick options) are the
  richest input — mine them for new locked decisions and new forks before
  writing the next round.

## Stop conditions

Stop grilling and move to decomposition when:
- every identified fork has a ruling, and
- no new findings emerged in the last round.

Interrupt the process (don't grind forward) when:
- a fork appears whose answer requires information neither of you has —
  name the missing evidence and go get it (or dispatch someone to) before
  asking;
- the scope revealed is much larger than the user framed — say so and let
  them re-scope before burning rounds on the wrong granularity;
- any deletion decision comes up — deletions are never grill outcomes; they
  go to the deletions ledger for explicit standalone approval.

## Tone

Direct, evidence-first, no praise-padding, no hedging on findings. The user
asked to be grilled: "this is wrong because X" beats "you might want to
consider". But defects in code are stated without blame, and the user's
domain calls (product, risk, priorities) are treated as ground truth once
made. Skepticism is for the architecture, not the person.
