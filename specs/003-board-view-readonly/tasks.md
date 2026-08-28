# Tasks: Board View (Read-Only)

**Input**: Design documents from `/specs/003-board-view-readonly/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/board-content-api.md, quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — no authentication/
authorization change (reuses 002's `BoardAccessService` unchanged), no irreversible
operation. Full Definition of Done applies; no Critical addendum.

**Tests**: Backend integration tests are included throughout —
`docs/rulebooks/backend-rules.md` requires one per endpoint unconditionally, and
constitution XI requires regression coverage for business-critical logic (access
scoping, ordering, due-date bucketing). No frontend test runner exists yet (unchanged
since 001) — frontend verification is the Visual Compliance Loop + `quickstart.md`.

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
`docs/sdlc/repository-strategy.md`'s cross-repository rule: backend gates and merges
before frontend starts), with `[Story]` labels for traceability back to spec.md's user
stories (US1 view my boards and open one, US2 theme, US3 sidebar collapse, US4
keyboard). See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4); Foundational/Polish
  tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 2+) may begin until this phase is complete —
every endpoint depends on this schema and seed data. No new packages this feature
(plan.md Technical Context) — nothing to add in a separate Setup phase.

- [x] T001 [P] Create `List` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/List.cs (data-model.md List)
- [x] T002 [P] Create `Card` entity (incl. `RowVersion`) in flowboard-api/src/Flowboard.Api/Domain/Entities/Card.cs (data-model.md Card)
- [x] T003 [P] Create `Label` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/Label.cs (data-model.md Label)
- [x] T004 [P] Create `CardLabel` entity (join, no `PublicId`) in flowboard-api/src/Flowboard.Api/Domain/Entities/CardLabel.cs (data-model.md CardLabel)
- [x] T005 [P] Create `CardMember` entity (join, no `PublicId`) in flowboard-api/src/Flowboard.Api/Domain/Entities/CardMember.cs (data-model.md CardMember)
- [x] T006 [P] Create `ChecklistItem` entity (no `PublicId` yet) in flowboard-api/src/Flowboard.Api/Domain/Entities/ChecklistItem.cs (data-model.md ChecklistItem)
- [x] T007 [P] Create `Comment` entity (no `PublicId` yet) in flowboard-api/src/Flowboard.Api/Domain/Entities/Comment.cs (data-model.md Comment)
- [x] T008 Register the 7 new entities as `DbSet`s in flowboard-api/src/Flowboard.Api/Data/FlowboardDbContext.cs (depends on T001–T007)
- [x] T009 [P] Create `ListConfiguration` (soft-delete query filter, `IX_List_BoardId_Position`) in flowboard-api/src/Flowboard.Api/Data/Configurations/ListConfiguration.cs (depends on T001)
- [x] T010 [P] Create `CardConfiguration` (soft-delete query filter, `.IsRowVersion()`, `IX_Card_ListId_Position`, `IX_Card_DueAt`) in flowboard-api/src/Flowboard.Api/Data/Configurations/CardConfiguration.cs (depends on T002)
- [x] T011 [P] Create `LabelConfiguration` (`IX_Label_BoardId`) in flowboard-api/src/Flowboard.Api/Data/Configurations/LabelConfiguration.cs (depends on T003)
- [x] T012 [P] Create `CardLabelConfiguration` (`UNIQUE(CardId,LabelId)`) in flowboard-api/src/Flowboard.Api/Data/Configurations/CardLabelConfiguration.cs (depends on T004)
- [x] T013 [P] Create `CardMemberConfiguration` (`UNIQUE(CardId,UserId)`) in flowboard-api/src/Flowboard.Api/Data/Configurations/CardMemberConfiguration.cs (depends on T005)
- [x] T014 [P] Create `ChecklistItemConfiguration` (`IX_ChecklistItem_CardId`) in flowboard-api/src/Flowboard.Api/Data/Configurations/ChecklistItemConfiguration.cs (depends on T006)
- [x] T015 [P] Create `CommentConfiguration` (`IX_Comment_CardId`) in flowboard-api/src/Flowboard.Api/Data/Configurations/CommentConfiguration.cs (depends on T007)
- [x] T016 Edit `BoardConfiguration` to add `Color`/`Starred` columns with defaults (data-model.md Board) in flowboard-api/src/Flowboard.Api/Data/Configurations/BoardConfiguration.cs
- [x] T017 [P] Create `CursorPage<T>` shared pagination DTO (ADR-12) in flowboard-api/src/Flowboard.Api/Domain/CursorPage.cs
- [x] T018 Generate the `AddBoardContent` migration (`dotnet ef migrations add`, repo-local tool) and author its `HasData` seed — three boards under the existing fixture workspace reproducing `screenshots/board-canvas.png` exactly where shown (research R-4, data-model.md Seed data) — in flowboard-api/src/Flowboard.Api/Migrations/ (depends on T008–T016)

**Checkpoint**: Foundation ready — schema and seed data exist. Backend endpoint work
(Phase 2) can now begin.

---

## Phase 2: Backend — Board Content (Priority: P1) 🎯 MVP — delivery Phase A

**Goal**: `GET /v1/boards` and `GET /v1/boards/{id}` per `contracts/board-content-api.md`,
reusing 002's `BoardAccessService` unchanged (US1).

**Independent Test**: `quickstart.md` §4 US1 rows — sign in, list boards, open one,
confirm lists/cards render in stored order with correct per-card indicators; a
non-member gets 404.

- [x] T019 [US1] Create `BoardContentService` (list boards visible to caller,
  cursor-paginated per R-3; hydrate one board's lists/cards, computing `dueStatus`
  server-side per the contract) in flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs (cite contracts/board-content-api.md)
- [x] T020 [US1] Create `BoardsEndpoints` (`GET /v1/boards`, `GET /v1/boards/{boardPublicId}`)
  in flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs (cite contracts/board-content-api.md); register in Program.cs
- [x] T021 [P] [US1] Integration test: `GET /v1/boards` returns exactly the boards the
  caller has access to (owner + explicit membership, none else), correct pagination
  shape, empty list for a user with no access (SC-002, SC-005) in flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs
- [x] T022 [P] [US1] Integration test: `GET /v1/boards/{id}` returns lists/cards in
  stored `Position` order; a card with no indicators shows none, a card with all of
  them shows all (VI-009, VI-011) in flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs
- [x] T023 [P] [US1] Integration test: `GET /v1/boards/{id}` for a board the caller has
  no access to → 404 (FR-006, matches board-membership-api.md's existing pattern) in flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs
- [x] T024 [US1] Golden-fixture integration test: the seeded "Product Roadmap Q3" board's
  exact rendered shape (list count/order, card count/order, `dueStatus` values, the
  WIP-exceeded flag on "In Progress") matches `screenshots/board-canvas.png` field by
  field — so a future change can't silently break what the Visual Compliance Loop
  depends on — in flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs

**Checkpoint — Phase A gate**: STOP. User runs
`dotnet build --warnaserror && dotnet test` in flowboard-api and confirms EXIT 0. AI
review AND human review. Commit Phase A. Per `docs/sdlc/repository-strategy.md`'s
cross-repository rule, the backend gates and merges to `main` **before** Phase B
(frontend) begins.

---

## Phase 3: Frontend — Board View (Priority: P1) — delivery Phase B, part 1

**Goal**: The sidebar, the app shell, and the board canvas rendering real content (US1).

**Independent Test**: `quickstart.md` §4 US1 rows, through the browser.

- [x] T025 [US1] Create server-only boards client (`list`, `getContent`) in flowboard-web/src/lib/api/boards-client.ts (cite contracts/board-content-api.md)
- [x] T026 [US1] Create the `boards` router (`protectedProcedure`: `list`, `getContent`) in flowboard-web/src/server/api/routers/boards.ts; register in root.ts
- [x] T027 [US1] Create the authenticated app-shell layout (ADR-13: redirect to `/login`
  if unauthenticated, render `Sidebar` + `TopBar` around `{children}`) in flowboard-web/src/app/(app)/layout.tsx
- [x] T028 [US1] Create `Sidebar` (brand block, boards list with color swatch/name/count,
  currently-open-board highlight, collapse control, user footer — VI-001/VI-002/VI-003)
  in flowboard-web/src/components/layout/sidebar.tsx
- [x] T029 [US1] Move flowboard-web/src/app/page.tsx to flowboard-web/src/app/(app)/page.tsx (content unchanged; URL unaffected by the route group)
- [x] T030 [US1] Move flowboard-web/src/app/boards/[boardPublicId]/page.tsx to
  flowboard-web/src/app/(app)/boards/[boardPublicId]/page.tsx, extended to fetch board
  content (`boards.getContent`) and render `BoardCanvas` (still shows the existing
  access-denied state for a 404, unchanged from 002)
- [x] T031 [P] [US1] Create `BoardCanvas` (horizontal list row — VI-006) in flowboard-web/src/components/board/board-canvas.tsx
- [x] T032 [P] [US1] Create `ListColumn` (header + WIP pill + cards + inert "+ Add a
  card" footer — VI-007/VI-008, FR-007) in flowboard-web/src/components/board/list-column.tsx
- [x] T033 [P] [US1] Create `CardFront` (label chips, title, meta row: due badge colored
  by server-computed `dueStatus`, checklist progress, comment count, member avatars —
  VI-009/VI-010/VI-011) in flowboard-web/src/components/board/card-front.tsx
- [x] T034 [US1] Make `TopBar` board-aware (R-6): accept an optional board-summary prop
  and render the full VI-004/VI-005 layout (title, star, search, filter, avatar stack,
  invite, theme toggle) only when a board is open, with the non-functional controls
  inert (FR-007) — in flowboard-web/src/components/layout/top-bar.tsx

**Checkpoint**: US1 verifiable end-to-end through the browser.

---

## Phase 4: Frontend — Theme (Priority: P2) — delivery Phase B, part 2

**Goal**: Theme toggle covers every element this feature adds (US2).

**Independent Test**: `quickstart.md` §4 US2 row.

- [x] T035 [US2] Apply dark-mode Tailwind variants across `Sidebar`, `BoardCanvas`,
  `ListColumn`, and `CardFront` (the existing `ThemeProvider`/class-toggle from 001
  needs no new logic — only styling coverage on the new components) in flowboard-web/src/components/layout/sidebar.tsx, flowboard-web/src/components/board/*.tsx

---

## Phase 5: Frontend — Sidebar Collapse (Priority: P2) — delivery Phase B, part 3

**Goal**: Collapse/expand the sidebar; canvas reclaims the freed width (US3).

**Independent Test**: `quickstart.md` §4 US3 row.

- [x] T036 [US3] Add collapse/expand state and the ☰ control's behavior to `Sidebar`
  (client component) and wire the app-shell layout so the canvas expands/contracts
  immediately in flowboard-web/src/components/layout/sidebar.tsx, flowboard-web/src/app/(app)/layout.tsx

---

## Phase 6: Frontend — Keyboard Operability (Priority: P3) — delivery Phase B, part 4

**Goal**: Every control this feature adds is keyboard-reachable and operable (US4).

**Independent Test**: `quickstart.md` §4 US4 row.

- [x] T037 [US4] Audit and fix keyboard operability across `Sidebar`'s board links,
  its collapse control, and the theme toggle — native `<button>`/`<a>` elements only (no
  `onClick`-only `<div>`s), visible focus-visible styling — in flowboard-web/src/components/layout/sidebar.tsx, flowboard-web/src/components/shell/theme-toggle.tsx

---

## Phase 7: Visual Compliance Loop (`docs/sdlc/review-process.md`) — before the Phase B gate

- [x] T038 Capture the implemented board view at the same viewport as
  `screenshots/board-canvas.png`, compare item-by-item against VI-001–VI-011, produce
  the deviation table, fix and recapture until it is empty or every remaining row is
  user-approved; attach the table and both screenshots to the phase notes

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0. AI review AND human review, including the UI-vs-
reference check (the Visual Compliance Loop's deviation table). Commit Phase B.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T039 [P] Walk `quickstart.md` end-to-end (all US1–US4 rows, both edge cases) and
  fix any doc drift in specs/003-board-view-readonly/quickstart.md
- [ ] T040 Write phase review notes (backend + frontend compliance checklist results,
  gate evidence, the domain-invariant pass) in
  specs/003-board-view-readonly/review-notes.md; write
  specs/003-board-view-readonly/human-pr-review.md; on merge, set roadmap row 003 →
  shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Foundational | T001–T018 | none (no endpoint surface yet); covered by `dotnet test` once Phase A's tests exist |
| Phase A — backend (board content) | T019–T024 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (sidebar, shell, canvas, theme, collapse, keyboard, Visual Compliance Loop) | T025–T038 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T039–T040 | both gates re-run at merge time |

## Dependencies & Execution Order

- Foundational (T001–T018) has no dependency on anything outside this feature and
  blocks every later task. Within it: entities (T001–T007) before `DbContext` (T008)
  before configurations (T009–T016) before the migration (T018); `CursorPage<T>` (T017)
  is independent of the rest and can be done any time in this phase.
- Phase A (T019–T024) depends on Foundational completing. `BoardContentService` (T019)
  before `BoardsEndpoints` (T020) before the endpoint's own tests (T021–T024). T024 (the
  golden fixture) depends on T018's exact seed content existing.
- Phase B (T025–T038) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule). Within it: T025 (client) before
  T026 (router); T027 (layout) before T028 (Sidebar) and T029/T030 (moved pages); T031–
  T033 (canvas/list/card components) can proceed in parallel once T026 exists, since
  they're pure rendering components; T034 (TopBar) depends on knowing a board's summary
  shape (T019/T026). T035 (theme) and T036 (collapse) depend on T028's `Sidebar`
  existing. T037 (keyboard) depends on T028 and T036. T038 (Visual Compliance Loop)
  depends on everything in Phase B being renderable.
- Polish (T039–T040) is last, after both phase gates pass.

## Parallel Opportunities

- Within Foundational: entity creation T001–T007 together; then configurations
  T009–T015 together (each depends only on its own entity).
- Within Phase A: integration tests T021/T022/T023 together (different assertions, same
  file — safe to author in parallel, xUnit runs the collection sequentially regardless).
- Within Phase B: T031 (`BoardCanvas`), T032 (`ListColumn`), and T033 (`CardFront`)
  together once T026 (router) exists — three independent presentational components.

## Implementation Strategy

MVP = Foundational + Phase A (US1's backend contract) gated on the backend alone —
proves boards/lists/cards are real, access-scoped, and correctly shaped before any
frontend work begins, matching 002's precedent of gating the backend as one unit ahead
of the consuming tier. Phase B delivers US1's UI first, then US2/US3/US4 as small,
independently-verifiable additions on top of the same shell, finishing with the Visual
Compliance Loop before requesting the frontend gate. One phase at a time; no unrelated
changes; 002's auth/board-membership surface is untouched.
