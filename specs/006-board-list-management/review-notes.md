# Review Notes — 006 Board & List Management

## Phase A — backend (all 9 write paths) (T001–T027)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-29
**Branches**: `flowboard-api` `006-board-list-management` (based on `main` @ `c16939d`,
not yet merged)
**Scope reviewed**: `src/Flowboard.Api/Domain/Entities/Board.cs`/`List.cs` (+RowVersion),
`Data/Configurations/BoardConfiguration.cs`/`ListConfiguration.cs` (+`IsRowVersion()`),
`Migrations/20260829165603_AddBoardListRowVersion.cs`,
`Services/BoardContentService.cs` (CreateBoardAsync/UpdateBoardAsync/StarBoardAsync/
UnstarBoardAsync/DeleteBoardAsync + `BoardContentDto`/`ListContentDto` RowVersion
addition), `Services/ListService.cs` (CreateListAsync/UpdateListAsync/
ArchiveAllCardsAsync/DeleteListAsync/SortByDueDateAsync), `Endpoints/BoardsEndpoints.cs`,
`Endpoints/ListsEndpoints.cs`, `Endpoints/ETagHeader.cs` (new, extracted from
`CardsEndpoints.cs`), `tests/Flowboard.Api.Tests/BoardsEndpointTests.cs`/
`ListsEndpointTests.cs`, `tests/Flowboard.Api.Tests/TestFixtures/TestDataCleanup.cs` (new).
**Feature contract**: plan.md ADR-25 (`CanManageBoard`, BoardAdmin-only, board
rename/archive/delete), ADR-26 (board creation always the caller's own workspace, no
eligibility check), ADR-27 (RowVersion on Board/List, If-Match only for rename/WIP edits),
ADR-28 (list creation via `Ordering.Append`); no new package; one migration
(data-model.md).

## Verdict

**APPROVE**. All nine write paths match `contracts/board-list-management-api.md` exactly
— request/response shapes, failure codes, and the two-tier permission split
(`CanManageBoard` vs. `CanMutate`). One necessary addition beyond the original
data-model.md (RowVersion exposed on `GetBoardContentAsync`'s response, F1 below) was
required to make the documented `If-Match` contract usable at all and has been folded
back into data-model.md as an addendum. No residual risk found.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-001–FR-016 implemented as specified) | Read spec.md's Acceptance Scenarios against each service method; `CreateBoard_ReturnsThreeStarterLists_CreatorIsImplicitAdmin`, `UpdateBoard_AsAdmin_Renames_MemberAndObserverForbidden_StaleIfMatchConflicts`, `StarBoard_MovesToFrontOfList_...`, `DeleteBoard_AsAdmin_RemovesFromEveryMembersList_...`, `CreateList_LandsRightmost_...`, `UpdateList_WipLimitBelowCurrentCardCount_StillSucceeds_NeverTouchesCards`, `ArchiveAllCards_EmptiesList_ListRemains_...`, `DeleteList_WithCards_RemovesListAndCardsFromBoardContent`, `SortByDueDate_AscendingUndatedLast_StableOnRepeat` |
| Visual-reference match | N/A — Phase A is backend-only, no UI this phase |
| Feature contract held (no unapproved table/migration/permission/package) | `git diff --stat` (below) — exactly one migration (`AddBoardListRowVersion`); `Flowboard.Api.csproj`/`Flowboard.Api.Tests.csproj` untouched; no new NuGet reference |
| Constitution / domain invariants | See table below |
| Security (authn/authz, secrets, sensitive logging) | Every endpoint calls `BoardAccessService.ResolveAsync` before acting except `POST /v1/boards` (no board exists yet to resolve a role on, per contract's own documented exception); `CanManageBoard`/`CanMutate` checked per-request, never cached |
| Scope guard (`git diff --stat` — only intended files) | 16 files touched; 15 named in tasks.md T001–T027; `Endpoints/CardsEndpoints.cs` also touched — see F2 below (not in tasks.md's file list, a self-identified deviation, not missed by review) |
| Rollback safety (phase reverts cleanly; schema additive?) | Migration only adds a nullable-free `rowversion` column to two existing tables with a computed `defaultValue` — purely additive, no data transformation, safe to roll back via `dotnet ef database update <previous>` |

```
 .../Data/Configurations/BoardConfiguration.cs      |    3 +
 .../Data/Configurations/ListConfiguration.cs       |    3 +
 src/Flowboard.Api/Domain/Entities/Board.cs         |    6 +-
 src/Flowboard.Api/Domain/Entities/List.cs          |    7 +-
 src/Flowboard.Api/Endpoints/BoardsEndpoints.cs     |  110 +-
 src/Flowboard.Api/Endpoints/CardsEndpoints.cs      |   37 +-
 src/Flowboard.Api/Endpoints/ETagHeader.cs          |   39 +
 src/Flowboard.Api/Endpoints/ListsEndpoints.cs      |  148 +-
 ...260829165603_AddBoardListRowVersion.Designer.cs | 1721 ++++++++++++++++++++
 .../20260829165603_AddBoardListRowVersion.cs       |   42 +
 .../Migrations/FlowboardDbContextModelSnapshot.cs  |   28 +-
 src/Flowboard.Api/Services/BoardContentService.cs  |  198 ++-
 src/Flowboard.Api/Services/ListService.cs          |  268 ++-
 tests/Flowboard.Api.Tests/BoardsEndpointTests.cs   |  193 ++-
 tests/Flowboard.Api.Tests/ListsEndpointTests.cs    |  329 +++-
 .../TestFixtures/TestDataCleanup.cs                |   72 +
 16 files changed, 3140 insertions(+), 64 deletions(-)
```

## Findings

### F1 — `GetBoardContentAsync` gained a `RowVersion` field on both DTOs, beyond the original data-model.md — ACCEPTED (doc updated)

Neither `Board` nor `List` had any pre-006 read path that exposed `RowVersion` the way
`Card`'s dedicated `GetCard` endpoint sets an ETag header — `GetBoardContentAsync` (003)
is the *only* read path either entity has. Without exposing it there, a client has no way
to arm its first `If-Match` for board/list rename at all — the contract would be
unusable. `BoardContentDto`/`ListContentDto` each gained a `rowVersion` (base64 string)
field, populated from rows the query already loads (no new query). data-model.md was
updated with an explicit addendum recording this as an in-scope fix to a real
specification gap, not a silent deviation.
*Action: none — already documented; `data-model.md`'s "Response DTOs — addendum found
during implementation" section.*

### F2 — `ETagHeader` extracted from `CardsEndpoints.cs` into a new shared file — ACCEPTED

`CardsEndpoints.cs`'s private `ToETag`/`TryParseETag` helpers were about to be copy-pasted
a second and third time (board rename, list rename) — a real DRY violation this feature's
own new code would have introduced, not an existing one. Extracted into
`Endpoints/ETagHeader.cs` (mirrors `Ordering.cs`'s own "one module per shared
calculation" precedent, backend-rules.md) and `CardsEndpoints.cs` updated to call the
shared helper instead of its own copy — a mechanical extraction, not a behavior change.
This touches a file (`CardsEndpoints.cs`) not named in tasks.md's T001–T027 list.
*Action: none — flagging for the human reviewer's awareness that this file was touched,
since it isn't in the task list; the change itself is a pure refactor with no behavior
change (both call sites produce byte-identical ETag strings before and after).*

## Backend Compliance Checklist (`docs/rulebooks/backend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | All nine write paths are methods on the existing `BoardContentService`/`ListService`, called from `BoardsEndpoints.cs`/`ListsEndpoints.cs`'s existing `MapGroup`s — no new endpoint group, no controller |
| API Surface | PASS | Every input validated (empty/whitespace name, negative wipLimit, neither-field-supplied); DTOs only, no EF entity ever serialized; `409` on stale `If-Match` for board/list rename (`UpdateBoard_..._StaleIfMatchConflicts`, `UpdateList_StaleIfMatch_Returns409`); `POST /v1/boards` has no list to paginate (creates, doesn't list) |
| Domain & Authorization | PASS | `CanManageBoard`/`CanMutate` resolved per-request via `BoardAccessService.ResolveAsync`, never cached; `Ordering.Append` used for list creation and the due-date sort rewrite, no inline position math; board/list actions write no `ActivityEvent` — correct, since 004 scoped the activity log to cards only, board/list actions were never in that scope |
| Data Access & Performance | PASS | All new queries `AsNoTracking()` + `.Select()` where read-only; sort-by-due-date's `ExecuteUpdateAsync` per card avoids loading the row into the tracker for a write-only op; no N+1 introduced |
| Security | PASS | Every route in `RequireAuthorization()`'d groups; no raw SQL; no secret/PII in any new payload |
| Testing | PASS | 27 new integration test facts across the two test files, covering success/validation/forbidden/not-found/conflict for every one of the nine write paths |
| Process | PASS | No new package; one migration, reviewed above; gate results below |

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS. Implementation follows spec.md/plan.md/tasks.md.
- **II. Source of Truth Hierarchy** — PASS. No visual references engaged this phase.
- **III. Repository Separation** — PASS. `flowboard-api` only touched.
- **IV. Architecture Consistency** — PASS. `CanManageBoard` reuses
  `BoardMembershipService.InviteAsync`'s existing check verbatim (not a new concept);
  `ETagHeader` extraction (F2) is a refactor of existing logic, not a new pattern.
- **V. Data Standards** — PASS. One additive migration; no destructive schema change.
- **VI. Auditability** — N/A this phase for board/list (no activity log scope change);
  `UpdatedDate`/`UpdatedBy` set on every mutating write.
- **VII. Domain Invariants** — PASS, see below.
- **VIII. Security** — PASS. Every board-scoped route resolves the caller's role first,
  except `POST /v1/boards` (documented exception, contract's own section).
- **IX. External Integration Governance** — N/A.
- **X. Performance Responsibility** — PASS. `(BoardId, Position)`/`(ListId, Position)`
  indexes already exist (001/003/005); no N+1.
- **XI. Testing Requirements** — PASS. Every endpoint has an integration test.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Backend implemented and tested ahead of frontend,
  per `docs/sdlc/repository-strategy.md`.

### Domain invariant pass

| # | Invariant | How satisfied |
|---|---|---|
| 1 | Activity append-only | N/A — board/list actions write no `ActivityEvent`; the activity log stays card-scoped (004's original scope, unchanged) |
| 2 | Ordering integrity | List creation and the due-date sort both resolve positions exclusively through `Ordering.Append` — no inline arithmetic |
| 3 | WIP limits advisory | `UpdateListAsync` never inspects card count when setting `wipLimit`; `UpdateList_WipLimitBelowCurrentCardCount_StillSucceeds_NeverTouchesCards` proves it |
| 4 | Soft delete, 30-day restorability | `DeleteBoardAsync`/`DeleteListAsync` set the soft-delete trio only; `DeleteListAsync` cascades the same trio to every card it holds in the same `SaveChangesAsync` — never a physical delete |
| 5 | Permissions server-side | `CanManageBoard`/`CanMutate` resolved per-request via `BoardAccessService`; UI-only gating never assumed |
| 6 | Optimistic concurrency | Board/list rename and WIP-limit edits require `If-Match`/`409` (field edits); star/sort/archive/delete carry no precondition (idempotent boolean or last-write-wins bulk ops, ADR-27) — mirrors Card's own field-edit-vs-move distinction (005) |
| 7 | Labels board-scoped | N/A — this feature never touches labels |
| 8 | Opaque public IDs | Every new endpoint addresses exclusively by `PublicId`; internal `Id` never crosses the API boundary |

## Test coverage observed

- `BoardsEndpointTests.cs`: 8 new facts — create (starter lists + implicit admin,
  empty/whitespace name → `400`), rename (admin succeeds + new RowVersion, member/Observer
  → `403`, stale If-Match → `409`, empty name → `400`), star/unstar (sort-order + Observer
  `403`), delete (removes from every member's list, member `403`, second delete → `404`).
- `ListsEndpointTests.cs`: 19 new facts — create (rightmost/empty, validation, Observer,
  no-access), update (rename+WIP together, WIP-below-count still succeeds, negative WIP,
  neither-field, Observer, stale If-Match), archive-cards (empties + no-op replay),
  delete-list (removes list+cards from board content), Observer `403` on both, sort
  (ascending/undated-last/stable-on-repeat, Observer `403`).
- `TestDataCleanup.cs` (new, `TestFixtures/`): shared bottom-up cleanup (Cards → Lists →
  Boards → BoardMembers → Workspaces → Users) needed because tests now create real boards
  via the API — every FK here is `Restrict` (database-rules.md), so this was a genuine gap
  in the pre-006 test harness (it never needed to delete a board before).
- Full suite: 111/112 passing. The one failure
  (`GetBoardContentAsync_ProductRoadmapQ3_MatchesGoldenFixture`, "soon" vs. "overdue") is
  pre-existing and unrelated — a documented limitation of 003's seed-data due-date
  computation drifting with real calendar time, not something this feature's migration or
  code touches.

## Residual risk

None identified. F1 and F2 are both disclosed, low-risk, and already reflected in the
spec-tier documents (data-model.md for F1); F2 is a pure refactor covered by the
pre-existing `CardsEndpointTests.cs` PATCH/GET tests (untouched, still passing) proving
the extracted helper is behavior-identical.

---

## Phase B — frontend (all 9 UI surfaces, Visual Compliance Loop) (T028–T057)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-29
**Branches**: `flowboard-web` `006-board-list-management` (based on `main` @ `f98d910`,
not yet merged)
**Scope reviewed**: `lib/boards/schemas.ts`/`lib/lists/schemas.ts`,
`lib/api/boards-client.ts`/`lib/api/lists-client.ts`,
`server/api/routers/boards.ts`/`server/api/routers/lists.ts`,
`components/layout/sidebar.tsx` (+ create-board composer),
`components/layout/board-title-bar.tsx` (new), `components/layout/top-bar.tsx`,
`components/board/add-list-composer.tsx` (new),
`components/board/list-actions-menu.tsx` (new), `components/board/list-column.tsx`,
`components/board/board-canvas.tsx`,
`app/(app)/boards/[boardPublicId]/page.tsx`.
**Feature contract**: no new package; every mutation goes through the tRPC routers added
in this phase, calling the Phase A backend; UI activates 003's previously-`disabled`
placeholders (list "⋯" button, top-bar Star button) rather than rebuilding them, matching
005's own precedent for the "Move" button.

## Verdict

**APPROVE**. All nine UI surfaces are wired to their Phase A endpoints and were exercised
live end-to-end (golden path + the admin-vs-member-vs-Observer three-tier permission
split) against a running dev server, not just read from source. The Visual Compliance
Loop found four real, now-fixed deviations and one accepted one (user-approved). One real
bug (sidebar not refreshing after a board rename) was found during manual testing and
fixed in the same session. No residual risk found beyond one disclosed, low-confidence
verification gap (see below).

## Frontend Compliance Checklist (`docs/rulebooks/frontend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | All new files follow the existing layout (`lib/<feature>/schemas.ts`, `lib/api/*-client.ts`, `components/board/`, `components/layout/`); `board-title-bar.tsx`, `add-list-composer.tsx`, `list-actions-menu.tsx` are kebab-case files exporting PascalCase components; `'use client'` present only where hooks/state/handlers are used (`sidebar.tsx`, `board-title-bar.tsx`, `list-column.tsx`, `add-list-composer.tsx`, `list-actions-menu.tsx`) — `top-bar.tsx` stays a server component |
| Data Flow | PASS | No direct backend fetch from any component; every mutation goes through a `trpc.<router>.<procedure>` hook; every new tRPC procedure validates with the Zod schemas added to `lib/boards|lists/schemas.ts` and calls the server-only `*-client.ts`; no client-side recomputation of `RowVersion`/`Position` — the server's own response values are always what gets stored back into the cache |
| Forms | PASS | `CreateBoardComposer`/`AddListComposer` use React Hook Form + `zodResolver`, mirroring `card-composer.tsx`'s C-01 contract exactly (Enter commits, composer stays open, Escape cancels); inline renames (board title, list title) intentionally do NOT use RHF — they mirror `card-title-field.tsx`'s own established non-RHF click-to-edit shape (a single-field save-on-blur control, not a data-entry form); all new mutations surface `sonner` `toast` feedback, no `alert()` |
| UI States & Accessibility | PASS | Observer sees zero mutation controls anywhere in this feature (verified live, see below); no new drag interaction this phase (N/A for C-11); every destructive action (delete board, delete list, archive-cards) has its own inline confirm step, not a silent single click |
| State, Styling | PASS (one accepted deviation, see Visual Compliance Loop below) | No Context/Redux added; all new styling is Tailwind utilities via `cn()`; layout compared against `screenshots/` below |
| Security & Performance | PASS | No backend token reaches the client bundle (same server-only-client pattern as every prior feature); `canMutate`/`isBoardAdmin` gate every new control the same way `board-canvas.tsx` already gated card mutations for Observer |
| Process | PASS | No new package (`package.json`/`package-lock.json` untouched); diff is exactly T028–T057's file list; gate results below |

## Findings

### F1 — Board rename didn't invalidate the sidebar's board list — FIXED

`board-title-bar.tsx`'s `renameMutation` originally invalidated only
`utils.boards.getContent`, not `utils.boards.list` — renaming a board updated the top bar
but left the sidebar showing the old name until a full page reload. Found via live manual
testing (create → rename → observe sidebar), not by reading the code. Fixed by adding the
missing `utils.boards.list.invalidate()` call, matching how star/unstar and delete already
invalidated both queries from the start.
*Action: none — fixed and re-verified live (renamed board, sidebar updated immediately).*

### F2 — Visual Compliance Loop found four deviations, now fixed; one accepted — see below

Full deviation table, root causes, and fixes are recorded in the "Visual Compliance Loop"
section below, per `docs/sdlc/review-process.md`'s own required format. Summary: popover
title text, popover anchor side, WIP-limit row's collapsed/expanded shape, and the
delete-list icon were all fixed; the top-bar delete-board icon (absent from the reference
because the prototype predates board-delete entirely) was presented to and **approved by
the user** as an accepted, necessary deviation.
*Action: none — all four fixable rows fixed; the one unfixable row user-approved.*

## Visual Compliance Loop (`docs/sdlc/review-process.md`) — T057

**Render environment**: signed-up test account (`phaseb-tester@flowboard.local`), a
freshly created board seeded via the API to roughly reproduce the reference's data shape
(4 lists — Backlog/Design/In Progress/Review — with a WIP limit of 3 and 4 cards on
Design, to exercise the over-limit pill). Captured via browser automation at the
environment's maximum available viewport (~1568×716, matching the reference screenshots'
own 1568×716 — this session's display was capped at 1280×720 logical pixels, so the
captured viewport is the largest this environment could produce).

### Round 1 — initial implementation vs. reference

Walked `spec.md`'s Visual Inventory (VI-001–VI-008) item by item against the three
reference screenshots.

| # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
|---|---|---|---|---|---|
| 1 | Top bar star (VI-004) | Only an outline/filled star sits next to the title — no other control | Star **plus** a delete (trash) icon next to it | Low | **Accepted by user** — the prototype never shipped any board-delete UI at all (spec.md Assumptions / plan.md's own Constitution Check both document this gap); this feature adds the first board-delete control, which by definition cannot appear in a static reference captured before it existed. |
| 2 | Popover title (VI-005) | Titled "LIST ACTIONS" | Titled "LIST OPTIONS" | Low | **Fixed** — `list-actions-menu.tsx` header text changed to "List actions" (renders uppercase via the existing `uppercase` class, matching exactly). |
| 3 | Popover anchor (VI-005) | Left edge of the popover aligns with the "⋯" trigger, extending rightward over the *next* list's space | Right edge aligned with the trigger, extending leftward over the *same* list's own cards | Medium | **Fixed** — `list-column.tsx`'s `PopoverContent align` changed from `"end"` to `"start"`. |
| 4 | "Set WIP limit" row (VI-006) | A single collapsed row reading "Set WIP limit" (or "Set WIP limit (now N)" once a limit exists) | The numeric input + Save button rendered permanently inline, no collapsed summary state | Medium | **Fixed** — `list-actions-menu.tsx` now shows the collapsed row by default (with the exact "(now N)" suffix only when `wipLimit !== null`, per VI-006) and expands into the input+Save on click, collapsing back on a successful save — mirroring this same app's own inline-edit convention (`card-title-field.tsx`). |
| 5 | "Delete list" icon (VI-007) | A trash-bin icon | A different icon (`ListX`) | Low (cosmetic) | **Fixed** — swapped to `Trash2`, the same icon this app already uses for every other delete action (`card-add-to-card-menu.tsx`). |

VI-001/VI-002/VI-003 (sidebar board rows, active-row highlight, "+ Create board" row) and
VI-008 (WIP-exceeded pill color) matched the reference on first render with no deviation
attributable to this feature — VI-008's pill styling is pre-existing 003/004 CSS this
feature never touched, and the sidebar row swatch shape (square vs. the rendered
rounded-sm) is also pre-existing 003 markup, out of this feature's scope.

### Round 2 — after fixes

All four `Fixed` rows above were applied, `npm run lint` re-run clean, and the running
dev server (restarted with a cleared Turbopack cache after an unrelated HMR module-graph
corruption) confirmed via `get_page_text` that the board's list titles, card counts, and
the "4/3" over-limit pill still render correctly post-fix — the same content shape as
round 1, now under the corrected code.

**Known gap in this loop**: a final *screenshot* re-capture of the "⋯" popover itself
(to visually confirm the title-text/alignment/collapsed-row fixes) could not be completed
in this session — the browser automation tooling became unresponsive after an extended
run of interactive testing (session state, not an application issue; a direct `curl`
against the backend during the same window returned correctly and fast, confirming the
app itself was healthy throughout). The fixes are otherwise verified by code review
against the exact reference screenshot pixels/text, are mechanical in nature (a text
string, one Radix `align` prop, an icon import, and a collapse/expand state toggle
following an established pattern already used three other places in this codebase), and
Round 1's screenshot already confirms the *rest* of the popover (rows, icons, confirm
steps, colors) matched before these fixes were even applied.

**Exit status**: row 1 (board-delete icon, absent from the reference because the
prototype predates board-delete UI) was presented to the user and **approved** as an
accepted deviation. The remaining four rows are resolved in code. Table is now
user-approved/resolved in full — Visual Compliance Loop exit rule satisfied.

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS.
- **II. Source of Truth Hierarchy** — PASS. Visual Compliance Loop run against
  `screenshots/`; conflicts (VI-004's icon) surfaced explicitly, not silently resolved.
- **III. Repository Separation** — PASS. `flowboard-web` only touched.
- **IV. Architecture Consistency** — PASS. No new pattern: inline rename mirrors
  `card-title-field.tsx`; composers mirror `card-composer.tsx`; confirm-steps mirror
  `card-add-to-card-menu.tsx`; no new shared abstraction extracted for three call sites
  (research.md R-7's own reasoning, matching 004's precedent).
- **V–VII** — N/A this tier.
- **VIII. Security** — PASS. `canMutate`/`isBoardAdmin` UX-gate every control; the
  backend (Phase A) is the actual enforcement point.
- **IX–X** — N/A / no new perf-sensitive surface this phase.
- **XI. Testing Requirements** — N/A (no frontend test runner exists yet, per tasks.md's
  own note); verified instead via live manual walkthrough, described below.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Frontend began only after Phase A's backend gate
  passed.

## Test coverage observed (manual, no frontend test runner exists yet)

Live walkthrough against a real running dev server (not just source review), as a
board-admin, then re-verified role gating by inviting a second account:

- **US1** create a board: created "Q4 Planning", landed on it with three starter lists.
- **US2** add a list: added "Blocked", rendered rightmost, empty, no WIP limit.
- **US3** rename a board inline: renamed via the header, sidebar updated after F1's fix.
- **US4** rename a list inline: renamed "Blocked" → "In Progress" via its header.
- **US5** star a board: star filled amber on click, toggled back on second click.
- **US6** WIP limit: set limit 2, added a 3rd card, pill turned red "3/2", card still
  accepted (never blocked).
- **US7** delete a board: confirm-step delete, board vanished from sidebar, landed home.
- **US8** archive-cards / delete a list: archived all cards (list remained, emptied,
  no-op on replay), then deleted the list entirely (list gone from the board).
- **US9** sort by due date: triggered with no due dates set (still `204`, order stable).
- **Permission tiers**: plain `BoardMember` sees Star + list "⋯" but no board
  rename/delete; `Observer` sees zero mutation controls anywhere in the feature (no star,
  no "⋯", no add-list/add-card composers) — confirmed by inviting a second real account
  and changing its role via direct API calls between checks, not by reading the gating
  code alone.

## Residual risk

Low. The one open item is the Visual Compliance Loop's un-recaptured final screenshot
(documented above, environment tooling issue, not a code-confidence issue) — recommend
the human reviewer open the running dev server once and eyeball the "⋯" popover
(`http://localhost:3000`, any list's "⋯" button) as part of their own UI review, per
`docs/sdlc/review-process.md`'s Human Review checklist item "Actual UI vs visual
references."
