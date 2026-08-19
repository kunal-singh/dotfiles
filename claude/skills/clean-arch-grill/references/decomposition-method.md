# Decomposition Method — seams, tiers, the DAG gate, ledgers

The output of a grill is a decomposed surface the user can review seam by
seam, plus a dependency graph proven acyclic, plus approval ledgers. This file
defines those artifacts.

## Unit of work: the seam

A seam is a cohesive slice of the system (a domain, a capability, a substrate
layer) small enough to decompose in one pass. Process seams **leaves first** —
things with no domain dependencies (config, logging, cache, storage, DB
substrate) before the domains that use them, composition root last. This
builds the dependency graph bottom-up so every edge points at something
already defined; anything consumed before it's defined is recorded as a
**forward reference** and must resolve by the end.

## Per-seam decomposition format

For each seam, produce:

1. **Services** — business logic as framework-free units. Every dependency in
   the constructor/factory signature. Signatures use domain types. No
   transport types, no DB clients, no ambient reads. Note any acceptable
   in-service ephemeral state (a short-TTL memo Map is honest state, not a
   hidden dep — inject a shared cache only when it must be distributed or
   large).
2. **Repository ports** — interfaces named in domain verbs (`findById`,
   `upsert`, `search`, `listFor…`) returning domain types. One repo per
   **table/collection** (a column — even an exotic one — does not get its own
   repo; shared tables get ONE port both consumers depend on). Row type +
   mapper noted wherever storage shape ≠ domain shape; the row type never
   travels above the repo. All implementations live together in one location;
   the driver/ORM appears only there.
3. **Handlers/routes** — thin factories `make<X>Routes(deps)` receiving
   exactly the services they use. Declared auth per route; an undeclared
   protected route fails closed. Validation at the edge; no re-validation
   inside services; no logic in handlers.
4. **Config slice** — the named sub-slice of config this seam consumes.
   Slices are per-consumer and minimal; a service asking for the whole config
   is a smell. If a "default" value has exactly one consumer, keep it at the
   narrowest scope that consumer can reach.
5. **Side-effect events** — named past-tense events for genuine side-effects
   (audit writes, cache invalidation, telemetry, background continuation of a
   *secondary* concern), each with trigger + handler + error posture,
   explicitly wired at the composition root. **Dispatch of primary work is a
   direct method call** — an event whose emitter and handler are the same
   service is indirection with no decoupling and should be collapsed.
6. **DI node** — the seam's nodes with `dependsOn` / `depended-on-by` edges,
   and tier assignment.

## Tier assignment

Assign by **dependency direction, not folder intuition**. A thing grouped
with infrastructure that runs domain queries is a domain service no matter
how central it is ("depended-on-by-many" ≠ "infra leaf"). Reclassify freely
when the edges say so; record the reclassification.

## The membership rule (composition-root shape)

For every public capability, decide where it lives by one test:

- **On the instance/container** ⟺ it closes over injected config or a
  constructed client (provider registry, DB handle, credentials, defaults).
- **Free function export** ⟺ it is pure or takes all inputs as arguments —
  do NOT invent a factory for something already DI-clean; wrapping a pure
  function in a constructor injects nothing and taxes every consumer.
- **Sibling (host-built, passed in or alongside)** ⟺ it has its own lifetime
  or must be usable where the main instance is not in scope (observability,
  run/job stores, per-scope service classes a consumer constructs). A sibling
  that the instance needs is passed INTO the factory; a sibling that shares
  no config with the instance stays fully outside.

The composition root itself is an ordered, instantiate-once assembly:
`config → infra → repositories → services → event wiring → mount/expose`.
Plain ordered construction — the compiler's forward-reference checking is the
first DAG gate (a mis-ordered dependency won't compile). The root is the
assembly site, never itself injected into services (no god object). Fail-loud
validation (config shape, tier/id resolution, catalog↔code drift) runs at
construction, not on first use.

## The DAG gate

After each seam merges, re-check the accumulated graph:

- **Cycles: zero.** A valid topological order must exist; that order IS the
  construction order.
- **The DAG constrains service→service edges only.** Routes/composition wiring
  are the outermost layer, built last, depended on by nothing — they may reach
  any tier. Only a service importing a higher-tier service is a back-edge.
- **Downward exceptions that are fine:** consuming another domain's DATA via a
  leaf repository port; calling an external leaf library with your own port;
  cross-tier service edges that point down (verify the lower tier doesn't
  point back up).
- **Lifecycle edges are not graph edges.** "A must initialize before B" is a
  sequencing guarantee the root provides; modeling it as a dependency edge
  creates false cycles.
- **Forward references** get an explicit open list; the final gate resolves
  every one to a real node or the design is incomplete.
- Deleting dead code is a legitimate cycle-breaking tool — a "dead" node is
  sometimes the only thing creating a cycle.

## Ledgers (the review contract)

Maintain three, append-only during the exercise:

**Decisions** — `| # | fork | ruling | date |`. Locked; re-litigation requires
explicit unlock.

**Breaking changes** — `| # | old → new | consumers (evidence) | status |`.
Every rename/reshape, each with an inventory of real call sites. A change with
"probably nobody uses this" instead of an inventory is not done.

**Deletions** — `| # | candidate | evidence |`. Record-only; applying any
deletion requires the user's explicit approval outside the grill flow. Rules
of evidence: zero-consumer claims are verified against call sites (not
comments or docs — both lie); "unmounted route" ≠ "dead service" (check other
reachability); re-sweep all zero-consumer claims once at the end, because
earlier passes miss late-discovered consumers.

## Loop closure

The exercise is DONE when all three hold — check them explicitly and say so:

- **[Coverage]** every seam in scope has a merged decomposition.
- **[Acyclic]** the full graph passes the DAG gate with zero cycles and zero
  unresolved forward references.
- **[Surface]** the surface is total: every existing export/route/method is
  kept, mapped (old → new), or sits in the deletions ledger — no silent drops.

Then stop. Do not gold-plate. The residue should be exactly: the human-gated
fork set and the deletion ledger.
