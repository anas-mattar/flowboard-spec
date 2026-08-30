# Feature Specification: Search & Filter

**Feature Branch**: `007-search-filter`
**Created**: 2026-08-30
**Status**: Draft
**Input**: User description: "007-search-filter: live search, label/member/due-date filters, filter chip bar, and empty state — covers INV-003 and functional stories F-01 through F-04 (FUNCTIONAL_SPEC.md §3.4, §4.3). Search filters cards currently visible on the board canvas by title/description text. Filters narrow visible cards by label, assigned member, and due-date bucket. Active filters render as removable chips in the filter chip bar (INV-003). When no cards match the active search/filter combination, lists show an empty state. This is a client-side/read-side feature layered on top of the board view already shipped in 003-board-view-readonly and the card data shipped in 004-card-crud — no new persistence, no new API writes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Live text search (Priority: P1)

As a board member, I want to type into the search box and see the board narrow to only
the cards whose title or description match, updating as I type, so I can find a specific
card without scrolling through every list.

**Why this priority**: Search is the single highest-value, lowest-friction way to locate a
card and is the story every other part of this feature builds on (the chip bar and empty
state both exist to support it). It also activates a top-bar control that has been visibly
present but disabled since 003-board-view-readonly.

**Independent Test**: Open a board with cards spread across multiple lists, type a
fragment of one card's title into the search box, and confirm only matching cards remain
visible while all others (in every list) disappear — with no page reload and no new
network write.

**Acceptance Scenarios**:

1. **Given** a board with cards in several lists, **When** the member types a fragment of
   a card's title into the search box, **Then** only cards whose title or description
   contain that fragment (case-insensitive) remain visible in each list, updating after
   every keystroke without a page reload.
2. **Given** an active search term, **When** the member clears the search box, **Then**
   every card on the board becomes visible again.
3. **Given** a search term that matches a card's description but not its title, **When**
   the member searches for that term, **Then** the card still appears (description text is
   searched, not just the title).

---

### User Story 2 - Filter by label, member, and due-date bucket (Priority: P1)

As a board member, I want to narrow the board to cards carrying a specific label,
assigned to a specific member, or falling into a due-date bucket (Overdue / Next 7 days /
No due date), so I can focus on the subset of work relevant to me right now.

**Why this priority**: Alongside search, filtering is the other core mechanism the
Filter chip bar (INV-003) and empty state exist to support; it delivers standalone value
even without search (e.g. "show me only my overdue cards").

**Independent Test**: Open a board with cards carrying varied labels, members, and due
dates. Open the filter control, select one label, and confirm only cards carrying that
label remain visible in every list. Repeat for a member and for a due-date bucket, and
confirm combining more than one category narrows further (AND across categories).

**Acceptance Scenarios**:

1. **Given** a board with labelled cards, **When** the member selects one label in the
   filter control, **Then** only cards carrying that label remain visible.
2. **Given** two labels selected in the filter control, **When** both are active, **Then**
   a card carrying either label remains visible (OR within the label category).
3. **Given** a label filter and a member filter both active, **When** both are set,
   **Then** only cards that satisfy both — carrying the selected label(s) **and**
   assigned to the selected member(s) — remain visible (AND across categories).
4. **Given** the "Overdue" due-date bucket is selected, **When** the filter is applied,
   **Then** only cards with a due date in the past (and not marked complete) remain
   visible.
5. **Given** the "Next 7 days" bucket is selected, **When** the filter is applied,
   **Then** cards due within the next 7 days, including any already overdue by up to a
   day, remain visible.
6. **Given** the "No due date" bucket is selected, **When** the filter is applied,
   **Then** only cards without any due date remain visible.

---

### User Story 3 - See and remove active filters (Priority: P2)

As a board member, I want every active search term or filter to show up as its own
removable chip, with a "Clear all" option, so I always know what's narrowing my view and
can back out of it in one click.

**Why this priority**: This depends on User Story 1 and/or 2 already being active — it is
the visibility/control layer on top of them, valuable but not independently meaningful
without an active search or filter to display.

**Independent Test**: With a search term and one filter category active at the same time,
confirm the chip bar appears showing one chip per active constraint (including the search
text itself), that clicking a chip's ✕ removes only that one constraint and restores the
cards it had hidden, and that "Clear all" removes every constraint at once.

**Acceptance Scenarios**:

1. **Given** no search term and no filter is active, **When** the board is viewed,
   **Then** the filter chip bar is not shown at all.
2. **Given** a search term is active, **When** the chip bar renders, **Then** it includes
   a chip showing the search text.
3. **Given** one label, one member, and the due-date bucket are all active, **When** the
   chip bar renders, **Then** it shows one chip per active label, one per active member,
   and one for the due-date bucket, plus a "Clear all" control.
4. **Given** multiple active chips, **When** the member clicks a single chip's ✕,
   **Then** only that constraint is removed and the board re-filters to reflect the
   remaining active constraints.
5. **Given** multiple active chips, **When** the member clicks "Clear all", **Then**
   every filter and the search text are reset and every card becomes visible again.

---

### User Story 4 - Empty state when a list has no matching cards (Priority: P3)

As a board member, I want a list that currently has zero cards matching my active
search/filter to say so explicitly, so I don't mistake "everything got filtered out" for
"this list happens to have nothing in it because I moved cards to another view."

**Why this priority**: Purely a clarity/polish layer on top of Stories 1–2; the filtering
itself already works without it, but its absence risks user confusion, so it ships in the
same feature rather than being deferred.

**Independent Test**: Apply a search term or filter that no card in a given list matches,
and confirm that list shows an explicit "No cards match the filter" message instead of
rendering as if it were simply empty of cards.

**Acceptance Scenarios**:

1. **Given** an active search/filter combination, **When** a list has at least one card
   that does not match, **Then** that non-matching card is hidden and does not count
   toward the list's visible content.
2. **Given** an active search/filter combination, **When** a list has zero cards matching
   it, **Then** that list displays "No cards match the filter" in place of its normal
   empty-list affordance.
3. **Given** no search/filter is active, **When** a list genuinely has zero cards,
   **Then** the list shows its ordinary empty-list state (e.g. "Drop cards here"), not the
   filter-specific message.

---

### Edge Cases

- Switching to a different board resets any active search text and filters — a filter
  set on one board must never silently carry over and hide cards on another.
- A card that is filtered out is only visually hidden, never altered, soft-deleted, or
  excluded from its list's underlying card count/WIP-limit calculation (006-board-list-
  management's WIP pill continues to reflect the true, unfiltered card count).
- The due-date bucket is mutually exclusive with itself (selecting a new bucket replaces
  the previous one) but combines with label and member filters exactly like any other
  category (AND across categories, per FR-002).
- A completed card that is technically past its due date is excluded from the "Overdue"
  bucket (matching card-front due-badge coloring rules already shipped in 004-card-crud,
  where a completed date badge renders green, not red).
- Keyboard shortcut: pressing `/` or `F` (per X-03) focuses the search box from anywhere
  on the board, unless the member is already typing into another field.
- Search matching is case-insensitive and matches on substring, not whole-word or fuzzy
  matching.

---

## Visual Inventory *(mandatory when the feature has `screenshots/` — else delete this section)*

Captured live from `docs/product/prototype/flowboard-prototype.html` (rung 2), run
locally via a temporary static server (`file://` URLs are not directly navigable by this
project's browser tooling).

### Screenshot: `screenshots/search-active-empty-state.jpg` — search active, chip bar, per-list empty state

- **VI-001**: Search box (top bar, right of board title) shows the typed term "design" as
  live input value while filtering is active.
- **VI-002**: Filter chip bar renders directly below the top bar, above the list row, as
  its own horizontal strip: label "Filters", one chip `Text: "design"` with an `✕`, and a
  "Clear all" button — in that left-to-right order.
- **VI-003**: Lists with at least one matching card ("Design") render normally, showing
  only the matching card(s); their header count pill keeps the list's true unfiltered
  count (e.g. "2/3"), not a filtered count.
- **VI-004**: Lists with zero matching cards ("Backlog", "In Progress", "Review") render
  the list header and "+ Add a card" control unchanged, but the card area shows centered
  gray text "No cards match the filter" in place of any cards.

### Screenshot: `screenshots/filter-popover.jpg` — Filter popover open, no selection yet

- **VI-005**: Popover opens anchored below/right of the "⚙ Filter" button, titled "FILTER
  CARDS" (all-caps heading).
- **VI-006**: Three sections top-to-bottom, each with an all-caps section label: "LABELS",
  "MEMBERS", "DUE DATE".
- **VI-007**: Each label row is a colored pill/swatch matching that label's own color,
  followed by its name — one row per board label (e.g. Bug, Feature, Design, Urgent,
  Research, Blocked).
- **VI-008**: Each member row is a round avatar (initials, colored background) followed by
  the member's full name.
- **VI-009**: Due-date section has exactly three plain-text rows, no swatch/avatar:
  "Overdue", "Due in the next 7 days", "No due date".

### Screenshot: `screenshots/multi-filter-chips.jpg` — two filters combined (AND), several lists emptied

- **VI-010**: Two chips render side by side in the chip bar in selection order: `Label:
  Design ✕`, then `Due: Next 7 days ✕`, followed by "Clear all" — no "Filters" label text
  once more than a text-search chip is present in this state (chip bar shows the chips
  directly).
- **VI-011**: Only cards satisfying both active filters remain visible (AND across
  categories) — here, one card in one list — while every other list shows the "No cards
  match the filter" empty state simultaneously.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST filter the currently displayed cards on a board by a
  live text search that matches (case-insensitively, substring match) each card's title
  or description, updating the visible set after every keystroke without a full page
  reload or any new network write.
- **FR-002**: The system MUST let a member narrow the currently displayed cards by any
  combination of: one or more labels, one or more assigned members, and one due-date
  bucket (Overdue, Next 7 days, No due date). Selections within the same category combine
  with OR (a card matching any selected label passes); selections across categories
  combine with AND (a card must satisfy every active category, including the search
  text, to remain visible).
- **FR-003**: The system MUST render the filter chip bar only when at least one search
  term or filter is active, showing one removable chip per active constraint (including
  the search text as its own chip) plus a single "Clear all" control; the bar MUST be
  completely hidden when nothing is active.
- **FR-004**: Removing a single chip MUST remove only that one constraint and
  re-evaluate the visible card set against the remaining active constraints; it MUST NOT
  clear any other active search text or filter.
- **FR-005**: "Clear all" MUST reset every active filter and the search text in one
  action, restoring every card on the board to visible.
- **FR-006**: When the active search/filter combination leaves a given list with zero
  matching cards, that list MUST display an explicit "No cards match the filter" message
  in place of its ordinary empty-list state; a list with genuinely zero cards (no filter
  active) MUST continue to show its ordinary empty-list state instead.
- **FR-007**: Filtering (search text, label, member, due-date bucket) MUST be applied
  entirely against data already loaded for the current board view; it MUST NOT trigger any
  new API write, and MUST NOT alter, soft-delete, or reorder any card, list, or board
  record.
- **FR-008**: Every list's card-count and WIP-limit pill (006-board-list-management)
  MUST continue to reflect the list's true, unfiltered card count while a search/filter is
  active — filtering changes what is visible, not what is counted.
- **FR-009**: Navigating to a different board, or reloading the current board's data,
  MUST reset the search text and every active filter back to none.
- **FR-010**: The system MUST let a member focus the search box via the `/` or `F`
  keyboard shortcut (per X-03) from anywhere on the board, except while already typing
  into another text field.

### Key Entities

This feature introduces no new persisted entity. It reads the `Card` fields already
established by 004-card-crud (`title`, `description`, `labelIds`, `memberIds`, `dueDate`,
`completed`) and holds search/filter selections only as transient, client-side view state
scoped to the currently open board — never written back to the API or database. Whether
the full description text is already present in the data this feature reads, or needs to
be added to an existing read response, is a technical question for `plan.md`, not a
scope question — either way no new entity, table, or write path is introduced.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A member can narrow a board of 50+ cards down to the single card they're
  looking for, by typing a search term, in under 5 seconds.
- **SC-002**: 100% of card searches and filter selections update the visible card set
  with no perceptible delay (rendered before the next keystroke can be typed) and produce
  zero additional API write calls.
- **SC-003**: A member can tell, at a glance and without opening the filter control, which
  search term and which filters are currently narrowing the board, and can remove any one
  of them individually.
- **SC-004**: When a filter empties a list, 100% of affected members see an explicit
  explanation ("No cards match the filter") rather than an ambiguous blank list.

## Assumptions

- The search input and Filter button already rendered (disabled) in the top bar since
  003-board-view-readonly (`flowboard-web/src/components/layout/top-bar.tsx`) are the
  controls this feature activates; no new top-bar layout is introduced.
- Due-date buckets are exactly the three named in FUNCTIONAL_SPEC.md §4.2 — Overdue,
  Next 7 days, No due date — matching the reference prototype's own bucket logic
  (`docs/product/prototype/flowboard-prototype.html`, `passesFilter`/due-bucket handling).
  There is no separate "due today" bucket.
- Filtering is scoped to the single board currently open; it never searches or filters
  across other boards.
- Reference screenshots of the search+chip-bar+empty-state combination, the filter
  popover, and a multi-filter AND combination were captured live from
  `docs/product/prototype/flowboard-prototype.html` under
  `specs/007-search-filter/screenshots/` (see Visual Inventory above) during planning.
- Whether this feature stays frontend-only or needs one small additive backend read-DTO
  change (no new persistence, no new endpoint, no write) is resolved in `plan.md`/
  `research.md` — the "no new API writes" framing in the input description holds either
  way; only whether an existing read response already carries everything search needs was
  left open at spec time.
