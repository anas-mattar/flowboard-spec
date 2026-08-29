# Feature Specification: Board & List Management

**Feature Branch**: `006-board-list-management`
**Created**: 2026-08-30
**Status**: Draft
**Input**: User description: "Board and list management: create a board with three default
lists (To Do, Doing, Done) and the creator as admin; rename a board inline; star a board so
starred boards sort to the top of the sidebar; archive or delete a board (deletion requires
confirmation, archived boards are hidden but restorable for 30 days); add a list to the
right of existing lists; rename a list inline; set an advisory WIP limit on a list (card
counter shows count/limit, turns red when exceeded, never blocks a drop); sort a list by due
date ascending with no-date cards last; archive all cards in a list or delete the list
(deleting a list archives its cards)." Covers roadmap row 006 — story ids B-02, B-03, B-04,
B-06, L-01, L-02, L-04, L-05, L-06 from `docs/product/FUNCTIONAL_SPEC.md`. See
`docs/roadmap.md` row `006-board-list-management` for scope framing.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a board (Priority: P1)

Any member creates a new board, by name, for a new piece of work, and lands on a
ready-to-use board with three starter lists already in place. Every member already owns
their own workspace (created automatically when they joined), so this is available to
everyone, not a privileged action.

**Why this priority**: Every board used by 003–005 so far was seeded, never created through
the product itself. Nothing else in this feature — or in the product's own growth beyond a
handful of demo boards — matters until a real workspace member can make their own board.

**Independent Test**: Can be fully tested by creating a board with a given name and
confirming it appears in the sidebar, becomes the active board, and shows exactly three
lists — "To Do", "Doing", "Done" — all empty.

**Acceptance Scenarios**:

1. **Given** a workspace member on any board, **When** they create a new board named
   "Q4 Planning", **Then** "Q4 Planning" appears in the sidebar, becomes the active board,
   and shows three empty lists in order: "To Do", "Doing", "Done".
2. **Given** a board was just created, **When** its creator opens the board's member list,
   **Then** the creator is listed as that board's Board Admin.

---

### User Story 2 - Add a list to a board (Priority: P1)

A board admin or member adds a new, empty list to the right of a board's existing lists so
there's somewhere new to put cards.

**Why this priority**: Ships alongside board creation — a three-list starter board is still
a fixed shape until lists themselves can be added. This is the first feature where a list is
created by a person rather than fixed at board-creation or seed time.

**Independent Test**: Can be fully tested by adding a list to a board with existing lists
and confirming the new list renders at the rightmost position, empty, and immediately
accepts a card.

**Acceptance Scenarios**:

1. **Given** a board with three lists, **When** a member adds a list named "Blocked",
   **Then** "Blocked" appears as the fourth (rightmost) list, empty, with no WIP limit.
2. **Given** a newly added list, **When** the member adds a card to it right away,
   **Then** the card is accepted with no separate save step for the list itself.

---

### User Story 3 - Rename a board inline (Priority: P2)

A board admin edits the board's title directly in the header, and the new name is what
everyone sees from then on.

**Why this priority**: A board is fully usable under whatever name it was created with;
renaming is a correction, not a blocker to any other capability in this feature.

**Independent Test**: Can be fully tested by editing a board's title in its header, moving
focus away (or pressing Enter), and confirming both the header and the sidebar show the new
name.

**Acceptance Scenarios**:

1. **Given** a board titled "Marketing Launch", **When** a board admin edits the header
   title to "Marketing Launch Q4" and blurs the field, **Then** the board's title updates
   everywhere it's shown, including the sidebar.
2. **Given** the title field is focused, **When** the admin clears it entirely and blurs
   the field, **Then** the board keeps its previous name rather than being renamed to
   nothing.

---

### User Story 4 - Rename a list inline (Priority: P2)

A board admin or member edits a list's title directly in its header, in place.

**Why this priority**: Same shape as board renaming, one tier lower — useful, not blocking,
and reuses list infrastructure list creation (User Story 2) already needs.

**Independent Test**: Can be fully tested by editing a list's title in its header and
confirming the change persists after a page reload.

**Acceptance Scenarios**:

1. **Given** a list titled "Doing", **When** a member edits its header title to "In
   Progress" and blurs the field, **Then** the list shows "In Progress" for every
   subsequent viewer of the board.

---

### User Story 5 - Star a board (Priority: P2)

A board admin or member stars a board they want to find quickly, and it sorts to the top of
the sidebar's board list.

**Why this priority**: A quality-of-life affordance for workspaces with more than a couple
of boards; no other capability in this feature depends on it.

**Independent Test**: Can be fully tested by starring a board that isn't already first in
the sidebar and confirming it moves to the top; unstarring it returns it to its normal
position.

**Acceptance Scenarios**:

1. **Given** a sidebar with three unstarred boards, **When** a member stars the third one,
   **Then** it moves to the top of the sidebar's board list.
2. **Given** a board is already starred, **When** the same or a different member unstars
   it, **Then** it returns to its normal (non-starred) sort position for every viewer.

---

### User Story 6 - Set a WIP limit on a list (Priority: P2)

A board admin or member sets a soft cap on how many cards a list should hold, and the
list's card counter reflects it — turning red the moment the list goes over, without ever
stopping a card from landing there.

**Why this priority**: The WIP counter itself has been visible since 003; this is the first
feature to give it a real, user-driven value instead of a fixed seeded number.

**Independent Test**: Can be fully tested by setting a WIP limit lower than a list's current
card count and confirming the counter immediately turns red, then dropping another card
into that list and confirming the drop still succeeds.

**Acceptance Scenarios**:

1. **Given** a list with 2 cards and no WIP limit, **When** a member sets its WIP limit to
   2, **Then** the counter reads "2/2" in its normal (non-over) style.
2. **Given** a list already at "2/2", **When** a card is added or moved into it, **Then**
   the card is accepted and the counter updates to "3/2" in its over-limit red style.
3. **Given** a list with a WIP limit set, **When** a member clears the limit back to none,
   **Then** the counter reverts to a plain card count with no "/N" suffix and no red style
   regardless of how many cards the list holds.

---

### User Story 7 - Archive or delete a board (Priority: P3)

A board admin removes a board that's no longer needed — either kind of removal hides it
from every member's sidebar, and it's the account's own decision whether to describe that
to themselves as "archiving" or "deleting" the board, since either one leaves it recoverable.

**Why this priority**: Cleanup is the least time-critical of this feature's capabilities —
a workspace works fine with boards nobody ever removes.

**Independent Test**: Can be fully tested by deleting a board through a confirmation step
and confirming it no longer appears in any member's sidebar afterward.

**Acceptance Scenarios**:

1. **Given** a board a board admin no longer needs, **When** they choose to delete it and
   confirm the destructive-action prompt, **Then** the board disappears from the sidebar
   for every member of that board.
2. **Given** the delete confirmation prompt is open, **When** the admin dismisses it
   without confirming, **Then** the board is untouched.

---

### User Story 8 - Archive all cards in a list, or delete the list (Priority: P3)

A board admin or member clears out a list's cards in bulk, or removes the list itself
entirely — either way after confirming, since both are hard to undo by accident.

**Why this priority**: A cleanup action, same tier as board deletion, and independent of
every other story here.

**Independent Test**: Can be fully tested by archiving all cards in a list (list remains,
cards gone) and, separately, by deleting a list outright (list and its cards both gone from
the board, cards still resolvable in their archived state).

**Acceptance Scenarios**:

1. **Given** a list with cards, **When** a member archives all its cards and confirms,
   **Then** the list remains on the board, now empty.
2. **Given** a list with cards, **When** a member deletes the list and confirms, **Then**
   the list no longer appears on the board and its cards are archived, not visible on the
   board, but still intact wherever an archived card can be resolved (e.g. existing
   comments or activity referencing one).

---

### User Story 9 - Sort a list by due date (Priority: P3)

A board admin or member reorders a list's cards by due date in one action, soonest first,
undated cards trailing at the end.

**Why this priority**: A convenience on top of manual drag-reordering (005); nothing else
depends on it.

**Independent Test**: Can be fully tested by triggering the sort on a list with a mix of
due and undated cards and confirming the resulting top-to-bottom order.

**Acceptance Scenarios**:

1. **Given** a list with cards due on the 5th, the 12th, and no date at all, **When** a
   member sorts the list by due date, **Then** the cards end up ordered 5th, 12th, then the
   undated card last.
2. **Given** a list already sorted by due date, **When** the member triggers the sort
   again with no cards changed, **Then** the order is unchanged.

---

### Edge Cases

- What happens when a board member (not a board admin) tries to rename, archive, or delete
  a board? It's rejected server-side and the interface offers no control for it — renaming,
  archiving, and deleting a board are Board Admin (and workspace admin) actions only, unlike
  every list- and card-level mutation in this feature and in 004/005, which board members
  can also perform.
- What happens when an Observer attempts any mutation in this feature — creating or
  renaming a board or list, starring, setting a WIP limit, sorting, archiving, or deleting?
  Nothing is available in the interface for that role, and a direct attempt is rejected
  server-side, consistent with every other feature's Observer restriction.
- What happens when the board a member is currently viewing gets archived or deleted by
  someone else while they're looking at it? Their next action against that board is
  rejected the same way any other now-inaccessible board would be; this feature does not
  add a live "this board was just removed" push (deferred to 008-realtime-sync, matching
  004/005's own precedent).
- What happens if the last remaining board in a workspace is deleted? The sidebar shows no
  boards and only the "create a board" affordance — the same empty state a brand-new
  workspace would show before its first board exists.
- What happens when "Archive all cards" is triggered on a list that's already empty? It
  succeeds as a no-op — the confirmation step still appears for consistency, but nothing
  visibly changes.
- What happens when a list is deleted? Its cards are archived, not deleted, and remain
  intact wherever something already references them (comments, checklist items, activity
  entries) — this is the same archive contract 004 already established for a single
  deleted card, applied here to every card a deleted list was holding.
- What happens if two board admins rename or delete the same board at nearly the same
  moment, or two members rename the same list? These are field edits, not moves — they use
  the same optimistic concurrency (a stale edit is rejected with a clear conflict, never
  silently overwritten) that 004 already established for card fields, not the last-write-
  wins rule 005 established for drags.
- What happens when a board or list name is submitted empty or all-whitespace? The rename
  or creation is rejected and the previous name (for a rename) is kept, or the creation
  simply doesn't happen (for a new board or list) — the member stays in the naming step to
  correct it.

## Visual Inventory *(mandatory when the feature has `screenshots/` — else delete this section)*

### Screenshot: `screenshots/sidebar-boards-list.jpg` — sidebar, default state

- **VI-001**: Under a "BOARDS" section label, the sidebar lists every board the member
  belongs to top to bottom, each row showing a small colored square (the board's own
  color), the board name, and a card count on the row's right edge.
- **VI-002**: The active board's row is filled with a solid accent-blue background spanning
  the row's full width; every other row is plain text on the sidebar's own dark background.
- **VI-003**: Below the last board row, a "+ Create board" row renders in the same list,
  visually distinct from the board rows above it (muted color, no swatch, no count).
- **VI-004**: In the top bar, a small outline star (☆) sits immediately to the right of the
  active board's title text; it renders as a solid star (★) instead when that board is
  starred. This star lives in the top bar next to the title, not on the sidebar's own board
  rows.

### Screenshot: `screenshots/list-actions-menu.jpg` — list "⋯" menu open

- **VI-005**: Clicking the "⋯" control at the right end of a list's header opens a popover
  titled "LIST ACTIONS", anchored directly below that list's header and left-aligned to it.
- **VI-006**: The popover holds exactly four rows, top to bottom: "Set WIP limit" (showing
  a "(now N)" suffix only when a limit is already set), "Sort by due date", "Archive all
  cards", "Delete list" — each row carries a small leading icon matching its action.
- **VI-007**: The "Delete list" row renders in a distinct red/destructive text color; the
  other three rows render in the popover's ordinary text color.

### Screenshot: `screenshots/list-wip-over-limit.jpg` — list header, WIP limit exceeded

- **VI-008**: A list's card-count badge, top-right of its header, switches from its normal
  neutral pill style (gray text and background, plain "count/limit") to a red/pink pill
  (red bold text, light pink-red background) the instant the card count exceeds the WIP
  limit — shown here as "4/3" in the over-limit style, contrasted against a neighboring
  list's normal "2/3".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Any authenticated member MUST be able to create a new board, in their own
  workspace, by supplying a name; the new board is created with exactly three lists —
  "To Do", "Doing", "Done", in that order, all empty — and the creator becomes the new
  board's Board Admin. A board is always created in the creator's own workspace; there is
  no way to create a board directly inside a workspace owned by someone else.
- **FR-002**: A newly created board MUST appear immediately in its creator's sidebar and
  become the active board, with no separate step to view it.
- **FR-003**: Board admins and board members (not Observers) MUST be able to add a new,
  empty list with no WIP limit to the right of a board's existing lists by supplying a
  name.
- **FR-004**: Board admins (and workspace admins) — but not plain board members or
  Observers — MUST be able to rename a board by editing its title inline in the board
  header; the new name MUST persist and appear everywhere the board's name is shown,
  including the sidebar.
- **FR-005**: Board admins and board members (not Observers) MUST be able to rename a list
  by editing its title inline in its header; the new name MUST persist for every subsequent
  viewer of the board.
- **FR-006**: Submitting an empty or all-whitespace name for a board rename, list rename,
  board creation, or list creation MUST be rejected without changing the existing name or
  creating anything.
- **FR-007**: Board admins and board members (not Observers) MUST be able to star or
  unstar a board; a starred board MUST sort above every unstarred board in the sidebar for
  every member who can see that board — starring is a shared property of the board, not a
  personal-only bookmark.
- **FR-008**: Board admins and board members (not Observers) MUST be able to set a list's
  WIP limit to any non-negative number, or clear it back to none; the list's card-count
  badge MUST reflect the new limit immediately.
- **FR-009**: A list's card-count badge MUST switch to a distinct over-limit visual style
  the moment its card count exceeds its WIP limit (matching 003/004/005's existing display
  rule), and MUST switch back the moment the count is at or under the limit again; a WIP
  limit MUST NEVER block a card from being created in, or moved into, that list.
- **FR-010**: Board admins (and workspace admins) — but not plain board members or
  Observers — MUST be able to archive or delete a board only after an explicit confirmation
  step; either action MUST remove the board from every member's sidebar and MUST NOT
  physically delete any of its data (soft-delete/archive, restorable for at least 30 days,
  per this product's existing archive/restore convention).
- **FR-011**: Board admins and board members (not Observers) MUST be able to archive every
  card in a list in one action, after an explicit confirmation step; the list itself MUST
  remain on the board, now empty.
- **FR-012**: Board admins and board members (not Observers) MUST be able to delete a list
  only after an explicit confirmation step; deleting a list MUST archive every card it held
  (never delete them outright) and MUST remove the list from the board.
- **FR-013**: Board admins and board members (not Observers) MUST be able to sort a list's
  cards by due date ascending, with cards that have no due date placed after every dated
  card, in a single action; this is a one-time reordering, not a persistent mode — a card
  added afterward is not automatically re-sorted.
- **FR-014**: Board and list rename edits MUST use the same optimistic concurrency already
  established for card field edits (a stale edit is rejected with a clear conflict, never
  silently overwritten) — this is a field edit, not a move, so last-write-wins does not
  apply here.
- **FR-015**: Every mutation in this feature MUST be rejected server-side for a role the
  permission rule above excludes, regardless of what the interface shows or hides for that
  role (matching 004/005's established enforcement pattern).
- **FR-016**: Every mutating action in this feature MUST confirm with the same toast
  pattern already established for other actions (e.g. "Board renamed", "List added", "WIP
  limit updated", "Sorted by due date", "Cards archived", "List deleted", "Board deleted").

### Key Entities

- **Board**: previously created only at seed time (001–005); this feature is the first to
  give it real, user-driven create, rename, star, and archive/delete write paths. Gains a
  shared `starred` flag and the standard soft-delete/archive fields already used elsewhere
  in the product (constitution VI).
- **List**: previously created only at board-creation or seed time; this feature is the
  first to give it real, user-driven create, rename, WIP-limit, sort, and archive/delete
  write paths (005 already gave it a user-driven position/reorder write path).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A workspace member can go from "no board for this work" to a usable
  three-list board in a single creation step.
- **SC-002**: A member can add a new, immediately usable list to any board in a single
  step, with no separate save action.
- **SC-003**: Renaming a board or a list is a single inline edit with no dialog, and the
  new name is what every subsequent viewer of the board sees.
- **SC-004**: Every list showing a WIP limit visibly signals when it's over capacity, and
  this signal never blocks a card from being created in or moved into that list.
- **SC-005**: Deleting a list or a board never loses data — every card involved remains
  resolvable in its archived state afterward, and the removal itself is recoverable for at
  least 30 days.
- **SC-006**: An Observer account has no way, through the interface, to create, rename,
  star, archive, or delete a board or a list, or to set a WIP limit or trigger a sort — a
  direct attempt at any of these is refused.
- **SC-007**: A plain board member (not a board admin) has no way, through the interface,
  to rename, archive, or delete a board — a direct attempt is refused, even though the same
  member can freely create, rename, and delete lists on that same board.

## Assumptions

- Every user is given their own workspace automatically at registration (002's `AuthService`
  — one owned `Workspace` per `User`, no separate "join a workspace" step exists). A user
  who is also a `BoardMember` on someone else's board (a different workspace's board) does
  not thereby gain any standing in *that* workspace — they still only ever create boards in
  their own. This means "any workspace member can create a board" (B-02) needs no
  eligibility check at all beyond normal authentication: every registered user already owns
  a workspace, so the capability is universal, not gated.
- Starring is a **shared** property of the board, not a personal per-viewer bookmark — one
  member starring a board changes sort order for every other member who can see it. This
  isn't a guess: `flowboard-api`'s existing `Board` entity already carries a plain `bool
  Starred` column (added by 003, unused until now — its own comment already names this
  feature as the one that sets it), so the shared-column shape is already load-bearing, not
  an open design choice this feature could still make the other way.
- Board rename/archive/delete is scoped to Board Admin (and workspace admin) only, per
  `FUNCTIONAL_SPEC.md` §6's permission table — narrower than the "admin or member" gate
  (`canMutate`) 004/005 established for card and list mutations. This feature introduces a
  second, stricter permission check alongside the existing one; the two MUST NOT be
  conflated in implementation.
- The prototype's own "Create board" and "Add list" interactions use the browser's native
  `prompt()`, and "Set WIP limit" uses a native `prompt()` as well — treated as prototype-
  only implementation shortcuts (matching 005's own precedent for excluding a prototype
  flourish), not literal UI requirements. The real implementation uses inline, in-app input
  matching this product's own established composer/dialog conventions (004), never a native
  browser dialog.
- Deleting a board has no dedicated "restore" UI in this feature, mirroring 004's own
  precedent for card deletion: the soft-delete/30-day-restorable contract is a data
  guarantee (constitution VI, invariant 4), not a self-service recovery screen that must
  ship alongside it.
- "Sort by due date" rewrites the `position` of every card in that list once, at the moment
  it's triggered (an ordinary write to the same ordering field 005 already established),
  rather than introducing a persistent "sort mode" flag on the list.
- No new realtime push is introduced; another viewer's board or sidebar catches up to any
  change in this feature on their own next fetch, exactly as 004 and 005 already
  established (deferred to 008-realtime-sync).
