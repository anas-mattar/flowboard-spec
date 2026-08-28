# Feature Specification: Card Lifecycle CRUD

**Feature Branch**: `004-card-crud`
**Created**: 2026-08-28
**Status**: Draft
**Input**: User description: "Card lifecycle CRUD on top of 003's read-only board view.
Covers roadmap Inv INV-007 (card detail modal), story ids C-01, C-03 through C-10, C-12,
C-13 from docs/product/FUNCTIONAL_SPEC.md section 3.3, and cross-cutting X-01 (action
toasts) from section 3.5. Scope: inline card composer (C-01); card detail modal
two-column layout (C-03, INV-007); inline title edit (C-04); description with Save
button (C-05); label multi-select (C-06); member multi-select with auto-add-to-board
(C-07); due date set/clear/complete (C-08); checklist add/tick/delete (C-09); comments
(C-10); copy card (C-12); delete card soft-delete (C-13); X-01 toasts. All mutations
append to the ActivityEvent trail; the activity feed reads it back. Optimistic
concurrency via the existing RowVersion, a stale write is rejected. Permissions reuse
the existing role matrix from 002. Out of scope: drag-and-drop and move-via-menu (005),
list/board CRUD (006), search/filter (007), realtime websocket push (008). A Visual
Compliance Loop governs the frontend phase."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add a card without leaving the board (Priority: P1)

As a board member, I can add a new card to the bottom of a list right from the board
canvas, and immediately add another, so I can capture work as fast as I think of it.

**Why this priority**: The entire feature is meaningless without a way to create the
cards everything else in this spec operates on. 003 shipped only seeded, read-only
cards — this is the first capability that lets a real user put their own work on a
board.

**Independent Test**: On any board the user is a member or admin of, click "+ Add a
card" on a list, type a title, and press Enter. Confirm the card appears at the bottom
of that list immediately, in a saved state (visible after reload), and the composer
stays open and ready for the next entry.

**Acceptance Scenarios**:

1. **Given** a list with existing cards, **When** I open the composer, type a title,
   and press Enter, **Then** a new card appears at the bottom of that list with that
   title, and the composer remains open and empty, ready for another entry.
2. **Given** the composer is open with text typed into it, **When** I press Escape,
   **Then** the composer closes without creating a card and the typed text is discarded.
3. **Given** I am an Observer on a board (view-and-comment only), **When** I look at a
   list, **Then** I have no way to open or use a card composer on it.

---

### User Story 2 - Open a card to see everything about it (Priority: P1)

As a board member, I can click any card — one seeded from 003 or one I just added — to
open a detail view showing its title, its location, its labels, its members, its
description, its checklist, and its full activity history in one place.

**Why this priority**: Every other story in this feature (editing title, description,
labels, members, due date, checklist, comments, copy, delete) happens inside this view.
Without it, none of those capabilities have anywhere to live.

**Independent Test**: Click any existing card (including one seeded by 003, before any
edits exist). Confirm a modal opens showing the card's title, its list and board name,
its due date if it has one, an (empty or populated) labels section, an (empty or
populated) members section, an (empty or populated) description, an (empty or
populated) checklist with a progress bar, an activity feed containing at minimum a
"card created" entry, a comment box, and an "Add to card" panel of actions. Confirm it
closes via its close button, a click outside it, or Escape, always returning to the
unchanged board underneath.

**Acceptance Scenarios**:

1. **Given** I am looking at a board, **When** I click a card, **Then** a modal opens
   showing that card's full detail without navigating away from the board.
2. **Given** the modal is open, **When** I click its close button, click outside it, or
   press Escape, **Then** it closes and I see the board exactly as it was before.
3. **Given** a card has never been edited since 003 seeded it, **When** I open it,
   **Then** its activity feed shows at least one entry recording its creation.

---

### User Story 3 - Edit a card's title and description (Priority: P1)

As a board member, I can rename a card and write or update its description from the
detail view, so the card accurately reflects the work it represents.

**Why this priority**: The most basic, most frequent edits to any card — needed before
labels, members, dates, or checklists are worth adding.

**Independent Test**: Open a card, change its title, confirm the board and the modal
header both reflect the new title. Separately, type a description and click Save;
confirm the card front now shows a description indicator, and reopening the modal shows
the saved text.

**Acceptance Scenarios**:

1. **Given** a card's detail view is open, **When** I edit its title and it saves,
   **Then** the modal header and the card's title on the board both show the new text.
2. **Given** a card has no description yet, **When** I type one and click Save,
   **Then** the card front gains a description indicator that wasn't there before.
3. **Given** a card already has a description, **When** I clear all of its text and
   click Save, **Then** the description is removed and the card front's description
   indicator disappears.
4. **Given** I am editing a card's description, **When** someone else's edit to the same
   card saves first, **Then** my Save is rejected with a clear "this was changed by
   someone else" outcome instead of silently overwriting their change.

---

### User Story 4 - Organize a card with labels and members (Priority: P1)

As a board member, I can attach one or more of the board's labels to a card, and assign
one or more people to it, so at a glance the board shows what kind of work it is and
who owns it.

**Why this priority**: Categorization and ownership are core to how a Kanban board
communicates status; both are simple multi-select actions on data 003 already renders
correctly (label chips, member avatars) once assigned.

**Independent Test**: Open a card with no labels or members. Assign an existing
board label; confirm the label chip appears on the card front immediately. Assign a
person who is already a board member; confirm their avatar appears on the card front.
Assign a person who is not yet on the board; confirm they become a board member as a
result and now appear in both places (card and board membership).

**Acceptance Scenarios**:

1. **Given** a card has no labels, **When** I assign one of the board's existing
   labels to it, **Then** that label's chip appears on the card front.
2. **Given** a card has a label assigned, **When** I remove it, **Then** the chip
   disappears from the card front.
3. **Given** a card has no members, **When** I assign an existing board member to it,
   **Then** their avatar appears on the card front.
4. **Given** I assign someone who is not yet a member of this board, **When** the
   assignment saves, **Then** they are added to the board (visible in the board's
   membership) and their avatar appears on the card.

---

### User Story 5 - Track a card's due date (Priority: P2)

As a board member, I can set, change, clear, or mark complete a card's due date, so the
board's existing color-coded urgency indicator (built in 003) reflects real deadlines
instead of only seeded ones.

**Why this priority**: Builds directly on 003's due-status display; without a way to set
a date, that indicator can only ever show seeded data.

**Independent Test**: Open a card with no due date; set one in the near future and
confirm the card front shows an amber "soon" badge (per 003's existing bucketing).
Change it to a past date and confirm the badge turns red ("overdue"). Mark it complete
and confirm the badge turns green ("complete"). Clear the due date and confirm the
badge disappears entirely.

**Acceptance Scenarios**:

1. **Given** a card has no due date, **When** I set one, **Then** the card front shows
   a due-date badge colored per 003's existing rule (grey future / amber soon / red
   overdue).
2. **Given** a card has an incomplete due date, **When** I mark it complete, **Then**
   its badge turns green regardless of how close or overdue the date is.
3. **Given** a card has a due date, **When** I clear it, **Then** the badge disappears
   from the card front entirely.

---

### User Story 6 - Break a card into checklist steps (Priority: P2)

As a board member, I can add checklist items to a card, tick them off as they're done,
and delete ones no longer needed, so the card front's progress indicator reflects real
sub-task completion instead of nothing.

**Why this priority**: A common, self-contained way teams track granular progress
inside a single card; independent of labels, members, or due dates.

**Independent Test**: Open a card with no checklist items; add three, tick one, and
confirm the card front shows a "1/3" progress indicator and a partially-filled progress
bar inside the modal. Delete one unticked item and confirm the total drops to 2.

**Acceptance Scenarios**:

1. **Given** a card has no checklist items, **When** I add one, **Then** the modal's
   checklist section shows it unticked, and the card front gains a "0/1" indicator.
2. **Given** a checklist item is unticked, **When** I tick it, **Then** the modal's
   progress bar and the card front's done/total indicator both update immediately.
3. **Given** a checklist item exists, **When** I delete it, **Then** it disappears from
   the modal and the card front's total count decreases accordingly.
4. **Given** every checklist item on a card is ticked, **When** I view the card front,
   **Then** its progress indicator shows the completed count equal to the total.

---

### User Story 7 - Discuss a card and see its history (Priority: P2)

As a board member, I can add a comment to a card and see every comment plus every other
change ever made to that card in one running activity feed, so the card carries its own
context instead of that context living in chat elsewhere.

**Why this priority**: Comments are a distinct, high-value action; the activity feed
also serves as the visible proof that every other story in this feature (title,
description, labels, members, due date, checklist) is actually being recorded, not just
displayed.

**Independent Test**: Open a card and add a comment; confirm it appears at the top of
the activity feed with the commenter's name and a timestamp, and the card front's
comment-count indicator increases by one. Separately, make any other edit covered by
this feature (e.g. set a due date) and confirm a corresponding entry appears in the same
feed.

**Acceptance Scenarios**:

1. **Given** a card's activity feed is open, **When** I submit a comment, **Then** it
   appears at the top of the feed with my name and a timestamp, and the card front's
   comment-count indicator increases by one.
2. **Given** I make any edit this feature supports (title, description, label, member,
   due date, checklist item), **When** I view the activity feed afterward, **Then** an
   entry describing that specific change is present, newest first.
3. **Given** I am an Observer on a board, **When** I open a card, **Then** I can add a
   comment but have no controls to make any other change to the card.

---

### User Story 8 - Duplicate or remove a card (Priority: P3)

As a board member, I can copy a card to quickly start a similar piece of work, or delete
a card that no longer needs to exist, so the board only shows what's actually relevant.

**Why this priority**: Useful but the least frequently used of this feature's actions,
and depends on a card already having interesting content worth copying or removing.

**Independent Test**: Open a card with a label, a member, and a due date. Copy it;
confirm a new card appears directly below the original in the same list, titled the
same with " (copy)" appended, carrying the same labels/members/due date, but with an
empty activity feed except for its own creation. Separately, delete a different card
with a confirmation prompt and confirm it no longer appears anywhere on the board.

**Acceptance Scenarios**:

1. **Given** a card with labels, members, and a due date, **When** I copy it, **Then** a
   new card appears immediately below it in the same list, with " (copy)" appended to
   the title, the same labels/members/due date, and its own activity feed starting
   fresh at "card created."
2. **Given** a card is open, **When** I choose to delete it, **Then** I am asked to
   confirm before it is removed from the board.
3. **Given** I confirm a card's deletion, **When** the board refreshes, **Then** that
   card no longer appears in its list, and its previous card count is reduced by one.

### Edge Cases

- What happens when two people edit the same field on the same card at nearly the same
  time? The second save to reach the system must be rejected with a clear conflict
  outcome and must never silently overwrite the first person's change (see Story 3,
  Acceptance Scenario 4) — this applies to every editable field this feature adds, not
  only description.
- What happens when someone opens a card that another person deletes moments later?
  Any further action from the still-open modal (edit, comment, copy) must fail with a
  clear "this card no longer exists" outcome rather than silently succeeding against
  nothing or corrupting board state.
- What happens when a card is copied? The copy is a new, independent card — deleting or
  editing the original afterward must never affect the copy, and vice versa.
- What happens when the last remaining checklist item on a card is deleted? The card
  front's checklist indicator disappears entirely (matching 003's "only what applies"
  rule), the same as a card that never had one.
- What happens when someone without edit permission (an Observer) is shown a card
  detail view? Every action except commenting is absent or disabled, never present but
  silently failing when used.
- What happens when a composer is left open with unsaved text and the user navigates
  away (e.g. clicks another list's composer, or closes the board)? The typed text is
  discarded — this feature does not add cross-navigation drafts.

## Visual Inventory *(mandatory when the feature has `screenshots/` — else delete this section)*

### Screenshot: `screenshots/card-detail-modal.png` — card detail modal, desktop viewport

Source: `docs/product/prototype/preview-card.png` (the prototype's own captured
preview, per `docs/product/prototype/README.md`), copied into this feature's
`screenshots/` folder since 003's spec explicitly reserved this capture for 004
(INV-007).

- **VI-001**: Modal header, left-to-right: a small board-glyph icon · the card title in
  bold, large text · a ✕ close button at the far right.
- **VI-002**: Directly beneath the header, a single muted breadcrumb-style line: "in
  list `<list name>` · board `<board name>` · due `<date>`" — the due date, when
  present, renders as a small pill/badge inline with the rest of the text rather than
  plain text.
- **VI-003**: Modal body is two columns (left wider than right); a translucent dark
  scrim covers the rest of the page behind it, dimming but not hiding the board.
- **VI-004**: Left column, "LABELS" section (small-caps gray header) followed by one
  colored, rounded chip per assigned label (e.g. a green "Feature" chip) — the section
  still renders (with its header) even before any label is assigned, per this feature's
  own Story 4.
- **VI-005**: Left column, "DESCRIPTION" section (small-caps gray header), a bordered
  multi-line textarea with placeholder text ("Add a more detailed description…") when
  empty, and a blue "Save" button beneath it, left-aligned.
- **VI-006**: Left column, "CHECKLIST" section (small-caps gray header), a thin
  horizontal progress bar (empty/gray when no items exist), "No checklist items yet."
  placeholder text when empty, and a text input ("Add an item…") with an adjacent "Add"
  button beneath it.
- **VI-007**: Left column, "ACTIVITY" section (small-caps gray header): the current
  user's avatar (colored circle, initials) beside a bordered textarea ("Write a
  comment…") with a blue "Comment" button beneath it, then the feed itself — each entry
  showing a small avatar, the actor's name, the action in plain text, and a relative
  timestamp (e.g. "Anas Matar created this card · 2 days ago"), newest first.
- **VI-008**: Right column, "ADD TO CARD" section (small-caps gray header) — a vertical
  stack of full-width, left-aligned buttons, each with a small icon: "Members,"
  "Labels," "Due date," "Move," "Copy," and "Delete" (rendered in a red/destructive
  tone, distinct from the others) — in that top-to-bottom order.
- **VI-009**: A due-date pill in the breadcrumb line (VI-002) uses the same
  grey/amber/red/green color rule already established for the card-front badge in 003
  — this capture shows the neutral/grey (future) state.

**Explicitly not part of this feature's Visual Inventory** (present in the capture but
out of scope): the "Move" action in the "ADD TO CARD" panel (VI-008) — real card
movement is 005-drag-drop-ordering's scope; this feature renders the button but it is
inert here (see Assumptions). The toast reading "Moved to 'In Progress'" at the bottom
of the capture is also 005's scope (it resulted from a drag, not from anything this
feature does) — but this feature's own mutations (Stories 1, 3–8) each need their own
toast per FR-014, this capture simply doesn't show one for those. The small "Prototype ·
drag cards & lists…" caption in the bottom-right is the prototype demo's own signage,
not a FlowBoard UI element.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST let a board admin or member add a new card to the bottom of
  any list on a board they have access to, via an inline composer that stays open and
  ready for another entry after each successful add.
- **FR-002**: System MUST let a board admin or member open any card (seeded or
  user-created) into a detail view showing its title, its list and board, its labels,
  its members, its due date if set, its description if set, its checklist if it has
  one, and its full activity history — closeable via an explicit close control, a click
  outside it, or the Escape key.
- **FR-003**: System MUST let a board admin or member rename a card from its detail
  view, reflecting the new title immediately on both the modal and the board.
- **FR-004**: System MUST let a board admin or member set, update, or clear a card's
  description via an explicit save action (not autosave), showing a description
  indicator on the card front only while a non-empty description exists.
- **FR-005**: System MUST let a board admin or member assign or remove any of the
  board's existing labels on a card, reflecting the change on the card front
  immediately.
- **FR-006**: System MUST let a board admin or member assign or remove members on a
  card from the board's current membership, reflecting the change on the card front
  immediately; assigning a person who is not yet a board member MUST add them to the
  board as part of that action.
- **FR-007**: System MUST let a board admin or member set, change, clear, or mark
  complete a card's due date, with the card front's existing due-status badge (grey
  future / amber soon / red overdue / green complete, from 003) reflecting the current
  value immediately and disappearing entirely when cleared.
- **FR-008**: System MUST let a board admin or member add, tick/untick, and delete
  checklist items on a card, with the card front's progress indicator and the modal's
  progress bar reflecting the current done/total count immediately.
- **FR-009**: System MUST let any board admin, member, or Observer add a comment to a
  card, appearing at the top of that card's activity feed with the author's name and a
  timestamp, and incrementing the card front's comment-count indicator.
- **FR-010**: System MUST record every mutation this feature makes (creation, rename,
  description change, label add/remove, member add/remove, due-date set/clear/complete,
  checklist item add/tick/untick/delete, comment) as its own entry in that card's
  activity feed, in newest-first order, and this record MUST never be edited or removed
  once written.
- **FR-011**: System MUST let a board admin or member copy a card, inserting the copy
  directly below the original in the same list with " (copy)" appended to its title,
  carrying over its labels, members, due date, description, and checklist items
  (unticked), while starting that copy's own activity feed fresh at its own creation.
- **FR-012**: System MUST let a board admin or member delete a card only after an
  explicit confirmation step, after which that card no longer appears anywhere on the
  board (soft-deleted and recoverable, consistent with this product's existing
  archive/restore convention).
- **FR-013**: System MUST detect a conflicting simultaneous edit to the same card field
  and reject the second save that reaches it with a clear "this was changed by someone
  else" outcome, never silently discarding either person's change.
- **FR-014**: System MUST confirm every mutating action this feature performs (add,
  rename, describe, label, assign, due-date change, checklist change, comment, copy,
  delete) with a brief on-screen confirmation, without requiring the user to reopen or
  refresh anything to see that it succeeded.
- **FR-015**: System MUST restrict every mutating action in this feature (add, rename,
  describe, label, assign, due-date change, checklist change, copy, delete) to board
  admins and members; an Observer MUST be able to view a card's full detail and add
  comments, and MUST have no way to perform any other action on it.
- **FR-016**: System MUST NOT provide any way, from this feature, to move a card by
  dragging or via the modal's "Move" action, or to reorder cards or lists — the "Move"
  control MUST still appear where the visual reference shows it (per FR-017), but MUST
  NOT perform a move.
- **FR-017**: Where the visual reference shows a control this feature does not
  implement (the "Move" action), the layout MUST still match the reference, but that
  control MUST NOT perform its action — consistent with how 003 handled its own
  non-functional controls.

### Key Entities

- **Card** *(extended from 003-board-view-readonly)*: gains real create, rename,
  describe, copy, and delete capability; its existing due-status badge computation and
  its already-modeled conflict-detection mechanism (both established in 003) are
  exercised for the first time by this feature's writes.
- **CardLabel / CardMember** *(join entities, already modeled in 003)*: gain real
  create/delete capability — assigning or removing a label or member on a card is now a
  user action instead of only seed data.
- **ChecklistItem** *(already modeled in 003, unused there)*: gains real create, toggle,
  and delete capability, plus the done/total aggregate the card front already knows how
  to display.
- **Comment** *(already modeled in 003, unused there)*: gains real create capability;
  comments are never edited or deleted once posted (matching the append-only activity
  convention).
- **ActivityEvent**: new to this feature. An append-only, per-card, timestamped record
  of every mutation type this feature performs, attributed to the user who performed
  it; the sole source of the activity feed the detail modal displays. Never edited or
  removed once written.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A board member can add a card and have it visible on the board in under 1
  second of pressing Enter, without the composer closing.
- **SC-002**: 100% of the mutation types this feature introduces (create, rename,
  describe, label, assign, due-date change, checklist change, comment, copy, delete)
  produce a corresponding, correctly-ordered entry in the affected card's activity feed
  — verified directly, with zero silent/unrecorded mutations.
- **SC-003**: Zero cases of one person's saved edit being silently overwritten by
  another person's concurrent edit to the same card field — every genuine conflict
  surfaces as a rejected save, never a silent loss.
- **SC-004**: 100% of this feature's mutating actions are unavailable to an Observer
  role, verified directly — commenting remains the sole exception.
- **SC-005**: A user performing any mutating action in this feature sees a confirming
  on-screen response within 200ms of that action completing.
- **SC-006**: A card copied by this feature always appears directly below its original
  in the same list, with the same labels/members/due date as the original at the moment
  of copying, and a demonstrably fresh (empty-until-now) activity feed.

## Assumptions

- **Visual reference source.** `screenshots/card-detail-modal.png` is a copy of the
  prototype's own `docs/product/prototype/preview-card.png`, not a fresh capture taken
  in this session — no browser automation was available at spec time. It is a genuine
  rung-1 reference and the Visual Compliance Loop runs against it normally. The
  prototype has no static screenshot of the card composer (C-01) mid-use; a live
  capture of that state directly from `flowboard-prototype.html` before or during
  implementation remains available and is a reasonable `plan.md`-time addition, not a
  blocker here (same approach 003 used for states its own single screenshot didn't
  cover).
- **"Move" stays visible but inert.** The reference shows a "Move" action in the
  detail modal's "Add to card" panel. Real card movement belongs to
  005-drag-drop-ordering, which needs the ordering/position model this feature does not
  build. Per FR-016/FR-017, the control is rendered but does nothing yet — the same
  non-functional-control pattern 003 established for controls outside its own scope.
- **Copy semantics.** FUNCTIONAL_SPEC.md's C-12 acceptance criterion only specifies that
  "activity resets"; it does not specify what happens to a checklist's checked state on
  the copy. This spec assumes checklist items carry over with their text but reset to
  unchecked (the copy represents starting that work again), while labels, members,
  description, and due date carry over unchanged. This is a reasonable default, not a
  business-critical decision, and can be revisited if it doesn't match user expectation
  after implementation.
- **Description save is explicit, not autosave.** Matches both the prototype
  (`preview-card.png` shows a distinct "Save" button) and FUNCTIONAL_SPEC.md C-05's own
  wording ("Saved explicitly with a Save button").
- **Permissions reuse 002's existing role matrix as-is.** No new role or permission
  concept is introduced; "board admin or member" and "Observer" are exactly the roles
  002-auth-workspaces and 003-board-view-readonly already established, applied here to
  a new set of actions.
- **Realtime is out of scope.** Other viewers of the same board see this feature's
  changes on their next fetch, not instantly. Instant, cross-client propagation is
  008-realtime-sync's scope; this feature only needs correct conflict handling for the
  person actually making the edit (FR-013), not live broadcast to others.
- **Toasts are new to this product.** X-01 has no prior implementation to extend (003's
  Visual Inventory explicitly excluded the toast it captured, since 003 has no
  mutations); this feature is where toast infrastructure is first built, per
  `docs/roadmap.md`'s decisions log.
