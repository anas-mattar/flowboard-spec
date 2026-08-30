# Tasks: Search & Filter

**Input**: Design documents from `/specs/007-search-filter/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/search-filter-addendum.md, quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — touches no domain
invariant newly, adds no write path, fully reversible (display-only filter). Full
Definition of Done applies; no Critical addendum.

**Tests**: One backend test assertion extended (`docs/rulebooks/backend-rules.md` — the
response-shape change needs coverage). No frontend test runner exists yet — frontend
verification is the Visual Compliance Loop + `quickstart.md`, same as 003–006.

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
cross-repository rule: backend gates and merges before frontend starts), with `[Story]`
labels for traceability back to spec.md's four user stories (US1 live text search, US2
label/member/due-date filters, US3 filter chips + Clear all, US4 per-list empty state).
See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4); Foundational/Visual/Polish
  tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Backend — `description` on the board-content read (US1) — delivery Phase A

**Goal**: `CardSummaryDto`/`GET /v1/boards/{boardPublicId}` gains one additive field so
search (US1) can match against description text, not just title (ADR-29, research.md R-2).

**Independent Test**: `quickstart.md` §2 — callable directly against the running API
before any frontend change exists.

- [x] T001 [US1] Add `string? Description` to the `CardSummaryDto` record and forward the
  already-loaded `c.Description` value when constructing it in `GetBoardContentAsync`, next
  to the existing `HasDescription` computation — in
  flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs (cite
  contracts/search-filter-addendum.md)
- [x] T002 [P] [US1] Extend
  `GetBoardContent_ReturnsListsAndCardsInStoredOrder_IndicatorsOnlyWhenApplicable` (and/or
  add a new fact) to assert `Description` is `null` for a card with no description and
  equals the stored text for a card that has one — in
  flowboard-api/tests/Flowboard.Api.Tests/BoardsEndpointTests.cs (depends on T001)

**Checkpoint**: The board-content response carries each card's description. Request the
backend gate (`dotnet build --warnaserror && dotnet test` in `flowboard-api`) before
starting Phase 2.

---

## Phase 2: Frontend — Foundational (shared filter state + predicate)

**Purpose**: Infrastructure every frontend user story below reads from. No user-story UI
work should begin until this phase is complete — mirrors 006's single up-front migration,
scaled to this feature's frontend-only shape.

**⚠️ CRITICAL**: Depends on Phase 1 merging first (repository-strategy.md's
cross-repository rule).

- [x] T003 [P] Add `description: string | null` to the `CardSummary` interface — in
  flowboard-web/src/lib/api/boards-client.ts (cite contracts/search-filter-addendum.md)
- [x] T004 [P] Create the pure filter predicate `passesBoardFilter(card, filter)` —
  case-insensitive substring match on `title + " " + description`; label/member filters
  OR-within-category (`some`); due-date bucket is `"overdue" | "week" | "none" | ""`
  (`"week"` = `-1 day ≤ (dueAt − now) ≤ +7 days`, reusing `dueStatus`/`dueAt` directly for
  `"overdue"`/`"none"` per ADR-31); every non-empty category combines with AND (research.md
  R-5) — in flowboard-web/src/lib/board/passes-board-filter.ts
- [x] T005 Create `BoardFilterProvider`/`useBoardFilter` — React Context holding `{ text,
  labelIds, memberIds, due }`, setters for each, and `clearAll()` (ADR-30, research.md
  R-4), mirroring `sidebar-context.tsx`'s existing shape — in
  flowboard-web/src/components/board/board-filter-context.tsx
- [x] T006 Wrap `<TopBar>` and `<BoardCanvas>` in `<BoardFilterProvider
  key={boardPublicId}>` so switching boards remounts the provider and resets all filter
  state (FR-009) — in flowboard-web/src/app/(app)/boards/[boardPublicId]/page.tsx
  (depends on T005; corrected during implementation from the original plan.md placement
  inside board-canvas.tsx — TopBar and BoardCanvas are page-level siblings, not
  parent/child, so the provider must wrap both from their common ancestor)

**Checkpoint**: Shared filter state and the filtering predicate exist and are ready for
story-level UI to consume.

---

## Phase 3: User Story 1 - Live text search (Priority: P1) 🎯 MVP

**Goal**: Typing in the top-bar search box narrows the board to cards whose title or
description match, live, with no page reload and no new network call.

**Independent Test**: `quickstart.md` §3 — type a fragment of a title (then a
description-only fragment) into the search box and confirm the visible card set narrows
correctly; clear it and confirm every card returns.

- [x] T007 [US1] Wire the top-bar search input to `useBoardFilter`'s `text`/`setText`,
  removing its `disabled` state; also implements FR-010/X-03's `/`/`F` focus shortcut
  (not separately tracked as its own task — folded in here since it's tightly coupled to
  this same input) — extracted into a new client component
  flowboard-web/src/components/layout/board-search-input.tsx, rendered from
  flowboard-web/src/components/layout/top-bar.tsx (server component, unchanged pattern
  per sidebar-toggle-button.tsx) (depends on T005, T006)
- [x] T008 [US1] Filter `list.cards` through `passesBoardFilter` before rendering
  (`list.cards.filter(...)` ahead of the existing `.map(...)`); `list.cardCount` and the
  WIP-limit pill continue reading the list's true, unfiltered `cards` array untouched
  (FR-008) — in flowboard-web/src/components/board/list-column.tsx (depends on T004, T006,
  T007)

**Checkpoint**: Live text search works end-to-end; independently testable and demoable on
its own even with the Filter popover, chip bar, and refined empty-state message not yet
built.

---

## Phase 4: User Story 2 - Filter by label, member, and due-date bucket (Priority: P1)

**Goal**: The Filter popover lets a member narrow the board by label, member, and
due-date bucket, combining with search exactly as User Story 1 already renders it.

**Independent Test**: `quickstart.md` §4 steps 1–3 — select a label, then also a member,
then also a due-date bucket, confirming each narrows the visible set further (AND across
categories).

- [x] T009 [US2] Create `FilterPopover` — three sections (Labels, Members, Due date;
  VI-005…009) wired to `useBoardFilter`'s `labelIds`/`memberIds`/`due` setters, replacing
  the top-bar Filter button's `disabled` state; member options come from `board.members`
  (`TopBarBoardSummary`, already passed to `TopBar` by the page for the avatar stack) — in
  flowboard-web/src/components/board/filter-popover.tsx and
  flowboard-web/src/components/layout/top-bar.tsx (depends on T005, T008). Since
  `FilterPopover` lives in `TopBar` (a sibling of `BoardCanvas`, same ADR-30 lesson as
  T006), it cannot read `board-canvas.tsx`'s local `boardLabels` `useMemo` directly —
  extracted that derivation into a shared `deriveBoardLabels()` helper in
  flowboard-web/src/lib/board/board-labels.ts, used by both `board-canvas.tsx` (updated to
  call it, no behavior change) and `filter-popover.tsx` (which independently calls
  `trpc.boards.getContent.useQuery({ boardPublicId })` — the same query key
  `BoardCanvas` already primed with `initialData`, so this reuses the existing cache entry
  and causes no extra network fetch).

**Checkpoint**: Label/member/due-date filters narrow the board and combine correctly with
an active search term; independently testable per `quickstart.md` §4 steps 1–3.

---

## Phase 5: User Story 3 - See and remove active filters (Priority: P2)

**Goal**: Every active search term or filter renders as its own removable chip in a chip
bar, plus a "Clear all" control; the bar is hidden entirely when nothing is active.

**Independent Test**: `quickstart.md` §4 steps 1, 4–5 — with a search term and a filter
both active, confirm the chip bar shows one chip per constraint, that removing one chip
leaves the others active, and that "Clear all" resets everything.

- [x] T010 [US3] Create `FilterChipBar` — reads `useBoardFilter`'s active state, renders
  one removable chip per active constraint (search text as its own `Text: "…"` chip, one
  per active label, one per active member, one for the due-date bucket) plus a single
  "Clear all" control; renders nothing at all when no constraint is active (VI-002/VI-010)
  — in flowboard-web/src/components/board/filter-chip-bar.tsx (depends on T005). Chip text
  and the "Filters" label follow the reference prototype's own `#chipBar` rendering logic
  (flowboard-prototype.html lines 417-428) exactly, not spec.md's VI-010 prose: opening
  `screenshots/multi-filter-chips.jpg` directly shows the "Filters" label present even with
  two non-text chips active, contradicting VI-010's claim that it's omitted once more than
  a text-search chip is present — the prototype source unconditionally renders it whenever
  `chips.length > 0`. Implemented to match the screenshot/prototype (rung 1) over the
  spec's prose description of it; "Filters" always renders alongside the chips.
- [x] T011 [US3] Render `<FilterChipBar>` above the list row, inside the board canvas — in
  flowboard-web/src/components/board/board-canvas.tsx (depends on T006, T010). Member
  options come from the same `trpc.boardMembers.list.useQuery({ boardPublicId })` call
  `board-canvas.tsx` already runs for the `canMutate` check (mapped to `member.user`) —
  no new query, same cache-sharing principle as T009's `deriveBoardLabels`.

**Checkpoint**: The chip bar appears exactly when a search/filter is active, each chip
removes only its own constraint, and "Clear all" resets every constraint at once;
independently testable per `quickstart.md` §4 steps 4–5.

---

## Phase 6: User Story 4 - Empty state when a list has no matching cards (Priority: P3)

**Goal**: A list with zero cards matching the active search/filter shows an explicit
"No cards match the filter" message instead of its ordinary empty-list state.

**Independent Test**: `quickstart.md` §5 — apply a filter that empties a specific list and
confirm it shows the filter-specific message, then clear the filter and confirm a
genuinely empty list shows its ordinary empty-list state instead.

- [x] T012 [US4] In the same rendering branch touched by T008, distinguish "no cards at
  all" (`list.cards.length === 0`, show the existing "No cards yet") from "cards exist but
  none match" (`list.cards.length > 0 && filteredCards.length === 0`, show "No cards match
  the filter") — in flowboard-web/src/components/board/list-column.tsx (depends on T008)

**Checkpoint**: All four user stories now work together; independently testable per
`quickstart.md` §5.

---

## Phase 7: Visual Compliance Loop (`docs/sdlc/review-process.md`) — before the Phase B gate

- [x] T013 Capture the implemented search-active state (with the chip bar and a
  filtered-to-nothing list), the Filter popover open, and a multi-filter AND combination
  at the same viewport as `screenshots/search-active-empty-state.jpg`,
  `screenshots/filter-popover.jpg`, and `screenshots/multi-filter-chips.jpg`; compare
  item-by-item against VI-001–VI-011; produce the deviation table; fix and recapture until
  it is empty or every remaining row is user-approved; attach the table and screenshots to
  the phase notes.

  **Render environment**: throwaway signed-up test account + a freshly created 3-list
  board ("To Do"/"Doing"/"Done", 4 cards, one member — this developer's own account, no
  board labels since no label-creation UI exists yet, ADR/known limitation from 004),
  captured via browser automation at ~1420×590 viewport (close to the reference
  screenshots' own captured size). Screenshots attached at
  `screenshots/implemented/search-active-empty-state.jpg`,
  `screenshots/implemented/filter-popover.jpg`,
  `screenshots/implemented/multi-filter-chips.jpg`.

  **Deviation table** (all rows fixed and recaptured — table closes empty, no user
  approval needed):

  | # | Element (VI ref) | Reference shows | Implemented shows (before fix) | Severity | Resolution |
  |---|---|---|---|---|---|
  | 1 | Filter popover rows (VI-007/008/009) | Prototype source (`flowboard-prototype.html` lines 804-809) renders plain clickable rows with a trailing "✓" tick shown only once selected — no checkbox glyph | Rows used a leading shadcn `Checkbox` (mirroring the card detail modal's label/member panels) | Medium | Fixed: rebuilt as plain `PopRow` buttons with a trailing `Check` icon shown only when `selected` — `filter-popover.tsx` |
  | 2 | Label rows (VI-007) | Small colored bar/swatch (`.lab`, 8px tall, no text) beside the plain-colored label name | Label name rendered inside a solid colored badge with white text (card-detail-panel convention, wrong surface) | Medium | Fixed: swatch is now a bare colored bar (`h-2 min-w-[34px] rounded-sm`) beside plain-text label name |
  | 3 | Chip bar chips + "Clear all" (VI-002/VI-010) | Both share one filled light-gray surface (`.chip`/`.btn`, `--panel-2`) | Chips used `bg-background` (white/transparent); "Clear all" had a border only, no fill | Medium | Fixed: both switched to `bg-muted` (this app's equivalent token, already used for the list header's count pill) — `filter-chip-bar.tsx` |
  | 4 | "FILTER CARDS" heading (VI-005) | Centered | Left-aligned | Low | Fixed: added `text-center` |
  | 5 | Per-list empty-filter message (VI-004) | Prototype text has no trailing period: "No cards match the filter" | Implemented text had a trailing period | Low | Fixed: dropped the period to match the reference exactly — `list-column.tsx` |

  Also confirmed (not a deviation, just verified in this loop): VI-010's spec.md prose
  claims the "Filters" label disappears once more than the text chip is active — the
  reference screenshot and the prototype's own render logic both show it unconditionally
  whenever any chip is active. Implemented to match the screenshot/prototype (documented
  in T010 already); re-confirmed correct during this loop's side-by-side comparison.

  **Exit status**: table is empty — every row fixed and recaptured against the live app,
  zero rows required user sign-off.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T014 [P] Walk `quickstart.md` end-to-end (§§2–7, all edge cases including
  description-only search matches, board-switch reset, and the `/`/`F` keyboard shortcut)
  and fix any doc drift in specs/007-search-filter/quickstart.md.

  Walked live against a running dev server (throwaway account, "Chip Bar Test Board" +
  a second freshly created board for §6): §3 live search including a description-only
  match ("xylophone" typed into a card's description, found by search even though absent
  from its title) then cleared to restore every card; §4/§5 filters, chips, AND-across-
  categories, and the per-list empty-filter vs genuinely-empty distinction (label filter
  substituted with member+due-date live, since no label-creation UI exists yet — same
  known limitation noted in Phases 4/6/7); §6 board-switch reset confirmed in both
  directions (switching away from a board with an active filter, and back); §7 the `/`
  keyboard shortcut confirmed focusing the search box from the board canvas.

  **Doc drift found and fixed**: §5 step 3 said a genuinely-empty list shows "Drop cards
  here" — that's the reference prototype's own wording, but the real app has shown
  "No cards yet." since 004 and always has; the quickstart text was never updated to match
  the actual shipped copy. Corrected in quickstart.md.
- [x] T015 Write phase review notes (backend + frontend compliance checklist results, gate
  evidence, the domain-invariant pass) in specs/007-search-filter/review-notes.md; write
  specs/007-search-filter/human-pr-review.md; on merge, set roadmap row 007 → shipped in
  docs/roadmap.md.

  `review-notes.md` written with both phases' full AI review (verdict, compliance
  checklists, findings F1–F4, Visual Compliance Loop table, constitution re-check, domain
  invariant pass, test coverage, residual risk — both APPROVE). `human-pr-review.md`
  scaffolded from the template with the checklist items an honest review already
  supports pre-filled, but Gate Result exit codes and the Approval/Decision sections left
  **pending** — nothing has been committed, pushed, or merged yet (see the branch-fix
  note below), so those sections can't honestly be filled in until the actual human
  review and merge happen. `docs/roadmap.md` row 007 bumped from `idea` to `in progress`
  (accurate given spec/plan/tasks all exist and implementation is complete) — the
  `→ shipped` step per this task's own wording happens `on merge`, not now.

  **Process note**: discovered at the start of this phase that both `flowboard-api` and
  `flowboard-web` had been on `main` this entire feature, with every phase's changes
  sitting as uncommitted working-tree diffs — no `007-search-filter` branch was ever
  created, violating `docs/sdlc/branch-strategy.md`'s "main is protected" / "one branch
  per feature" rules. Nothing had been committed yet, so nothing was lost. Flagged to the
  user, who approved creating the branch now; both repos are on `007-search-filter` as of
  this phase, carrying all uncommitted work forward safely.

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Phase A — backend (`description` field) | T001–T002 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (foundational + all 4 user stories, Visual Compliance Loop) | T003–T013 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T014–T015 | both gates re-run at merge time |

## Dependencies & Execution Order

- Phase 1 (backend, T001–T002) blocks all of Phase 2 onward — `passesBoardFilter`'s
  description-matching branch (T004) and the frontend `CardSummary` type (T003) both need
  the backend response to actually carry the field, and repository-strategy.md's
  cross-repository rule requires the backend phase to gate and merge first regardless.
- Phase 2 (Foundational, T003–T006) blocks every user-story phase — all four stories read
  from `useBoardFilter` and/or `passesBoardFilter`.
- User Story 1 (T007–T008) has no dependency on User Stories 2–4 and is the suggested MVP
  cut point.
- User Story 2 (T009) depends only on Foundational + T008 (the filtering render path must
  already exist for a newly-set label/member/due selection to visibly narrow anything) —
  not on the search box itself being wired.
- User Story 3 (T010–T011) depends only on Foundational (T005) — the chip bar renders
  whatever is active in context regardless of which control set it, so it has no code
  dependency on the Filter popover (T009) itself, only on there being *something* to
  exercise it with (US1 or US2 already existing) for a meaningful manual test.
- User Story 4 (T012) depends on T008 (the same rendering branch it refines).
- Visual Compliance Loop (T013) depends on every user-story UI surface being in its final
  state. Polish (T014–T015) is last, after both phase gates pass.

## Parallel Opportunities

- T002 (backend test) can be written in parallel with review of T001, though it exercises
  T001's own change.
- T003 and T004 (frontend type addition, filter predicate) touch different files and have
  no dependency on each other — safe in parallel once Phase 1 merges.
- Once Foundational (T003–T006) is complete, User Story 1 (T007–T008) and the *build* of
  User Story 3's chip bar (T010) can proceed in parallel — T010 doesn't touch
  `list-column.tsx` or `top-bar.tsx`. User Story 2 (T009) and User Story 4 (T012) each
  depend on T008 landing first, since both touch/extend the same `list-column.tsx`
  rendering path or need it in place to test against.

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (backend gate passes and merges)
2. Complete Phase 2 (Foundational)
3. Complete Phase 3 (User Story 1 — live text search)
4. **STOP and VALIDATE**: `quickstart.md` §3 end-to-end
5. Deploy/demo if ready — search alone is already a complete, valuable increment

### Incremental Delivery

1. Phase 1 (backend) → gate → merge
2. Phase 2 (Foundational) → User Story 1 → validate independently (MVP!)
3. Add User Story 2 (Filter popover) → validate independently
4. Add User Story 3 (chip bar) → validate independently
5. Add User Story 4 (empty-state message) → validate independently
6. Visual Compliance Loop → Polish → request the frontend gate → merge

One phase at a time; no unrelated changes; 003–006's existing top-bar/board-canvas/
list-column components are extended (never rebuilt) — the search box and Filter button in
particular go from `disabled` placeholders (003) to fully wired controls, the same way 006
activated the previously-inert list "⋯" button and Star control.
