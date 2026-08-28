# Tasks: Card Lifecycle CRUD

**Input**: Design documents from `/specs/004-card-crud/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/card-crud-api.md, quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — no
authentication/authorization change (reuses 002's `BoardAccessService` unchanged, only
applying it to new resources), every mutation is soft-delete/reversible. Full
Definition of Done applies; no Critical addendum.

**Tests**: Backend integration tests are included throughout —
`docs/rulebooks/backend-rules.md` requires one per endpoint unconditionally, plus a
concurrency-conflict test for the one endpoint with `If-Match`, plus a golden-fixture
test for the ordering module (constitution XI). No frontend test runner exists yet —
frontend verification is the Visual Compliance Loop + `quickstart.md`.

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
cross-repository rule: backend gates and merges before frontend starts), with `[Story]`
labels for traceability back to spec.md's user stories (US1 add a card, US2 open a
card, US3 title/description, US4 labels/members, US5 due date, US6 checklist, US7
comments/activity, US8 copy/delete). See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US8); Foundational/Polish
  tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 2+) may begin until this phase is complete.
No new packages this feature (plan.md Technical Context) — nothing to add in a separate
Setup phase.

- [x] T001 [P] Add `PublicId` column + unique index to `ChecklistItem` in flowboard-api/src/Flowboard.Api/Data/Configurations/ChecklistItemConfiguration.cs (data-model.md ChecklistItem)
- [x] T002 [P] Create `ActivityEvent` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/ActivityEvent.cs (data-model.md ActivityEvent)
- [x] T003 [P] Create `ActivityEventConfiguration` (no soft delete, `IX_ActivityEvent_CardId_CreatedDate`) in flowboard-api/src/Flowboard.Api/Data/Configurations/ActivityEventConfiguration.cs (depends on T002)
- [x] T004 Register `ActivityEvent` as a `DbSet` in flowboard-api/src/Flowboard.Api/Data/FlowboardDbContext.cs (depends on T002)
- [x] T005 [P] Create the ordering module — `Append(lastPosition)`, `InsertBetween(lower, upper)` — in flowboard-api/src/Flowboard.Api/Domain/Ordering.cs (plan.md ADR-18, 001's ADR-4 reserved this file)
- [x] T006 [P] Extract `CardDueStatus.Compute(dueAt, dueComplete, now)` into flowboard-api/src/Flowboard.Api/Domain/CardDueStatus.cs; update flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs to call it instead of its inline 003 logic (research.md R-5 — no behavior change, single source of truth)
- [x] T007 Generate the `AddCardActivity` migration (`dotnet ef migrations add`, repo-local tool) — `ActivityEvent` table + `ChecklistItem.PublicId` column, no seed changes — in flowboard-api/src/Flowboard.Api/Migrations/ (depends on T001–T004)

**Checkpoint**: Foundation ready — schema, ordering module, and shared due-status helper
exist. Backend endpoint work (Phase 2) can now begin.

---

## Phase 2: Backend — Card Mutations (Priority: P1-P3) 🎯 — delivery Phase A

**Goal**: Every route in `contracts/card-crud-api.md`, reusing 002's
`BoardAccessService` for permission resolution (research.md R-2).

**Independent Test**: `quickstart.md` §4, backend half of every row — each capability
callable directly against the running API before any frontend exists.

- [x] T008 [US1] `CardService.CreateCard` (position via `Ordering.Append`, writes a `card.created` event, no WIP-limit check — invariant 3) in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/card-crud-api.md)
- [x] T009 [US1] `POST /v1/lists/{listPublicId}/cards` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T008); register in Program.cs
- [x] T010 [P] [US1] Integration test: create succeeds and appends at the bottom regardless of the list's `WipLimit`; empty/too-long title → `400`; no board access → `404` in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T011 [US2] `CardService.GetCardDetail` (full detail incl. checklist items, `dueStatus` via T006's helper) in flowboard-api/src/Flowboard.Api/Services/CardService.cs
- [x] T012 [US2] `GET /v1/cards/{cardPublicId}` with `ETag` response header in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T011)
- [x] T013 [P] [US2] Integration test: detail returned correctly including empty sections; Observer can view; no access → `404` in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T014 [US3] `CardService.UpdateCard` (title/description/`dueAt`/`dueComplete`, `RowVersion`/`If-Match` check, writes `card.renamed`/`card.described`/`due.set`/`due.cleared`/`due.completed` events as applicable) in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/card-crud-api.md, plan.md ADR-17)
- [x] T015 [US3] `PATCH /v1/cards/{cardPublicId}` — `If-Match` required, `409` on mismatch — in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T014)
- [x] T016 [P] [US3] Integration test: title/description update succeeds and reflects in a follow-up `GET`; a stale `If-Match` on a genuinely concurrent edit → `409` with the card unchanged; empty title/no board access → `400`/`404` in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T017 [US4] `CardService` label assign/remove (invariant 7: reject a label from a different board) and member assign/remove (auto-adds the user to the board, invariant 5's sanctioned side effect) in flowboard-api/src/Flowboard.Api/Services/CardService.cs
- [x] T018 [US4] `POST/DELETE /v1/cards/{cardPublicId}/labels[/{labelPublicId}]` and `.../members[/{userPublicId}]` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T017)
- [x] T019 [P] [US4] Integration test: assigning a label from a different board → `400`; assign/remove are idempotent; assigning a non-board-member adds them to the board (verify via `BoardMember`) in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T020 [P] [US5] Integration test: `dueStatus` bucketing after `PATCH` (future/soon/overdue), and `dueComplete=true` forces `"complete"` regardless of date; clearing `dueAt` returns `dueStatus: null` — reuses T014/T015, no new endpoint — in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T021 [US6] `CardService` checklist item add/toggle/delete (writes `checklist.item.added`/`checked`/`deleted` events) in flowboard-api/src/Flowboard.Api/Services/CardService.cs
- [x] T022 [US6] `POST /v1/cards/{cardPublicId}/checklist-items`, `PATCH`/`DELETE /v1/checklist-items/{checklistItemPublicId}` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T021)
- [x] T023 [P] [US6] Integration test: add/tick/delete each reflected in a follow-up `GET` card detail; no board access → `404` in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T024 [US7] `CardService.AddComment` (writes a `Comment` row + a `comment.added` event embedding the body, research.md R-6) and `GetActivity` (cursor-paginated, newest first) in flowboard-api/src/Flowboard.Api/Services/CardService.cs
- [x] T025 [US7] `POST /v1/cards/{cardPublicId}/comments`, `GET /v1/cards/{cardPublicId}/activity` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T024)
- [x] T026 [P] [US7] Integration test: an Observer can comment; the feed contains one correctly-typed entry per mutation exercised by T010/T016/T019/T023, newest first; pagination shape matches ADR-12 in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T027 [US8] `CardService.CopyCard` (position via `Ordering.InsertBetween`, duplicates labels/members/checklist text with `Done` reset to `false`, fresh `card.created` event only — research.md R-3) and `DeleteCard` (soft-delete trio) in flowboard-api/src/Flowboard.Api/Services/CardService.cs
- [x] T028 [US8] `POST /v1/cards/{cardPublicId}/copy`, `DELETE /v1/cards/{cardPublicId}` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T027)
- [x] T029 [P] [US8] Integration test: copy duplicates labels/members/due date/description, resets checklist `Done`, and starts a fresh activity feed containing only its own creation; delete excludes the card from `GET /v1/boards/{id}` (003's existing exclusion) and a second delete → `404` in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [x] T030 [P] Golden-fixture test: `Ordering.Append`/`InsertBetween` against hand-worked expected position values (backend-rules.md's requirement for position/ranking math) in flowboard-api/tests/Flowboard.Api.Tests/OrderingTests.cs

**Checkpoint — Phase A gate**: STOP. User runs
`dotnet build --warnaserror && dotnet test` in flowboard-api and confirms EXIT 0. AI
review AND human review. Commit Phase A. Per `docs/sdlc/repository-strategy.md`'s
cross-repository rule, the backend gates and merges to `main` **before** Phase B
(frontend) begins.

---

## Phase 3: Frontend — Add a card (Priority: P1) — delivery Phase B, part 1

**Goal**: A real, working inline composer (US1).

**Independent Test**: `quickstart.md` §4 US1 row, through the browser.

- [x] T031 [US1] Create `lib/cards/schemas.ts` (Zod: create/update/label/member/checklist/comment input schemas — author all of them now, later tasks just import) in flowboard-web/src/lib/cards/schemas.ts
- [x] T032 [US1] Create the server-only cards client (`createCard` first; later tasks extend this file) in flowboard-web/src/lib/api/cards-client.ts (cite contracts/card-crud-api.md)
- [x] T033 [US1] Create the `cards` tRPC router (`create` `protectedProcedure` first; later tasks extend this file) in flowboard-web/src/server/api/routers/cards.ts; register in root.ts
- [x] T034 [US1] Create `CardComposer` (React Hook Form, Enter commits and re-opens empty, Escape cancels and discards typed text — `frontend-rules.md`'s inline-edit contract) in flowboard-web/src/components/board/card-composer.tsx
- [x] T035 [US1] Make `ListColumn` a client component wired to `cards.create` (invalidate `boards.getContent` on success, per plan.md ADR-19; success/error toast, X-01) in flowboard-web/src/components/board/list-column.tsx

**Checkpoint**: US1 verifiable end-to-end through the browser.

---

## Phase 4: Frontend — Open a card (Priority: P1) — delivery Phase B, part 2

**Goal**: The product's first modal — open, view, and close (US2).

**Independent Test**: `quickstart.md` §4 US2 row.

- [x] T036 [US2] Extend `cards` router/client with `getDetail` (depends on T032/T033) in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T037 [US2] Make `BoardCanvas` a client component owning `openCardPublicId` state (plan.md ADR-14/ADR-19) in flowboard-web/src/components/board/board-canvas.tsx
- [x] T038 [US2] Wire `CardFront`'s click handler to set the open-card state (depends on T037) in flowboard-web/src/components/board/card-front.tsx
- [x] T039 [US2] Create `CardDetailModal` shell (shadcn `Dialog`; header with close button; breadcrumb; loading/error states; closes via ✕, outside click, and Escape) in flowboard-web/src/components/board/card-detail/card-detail-modal.tsx (depends on T036)

**Checkpoint**: US2 verifiable end-to-end — every seeded card from 003 can be opened and
closed.

---

## Phase 5: Frontend — Edit title and description (Priority: P1) — delivery Phase B, part 3

**Goal**: The most basic edits (US3).

**Independent Test**: `quickstart.md` §4 US3 row, including the concurrency-conflict
check.

- [x] T040 [US3] Extend `cards` router/client with `update` (passes the `ETag` captured from `getDetail` as `If-Match`; maps a `409` to a typed conflict result, not a generic error) in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T041 [US3] Create `CardTitleField` (inline edit in the modal header) in flowboard-web/src/components/board/card-detail/card-title-field.tsx (depends on T040)
- [x] T042 [US3] Create `CardDescriptionPanel` (textarea + Save button; plain-text render via `whitespace-pre-wrap`, never `dangerouslySetInnerHTML` — plan.md ADR-15; on `409`, re-fetch via `getDetail` and show the "changed by someone else" toast, FR-013) in flowboard-web/src/components/board/card-detail/card-description-panel.tsx (depends on T040)

**Checkpoint**: US3 verifiable end-to-end, including two-tab concurrent-edit rejection.

---

## Phase 6: Frontend — Labels and members (Priority: P1) — delivery Phase B, part 4

**Goal**: Categorize and assign a card (US4).

**Independent Test**: `quickstart.md` §4 US4 row.

- [x] T043 [US4] Extend `cards` router/client with `assignLabel`/`removeLabel`/`assignMember`/`removeMember` in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T044 [P] [US4] Create `CardLabelsPanel` (multi-select from the board's own labels; success/error toast) in flowboard-web/src/components/board/card-detail/card-labels-panel.tsx (depends on T043)
- [x] T045 [P] [US4] Create `CardMembersPanel` (multi-select from current board members; success/error toast) in flowboard-web/src/components/board/card-detail/card-members-panel.tsx (depends on T043)

**Checkpoint**: US4 verifiable end-to-end, including auto-adding a non-member.

---

## Phase 7: Frontend — Due date (Priority: P2) — delivery Phase B, part 5

**Goal**: Track a due date from the modal (US5).

**Independent Test**: `quickstart.md` §4 US5 row.

- [x] T046 [US5] Create `CardDueDatePanel` (set/clear/mark-complete, reusing T040's `update` mutation; success/error toast) in flowboard-web/src/components/board/card-detail/card-due-date-panel.tsx (depends on T040)

**Checkpoint**: US5 verifiable end-to-end — badge colors match 003's existing rule.

---

## Phase 8: Frontend — Checklist (Priority: P2) — delivery Phase B, part 6

**Goal**: Break a card into steps (US6).

**Independent Test**: `quickstart.md` §4 US6 row.

- [x] T047 [US6] Extend `cards` router/client with `addChecklistItem`/`toggleChecklistItem`/`deleteChecklistItem` in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T048 [US6] Create `CardChecklistPanel` (add/tick/delete, progress bar; success/error toast) in flowboard-web/src/components/board/card-detail/card-checklist-panel.tsx (depends on T047)

**Checkpoint**: US6 verifiable end-to-end.

---

## Phase 9: Frontend — Comments and activity (Priority: P2) — delivery Phase B, part 7

**Goal**: Discuss a card and see its history (US7).

**Independent Test**: `quickstart.md` §4 US7 row.

- [x] T049 [US7] Extend `cards` router/client with `addComment`/`getActivity` in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T050 [US7] Create `CardActivityFeed` (comment box + feed rendering via the fixed message-template lookup, research.md R-6; success/error toast on comment) in flowboard-web/src/components/board/card-detail/card-activity-feed.tsx (depends on T049)

**Checkpoint**: US7 verifiable end-to-end — every prior story's mutation shows up here.

---

## Phase 10: Frontend — Copy and delete (Priority: P3) — delivery Phase B, part 8

**Goal**: Duplicate or remove a card (US8).

**Independent Test**: `quickstart.md` §4 US8 row.

- [x] T051 [US8] Extend `cards` router/client with `copy`/`delete` in flowboard-web/src/server/api/routers/cards.ts, flowboard-web/src/lib/api/cards-client.ts
- [x] T052 [US8] Create `CardAddToCardMenu` (Members/Labels/Due date/Move[inert per FR-016/FR-017]/Copy/Delete; delete requires a confirmation dialog; success/error toast on both actions) in flowboard-web/src/components/board/card-detail/card-add-to-card-menu.tsx (depends on T051)

**Checkpoint**: US8 verifiable end-to-end.

---

## Phase 11: Visual Compliance Loop (`docs/sdlc/review-process.md`) — before the Phase B gate

- [x] T053 Capture the implemented card detail modal (and, best-effort, the composer mid-use) at the same viewport as `screenshots/card-detail-modal.png`, compare item-by-item against VI-001–VI-009, produce the deviation table, fix and recapture until it is empty or every remaining row is user-approved; attach the table and screenshots to the phase notes

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0. AI review AND human review, including the UI-vs-
reference check (the Visual Compliance Loop's deviation table). Commit Phase B.

---

## Phase 12: Polish & Cross-Cutting Concerns

- [ ] T054 [P] Walk `quickstart.md` end-to-end (all US1–US8 rows, both edge cases) and
  fix any doc drift in specs/004-card-crud/quickstart.md
- [ ] T055 Write phase review notes (backend + frontend compliance checklist results,
  gate evidence, the domain-invariant pass) in
  specs/004-card-crud/review-notes.md; write
  specs/004-card-crud/human-pr-review.md; on merge, set roadmap row 004 →
  shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Foundational | T001–T007 | none (no endpoint surface yet); covered by `dotnet test` once Phase A's tests exist |
| Phase A — backend (card mutations) | T008–T030 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (composer, modal + 7 panels, client-driven canvas, Visual Compliance Loop) | T031–T053 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T054–T055 | both gates re-run at merge time |

## Dependencies & Execution Order

- Foundational (T001–T007) has no dependency on anything outside this feature and
  blocks every later task. Within it: T001–T004 (schema/DbContext) can proceed in
  parallel with T005 (ordering module) and T006 (due-status extraction); the migration
  (T007) depends on T001–T004.
- Phase A (T008–T030) depends on Foundational completing. Within each story's slice,
  the service method precedes its endpoint precedes its test (e.g. T008 → T009 → T010).
  US5's test (T020) depends on US3's endpoint (T014/T015) — it adds no new code, only
  coverage. T026 (US7's feed test) depends on T010/T016/T019/T023 having run first in
  the same test class, since it asserts their events appear in the feed.
- Phase B (T031–T053) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule). T031–T033 (schemas/client/router
  scaffolding) precede everything else in Phase B — every later story's router/client
  task extends the same three files rather than recreating them. T037 (client-driven
  `BoardCanvas`) precedes T038 (`CardFront` click) precedes T039 (modal shell) precedes
  every panel (T041–T052, each independent of the others once the modal shell and
  `getDetail`/`update` exist). T053 (Visual Compliance Loop) depends on every panel
  being renderable.
- Polish (T054–T055) is last, after both phase gates pass.

## Parallel Opportunities

- Within Foundational: T001, T002/T003, T005, T006 together (independent files).
- Within Phase A: each story's own integration test (T010, T013, T016, T019, T020,
  T023, T026, T029, T030) is marked `[P]` — different assertions, same test file where
  noted, safe to author in parallel (xUnit runs the collection sequentially regardless).
- Within Phase B: T044 (`CardLabelsPanel`) and T045 (`CardMembersPanel`) together once
  T043 exists — two independent panels over the same router extension.

## Implementation Strategy

MVP = Foundational + Phase A (every US1–US8 backend capability) gated on the backend
alone, matching 003's precedent of gating the backend as one unit ahead of the
consuming tier. Phase B delivers US1–US4 first (add, open, edit core content,
organize — together the smallest useful "real card lifecycle" loop), then US5–US7
(due date, checklist, comments — richer detail), then US8 (copy/delete — least
frequently used), finishing with the Visual Compliance Loop before requesting the
frontend gate. One phase at a time; no unrelated changes; 003's read path
(`BoardContentService`, `GET /v1/boards`/`GET /v1/boards/{id}`) is extended (T006) but
never behaviorally changed.
