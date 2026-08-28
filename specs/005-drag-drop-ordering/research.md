# Research: Drag & Drop Ordering

Phase 0 output. No `NEEDS CLARIFICATION` markers remain in spec.md. The larger
architecture calls (dedicated move endpoints, no concurrency precondition, optimistic
client updates, native HTML5 drag, deferred rebalancing) are recorded as ADR-20 through
ADR-24 in `plan.md`; this document covers the remaining operational decisions those
ADRs depend on.

## R-1: Insertion-point resolution — exact algorithm, both endpoints

**Decision**: Both move endpoints accept an optional "insert before this sibling"
identifier, resolved into a `Ordering.cs` call the same way on both:

- `POST /v1/cards/{id}/move` body carries `listPublicId` (required — the destination
  list, which may be the card's current list, for a same-list reorder) and
  `beforeCardPublicId` (optional — the sibling the card should land immediately before,
  within the destination list; omitted/null means "at the end").
- `POST /v1/lists/{id}/move` body carries `beforeListPublicId` (optional, same meaning,
  scoped to the board's own list order; omitted/null means "at the end").

Server-side resolution (identical shape for both): if `beforeXPublicId` is supplied,
load that sibling's `Position` and the position of whichever sibling immediately
precedes it in the destination's current order (`null` if it's already first), then call
`Ordering.InsertBetween(precedingPosition ?? 0, beforeSibling.Position)`. If
`beforeXPublicId` is omitted, load the destination's current last position and call
`Ordering.Append(lastPosition)`. Both are the exact two functions `Ordering.cs` already
exposes (reserved by 001, used by 004's card create/copy) — no new ordering primitive.

**Rationale**: This is precisely what the prototype's own drop handler computes
client-side (`docs/product/prototype/flowboard-prototype.html`: "which visible sibling
should the card land before" via a vertical-midpoint comparison, R-4 below) — the API
just needs the resolved answer as an id, not a raw coordinate, and does the actual
position math itself using the module reserved for exactly this.

**Alternatives considered**: Sending a raw numeric `position` from the client — rejected,
it would leak the sparse-float scheme into the wire contract and let a client compute an
invalid or colliding value; an opaque "insert before this sibling" reference keeps the
actual numbers a server-only concern (matching how `PublicId`-only addressing already
works everywhere else, invariant 8).

## R-2: Permission matrix — identical to 004, no new role concept

**Decision**: Both move endpoints resolve the caller's role via `BoardAccessService`
(the card's or list's own board) and require `BoardAdmin`/`BoardMember`; `Observer` gets
`403`; no resolvable role gets `404` — the exact table 004's `CanMutate(role)` helper
already encodes, reused unchanged.

**Rationale**: Spec FR-011 restates the same matrix 004 already established; no new
distinction is needed for moving vs. any other mutation.

## R-3: `card.moved` — when it's written, and its payload

**Decision**: `MoveCardAsync` writes exactly one `card.moved` `ActivityEvent`, and only
when the resolved destination `ListId` differs from the card's current `ListId` before
the move is applied — never for a same-list reorder (spec FR-003). Payload:
`{ fromListName, toListName }` (list *names* at the moment of the move, not ids — the
activity feed already renders other entries as plain text, and a list can later be
renamed or archived without invalidating what this event says happened).

**Rationale**: Matches the prototype's own guard (`if (found.list.id !== target.id)`)
exactly, and gives `card-activity-feed.tsx` (004) a display template
("moved this card from {fromListName} to {toListName}") with no new backend concept —
`type` + `payload` is the same contract 004's other event types already use (research
R-6 from 004).

## R-4: Frontend drop-position resolution — matches the prototype's own algorithm

**Decision**: On `dragover` within a list's card container, compare the pointer's
vertical position against each visible sibling card's own bounding-box vertical
midpoint; the first sibling whose midpoint is below the pointer is the "insert before"
card (`beforeCardPublicId`); if the pointer is below every sibling's midpoint,
`beforeCardPublicId` is omitted (append at the end). This is copied directly from
`docs/product/prototype/flowboard-prototype.html`'s own `drop` handler logic, not
reinvented.

**Rationale**: Source-of-Truth rung 1/2 — the prototype already defines this exact
interaction; there's no reason to design a different one.

## R-5: Optimistic update rollback — snapshot-and-restore, not per-field patching

**Decision**: The move mutation's `onMutate` callback (React Query) takes a snapshot of
the current `boards.getContent` cache entry before applying the optimistic reorder, and
`onError` restores that exact snapshot (rather than trying to compute a reverse patch).
`onSettled` always invalidates the query regardless of success/failure, so the
eventually-consistent server state is what's shown once the round-trip completes either
way.

**Rationale**: Snapshot-and-restore is the standard, low-risk React Query optimistic-
update shape; computing a reverse-patch is unnecessary extra logic for a mutation that
essentially never fails (ADR-21 — there is no conflict-rejection path, only genuine
network/permission failures, which are rare and where a full restore is exactly what a
user expects to see).

## R-6: WIP limits — no backend check to add, only confirm none exists

**Decision**: Neither move endpoint checks the destination list's `WipLimit` before
accepting a move. The existing display-only over-limit pill (003/004,
`list.cardCount > list.wipLimit`) already recomputes correctly from the destination
list's new `CardCount` after the move's invalidation/refetch — no new logic needed on
either tier.

**Rationale**: Restates invariant 3 for this feature's own reviewers; the risk being
guarded against is an implementer reflexively adding a limit check "since it's right
there," which would be a regression against an existing, already-shipped invariant.
