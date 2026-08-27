# Review Notes — 003 Board View (Read-Only)

## Phase A — backend board content (T001–T024)

**Gate**: `dotnet build --warnaserror && dotnet test` in `flowboard-api` — run by the
user 2026-08-28, **EXIT: 0 confirmed** (build 0 warnings / 0 errors; 40/40 tests
passed). Two more test cases (`ListBoards_LimitOutOfRange_ReturnsValidationProblem`,
`ListBoards_MalformedCursor_ReturnsValidationProblem`) were added immediately
afterward, during this AI review, to close a Testing-checklist gap (see below) — the
confirmed run predates them, so a fresh gate confirmation is needed before commit. My
own fast-feedback re-run (allowed mid-implementation for this Standard-delivery
feature) shows 43/43 passing after the addition.

**Diff surface**: new `Domain/Entities/{List,Card,Label,CardLabel,CardMember,
ChecklistItem,Comment}.cs`, new `Domain/CursorPage.cs` (ADR-12), new
`Data/Configurations/{List,Card,Label,CardLabel,CardMember,ChecklistItem,Comment}
Configuration.cs`, new `Migrations/20260827165840_AddBoardContent.{cs,Designer.cs}`,
new `Services/BoardContentService.cs`, new `Endpoints/BoardsEndpoints.cs`, new
`tests/BoardsEndpointTests.cs`. Edited: `BoardConfiguration.cs` (+`Color`/`Starred`
columns and the three-board seed), `BoardMemberConfiguration.cs` (+5 seeded
memberships), `UserConfiguration.cs` (+5 seeded placeholder users for card-avatar
fidelity), `Board.cs` (+2 properties), `FlowboardDbContext.cs` (+7 `DbSet`s),
`Program.cs` (+2 DI registrations, +1 endpoint-group mapping),
`FlowboardDbContextModelSnapshot.cs` (EF-generated). No files outside this feature's
schema/seed/read-endpoint scope; 002's auth/board-membership business logic is
untouched.

**AI review vs `docs/rulebooks/backend-compliance-checklist.md`** (2026-08-28):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `BoardsEndpoints.cs` uses `MapBoardsEndpoints` + `MapGroup("/v1/boards")`; handlers are thin (auth check + input shape check, then one service call); both `BoardsEndpoints.cs` and `BoardContentService.cs` cite `contracts/board-content-api.md` in a top comment |
| API Surface | PASS | `limit`/`cursor` validated at the boundary → `ValidationProblem`; every DTO exposes `PublicId` only, never the internal `Id`; `GET /v1/boards` is cursor-paginated (ADR-12); `409`/`If-Match` N/A — no writes in this feature |
| Domain & Authorization | PASS | `GetBoardContentAsync` calls `BoardAccessService.ResolveAsync` before any query (invariant 5); `ListBoardsAsync` has no per-board check by contract design — it queries exactly the boards the caller owns or is an explicit member of, which *is* the enforcement point for a list operation, not a gap. Soft-delete (invariant 4) and board-scoping (invariant 7) both fall out of existing query filters and the `CardLabel`→`Card`→`List`→`Board` FK chain — no leakage path exists. Position sorted, not recomputed — research R-8's deferred `Ordering.cs` module is for write-side move math, which doesn't exist yet; a plain `OrderBy(x => x.Position)` isn't the "inline re-derivation" that rule targets. Invariant 1 (Activity Append-Only) and 6 (Optimistic Concurrency) are N/A — no mutations in this feature |
| Data Access & Performance | PASS | Every query is `AsNoTracking()` + `.Select()` projection; `GetBoardContentAsync` batches lists/cards/checklist-counts/comment-counts/labels/members as flat `WHERE id IN (...)` queries and joins in memory instead of nesting correlated collections three levels deep — avoids both N+1 and an EF translation risk; `ListBoardsAsync`'s per-board `CardCount` is a single correlated scalar subquery inside one SQL statement, not a per-row round trip; no explicit `IgnoreQueryFilters()`; all I/O `async` with `CancellationToken` throughout |
| Security | PASS | `.RequireAuthorization()` on the boards group; all data access is LINQ (parameterized) — the one `migrationBuilder.Sql(...)` call in `AddBoardContent.Up()` interpolates only an internal `DateTime`/`int` computed value, never user input, so it carries no injection surface despite the string-interpolation shape; no secrets in source; external HTTP N/A |
| Testing | PASS (after fix) | Initially missing a validation-failure case (checklist requires success/validation/authz/concurrency coverage) — added `ListBoards_LimitOutOfRange_ReturnsValidationProblem` and `ListBoards_MalformedCursor_ReturnsValidationProblem` during this review. Final coverage: success (list + hydrate), validation failure (bad limit, bad cursor), authorization failure (404 for no access, 404 for unknown board), and the T024 golden-fixture test asserting `dueStatus`/checklist/comment/label/member values against hand-worked expectations; concurrency N/A (no writes) |
| Process | PASS | No new packages; diff surface reviewed above is exactly this feature's schema/seed/read-endpoint scope; gate previously user-confirmed EXIT 0, re-confirmation requested for the two added tests |

**Verdict**: Phase A PASS — one gap found (missing validation-failure tests) and fixed
within this review before recording it; no other FAIL items, no waivers. Cleared to
commit once the gate is re-confirmed against the current diff.
