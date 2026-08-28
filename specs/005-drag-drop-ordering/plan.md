# Implementation Plan: Drag & Drop Ordering

**Branch**: `005-drag-drop-ordering` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-drag-drop-ordering/spec.md`

## Summary

Card drag-and-drop within and across lists, a keyboard-operable "Move" menu alternative
(activating the button 004 already built but left inert), and list drag-and-drop
reordering — all built on the sparse-float ordering module (`Domain/Ordering.cs`)
reserved since 001 and already exercised by 004's card create/copy. This is the first
feature to give `Card.Position`/`Card.ListId` and `List.Position` a real, repeated,
user-driven write path. Moves use last-write-wins concurrency (no `If-Match`, no `409`)
— deliberately different from 004's field-edit concurrency — via two new, narrow
endpoints rather than extending 004's `PATCH /v1/cards/{id}`.

## Technical Context

**Language/Version**: C# / .NET 10 (backend, unchanged); TypeScript / Next.js 16 App
Router (frontend, unchanged)
**Primary Dependencies**: No new packages either side. Backend reuses EF Core 10, the
existing `Ordering.cs` module, and 002's `BoardAccessService`. Frontend reuses
tRPC/React Query, and adds native browser HTML5 Drag and Drop (no library) — matching
`docs/product/prototype/flowboard-prototype.html`'s own implementation exactly.
**Storage**: SQL Server — no schema change. `Card.Position`, `Card.ListId`, and
`List.Position` already exist (001/003); this feature is the first to write to them
outside of seed data and 004's create/copy paths.
**Testing**: `dotnet test` (xUnit, `WebApplicationFactory` integration tests, extending
004's pattern) + a golden-fixture test for the new insertion-point resolution logic
(constitution XI); no frontend test runner exists yet (see 003/004 precedent) — frontend
verification is the Visual Compliance Loop + `quickstart.md`.
**Target Platform**: Web (existing Next.js/ASP.NET Core stack, unchanged)
**Project Type**: Web application (existing `flowboard-api` + `flowboard-web`, unchanged)
**Performance Goals**: A move is one row write, no renumbering of siblings (invariant 2)
— O(1) regardless of list size.
**Constraints**: Moves MUST NOT use the `If-Match`/`409` conflict pattern 004 established
for field edits (spec FR-010; `docs/product/FUNCTIONAL_SPEC.md` §7.1).
**Scale/Scope**: Two new backend endpoints, no new entities, no migration; frontend adds
drag handlers to two existing components plus one new "Move" picker panel.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated; this plan.md and
  tasks.md follow before any implementation.
- [x] **Source of Truth (II)**: Visual references (`screenshots/`) captured directly from
  the prototype and used to resolve two behaviors not visible in a single still frame
  (same-list reorder writes no activity event; "Move" only offers a destination list,
  never an in-list position) — recorded in spec.md's Assumptions rather than guessed at
  here. No conflict found between rungs.
- [x] **Repository Separation (III)**: `flowboard-api` (endpoints/services) and
  `flowboard-web` (drag handlers, Move panel) stay separate; no mixing.
- [x] **Architecture Consistency (IV)**: No new framework, UI library, or persistence
  approach. Native HTML5 drag-and-drop and optimistic client-side mutation updates are
  both new *patterns* for this codebase (001–004 only ever invalidate-then-refetch) —
  each is recorded as an ADR below with its justification, per this principle's approval
  requirement.
- [ ] **Data Standards (V)**: N/A — no new entities, no new primary keys.
- [ ] **Auditability (VI)**: N/A — no new entities; existing audit fields on `Card`/`List`
  are already touched by `UpdatedDate`/`UpdatedBy` on every move, matching 004's pattern.
- [x] **Domain Invariants (VII)**: This feature is the direct implementation of invariant
  2 (Ordering Integrity) — see ADR-20/ADR-21 and the domain-invariant pass table below.
  Invariant 3 (WIP Limits Are Advisory) is explicitly re-affirmed in spec FR-009.
- [x] **Security (VIII)**: Every new endpoint requires auth and re-resolves the caller's
  board role via `BoardAccessService` before acting (invariant 5's enforcement pattern),
  exactly like every 004 endpoint.
- [ ] **External Integration Governance (IX)**: N/A — no external integrations.
- [x] **Performance Responsibility (X)**: One-row moves only (invariant 2); no N+1; see
  Complexity Tracking for the deferred rebalancing job.
- [x] **Testing Requirements (XI)**: Integration tests for both new endpoints (success,
  validation, authorization, WIP-limit-not-enforced, last-write-wins) plus a golden-
  fixture test for insertion-point resolution.
- [x] **Human Review (XII)**: Same phased AI-then-human review as 001–004, gated per
  phase below.
- [x] **Controlled Delivery (XIII)**: Backend phase implemented and gated before frontend,
  per `docs/sdlc/repository-strategy.md`'s cross-repository rule — same as 004.

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`). This feature touches
domain invariant 2, but Ordering Integrity is not in the Critical-triggering category
(postings/balances/consent trails/state machines, or irreversible/destructive/regulated
operations) — a wrong card position is a one-drag-to-fix UX issue, not an unrecoverable
harm, exactly the same reasoning 004 applied to the several invariants it touched.

## Architecture Decision Records

**ADR-20 — Dedicated move endpoints, not an extension of `PATCH /v1/cards/{id}`**:
`docs/product/FUNCTIONAL_SPEC.md` §7's own API table lists `PATCH /v1/cards/{id}` as
"update fields **and** move," and 004 deliberately left `list_id`/`position` rejected on
that route for 005 to decide. This plan does **not** lift that rejection. A move (last-
write-wins, no precondition) and a field edit (strict `If-Match`/`409`) need
fundamentally incompatible concurrency contracts; retrofitting an exception into the
already-shipped, tested `PATCH` handler is more error-prone than two small, single-
purpose routes: `POST /v1/cards/{cardPublicId}/move` and `POST
/v1/lists/{listPublicId}/move`. API shape is an implementation decision the visual
references don't speak to, so this doesn't conflict with Source-of-Truth rung 1/2 — it's
squarely this plan's call to make, and it's made here explicitly rather than by default.

**ADR-21 — Moves have no concurrency precondition at all**: Per
`docs/product/FUNCTIONAL_SPEC.md` §7.1 ("card moves are last-write-wins on `(list_id,
position)` with an `updated_at` precondition") and spec.md FR-010, the move endpoints
take no `If-Match` header and never return `409`. `Card.RowVersion` still advances on a
move (EF Core's normal behavior for any tracked-row update) but nothing checks it on this
path — a stale client's move still lands; the "precondition" is simply that the move
always applies to whatever the row's current state is at write time.

**ADR-22 — Optimistic client-side updates for move mutations**: 001–004 only ever
invalidate a query after a mutation and wait for the refetch. Drag-and-drop feels broken
under that pattern (the card would snap back to its start position and then jump to
where it was dropped once the refetch lands). Because a move can never be rejected
(ADR-21), it's safe to patch the local `boards.getContent` cache immediately on drop
(tRPC/React Query `onMutate`) and only reconcile-by-invalidation in the background;
`onError` (a genuine network failure, not a conflict — those don't exist here) rolls the
optimistic patch back and re-toasts.

**ADR-23 — Native HTML5 Drag and Drop, no new package**: The prototype
(`docs/product/prototype/flowboard-prototype.html`) implements both card and list
dragging with plain `draggable="true"` + `dragstart`/`dragover`/`dragleave`/`drop` — no
library. This plan matches that exactly (constitution IV: no new UI library without
justification, and none is needed here). The keyboard-operable "Move" menu (US2, C-11)
is the accessibility answer FUNCTIONAL_SPEC §8 requires — it is a plain, already-
patterned popover (matching `card-labels-panel.tsx`'s shape), not a drag-library
feature, so native drag's own lack of keyboard support is not a compliance gap.

**ADR-24 — Position-rebalancing background job stays out of scope**: `docs/product/
FUNCTIONAL_SPEC.md` §5.1 mentions "a background job re-balances when gaps get too
small" as an aside, not a requirement with an owning feature. No background-job
infrastructure exists in this codebase yet, and introducing one now would be a new
architectural pattern this feature doesn't otherwise need. IEEE-754 double-precision
gaps between two sparse-float positions take on the order of dozens of repeated same-
spot insertions to exhaust — far beyond realistic manual use — so this is deferred
until a feature actually needs it, exactly as 001 deferred `Ordering.cs` itself until
004 needed it.

## Project Structure

### Documentation (this feature)

```text
specs/005-drag-drop-ordering/
├── plan.md              # this file
├── research.md
├── data-model.md
├── contracts/
│   └── move-api.md
├── quickstart.md
├── screenshots/
│   ├── board-canvas-dragging.jpg
│   ├── card-move-to-list-popup.jpg
│   └── list-reorder-dragging.jpg
└── tasks.md
```

### Source Code

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Domain/
│   │   └── ActivityEventType.cs        # + CardMoved = "card.moved"
│   ├── Endpoints/
│   │   ├── CardsEndpoints.cs           # + POST /v1/cards/{id}/move
│   │   └── ListsEndpoints.cs           # NEW — first list-scoped endpoint group
│   ├── Services/
│   │   ├── CardService.cs              # + MoveCardAsync
│   │   └── ListService.cs              # NEW — MoveListAsync
│   └── Program.cs                      # + 1 DI registration, + 1 endpoint mapping
└── tests/Flowboard.Api.Tests/
    ├── CardsEndpointTests.cs           # + move test cases
    ├── ListsEndpointTests.cs           # NEW
    └── OrderingTests.cs                # + insertion-point resolution cases

flowboard-web/
├── src/
│   ├── lib/
│   │   ├── cards/schemas.ts            # + moveCardInputSchema
│   │   ├── lists/schemas.ts            # NEW — moveListInputSchema
│   │   └── api/
│   │       ├── cards-client.ts         # + moveCard
│   │       └── lists-client.ts         # NEW — moveList
│   ├── server/api/
│   │   ├── routers/
│   │   │   ├── cards.ts                # + move procedure
│   │   │   └── lists.ts                # NEW — move procedure
│   │   └── root.ts                     # + lists router registration
│   └── components/board/
│       ├── card-front.tsx              # + draggable/dragstart/dragend
│       ├── list-column.tsx             # + card drop-zone, + list draggable/drop-zone
│       ├── board-canvas.tsx            # + optimistic-update wiring (ADR-22)
│       └── card-detail/
│           ├── card-add-to-card-menu.tsx   # "Move" button becomes functional
│           └── card-move-panel.tsx         # NEW — the "Move to list" popover
```

**Structure Decision**: Extends the existing single-service-per-tier layout from
001–004; no new top-level directories. `ListsEndpoints.cs`/`ListService.cs` are new
files, not a new architectural layer — they follow the exact same
Endpoints→Service→DbContext shape `CardsEndpoints.cs`/`CardService.cs` already
established.

## Domain Invariant Pass

| # | Invariant | How this feature satisfies it |
|---|---|---|
| 1 | Activity Is Append-Only | `card.moved` is written once per cross-list move via the same `ActivityEvent` insert-only path 004 established; same-list reorders write nothing (spec FR-003) |
| 2 | Ordering Integrity | The reason this feature exists — one-row writes only via `Ordering.Append`/`InsertBetween`, no renumbering, tiebreak already resolved by `Id` (existing) |
| 3 | WIP Limits Are Advisory | FR-009 — a move is never blocked by a destination list's WIP limit |
| 4 | Soft Delete | Unaffected — moves don't delete anything |
| 5 | Permissions Enforced Server-Side | Every move route resolves role via `BoardAccessService`; Observer gets `403` regardless of UI |
| 6 | Optimistic Concurrency | Deliberately **not** applied to moves (ADR-21) — ETag/If-Match stays scoped to field edits only, per FUNCTIONAL_SPEC §7.1's own distinction |
| 7 | Labels Are Board-Scoped | Unaffected |
| 8 | Opaque Public Identifiers | Move requests address cards/lists by `PublicId` only, same as every other route |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Optimistic client-side cache updates (new pattern, ADR-22) | Drag-and-drop is unusable if the UI waits for a round-trip before showing the card where it was dropped | Plain invalidate-after-mutate (004's pattern) causes a visible snap-back-then-jump on every drop; rejected as a real UX regression for this specific interaction, not applied anywhere invalidate-after-mutate already works fine |
| New `ListsEndpoints.cs`/`ListService.cs` files (no prior list-scoped endpoint group existed) | List reordering needs a real write path; no existing list-mutation surface to extend | Folding list-move into `CardsEndpoints.cs` was rejected — lists aren't cards, and 006 will need its own list-endpoint group anyway; this feature just gets there one route early, not the wrong shape |
