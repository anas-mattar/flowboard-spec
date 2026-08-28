# AI Code Review — 005 Drag & Drop Ordering

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-28
**Branches**: `flowboard-api` `005-drag-drop-ordering` (Phase A, not yet merged)
**Scope reviewed**: `src/Flowboard.Api/Domain/ActivityEventType.cs`,
`src/Flowboard.Api/Services/CardService.cs` (`MoveCardAsync` addition),
`src/Flowboard.Api/Services/ListService.cs` (new),
`src/Flowboard.Api/Endpoints/CardsEndpoints.cs` (`/move` addition),
`src/Flowboard.Api/Endpoints/ListsEndpoints.cs` (new), `src/Flowboard.Api/Program.cs`
(DI + route registration), `tests/Flowboard.Api.Tests/CardsEndpointTests.cs` (move tests),
`tests/Flowboard.Api.Tests/ListsEndpointTests.cs` (new),
`tests/Flowboard.Api.Tests/OrderingTests.cs` (golden-fixture additions).
**Feature contract**: plan.md ADR-20 (dedicated move endpoints, not a `PATCH` extension),
ADR-21 (no concurrency precondition on moves, ever), ADR-24 (no rebalancing job); no new
package, no migration/schema change (data-model.md).

## Verdict

**APPROVE**. Both move endpoints match contracts/move-api.md exactly: request/response
shapes, failure codes, and the `card.moved`-only-on-list-change activity rule. The one
non-obvious design point — bypassing EF's `RowVersion` concurrency token on the move path
via `ExecuteUpdateAsync` rather than a normal tracked `SaveChangesAsync` — is necessary to
actually deliver ADR-21 (Card.RowVersion is a real concurrency token per 004's
`CardConfiguration.IsRowVersion()`; a plain save would have silently reintroduced a `409`
that ADR-21 explicitly forbids) and is covered by a dedicated test. No residual risk found.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-001–FR-012 implemented as specified) | Read spec.md's Acceptance Scenarios against `MoveCardAsync`/`MoveListAsync`; same-list reorder writes no event (`MoveCard_SameList_ReordersAndWritesNoActivityEntry`), cross-list writes exactly one (`MoveCard_CrossList_MovesAndWritesOneActivityEntry`), WIP never blocks (`MoveCard_DestinationOverWipLimit_StillSucceeds`) |
| Visual-reference match | N/A — Phase A is backend-only, no UI this phase |
| Feature contract held (no unapproved table/migration/permission/package) | `git diff --stat` (below) — no migration added; `Flowboard.Api.csproj`/`Flowboard.Api.Tests.csproj` untouched; no new NuGet reference |
| Constitution / domain invariants | See table below |
| Security (authn/authz, secrets, sensitive logging) | Both endpoints `.RequireAuthorization()` via their `MapGroup`; `BoardAccessService.ResolveAsync` re-resolved per-request (ADR-9), no cached role; no secrets/PII in the `card.moved` payload (list names only) |
| Scope guard (`git diff --stat` — only intended files) | 9 files touched, all named in tasks.md T001–T008; no unrelated file changed |
| Rollback safety (phase reverts cleanly; schema additive?) | No schema change at all this phase — a revert is a pure code revert, no migration to roll back |

```
 src/Flowboard.Api/Domain/ActivityEventType.cs   |   1 +
 src/Flowboard.Api/Endpoints/CardsEndpoints.cs   |  18 ++++
 src/Flowboard.Api/Program.cs                    |   2 +
 src/Flowboard.Api/Services/CardService.cs       |  99 +++++++++++++++++
 tests/Flowboard.Api.Tests/CardsEndpointTests.cs | 136 +++++++++++++++++++++++-
 tests/Flowboard.Api.Tests/OrderingTests.cs      |  55 ++++++++++
 (new) src/Flowboard.Api/Endpoints/ListsEndpoints.cs
 (new) src/Flowboard.Api/Services/ListService.cs
 (new) tests/Flowboard.Api.Tests/ListsEndpointTests.cs
 9 files changed, 309 insertions(+), 2 deletions(-)
```

## Findings

### F1 — Move bypasses the RowVersion concurrency token via `ExecuteUpdateAsync` — ACCEPTED

`CardService.MoveCardAsync` writes `ListId`/`Position`/`UpdatedDate`/`UpdatedBy` through
`db.Cards.Where(...).ExecuteUpdateAsync(...)` instead of mutating the tracked `card` entity
and calling `SaveChangesAsync`. A normal tracked save would have included `Card.RowVersion`
(configured `IsRowVersion()` in 004's `CardConfiguration`) as an implicit concurrency token
in the `UPDATE`'s `WHERE` clause — reintroducing exactly the `409` ADR-21 says must never
happen on this path. `ExecuteUpdateAsync` issues the SQL directly with no concurrency-token
predicate, which is the correct implementation of an already-approved ADR, not a new
architectural pattern requiring separate plan.md sign-off.
*Action: none — covered by `MoveCard_TwoSuccessiveMoves_NeitherIsRejected_LastWriteWins`,
which proves two successive moves against the same card both return `204`.*

### F2 — `ListService`/`CardService` each keep their own private `CanMutate(role)` — ACCEPTED

Duplicates the one-line role check 004's `CardService` already had, rather than
introducing a new shared `BoardRole` helper class. No such shared utility exists anywhere
in the codebase yet; adding one now for a single line would be exactly the kind of
unapproved abstraction `backend-rules.md`'s "New code MUST follow the existing layout"
warns against introducing without a plan.md justification.
*Action: none.*

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS. Implementation follows spec.md/plan.md/tasks.md;
  no undocumented behavior added.
- **II. Source of Truth Hierarchy** — PASS. No visual references engaged this phase
  (backend-only); no conflicts encountered.
- **III. Repository Separation** — PASS. `flowboard-api` only touched.
- **IV. Architecture Consistency** — PASS. Minimal-API endpoint groups over a service
  layer, matching 001–004's established layout; no new package; `ListsEndpoints.cs` is a
  new file but the same shape as `CardsEndpoints.cs`, per plan.md's own Complexity
  Tracking entry for this feature.
- **V. Data Standards** — N/A this phase (no schema change).
- **VI. Auditability** — PASS. `card.moved` carries `CreatedBy`/`CreatedDate` like every
  other `ActivityEvent`; `UpdatedBy`/`UpdatedDate` set on every move (both Card and List).
- **VII. Domain Invariants** — PASS, see below.
- **VIII. Security** — PASS. Both routes require auth + board-role resolution; Observer
  gets `403`, no access gets `404`.
- **IX. External Integration Governance** — N/A (no external integration this feature).
- **X. Performance Responsibility** — PASS. Sibling-position lookups are indexed
  (`(ListId, Position)` / `(BoardId, Position)`, both from 001/003's schema); no N+1.
- **XI. Testing Requirements** — PASS. Every endpoint has an integration test; ordering
  resolution has a golden-fixture test.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Backend gates and merges before frontend begins,
  per `docs/sdlc/repository-strategy.md`.

### Domain invariant pass

| # | Invariant | How satisfied |
|---|---|---|
| 1 | Activity append-only | `card.moved` is `Add`-only; no move path updates/deletes an `ActivityEvent` |
| 2 | Ordering integrity | Both move paths resolve positions exclusively through `Ordering.Append`/`InsertBetween`; no inline arithmetic |
| 3 | WIP limits advisory | Neither endpoint checks `WipLimit`; `MoveCard_DestinationOverWipLimit_StillSucceeds` proves it |
| 4 | Soft delete | Move endpoints operate through the existing `!IsDeleted` query filters (no `IgnoreQueryFilters()` used) |
| 5 | Permissions server-side | `BoardAccessService.ResolveAsync` re-checked per request on both endpoints |
| 6 | Optimistic concurrency | Deliberately NOT applied to moves (ADR-21) — Card field-edits (004's `PATCH`) keep their own `If-Match`/`409` untouched |
| 7 | Labels board-scoped | N/A — this feature never touches labels |
| 8 | Opaque public IDs | Both move endpoints address exclusively by `PublicId`; internal `Id` never crosses the API boundary |

## Test coverage observed

- `CardsEndpointTests.cs`: 8 new facts — same-list reorder (no activity), cross-list move
  (exactly one `card.moved`), destination over its WIP limit (still `204`), two successive
  moves (both `204`, no `409`), cross-board `listPublicId` (`400`), cross-board/foreign-list
  `beforeCardPublicId` (`400`), non-member (`404`), Observer (`403`).
- `ListsEndpointTests.cs` (new): 5 facts — reorder persists on refetch, same-position move
  is an observable no-op, cross-board `beforeListPublicId` (`400`), non-member (`404`),
  Observer (`403`). `DisposeAsync` restores the four seeded Product Roadmap lists' fixed
  positions after every test so `BoardsEndpointTests`'s stored-order assertion (which
  shares the same database) is never affected by this class's moves.
- `OrderingTests.cs`: 5 new facts — a pure, DB-free restatement of the insertion-point
  resolution algorithm (research.md R-1) against hand-worked sibling-position tables:
  before-first (no predecessor), before-middle, before-last, append (last-position + 1
  step), append into an empty list.
- Full suite: 89/89 passing (71 pre-existing + 18 new), user-confirmed
  `dotnet build --warnaserror && dotnet test` → `EXIT: 0`.

## Residual risk

None identified for this phase. The one non-obvious technique (F1) is isolated to a
single method and directly tested; list-move is a genuinely new endpoint group but follows
the existing card-endpoint shape exactly, so no new review burden for future features.
