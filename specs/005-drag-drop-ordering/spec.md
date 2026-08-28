# Feature Specification: Drag & Drop Ordering

**Feature Branch**: `005-drag-drop-ordering`
**Created**: 2026-08-28
**Status**: Draft
**Input**: User description: "Card and list drag-and-drop with a keyboard-operable move
alternative, on top of 004's card lifecycle CRUD. Covers roadmap row 005 — story ids
C-02, C-11, L-03 from docs/product/FUNCTIONAL_SPEC.md, and INV-013 §5.1 (ordering
rules)." See `docs/roadmap.md` row `005-drag-drop-ordering` for scope framing.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reorder or move a card by dragging (Priority: P1)

A board member picks up a card and drops it somewhere else — either further up or down
the same list, or into a different list entirely — and the card stays exactly where they
dropped it the next time anyone looks at the board.

**Why this priority**: This is the single most central Kanban interaction (C-02) and the
whole reason the board exists as a visual tool rather than a plain list. Nothing else in
this feature matters if this doesn't work.

**Independent Test**: Can be fully tested by dragging a card to a new position within its
own list, and separately by dragging a card into a different list, then reloading the
board and confirming the card is exactly where it was dropped in both cases.

**Acceptance Scenarios**:

1. **Given** a list with three cards, **When** a member drags the first card to between
   the second and third, **Then** the card lands between them and stays there after a
   page reload.
2. **Given** two lists, **When** a member drags a card from the first list and drops it
   in the middle of the second list's cards, **Then** the card appears at that position
   in the second list, no longer appears in the first list, and the card's own activity
   feed gains a "moved this card from X to Y" entry.
3. **Given** a card reordered within the same list (no list change), **When** the drop
   completes, **Then** no activity entry is added for the reorder — only a move to a
   different list is logged.
4. **Given** a list already at or over its WIP limit, **When** a member drops another
   card into it, **Then** the drop still succeeds and the list's existing over-limit
   indicator updates — the limit is never enforced as a hard block.

---

### User Story 2 - Move a card via an accessible menu (Priority: P1)

A board member who can't or doesn't want to drag opens a card, uses the existing "Move"
button, picks a different list from a short list of choices, and the card moves there —
landing at the end of that list — without ever touching a mouse.

**Why this priority**: Ships together with User Story 1, not after it — every drag
interaction in this product needs a keyboard/menu equivalent (see the accessibility
non-functional requirement in `docs/product/FUNCTIONAL_SPEC.md` §8), and C-11 is that
equivalent for C-02. A drag-only release would leave keyboard users unable to move a
card at all.

**Independent Test**: Can be fully tested by opening a card's detail view with only a
keyboard, activating "Move", choosing a different list, and confirming the card now
appears at the end of that list with no mouse interaction at any point.

**Acceptance Scenarios**:

1. **Given** an open card currently in "Backlog", **When** a member activates "Move" and
   chooses "Design", **Then** the card moves to the end of the "Design" list and the
   card's activity feed gains the same "moved this card from Backlog to Design" entry a
   drag would have produced.
2. **Given** the "Move" menu is open, **When** the member chooses the list the card is
   already in, **Then** nothing happens — no move, no activity entry, no toast.
3. **Given** the "Move" menu is open, **When** the member presses Escape or clicks
   outside it, **Then** the menu closes and the card does not move.

---

### User Story 3 - Reorder lists by dragging (Priority: P2)

A board member drags an entire list column to a new place among the other lists, and
that new left-to-right order is what everyone sees on the board afterward.

**Why this priority**: Useful and expected (L-03), but a board is fully usable with
cards moving correctly (User Stories 1–2) even before lists can be reordered — this is
the lower-frequency of the two ordering interactions.

**Independent Test**: Can be fully tested by dragging one list column to a different
position among the others and confirming the new order survives a page reload.

**Acceptance Scenarios**:

1. **Given** a board with four lists, **When** a member drags the last list to the
   first position, **Then** it appears first for every viewer of that board afterward.
2. **Given** a list is dropped back into the same position it started in, **When** the
   drop completes, **Then** nothing changes — no reorder is recorded.

---

### Edge Cases

- What happens if two people move the same card, or reorder the same list, at nearly
  the same moment? The later write simply wins — moves never reject with a conflict
  error the way field edits (title, description, due date) do, because rejecting a drop
  the person just performed with their own hands is a worse experience than silently
  taking the more recent instruction.
- What happens when a card is dropped into an empty list? It becomes that list's only
  card; the list's own empty-state message disappears.
- What happens when the last card is dragged out of a list? The list falls back to its
  existing empty-state message.
- What happens when an Observer tries to drag a card or list, or open the "Move" menu?
  Nothing is draggable and the "Move" control is unavailable for that role — consistent
  with every other card control already gated this way in 004; the same restriction is
  enforced regardless of what the interface shows.
- What happens if a card is deleted or copied by someone else while a drag is in
  progress? The drop targets the list the dragging person can currently see; a
  since-deleted card simply has nothing to drop, which the interface already prevents by
  no longer rendering it.

## Visual Inventory *(mandatory when the feature has `screenshots/` — else delete this section)*

### Screenshot: `screenshots/board-canvas-dragging.jpg` — board mid-drag (card)

- **VI-001**: The card being dragged ("Research competitor onboarding flows" in
  Backlog) renders at visibly reduced opacity (faded, roughly 40% of normal) while still
  occupying its original position in its source list.
- **VI-002**: The list currently under the pointer ("Design") gains a dashed outline in
  the board's accent colour around its entire column, distinguishing it as the active
  drop target; no other list shows this outline at the same time.
- **VI-003**: Every other card and list on the board renders completely normally — the
  drag state is visually isolated to exactly the dragged card and the one hovered list.

### Screenshot: `screenshots/card-move-to-list-popup.jpg` — "Move" menu open

- **VI-004**: Clicking "Move" in the card detail view's right-hand panel opens a small
  popover titled "MOVE TO LIST", anchored directly below the "Move" button.
- **VI-005**: The popover lists every list on the board as a single plain-text row, top
  to bottom in the board's own list order — not a dropdown, not paginated.
- **VI-006**: The row matching the card's current list carries a checkmark to its right;
  no other row does.
- **VI-007**: Rows have no icon besides the list name itself; choosing a different row
  is the entire interaction — there is no secondary "confirm" step and no
  position-within-the-list choice.

### Screenshot: `screenshots/list-reorder-dragging.jpg` — board mid-drag (list)

- **VI-008**: The list being dragged ("Backlog") renders at the same reduced opacity as
  a dragged card, but applied to the entire column — header, cards, and footer all fade
  together as one unit.
- **VI-009**: The list under the pointer ("In Progress") shows the identical dashed
  drop-target outline used for card drags (VI-002), confirming both interactions share
  one visual language for "you are about to drop here."

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Board members and admins MUST be able to drag any card to a new position
  within its current list; the card MUST land at the dropped position, not always at the
  top or bottom.
- **FR-002**: Board members and admins MUST be able to drag any card into a different
  list on the same board, landing at the dropped position within that list.
- **FR-003**: A card move that changes which list a card is in MUST append exactly one
  "moved this card from X to Y" entry to that card's own activity feed (the same feed
  built in 004); a reorder that keeps the card in the same list MUST NOT append an
  activity entry.
- **FR-004**: The system MUST confirm a cross-list move with the same toast pattern
  already established for other card actions (e.g. "Moved to \"List Name\""); a
  same-list reorder needs no confirmation toast.
- **FR-005**: Board members and admins MUST be able to move a card into any other list
  on the same board using a keyboard-operable menu ("Move"), reachable and completable
  without a pointer device, producing the same end state (card at the end of the target
  list, one activity entry, one toast) as the equivalent drag would have.
- **FR-006**: Choosing the card's own current list from the "Move" menu MUST be a no-op —
  no move, no activity entry, no toast.
- **FR-007**: Board members and admins MUST be able to drag an entire list to a new
  position among the other lists on the same board; the new order MUST persist for every
  subsequent viewer of that board.
- **FR-008**: Dropping a list back into its original position MUST NOT record a change.
- **FR-009**: A card move or list reorder MUST NOT be blocked by a list's WIP limit,
  regardless of how far over that limit the destination list already is; the limit
  display alone (already built in 003/004) reflects the new count.
- **FR-010**: Card moves and list reorders MUST use last-write-wins conflict handling —
  a move always takes effect for the person performing it, never rejected because
  someone else moved the same card or reordered the same list a moment earlier.
- **FR-011**: Only board admins and board members may drag, reorder, or use the "Move"
  menu; an Observer MUST see no drag affordance and no usable "Move" control, and any
  attempt to move or reorder MUST be rejected server-side regardless of what the
  interface shows (matching 004's established permission pattern).
- **FR-012**: A card's or list's new order MUST be visible to every board member on
  their next view of the board; this feature does not need to push the change live to
  someone already looking at the board when the move happens (deferred to
  008-realtime-sync, matching 004's own precedent).

### Key Entities

- **Card**: unchanged shape from 004 — this feature is the first to give its ordering
  position a real, user-driven write path (previously only set once, at creation or
  copy time).
- **List**: unchanged shape from 003 — this feature is the first to give its ordering
  position a real, user-driven write path (previously fixed at seed time).
- **ActivityEvent**: reuses 004's append-only card activity trail; this feature is the
  first to write the "card moved" event type (already accounted for in the product's
  event vocabulary, alongside the event types 004 already uses).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A member can move a card to any position on the board — same list or a
  different one — in a single drag gesture, with the result visible immediately and
  unchanged after a page reload.
- **SC-002**: Every card move achievable by dragging is also achievable by keyboard
  alone, in no more steps than opening the card, activating "Move", and choosing a list.
- **SC-003**: Reordering a list is a single drag gesture with no additional confirmation
  step, and the new order is what every subsequent viewer of the board sees.
- **SC-004**: Two people moving the same card or the same list at nearly the same time
  never see an error — the interaction always completes for the person doing it.
- **SC-005**: An Observer account has no way, through the interface, to move a card or
  reorder a list, and a direct attempt to do so is refused.

## Assumptions

- The "Move" menu only offers a choice of destination *list*, landing the card at the
  end of it — not a specific position within that list — matching the prototype
  reference exactly (`docs/product/prototype/flowboard-prototype.html`'s own "Move to
  list" popover). A finer-grained keyboard-operable position picker is a reasonable
  future enhancement, not required here.
- The prototype's sample board includes a list named "Done" and a rule that auto-marks
  a card's due date complete when it's moved into a list whose name matches
  done/resolved/published/complete. No roadmap item, functional-spec story, or invariant
  documents this as a real requirement, and the actual seeded boards (003/004) have no
  such list — treated as a prototype-only flourish, explicitly excluded from this
  feature.
- Dragging is pointer-based (mouse or touch); no separate touch-specific interaction is
  designed beyond what standard browser drag-and-drop already provides.
- This feature does not add any new way to create, rename, archive, or delete a list —
  only to reposition one (006-board-list-management owns everything else about lists).
- No new realtime push is introduced; another viewer's board catches up to a move on
  their own next fetch, exactly as 004 already established for its mutations.
- The existing `If-Match`/`409` conflict pattern from 004's field edits does not apply to
  moves at all — moves have no concurrency precondition a client can fail, per
  `docs/product/FUNCTIONAL_SPEC.md` §7.1's own last-write-wins rule for moves.
