# Feature Specification: Realtime Sync & Concurrency

**Feature Branch**: `008-realtime-sync`
**Created**: 2026-08-30
**Status**: Draft
**Delivery Level**: **Critical** (`docs/sdlc/critical-delivery.md`) — this feature touches
domain invariants 1 (activity append-only/shape), 5 (server-side permission enforcement),
6 (optimistic concurrency), and 8 (opaque public identifiers) directly, and introduces a
new authentication mechanism (a short-lived, board-scoped realtime token) — two of the
addendum's explicit must-be-Critical triggers. The full addendum applies on top of the
standard workflow: rollback plan before Phase 1, domain-invariant review in both AI and
human review, audit evidence retained, human-executed gates only, independent (or
second-model adversarial, for a solo developer) approval.
**Input**: User description: "008-realtime-sync: Realtime sync layer for FlowBoard — a websocket (SignalR) channel that pushes live board updates (card moves, edits, list changes, comments) to all connected clients viewing a board, plus concurrency rules for conflicting simultaneous edits. Covers INV-015 (realtime part of the API surface) and INV-016 (Realtime & concurrency, FUNCTIONAL_SPEC.md §7.1). Builds on the already-shipped board view (003), card CRUD (004), drag/drop ordering (005), board/list management (006), and search/filter (007) — this feature adds live propagation of those mutations to other connected sessions and defines what happens when two users edit the same card/list/board concurrently."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See teammates' changes live (Priority: P1)

A board member has a board open while a teammate, on another device or browser tab, creates a
card, edits a card's fields, moves a card between lists, renames a list, or adds a comment. The
first member sees that change appear on their own screen without refreshing the page.

**Why this priority**: This is the entire point of the feature — every other rule in this spec
exists to make live propagation safe. Without it, FlowBoard is a polling app; the feature would
deliver zero value if this story alone shipped incorrectly.

**Independent Test**: Open the same board in two sessions signed in as two different board
members. Perform a card creation, a card field edit, a card move, a list rename, and a comment
in session A. Confirm each shows up in session B within the latency target, with no manual
refresh, and that history (the card's activity feed) records the identical event.

**Acceptance Scenarios**:

1. **Given** two members have the same board open, **When** member A creates a card, **Then**
   member B sees the new card appear in the correct list and position without reloading.
2. **Given** two members have the same board open, **When** member A moves a card to a different
   list, **Then** member B sees the card leave its old list and appear in the new list at the
   correct position.
3. **Given** two members have the same board open, **When** member A renames a list, edits a
   card's description, or adds a comment, **Then** member B sees the updated text appear live.
4. **Given** an observer (view-and-comment role) has the board open, **When** another member
   changes the board, **Then** the observer sees the same live update as a full member.
5. **Given** a member is viewing Board X only, **When** an unrelated change happens on Board Y,
   **Then** nothing changes on the member's screen — updates are scoped to the board being
   viewed.

---

### User Story 2 - Never silently lose a concurrent edit (Priority: P1)

Two board members edit the same card's fields (e.g., both open the description) at nearly the
same time. The system must not let the second save silently erase the first member's change; the
second member must be told their edit conflicted and be shown the current data before they can
try again. Two members moving the same card, or moving different cards within the same list, at
the same time must not corrupt the list's order.

**Why this priority**: Silent data loss during concurrent editing is the single worst outcome a
multi-user board can produce, and is the reason "concurrency rules" are called out explicitly in
this feature's scope. It ships alongside Story 1 as the other half of the same guarantee.

**Independent Test**: From two sessions, load the same card, change its description in both
without saving, save from session A first, then save from session B. Confirm session B's save is
rejected with a clear conflict signal and session B is shown A's saved content rather than
overwriting it. Separately, drag the same card from two sessions at once and confirm the card
ends up in exactly one, deterministic final position with no duplication or loss.

**Acceptance Scenarios**:

1. **Given** two members opened the same card, **When** member A saves a field edit first and
   member B then tries to save a conflicting edit made against the old version, **Then** member
   B's save is rejected, member B is shown the current (A's) version, and nothing is overwritten
   silently.
2. **Given** two members drag the same card at nearly the same time, **When** both moves are
   submitted, **Then** the card ends up in exactly one final list and position, determined by a
   consistent, documented rule — never split, duplicated, or lost.
3. **Given** member A is moving a card at the same moment member B edits a non-position field
   (e.g., description) on that same card, **When** both actions complete, **Then** the final card
   state includes both the new position and member B's field edit — one action does not erase the
   other.
4. **Given** a WIP limit is exceeded by concurrent drops from two sessions, **When** both drops
   land in the same list, **Then** both cards are accepted (WIP limits are advisory) and the
   over-limit indicator updates live for both sessions.

---

### User Story 3 - Recover cleanly after a dropped connection (Priority: P2)

A board member's live connection drops (network blip, laptop sleep, tab backgrounded) while
teammates keep changing the board. When the connection comes back, the member's view catches up
to the current state rather than staying frozen on stale data or silently missing changes.

**Why this priority**: Connections drop routinely in real usage; without recovery, Story 1's
guarantee quietly erodes over the course of a normal work session. It is not required for the
first demonstrable version of live sync, so it ranks below Stories 1–2.

**Independent Test**: Open a board, simulate a connection drop, make several changes from another
session while disconnected, then restore the connection. Confirm the recovering session ends up
showing the exact current board state with no missing or duplicated changes, and that the user is
given a visible signal while disconnected.

**Acceptance Scenarios**:

1. **Given** a member's live connection drops, **When** the drop occurs, **Then** the member sees
   a visible indicator that live updates are paused (not a silent failure).
2. **Given** a member was disconnected while other members changed the board, **When** the
   member's connection is restored, **Then** their view is refreshed to the current board state
   without requiring a manual page reload.
3. **Given** a member's connection is restored, **When** the catch-up completes, **Then** no
   event is applied twice and no in-flight event from before the drop is replayed out of order.

---

### User Story 4 - Board stays usable if live updates aren't available (Priority: P3)

A board member is on a network or in an environment where the live channel cannot be established
at all (e.g., a restrictive proxy). The board must still be usable — the member can still see and
act on current data — just without instant propagation of others' changes.

**Why this priority**: A hard dependency on the live channel would regress the read-only and CRUD
behavior already shipped in earlier features for a subset of users; this is a safety net, not the
core value, so it is lowest priority.

**Independent Test**: Block the live channel for one session while leaving normal page loads and
API calls working. Confirm the board still loads, all existing CRUD/search/filter features from
003–007 still work, and the member can manually refresh to see others' changes.

**Acceptance Scenarios**:

1. **Given** the live channel cannot be established, **When** the member opens a board, **Then**
   the board still loads and is fully usable via the features already shipped in 003–007.
2. **Given** the live channel is unavailable, **When** the member wants the latest state, **Then**
   a manual refresh reflects current data (no live updates are silently claimed to be working).

---

### Edge Cases

- A member is removed from a board (or the board is archived/deleted) while they are actively
  viewing it: live updates for that board MUST stop reaching them, consistent with permissions
  being enforced server-side, not just hidden in the UI.
- A burst of many rapid changes (e.g., someone dragging several cards in quick succession, or a
  bulk archive) MUST NOT flood a viewer's screen with flicker or visibly lag the UI — updates
  still converge to the correct final state.
- A card is archived by one member at the same moment another member is editing one of its
  fields: the edit attempt MUST fail safely (conflict or "no longer available") rather than
  resurrecting or corrupting an archived card.
- A list is archived (which archives its cards, per existing invariant) while another member is
  mid-drag on one of those cards: the drag MUST resolve safely and MUST NOT leave the card in two
  places or in a deleted list.
- The same user has the same board open in two tabs/devices at once: both surfaces MUST converge
  to the same state; a change made in one MUST appear in the other exactly like a change made by
  a different person.
- Comments added concurrently by two different members on the same card MUST both be preserved in
  the order they were actually committed — never lost, never merged into one.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST push card, list, board, and comment changes to every other currently
  connected client viewing the same board, without requiring that client to manually refresh.
- **FR-002**: Live updates MUST be scoped per board — a client viewing one board MUST NOT receive
  updates from a board it is not currently viewing.
- **FR-003**: The event delivered live for a given change MUST carry the same shape and meaning
  as the corresponding stored activity event, so a board's live view and its audit history never
  diverge (per existing invariant: activity is append-only and realtime must not diverge from it).
- **FR-004**: System MUST NOT allow a field edit to silently overwrite another member's
  more-recent field edit on the same card; the losing save MUST be rejected and the member MUST
  be shown the current data rather than having their stale write applied.
- **FR-005**: Concurrent moves of the same card MUST resolve to exactly one deterministic final
  position (last-write-wins on the card's list and position, per existing invariant) — never a
  duplicated, split, or lost card.
- **FR-006**: A card move MUST NOT discard a concurrent field edit on that same card, and a field
  edit MUST NOT revert a concurrent move on that same card — both outcomes must be reflected in
  the final state.
- **FR-007**: System MUST stop delivering board updates to a client as soon as that user's access
  to the board ends (removed as member, board archived or deleted), matching the existing
  server-side permission enforcement rule.
- **FR-008**: A client whose live connection drops and later reconnects MUST have its board view
  brought back into agreement with the current server state, with no event applied twice and no
  missed change left unreflected.
- **FR-009**: System MUST give the member a visible signal when their live connection is down,
  rather than silently showing a view that looks current but is not.
- **FR-010**: Live events MUST expose only opaque public identifiers, matching the rule already
  in force for the REST API — internal identifiers must never appear on the wire.
- **FR-011**: Observers (view-and-comment role) MUST receive the same live updates as full board
  members; the live channel MUST NOT let an observer trigger a mutation they are not permitted to
  make under the existing capability matrix.
- **FR-012**: If a client cannot establish a live connection at all, the board MUST remain fully
  usable through the already-shipped view, CRUD, drag-drop, board/list management, and
  search/filter behavior — live sync is additive, not a hard dependency for basic usability.
- **FR-013**: A burst of many changes in quick succession MUST still converge every connected
  client to the correct final board state, without the update stream itself causing visible UI
  lag or corruption.
- **FR-014**: WIP limits MUST remain advisory under concurrent drops — simultaneous moves that
  push a list over its limit MUST all be accepted, with only the visual over-limit signal
  affected (per existing invariant).

### Key Entities

- **Live update / realtime event**: The message delivered to connected clients for a board
  change. Same shape as the stored activity event for that change (card created/moved/renamed/
  described, label added/removed, member assigned/unassigned, due set/cleared/completed,
  checklist item added/checked, comment added, card archived), scoped to the board it belongs to,
  and addressed only by opaque public identifiers.
- **Connection state**: Whether a given client currently has a working live channel to a given
  board. Drives whether the member sees the "live" indicator or the "reconnecting/offline"
  indicator from Story 3.
- **Edit conflict**: The transient outcome when a field-edit save is rejected because the data it
  was based on is no longer current. Not persisted — represented only as the rejection returned
  to the losing save and the refreshed data shown in its place.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A change made by one board member is visible on another connected member's screen
  in under 500 ms at the 95th percentile (existing non-functional target).
- **SC-002**: In concurrent-edit testing, 0% of conflicting field-edit saves result in a silently
  lost change — every losing save is either rejected with current data shown, or its content is
  preserved in the final state.
- **SC-003**: In concurrent-move testing, 100% of simultaneous card moves converge to exactly one
  final position with no duplicated or missing cards across any connected session.
- **SC-004**: After a simulated connection drop of up to 60 seconds during which other members
  make changes, a reconnecting client's board matches the current server state within one
  refresh cycle, with zero duplicated or missing events.
- **SC-005**: A board remains fully readable and actionable (create, edit, move, comment, search,
  filter) for a client that never successfully establishes a live connection.

## Assumptions

- Live propagation applies to the mutation surface already shipped in 003–007 (board/list/card
  CRUD, drag-drop ordering, board/list management, search/filter) — this feature adds delivery
  and conflict handling for those existing mutations; it does not introduce new mutation types.
- The concurrency rules are exactly those already fixed by the functional spec and domain
  invariants: last-write-wins on card position with an update-time precondition, and
  optimistic-concurrency (reject-and-refetch) on field edits. This feature specifies the
  observable behavior of those rules under the live channel; it does not renegotiate them.
- "Currently viewing a board" means the client has that board open in the application; switching
  boards or navigating away stops that client's updates for the board left behind (FR-002).
- No new user-facing presence indicator (e.g., "who else is looking at this board right now") is
  in scope — the functional spec's top-bar avatars remain static membership display, not live
  presence. If product wants live presence, it is a follow-up feature.
- Reconnection recovery (Story 3) is satisfied by bringing the client back to current server
  state; it does not require replaying every intermediate event the client missed, only that the
  end result is correct and complete.
- Rate/volume assumptions match the existing non-functional targets (board with 20 lists /
  1,000 cards); this feature does not introduce new scale requirements beyond keeping that board
  responsive while live updates are flowing.
