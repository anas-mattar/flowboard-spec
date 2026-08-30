# Tasks: Board & List Management

**Input**: Design documents from `/specs/006-board-list-management/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/board-list-management-api.md, quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — touches invariant 4
(soft delete) for the first time on `Board`/`List`, but every deletion here is recoverable
for ≥30 days by the same rule already governing card deletion (004); not a
postings/balances/consent-trail/state-machine case, and not irreversible. Full Definition
of Done applies; no Critical addendum.

**Tests**: Backend integration tests are included throughout —
`docs/rulebooks/backend-rules.md` requires one per endpoint unconditionally, plus a
due-date-sort ordering test (nulls-last, stable tiebreak). No frontend test runner exists
yet — frontend verification is the Visual Compliance Loop + `quickstart.md`.

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
cross-repository rule: backend gates and merges before frontend starts), with `[Story]`
labels for traceability back to spec.md's nine user stories (US1 create a board, US2 add a
list, US3 rename a board, US4 rename a list, US5 star a board, US6 WIP limit, US7 archive/
delete a board, US8 archive-cards/delete a list, US9 sort by due date). See "Delivery
Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US9); Foundational/Visual/Polish
  tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 2+) may begin until this phase is complete.
One migration this feature (plan.md ADR-27) — `RowVersion` on `Board` and `List`, required
before board/list rename (US3/US4) can use `If-Match`; every other story in this feature
is independent of it but the migration is cheapest to land once, up front.

- [x] T001 Add `public byte[] RowVersion { get; set; } = [];` to
  flowboard-api/src/Flowboard.Api/Domain/Entities/Board.cs and
  flowboard-api/src/Flowboard.Api/Domain/Entities/List.cs; add
  `builder.Property(x => x.RowVersion).IsRowVersion();` to
  flowboard-api/src/Flowboard.Api/Data/Configurations/BoardConfiguration.cs and
  ListConfiguration.cs (mirrors `CardConfiguration.cs`'s existing mapping exactly,
  data-model.md)
- [x] T002 Generate and apply the EF Core migration (`AddBoardListRowVersion`) in
  flowboard-api/src/Flowboard.Api/Migrations/ (depends on T001; run via the repo-local
  `dotnet tool` manifest per CLAUDE.md's Known failure modes note)

**Checkpoint**: `Board`/`List` both carry `RowVersion`. Backend endpoint work (Phase 2+)
can now begin.

---

## Phase 2: Backend — Create a board (US1, Priority: P1) — delivery Phase A

**Goal**: `POST /v1/boards` (contracts §"create a board") — no board role to resolve,
always targets the caller's own workspace (ADR-26, research R-3).

**Independent Test**: `quickstart.md` §3, US1 row — callable directly against the running
API before any frontend exists.

- [x] T003 [US1] `BoardContentService.CreateBoardAsync` — resolve the caller's own
  workspace (`db.Workspaces.First(w => w.OwnerUserId == caller.Id)`, research R-3); reject
  empty/whitespace `name` (`400`); create the board (auto-assigned rotating `Color`,
  `Starred = false`) and its three starter lists via `Ordering.Append` in order — "To
  Do", "Doing", "Done" — in flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs
  (cite contracts/board-list-management-api.md)
- [x] T004 [US1] `POST /v1/boards` in
  flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (depends on T003)
- [x] T005 [P] [US1] Integration test: creating a board returns the three starter lists
  in order; the creator resolves as that board's `BoardAdmin` via `BoardAccessService`
  immediately afterward with no `BoardMember` row required; empty/whitespace name → `400`
  — in flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs

**Checkpoint**: A board can be created through the API alone.

---

## Phase 3: Backend — Add a list (US2, Priority: P1) — delivery Phase A

**Goal**: `POST /v1/boards/{boardPublicId}/lists` — the first user-driven list-creation
write path (`Ordering.Append`, ADR-28, research R-4).

**Independent Test**: `quickstart.md` §3, US2 row.

- [x] T006 [US2] `ListService.CreateListAsync` — `CanMutate` (`BoardAdmin`/`BoardMember`);
  reject empty/whitespace `name` (`400`); append via `Ordering.Append` against the board's
  current highest `List.Position` — in
  flowboard-api/src/Flowboard.Api/Services/ListService.cs (cite
  contracts/board-list-management-api.md)
- [x] T007 [US2] `POST /v1/boards/{boardPublicId}/lists` in
  flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (depends on T006)
- [x] T008 [P] [US2] Integration test: a new list lands rightmost among existing lists,
  empty, `wipLimit: null`; empty/whitespace name → `400`; Observer → `403`; no board access
  → `404` — in flowboard-api/tests/Flowboard.Api.Tests/ListsEndpointTests.cs

**Checkpoint**: A list can be added to any board through the API alone.

---

## Phase 4: Backend — Rename a board (US3, Priority: P2) — delivery Phase A

**Goal**: `PATCH /v1/boards/{boardPublicId}` — `CanManageBoard` only (ADR-25), `If-Match`
required (ADR-27).

**Independent Test**: `quickstart.md` §3, US3 row + the stale-rename edge case.

- [x] T009 [US3] `BoardContentService.UpdateBoardAsync` — `access.Role !=
  BoardRole.BoardAdmin` → `403` (the exact check `BoardMembershipService.InviteAsync`
  already uses, research R-2); check `If-Match` against `Board.RowVersion` (`409` on
  mismatch, mirrors `CardService.UpdateCardAsync`); reject empty/whitespace `name`
  (`400`) — in flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs
- [x] T010 [US3] `PATCH /v1/boards/{boardPublicId}` in
  flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (depends on T009)
- [x] T011 [P] [US3] Integration test: a `BoardAdmin` renames successfully and gets back
  the new `RowVersion`; a plain `BoardMember`'s identical request → `403`; an `Observer`'s
  → `403`; a stale `If-Match` → `409`; empty/whitespace `name` → `400` — in
  flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs

**Checkpoint**: A board admin can rename a board through the API alone; a plain member
cannot.

---

## Phase 5: Backend — Rename a list, and set its WIP limit (US4 + US6, Priority: P2) — delivery Phase A

**Goal**: `PATCH /v1/lists/{listPublicId}` — one combined endpoint for both fields
(mirrors `PATCH /v1/cards/{id}`'s own multi-field shape), `CanMutate`, `If-Match`.

**Independent Test**: `quickstart.md` §3, US4 and US6 rows.

- [x] T012 [US4] [US6] `ListService.UpdateListAsync` — accepts optional `name` and/or
  `wipLimit` (at least one required, `400` if neither supplied); `CanMutate`; `If-Match`
  against `List.RowVersion` (`409` on mismatch); reject empty/whitespace `name` or a
  negative `wipLimit` (`400`); `wipLimit: null` clears the limit — in
  flowboard-api/src/Flowboard.Api/Services/ListService.cs
- [x] T013 [US4] [US6] `PATCH /v1/lists/{listPublicId}` in
  flowboard-api/src/Flowboard.Api/Endpoints/ListsEndpoints.cs (depends on T012)
- [x] T014 [P] [US4] [US6] Integration test: renaming persists and returns the new
  `RowVersion`; setting a `wipLimit` below the list's current card count still succeeds
  and doesn't touch any card; clearing `wipLimit` to `null` persists; a negative
  `wipLimit` → `400`; neither field supplied → `400`; Observer → `403`; stale `If-Match` →
  `409` — in flowboard-api/tests/Flowboard.Api.Tests/ListsEndpointTests.cs

**Checkpoint**: A list can be renamed and WIP-limited through the API alone, never
blocking any card.

---

## Phase 6: Backend — Star a board (US5, Priority: P2) — delivery Phase A

**Goal**: `POST /v1/boards/{boardPublicId}/star` / `.../unstar` — `CanMutate`, no
`If-Match` (idempotent boolean, ADR-27).

**Independent Test**: `quickstart.md` §3, US5 row.

- [x] T015 [US5] `BoardContentService.StarBoardAsync`/`UnstarBoardAsync` — `CanMutate`;
  sets `Board.Starred` directly (shared column, spec.md Assumptions) — in
  flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs
- [x] T016 [US5] `POST /v1/boards/{boardPublicId}/star` and `.../unstar` in
  flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (depends on T015)
- [x] T017 [P] [US5] Integration test: starring then re-fetching `boards.list` (already
  ordered `OrderByDescending(b => b.Starred)`, 003) shows the board first; unstarring
  returns it to normal order; Observer → `403` — in
  flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs

**Checkpoint**: A board can be starred/unstarred through the API alone, and the existing
003 sort-order query already reflects it with no further change.

---

## Phase 7: Backend — Archive/delete a board (US7, Priority: P3) — delivery Phase A

**Goal**: `DELETE /v1/boards/{boardPublicId}` — `CanManageBoard` only, soft-delete
(invariant 4).

**Independent Test**: `quickstart.md` §3, US7 row.

- [x] T018 [US7] `BoardContentService.DeleteBoardAsync` — `access.Role !=
  BoardRole.BoardAdmin` → `403`; sets the soft-delete trio (`IsDeleted`/`DeletedDate`/
  `DeletedBy`); does not cascade to lists/cards (research R-5's cascade is list-delete
  only) — in flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs
- [x] T019 [US7] `DELETE /v1/boards/{boardPublicId}` in
  flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (depends on T018)
- [x] T020 [P] [US7] Integration test: deleting removes the board from
  `boards.list`/`ListBoardsAsync`'s results for every member (its `Where` clause already
  excludes soft-deleted rows via the standard query filter); a plain `BoardMember`'s
  attempt → `403`; a second delete of an already-deleted board → `404` — in
  flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs

**Checkpoint**: A board admin can archive/delete a board through the API alone; a plain
member cannot; deleted data is never lost.

---

## Phase 8: Backend — Archive all cards, or delete a list (US8, Priority: P3) — delivery Phase A

**Goal**: `POST /v1/lists/{listPublicId}/archive-cards` and `DELETE
/v1/lists/{listPublicId}` — `CanMutate`; list delete cascades to its cards in the same
transaction (research R-5, invariant 4).

**Independent Test**: `quickstart.md` §3, US8 row.

- [x] T021 [US8] `ListService.ArchiveAllCardsAsync` — `CanMutate`; soft-deletes every
  non-deleted `Card` in the list; a no-op (still success) on an already-empty list — in
  flowboard-api/src/Flowboard.Api/Services/ListService.cs
- [x] T022 [US8] `ListService.DeleteListAsync` — `CanMutate`; sets the list's own
  soft-delete trio **and**, in the same `SaveChangesAsync`, every non-deleted card it
  currently holds (research R-5) — in
  flowboard-api/src/Flowboard.Api/Services/ListService.cs
- [x] T023 [US8] `POST /v1/lists/{listPublicId}/archive-cards` and `DELETE
  /v1/lists/{listPublicId}` in flowboard-api/src/Flowboard.Api/Endpoints/ListsEndpoints.cs
  (depends on T021/T022)
- [x] T024 [P] [US8] Integration test: archiving all cards empties the list but the list
  itself remains (a subsequent `boards.getContent` still shows it); deleting a list with
  cards removes the list and every one of its cards from `boards.getContent`, while each
  card remains individually fetchable in its archived state (e.g. via
  `cards.getActivity`/an existing card-scoped read route, matching 004's own archived-card
  precedent); Observer → `403` on both — in
  flowboard-api/tests/Flowboard.Api.Tests/ListsEndpointTests.cs

**Checkpoint**: A list's cards can be bulk-archived, or the list deleted outright
(archiving its cards), through the API alone — no data is ever physically lost.

---

## Phase 9: Backend — Sort a list by due date (US9, Priority: P3) — delivery Phase A

**Goal**: `POST /v1/lists/{listPublicId}/sort` — ascending `DueAt`, nulls last, stable
tiebreak by current `Position` (research R-1).

**Independent Test**: `quickstart.md` §3, US9 row.

- [x] T025 [US9] `ListService.SortByDueDateAsync` — `CanMutate`; order by `CASE WHEN
  DueAt IS NULL THEN 1 ELSE 0 END, DueAt, Position` (research R-1, SQL Server's own
  `NULL`-first default must be overridden explicitly); rewrite every card's `Position` in
  that resolved order via repeated `Ordering.Append` calls — in
  flowboard-api/src/Flowboard.Api/Services/ListService.cs
- [x] T026 [US9] `POST /v1/lists/{listPublicId}/sort` in
  flowboard-api/src/Flowboard.Api/Endpoints/ListsEndpoints.cs (depends on T025)
- [x] T027 [P] [US9] Integration test: a list with dated and undated cards sorts
  ascending, undated last; two cards sharing a due date keep their prior relative order;
  triggering the sort twice in a row with nothing changed produces an identical order both
  times; Observer → `403` — in flowboard-api/tests/Flowboard.Api.Tests/ListsEndpointTests.cs

**Checkpoint**: All nine backend write paths exist and are independently tested. Phase A
is complete — request the backend gate (`dotnet build --warnaserror && dotnet test` in
`flowboard-api`) before starting Phase B.

---

## Phase 10: Frontend — Create a board (US1) — delivery Phase B, part 1

- [x] T028 [US1] Add `createBoardInputSchema` (`name`) to
  flowboard-web/src/lib/boards/schemas.ts
- [x] T029 [US1] Extend the server-only boards client with `createBoard` in
  flowboard-web/src/lib/api/boards-client.ts (cite
  contracts/board-list-management-api.md; depends on T028)
- [x] T030 [US1] Extend `boardsRouter` with a `create` `protectedProcedure` in
  flowboard-web/src/server/api/routers/boards.ts (depends on T029)
- [x] T031 [US1] Add a "+ Create board" inline composer row to
  flowboard-web/src/components/layout/sidebar.tsx (mirrors 004's card-composer shape —
  research R-6), calling `boards.create`, invalidating `boards.list` on success, and
  navigating to the new board — depends on T030

---

## Phase 11: Frontend — Add a list (US2) — delivery Phase B, part 2

- [x] T032 [US2] Add `createListInputSchema` (`boardPublicId`, `name`) to
  flowboard-web/src/lib/lists/schemas.ts
- [x] T033 [US2] Extend the server-only lists client with `createList` in
  flowboard-web/src/lib/api/lists-client.ts (depends on T032)
- [x] T034 [US2] Extend `listsRouter` with a `create` `protectedProcedure` in
  flowboard-web/src/server/api/routers/lists.ts (depends on T033)
- [x] T035 [US2] Create `add-list-composer.tsx` (mirrors 004's card composer, research
  R-6) and wire it as the board canvas's trailing "+ Add another list" control, calling
  `lists.create` and invalidating `boards.getContent` — in
  flowboard-web/src/components/board/add-list-composer.tsx and
  flowboard-web/src/components/board/board-canvas.tsx (depends on T034)

---

## Phase 12: Frontend — Rename a board inline (US3) — delivery Phase B, part 3

- [x] T036 [US3] Add `renameBoardInputSchema` (`name`) to
  flowboard-web/src/lib/boards/schemas.ts
- [x] T037 [US3] Extend the boards client with `renameBoard` (sends `If-Match`, maps
  `409`) in flowboard-web/src/lib/api/boards-client.ts (depends on T036)
- [x] T038 [US3] Extend `boardsRouter` with a `rename` `protectedProcedure` surfacing a
  `CONFLICT` `TRPCError` on `409` and `FORBIDDEN` on `403` in
  flowboard-web/src/server/api/routers/boards.ts (depends on T037)
- [x] T039 [US3] Create `board-title-bar.tsx` (client component) with an inline-editable
  title, replacing `top-bar.tsx`'s static `h1`; editable only when the viewer's role is
  `BoardAdmin` (derived from `boardMembers.list`, mirroring `board-canvas.tsx`'s own
  `viewerEntry` derivation exactly); wire the board page
  (flowboard-web/src/app/(app)/boards/[boardPublicId]/page.tsx) and
  flowboard-web/src/components/layout/top-bar.tsx to pass `publicId`/`starred`/the
  viewer's role through to it — in
  flowboard-web/src/components/layout/board-title-bar.tsx (depends on T038)

---

## Phase 13: Frontend — Rename a list inline (US4) — delivery Phase B, part 4

- [x] T040 [US4] Add `updateListInputSchema` (`name?`, `wipLimit?`, at least one
  required) to flowboard-web/src/lib/lists/schemas.ts — the one schema US4 and US6 both
  use
- [x] T041 [US4] Extend the lists client with `updateList` (sends `If-Match`, maps `409`)
  in flowboard-web/src/lib/api/lists-client.ts — shared by US4 and US6 (depends on T040)
- [x] T042 [US4] Extend `listsRouter` with an `update` `protectedProcedure` in
  flowboard-web/src/server/api/routers/lists.ts (depends on T041)
- [x] T043 [US4] Make `list-column.tsx`'s header title inline-editable, calling
  `lists.update` with just `name` — in flowboard-web/src/components/board/list-column.tsx
  (depends on T042)

---

## Phase 14: Frontend — Star a board (US5) — delivery Phase B, part 5

- [x] T044 [US5] Extend the boards client with `starBoard`/`unstarBoard` in
  flowboard-web/src/lib/api/boards-client.ts
- [x] T045 [US5] Extend `boardsRouter` with `star`/`unstar` `protectedProcedure`s in
  flowboard-web/src/server/api/routers/boards.ts (depends on T044)
- [x] T046 [US5] Wire `board-title-bar.tsx`'s Star button to `boards.star`/`boards.unstar`
  (toggling on the current `starred` value, invalidating `boards.list`), removing its
  `disabled` state — in flowboard-web/src/components/layout/board-title-bar.tsx (depends
  on T039, T045)

---

## Phase 15: Frontend — Set a WIP limit on a list (US6) — delivery Phase B, part 6

- [x] T047 [US6] Create `list-actions-menu.tsx` (client popover) with its "Set WIP limit"
  row — an inline numeric input calling `lists.update` (T042) with just `wipLimit` —
  replacing `list-column.tsx`'s currently-`disabled` "⋯" (`MoreHorizontal`) button with
  one that opens this popover — in
  flowboard-web/src/components/board/list-actions-menu.tsx and
  flowboard-web/src/components/board/list-column.tsx (depends on T042, T043)

---

## Phase 16: Frontend — Archive/delete a board (US7) — delivery Phase B, part 7

- [x] T048 [US7] Extend the boards client with `deleteBoard` in
  flowboard-web/src/lib/api/boards-client.ts
- [x] T049 [US7] Extend `boardsRouter` with a `delete` `protectedProcedure` surfacing
  `FORBIDDEN` on `403` in flowboard-web/src/server/api/routers/boards.ts (depends on T048)
- [x] T050 [US7] Add a `BoardAdmin`-only "Delete board" control to `board-title-bar.tsx`,
  with the same inline confirm-step shape `card-add-to-card-menu.tsx` already uses for
  card delete (research R-7) — no new dialog component; navigate to the sidebar's next
  available board (or its empty state) on success — in
  flowboard-web/src/components/layout/board-title-bar.tsx (depends on T039, T049)

---

## Phase 17: Frontend — Archive all cards, or delete a list (US8) — delivery Phase B, part 8

- [x] T051 [US8] Extend the lists client with `archiveListCards`/`deleteList` in
  flowboard-web/src/lib/api/lists-client.ts
- [x] T052 [US8] Extend `listsRouter` with `archiveCards`/`delete` `protectedProcedure`s
  in flowboard-web/src/server/api/routers/lists.ts (depends on T051)
- [x] T053 [US8] Add "Archive all cards" and "Delete list" rows to
  `list-actions-menu.tsx`, each with its own inline confirm step (research R-7) — in
  flowboard-web/src/components/board/list-actions-menu.tsx (depends on T047, T052)

---

## Phase 18: Frontend — Sort a list by due date (US9) — delivery Phase B, part 9

- [x] T054 [US9] Extend the lists client with `sortListByDueDate` in
  flowboard-web/src/lib/api/lists-client.ts
- [x] T055 [US9] Extend `listsRouter` with a `sort` `protectedProcedure` in
  flowboard-web/src/server/api/routers/lists.ts (depends on T054)
- [x] T056 [US9] Add a "Sort by due date" row to `list-actions-menu.tsx`, invalidating
  `boards.getContent` on success — in
  flowboard-web/src/components/board/list-actions-menu.tsx (depends on T047, T055)

---

## Phase 19: Visual Compliance Loop (`docs/sdlc/review-process.md`) — before the Phase B gate

- [x] T057 Capture the implemented sidebar (default state), the list "⋯" menu open, and a
  list's WIP badge over limit at the same viewport as `screenshots/sidebar-boards-list.jpg`,
  `screenshots/list-actions-menu.jpg`, and `screenshots/list-wip-over-limit.jpg`; compare
  item-by-item against VI-001–VI-008; produce the deviation table; fix and recapture
  until it is empty or every remaining row is user-approved; attach the table and
  screenshots to the phase notes

---

## Phase 20: Polish & Cross-Cutting Concerns

- [x] T058 [P] Walk `quickstart.md` end-to-end (US1–US9 rows, all edge cases including
  the admin-vs-member permission split and the stale-rename `409` check) and fix any doc
  drift in specs/006-board-list-management/quickstart.md
- [ ] T059 Write phase review notes (backend + frontend compliance checklist results,
  gate evidence, the domain-invariant pass) in
  specs/006-board-list-management/review-notes.md; write
  specs/006-board-list-management/human-pr-review.md; on merge, set roadmap row 006 →
  shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Foundational (migration) | T001–T002 | covered by `dotnet test` once Phase A's tests exist |
| Phase A — backend (all 9 write paths) | T003–T027 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (all 9 UI surfaces, Visual Compliance Loop) | T028–T057 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T058–T059 | both gates re-run at merge time |

## Dependencies & Execution Order

- Foundational (T001–T002) blocks Phase 4 (board rename) and Phase 5 (list rename/WIP) —
  both need `RowVersion` to exist — but not Phases 2, 3, 6, 7, 8, or 9, none of which use
  `If-Match`. In practice, land Foundational first anyway; it's cheap and this feature's
  own migration only ever needs writing once.
- Within Phase A (T003–T027): each of the nine story-slices (create board, add list,
  rename board, rename list+WIP, star, archive/delete board, archive-cards/delete list,
  sort) touches its own service method and endpoint route — all nine can proceed in
  parallel once Foundational completes, except Phase 4/5 which additionally need T001/T002.
- Phase B (T028–T057) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule). Within Phase B: each story's
  schema→client→router chain (e.g. T028→T029→T030) is strictly sequential; the nine
  chains themselves are independent of each other except where a UI surface is shared —
  T047 (creates `list-actions-menu.tsx`) must land before T053/T056 (which add rows to
  it), and T039 (creates `board-title-bar.tsx`) must land before T046/T050 (which add
  controls to it).
- Visual Compliance Loop (T057) depends on every Phase B UI surface being in its final
  state. Polish (T058–T059) is last, after both phase gates pass.

## Parallel Opportunities

- Within Phase A: all nine story-slices are independent vertical slices (each its own
  service method + endpoint + test file section) — safe to implement in any order or in
  parallel once Foundational (T001–T002) exists.
- Within Phase B: US1/US2/US5/US9's schema→client→router→UI chains (T028–T031, T032–T035,
  T044–T046, T054–T056) can proceed independently of each other; US6/US7/US8's UI steps
  (T047, T050, T053) share two host components (`list-actions-menu.tsx`,
  `board-title-bar.tsx`) and should land in the order given to avoid rework on the same
  file.

## Implementation Strategy

MVP = Foundational + Phase A (all nine backend write paths) gated on the backend alone,
matching 004/005's precedent of gating the backend as one unit ahead of the consuming
tier. Phase B delivers all nine UI surfaces before requesting the frontend gate, then runs
the Visual Compliance Loop against the three captured reference screenshots. One phase at
a time; no unrelated changes; 003/004/005's existing sidebar/top-bar/board-canvas/
list-column components are extended (never rebuilt) — the "⋯" list-options button and the
top-bar Star button in particular go from `disabled` placeholders (003) to fully wired
controls, the same way 005 activated the previously-inert "Move" button.
