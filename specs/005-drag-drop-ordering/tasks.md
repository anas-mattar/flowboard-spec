# Tasks: Drag & Drop Ordering

**Input**: Design documents from `/specs/005-drag-drop-ordering/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/move-api.md,
quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — touches domain
invariant 2 (Ordering Integrity) but not in the Critical-triggering category; every
mutation is a reversible one-row position write. Full Definition of Done applies; no
Critical addendum.

**Tests**: Backend integration tests are included throughout —
`docs/rulebooks/backend-rules.md` requires one per endpoint unconditionally, plus a
golden-fixture test for the insertion-point resolution logic (constitution XI). No
frontend test runner exists yet — frontend verification is the Visual Compliance Loop +
`quickstart.md`.

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
cross-repository rule: backend gates and merges before frontend starts), with `[Story]`
labels for traceability back to spec.md's user stories (US1 reorder/move a card by
dragging, US2 move via an accessible menu, US3 reorder lists by dragging). See
"Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US3); Foundational/Polish
  tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 2+) may begin until this phase is complete.
No new packages this feature (plan.md Technical Context) — nothing to add in a separate
Setup phase; no migration either (no schema change).

- [ ] T001 Add `CardMoved = "card.moved"` to flowboard-api/src/Flowboard.Api/Domain/ActivityEventType.cs (data-model.md ActivityEvent)

**Checkpoint**: Shared event-type constant exists. Backend endpoint work (Phase 2) can
now begin.

---

## Phase 2: Backend — Card Move (Priority: P1) 🎯 — delivery Phase A

**Goal**: `POST /v1/cards/{cardPublicId}/move`, the single endpoint both US1 (drag) and
US2 (the "Move" menu) call.

**Independent Test**: `quickstart.md` §3, backend half of the US1/US2 rows — callable
directly against the running API before any frontend exists.

- [ ] T002 [US1] `CardService.MoveCardAsync` — resolve `listPublicId`/`beforeCardPublicId` into an `Ordering.Append`/`InsertBetween` call (research.md R-1); reject if the target list or `beforeCardPublicId` isn't on the same board (`400`); write a `card.moved` event only when the resolved list differs from the card's current list (research.md R-3); never check `RowVersion`/`If-Match` (plan.md ADR-21); never enforce the destination's WIP limit (research.md R-6) — in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/move-api.md)
- [ ] T003 [US1] `POST /v1/cards/{cardPublicId}/move` in flowboard-api/src/Flowboard.Api/Endpoints/CardsEndpoints.cs (depends on T002)
- [ ] T004 [P] [US1] Integration test: same-list reorder lands at the resolved position and writes no activity entry; cross-list move lands correctly, disappears from the source list, and writes exactly one `card.moved` entry; a destination list already over its WIP limit still accepts the move; a stale caller's move still succeeds against a card someone else just moved (last-write-wins, no `409`); `beforeCardPublicId`/`listPublicId` from a different board → `400`; Observer → `403`; no board access → `404` — in flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs
- [ ] T005 [P] Golden-fixture test: given a set of sibling positions and a target "insert before" id, `CardService`'s insertion-point resolution calls the correct `Ordering.Append`/`InsertBetween` with hand-worked expected values, including the "append at the end" (`beforeCardPublicId` omitted) case — in flowboard-api/tests/Flowboard.Api.Tests/OrderingTests.cs

**Checkpoint**: A card can be moved anywhere on the board through the API alone.

---

## Phase 3: Backend — List Move (Priority: P2) — delivery Phase A

**Goal**: `POST /v1/lists/{listPublicId}/move` (US3) — the first list-scoped endpoint
group this project has built.

**Independent Test**: `quickstart.md` §3, US3 row's backend half.

- [ ] T006 [US3] `ListService.MoveListAsync` — resolve `beforeListPublicId` into an `Ordering.Append`/`InsertBetween` call the same way T002 does for cards; reject a `beforeListPublicId` from a different board (`400`); no activity event (lists aren't card-scoped, research.md R-3's own note) — in flowboard-api/src/Flowboard.Api/Services/ListService.cs (new file; cite contracts/move-api.md)
- [ ] T007 [US3] `POST /v1/lists/{listPublicId}/move` in flowboard-api/src/Flowboard.Api/Endpoints/ListsEndpoints.cs (new file; depends on T006); register `IListService` and `MapListsEndpoints` in flowboard-api/src/Flowboard.Api/Program.cs
- [ ] T008 [P] [US3] Integration test: reordering a list lands it at the resolved position for a subsequent board fetch; dropping a list back at its own position is a no-op; a `beforeListPublicId` from a different board → `400`; Observer → `403`; no board access → `404` — in flowboard-api/tests/Flowboard.Api.Tests/ListsEndpointTests.cs (new file)

**Checkpoint — Phase A gate**: STOP. User runs
`dotnet build --warnaserror && dotnet test` in flowboard-api and confirms EXIT 0. AI
review AND human review. Commit Phase A. Per `docs/sdlc/repository-strategy.md`'s
cross-repository rule, the backend gates and merges to `main` **before** Phase B
(frontend) begins.

---

## Phase 4: Frontend — Reorder or move a card by dragging (Priority: P1) — delivery Phase B, part 1

**Goal**: Native HTML5 drag-and-drop for cards, with the optimistic-update pattern
plan.md ADR-22 establishes for this feature.

**Independent Test**: `quickstart.md` §3 US1 row, through the browser.

- [ ] T009 [US1] Create `lib/cards/schemas.ts` addition — `moveCardInputSchema` (cardPublicId, listPublicId, beforeCardPublicId optional) in flowboard-web/src/lib/cards/schemas.ts
- [ ] T010 [US1] Extend the server-only cards client with `moveCard` in flowboard-web/src/lib/api/cards-client.ts (cite contracts/move-api.md)
- [ ] T011 [US1] Extend the `cards` tRPC router with a `move` `protectedProcedure` in flowboard-web/src/server/api/routers/cards.ts (depends on T009/T010)
- [ ] T012 [US1] Make `CardFront` draggable — `draggable`, `dragstart`/`dragend` reporting the dragged card's id up via a callback prop, faded (opacity) while dragging (VI-001) — in flowboard-web/src/components/board/card-front.tsx
- [ ] T013 [US1] Wire `ListColumn`'s card container as a drop zone — `dragover`/`dragleave`/`drop`, resolving `beforeCardPublicId` by comparing the pointer's Y position against each visible sibling's vertical midpoint (research.md R-4), calling `cards.move` with an optimistic `boards.getContent` cache patch on `onMutate` and a snapshot-restore on `onError` (plan.md ADR-22); dashed drag-over outline on the hovered list (VI-002) — in flowboard-web/src/components/board/list-column.tsx

**Checkpoint**: US1 verifiable end-to-end through the browser.

---

## Phase 5: Frontend — Move a card via an accessible menu (Priority: P1) — delivery Phase B, part 2

**Goal**: Activate 004's already-built but inert "Move" button (C-11).

**Independent Test**: `quickstart.md` §3 US2 row, keyboard-only.

- [ ] T014 [US2] Create `CardMovePanel` — a "Move to list" popover listing every list on the board (from the already-fetched board content, same derivation style as 004's `boardLabels`), a checkmark beside the card's current list, calling the same `cards.move` mutation from T011 with no `beforeCardPublicId` (append at the end) — in flowboard-web/src/components/board/card-detail/card-move-panel.tsx (mirrors `card-labels-panel.tsx`'s shape)
- [ ] T015 [US2] Wire `CardAddToCardMenu`'s "Move" button to open `CardMovePanel` in a `Popover`, the same pattern as its Members/Labels/Due date buttons; remove the `disabled`/inert styling — in flowboard-web/src/components/board/card-detail/card-add-to-card-menu.tsx (depends on T014)

**Checkpoint**: US2 verifiable end-to-end with a keyboard alone.

---

## Phase 6: Frontend — Reorder lists by dragging (Priority: P2) — delivery Phase B, part 3

**Goal**: Native HTML5 drag-and-drop for whole list columns (L-03).

**Independent Test**: `quickstart.md` §3 US3 row, through the browser.

- [ ] T016 [US3] Create `lib/lists/schemas.ts` — `moveListInputSchema` (listPublicId, beforeListPublicId optional) in flowboard-web/src/lib/lists/schemas.ts
- [ ] T017 [US3] Create the server-only lists client — `moveList` in flowboard-web/src/lib/api/lists-client.ts (cite contracts/move-api.md)
- [ ] T018 [US3] Create the `lists` tRPC router — `move` `protectedProcedure` in flowboard-web/src/server/api/routers/lists.ts (depends on T016/T017); register in flowboard-web/src/server/api/root.ts
- [ ] T019 [US3] Make `ListColumn` itself draggable — `draggable`, `dragstart`/`dragend` on the list header, faded while dragging (VI-008) — in flowboard-web/src/components/board/list-column.tsx (depends on T013 — the card-drop-zone wiring from Phase 4 must not fire during a list-level drag)
- [ ] T020 [US3] Wire `BoardCanvas`'s list container as the list drop zone — `dragover`/`dragleave`/`drop` resolving `beforeListPublicId` the same way T013 resolves cards, optimistic cache patch + snapshot-restore (ADR-22), dashed drag-over outline (VI-009) — in flowboard-web/src/components/board/board-canvas.tsx (depends on T018/T019)

**Checkpoint**: US3 verifiable end-to-end through the browser.

---

## Phase 7: Visual Compliance Loop (`docs/sdlc/review-process.md`) — before the Phase B gate

- [ ] T021 Capture the implemented board mid-card-drag, the "Move to list" popover, and the board mid-list-drag at the same viewport as `screenshots/board-canvas-dragging.jpg`, `screenshots/card-move-to-list-popup.jpg`, and `screenshots/list-reorder-dragging.jpg`; compare item-by-item against VI-001–VI-009; produce the deviation table; fix and recapture until it is empty or every remaining row is user-approved; attach the table and screenshots to the phase notes

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0. AI review AND human review, including the UI-vs-
reference check (the Visual Compliance Loop's deviation table). Commit Phase B.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T022 [P] Walk `quickstart.md` end-to-end (US1–US3 rows, all edge cases including
  the two-window last-write-wins check) and fix any doc drift in
  specs/005-drag-drop-ordering/quickstart.md
- [ ] T023 Write phase review notes (backend + frontend compliance checklist results,
  gate evidence, the domain-invariant pass) in
  specs/005-drag-drop-ordering/review-notes.md; write
  specs/005-drag-drop-ordering/human-pr-review.md; on merge, set roadmap row 005 →
  shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Foundational | T001 | none (no endpoint surface yet); covered by `dotnet test` once Phase A's tests exist |
| Phase A — backend (card move, list move) | T002–T008 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (card drag, Move menu, list drag, Visual Compliance Loop) | T009–T021 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T022–T023 | both gates re-run at merge time |

## Dependencies & Execution Order

- Foundational (T001) has no dependency on anything outside this feature and blocks
  every later task.
- Phase A (T002–T008) depends on Foundational completing. Within it: card-move (T002–
  T005) and list-move (T006–T008) touch disjoint files and can proceed in parallel; T005
  (golden-fixture) depends on T002 existing (it tests the resolution logic T002
  implements) but not on T003/T004.
- Phase B (T009–T021) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule). T009–T011 (card-move schema/client/
  router) precede T012/T013 (the actual drag wiring). T014–T015 (US2, the Move menu)
  depend on T011 (same mutation) but not on T012/T013 — the menu and dragging are
  independent consumers of the same backend call, and can be built in either order once
  T011 exists. T016–T018 (list-move schema/client/router) precede T019/T020. T019
  depends on T013 (the card drop-zone must ignore a list-level drag in progress — a real
  interaction-ordering dependency, not just a file dependency). T021 (Visual Compliance
  Loop) depends on every drag/menu interaction being in its final state.
- Polish (T022–T023) is last, after both phase gates pass.

## Parallel Opportunities

- Within Phase A: T002–T005 (card move) and T006–T008 (list move) are two independent
  vertical slices — safe to implement in parallel once T001 exists.
- Within Phase B: T014–T015 (US2, Move menu) can be built in parallel with T012–T013
  (US1, dragging) once T011 exists, since both are independent consumers of the same
  `cards.move` mutation.

## Implementation Strategy

MVP = Foundational + Phase A (both move endpoints) gated on the backend alone, matching
004's precedent of gating the backend as one unit ahead of the consuming tier. Phase B
delivers US1 (drag) and US2 (the accessible menu) together — they are two sides of one
accessibility requirement and should not ship one without the other — then US3 (list
reorder) as the lower-priority, independent addition, finishing with the Visual
Compliance Loop before requesting the frontend gate. One phase at a time; no unrelated
changes; 003/004's existing board-canvas/list-column/card-front components are extended
(never rebuilt) with the new drag behavior layered on top of what's already there.
