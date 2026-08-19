# Heuristics — accumulated judgment calls

Generalized rules earned in real decomposition loops. Each is a default, not
dogma — but deviating from one deserves a stated reason. **Append new rules
here when a grill session teaches one**; keep each entry to a claim + why.

## Classification

- **Classify by dependency direction, not folder or intuition.** A module
  grouped with the substrate that performs domain work belongs to the domain
  tier. "Everything depends on it" does not make something infrastructure.
- **A registry/catalog that closes over services is a service-locator** even
  if it looks like data. The composition root builds it from injected deps;
  entries become `(ctx) => (args) => result` closures over the injected
  context, never top-level imports.
- **Two subsystems that look like old-vs-new may both be live.** Verify with
  consumers before treating either as legacy.

## State & config

- **`configure()`-plus-memo is a leak factory.** A global config setter
  combined with any lazily-memoized client/registry means later
  reconfiguration silently doesn't take — in multi-tenant or per-request-
  credential systems this is a credential-leak bug, not a style issue. The
  fix is structural (factory + per-instance state), not a reset hook.
- **A runtime `require()`/lazy import that exists to dodge an import cycle is
  a global-state smell.** Making config an argument usually dissolves the
  cycle outright.
- **Shared caches need a scope dimension.** Any cache/dedup keyed only on
  request content will cross tenants and hosts. Prefer per-instance closure
  state + an explicit scope key with a fail-safe default (an unscoped call
  degrades to no-sharing, never wrong-sharing). Cache keys must cover every
  parameter that changes the response; hash long keys instead of embedding
  payloads.
- **In-service ephemeral state is honest** (short-TTL memo, in-process run
  index). The stateless-service rule bans persisting *consumer/domain* state,
  not process-local bookkeeping. Inject the shared cache only when the data
  must be distributed or large.
- **Connect-on-construct is a repair item everywhere it appears**: build the
  client once from injected config, expose explicit `initialize()`, let the
  root order the calls.

## Boundaries

- **Cross-domain table read = back-edge, even for a SELECT.** A repository
  touches only its own domain's tables; needing another domain's data means
  depending on that domain's leaf PORT. Back-edges are about depending on
  another domain's *logic*, not its data.
- **Row types never travel upward.** Map at the repo boundary; a
  `Record<string, unknown>` above the repo is a leak.
- **A write hiding inside a read method is an unextracted side-effect.**
  Name it as an event, wire it explicitly, keep the read pure.
- **Events are for side-effects; dispatch is a direct call.** An event whose
  emitter and handler are the same service is indirection with zero
  decoupling. Keep cancel/audit/invalidate seams as events; collapse
  self-dispatch.
- **The event bus must exist before the services that emit into it** —
  construct it empty with the infrastructure, wire handlers last. (Constructing
  it after services that take it by constructor cannot compile.)
- **Routes reach up; services don't.** Composition layers built last may wire
  anything; the load-order DAG constrains service→service edges only. Check
  which kind of node an "upward" edge starts from before calling it a cycle.

## Surfaces & factories

- **Don't invent factories for pure functions.** If a unit reads no config and
  holds no state, a factory injects nothing and taxes every consumer. The
  membership test: on-instance ⟺ closes over injected config/clients.
- **Sibling over namespace when lifetimes differ** or when a consumer needs
  the capability with no main instance in scope. A per-scope service class a
  consumer constructs is a sibling; so is anything two hosts share where only
  one host builds the main instance.
- **Generated contracts must be load-bearing or they're decorative.** A typed
  client that most call sites bypass (string paths, `as never` casts,
  hand-written response types) protects nothing — regeneration breaks nobody,
  which means the CI gate on it guards a fiction. Route every call through
  the typed surface; ban body casts; alias generated types with named exports.
- **Star re-export barrels hide dead exports.** Curate named exports; keep
  root barrels minimal or empty. Dead exports accumulate precisely where
  `export *` makes them invisible.
- **An explicit exception is better than a leaky abstraction.** When a
  capability genuinely can't route through the standard seam (no matching
  interface exists), inject the narrow thing it needs and record the
  exception — don't force indirection that buys nothing, and don't let the
  exception go undocumented.

## Evidence & deletion discipline

- **Grep-dead ≠ dead.** A route can guard on one thing then do live work;
  unmounted ≠ unreachable; dynamic dispatch and reflection hide consumers.
  Claim dead only with call-site + reachability evidence.
- **Stale comments and docs lie about wiring.** "Populated via X" or "shared
  by Y" claims are verified against actual call sites, not documentation —
  including the code's own doc comments.
- **Re-sweep zero-consumer claims at closure.** Ledgers rot during a long
  exercise; a final sweep catches consumers discovered late (and prevents a
  live export being deleted as "dead").
- **A deleted thing sometimes returns re-implemented elsewhere.** Before
  mapping an old capability to a new home, check whether a replacement
  already shipped — the answer to "how do we satisfy this need" is sometimes
  "it's already satisfied; delete the original".
- **Deletion is a design tool.** Don't decompose dead code — record it for
  deletion. Sometimes the dead node is the only cycle in the graph.

## Shared leaf packages (types/contracts packages)

Applies when the codebase has (or is growing) dedicated shared type/contract
packages — a general-purpose one and optionally one per domain family.
Placement decision procedure — walk in order, first match wins:

1. Runtime code (executes, holds state, does I/O)? → NOT a leaf package.
   Exception class: web-standard-only helpers needed across ≥3 boundaries
   where every other home drags a heavy dep tree — document inline.
2. Not a type/schema? → stop; wrong package.
3. References a heavyweight third-party type (e.g. an AI-SDK/framework type)?
   → lives in the package that owns that dependency, never a leaf.
4. Consumed by ONE package? → stay local to it. Anticipated sharing ≠ sharing.
5. Shared and any consumer is browser-side? → the general-purpose leaf.
6. Shared server-side within one domain family? → that family's leaf
   (if one exists; otherwise the general-purpose leaf).
7. Otherwise shared server-side? → the general-purpose leaf.
8. Always: own subpath (keep root barrels empty), explicit named exports,
   DB/row shapes stay with their repo — only domain types are shared.

Corollaries: a "shared" contract one side has stopped importing is a
near-duplicate, not a contract — reconcile before promoting anything else
(drifted twins are worse than duplicates because both look authoritative);
never mint a third name for a type that already exists twice; two vocabularies
sharing an English word are not one domain — check liveness and semantics
before merging.
