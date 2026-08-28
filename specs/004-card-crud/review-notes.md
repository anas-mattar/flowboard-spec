# Review Notes — 004 Card Lifecycle CRUD

## Phase A — backend (Foundational + Card Mutations) (T001–T030)

**Gate**: `dotnet build --warnaserror && dotnet test` in `flowboard-api` — my own fast-feedback
run (allowed mid-implementation for this Standard-delivery feature) shows 0 warnings/0
errors and 71/71 tests passing. The certifying run is the user's, requested after this
review.

**Diff surface**: new `Domain/Entities/ActivityEvent.cs`, `Domain/ActivityEventType.cs`,
`Domain/Ordering.cs` (ADR-18, fulfilling 001's ADR-4 reservation), `Domain/CardDueStatus.cs`
(research R-5, extracted from `BoardContentService`), `Data/Configurations/
ActivityEventConfiguration.cs`, `Endpoints/CardsEndpoints.cs`, `Services/CardService.cs`,
`Migrations/20260828034037_AddCardActivity.{cs,Designer.cs}`, `tests/
CardsEndpointTests.cs`, `tests/OrderingTests.cs`. Edited: `ChecklistItemConfiguration.cs`
(+`PublicId` column and its seed backfill), `ChecklistItem.cs` (+`PublicId` property),
`FlowboardDbContext.cs` (+1 `DbSet`), `Program.cs` (+1 DI registration, +1 endpoint-group
mapping), `BoardContentService.cs` (inline `dueStatus` bucketing replaced by a call to the
new shared `CardDueStatus.Compute`, per R-5 — behavior unchanged),
`FlowboardDbContextModelSnapshot.cs` (EF-generated). No files outside this feature's
schema/service/endpoint scope; 002/003's auth, board-membership, and board-content read
logic are untouched except the R-5 extraction (which is a pure refactor with no behavior
change, confirmed by 003's own `BoardsEndpointTests` still passing unmodified).

**AI review vs `docs/rulebooks/backend-compliance-checklist.md`** (2026-08-28):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `CardsEndpoints.cs` uses `MapCardsEndpoints` + `MapGroup`; handlers are thin (auth check + input-shape parsing, then one service call); both `CardsEndpoints.cs` and `CardService.cs` cite `contracts/card-crud-api.md` in a top comment |
| API Surface | PASS | Title/text/body length validated before any write, returning `ValidationProblem`; every DTO exposes `PublicId` only; `PATCH /v1/cards/{id}` requires `If-Match` and returns `409` on a stale `RowVersion` (via `DbUpdateConcurrencyException`, not a manual check-then-write race); `GET /v1/cards/{id}/activity` is cursor-paginated (ADR-12's shape reused) |
| Domain & Authorization | PASS | Every route resolves the caller's role via `BoardAccessService.ResolveAsync` before acting (invariant 5); `Observer` is permitted only on the three read/comment routes, enforced by one `CanMutate(role)` helper reused everywhere else (R-2's fixed table). Invariant 7 enforced in `AddLabelAsync` (`label.BoardId != card.List.BoardId` → `400`). Invariant 5's sanctioned side effect (`AddMemberAsync` inserting a `BoardMember` row) is scoped to exactly that one path. All position math for card create/copy/checklist-item create goes through `Ordering.cs` — no inline arithmetic elsewhere (invariant 2). Invariant 1 verified two ways: no code path calls `Update`/`Remove` on `ActivityEvents`, and every state-changing card action writes one — including checklist **unchecking**, found missing during this review (see below) |
| Data Access & Performance | PASS (one accepted tradeoff) | Pure-read aggregation queries (`BuildDetailDtoAsync`, `GetActivityAsync`, `CopyCardAsync`'s label/member/checklist reads) use `AsNoTracking()` + `.Select()` projection. `ResolveCardAsync`/`ResolveChecklistItemAsync` intentionally do **not** use `AsNoTracking()` — they're the single shared resolver for both mutating and read paths (avoids duplicating the `Card → List → Board` access-resolution logic across 14 routes), so `GetCardDetailAsync` incurs one tracked single-row query it doesn't strictly need. Accepted as a deliberate simplicity-over-micro-optimization tradeoff (single row, not a collection scan) rather than forking a duplicate untracked resolver. No N+1 (all aggregate reads are flat `.Select()` projections, not per-row loops); all I/O async with `CancellationToken`; no explicit `IgnoreQueryFilters()` in production code (test-only cleanup uses it, appropriately) |
| Security | PASS | `.RequireAuthorization()` on every route; all data access is LINQ (parameterized); no secrets in source; external HTTP N/A |
| Testing | PASS | `CardsEndpointTests.cs` covers all 14 routes: success, validation failure (empty title/text/body, missing `If-Match`, rejected `list_id`/`position`), authorization failure (404 non-member, 403 Observer on every mutating route, Observer-may-comment), and the concurrency conflict (`409` on stale `If-Match`, proven by a real first-writer-wins sequence). `OrderingTests.cs` gives `Ordering.Append`/`InsertBetween` golden-fixture coverage with hand-worked values |
| Process | PASS | No new packages; diff surface above is exactly T001–T030's scope; gate previously only self-run, user confirmation requested below |

**Gap found and fixed during this review**: `UpdateChecklistItemAsync` originally wrote a
`checklist.item.checked` event only when `done == true`, silently dropping unchecking as
an unrecorded state change (an invariant-1 gap — a state-changing card action with no
activity trail). Fixed by adding a `checklist.item.unchecked` type (also documented in
`data-model.md`'s `ActivityEvent.Type` enumeration) and only writing either event when the
value actually changes (so re-sending the same `done` value, e.g. a retried optimistic
update, no longer double-logs). Covered by a new assertion in
`ChecklistItem_AddCheckDelete_Flow`.

**Verdict**: Phase A PASS — one real gap found (missing unchecked-state activity event)
and fixed within this review before recording it; one accepted, disclosed performance
tradeoff; no other FAIL items, no waivers. Cleared to commit once the user runs the
backend gate and confirms exit 0.
