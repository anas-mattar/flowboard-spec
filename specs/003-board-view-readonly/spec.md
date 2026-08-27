# Feature Specification: Board View (Read-Only)

**Feature Branch**: `003-board-view-readonly`
**Created**: 2026-08-28
**Status**: Draft
**Input**: User description: "Render seeded boards in a read-only view — sidebar (boards
list, collapse), top bar (title, avatars, theme toggle), board canvas with lists and
cards rendered from seeded data, card front (labels, badges, avatars). Covers roadmap
Inv INV-001...006 (render-only), story B-01, and cross-cutting X-02 (theme), X-03
(keyboard), X-04 (sidebar collapse). Builds on 002-auth-workspaces: only boards the
signed-in user has access to are visible, enforced server-side. No board/list/card
creation or editing, no drag-and-drop, no search/filter execution, no card detail modal
— those belong to 004 (cards, incl. detail modal), 005 (drag-drop), 006 (board/list
management), and 007 (search/filter)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View my boards and open one (Priority: P1)

As a signed-in member, I can see every board I have access to listed in a sidebar, and
open one to see its actual lists and cards, so I can find and review my team's work
without asking anyone where it lives.

**Why this priority**: This is the entire value of the feature — without it, nothing
built in 002 (accounts, workspaces, board membership) has anywhere to show its result.
Every later board feature (cards, drag-drop, search) is built on top of this view.

**Independent Test**: Sign in as a user with access to at least one board (owner or
invited member/admin/observer). Confirm the sidebar lists exactly the boards that user
has access to, and that opening one renders its lists (in stored order) and each list's
cards (in stored order) with their existing details — with no ability to create, edit,
reorder, or delete anything.

**Acceptance Scenarios**:

1. **Given** I am signed in and have access to two boards, **When** I land on the app,
   **Then** I see both boards listed in the sidebar, each showing its name and total
   card count, and the currently open board (if any) is visually highlighted.
2. **Given** I click a board I have access to, **When** it loads, **Then** I see its
   lists left-to-right in their existing order, each showing its name, its card count,
   and its cards top-to-bottom in their existing order.
3. **Given** a card has labels, a due date, a description, a checklist, comments, and/or
   assigned members, **When** I view the board, **Then** the card front shows exactly
   the indicators that apply to it (label chips, due-date badge, description marker,
   checklist progress, comment count, member avatars) and nothing for what doesn't apply.
4. **Given** I attempt to open a board by its URL that I do not have access to, **When**
   the page loads, **Then** I am shown the same access-denied outcome as any other
   protected board page in this product — never the board's actual content.

---

### User Story 2 - Switch between light and dark theme while browsing boards (Priority: P2)

As a signed-in member, I can switch the whole application between light and dark theme
while looking at my boards, so I can read comfortably in my preferred environment.

**Why this priority**: A real preference already supported by the app shell (001); this
story only confirms it keeps working once real board content exists to look at.

**Independent Test**: With a board open, toggle the theme control and confirm every
visible element (sidebar, top bar, board canvas, lists, cards) re-renders in the new
theme immediately, with no unstyled or stuck-in-the-old-theme element.

**Acceptance Scenarios**:

1. **Given** I am viewing a board in light theme, **When** I toggle to dark theme,
   **Then** the sidebar, top bar, and every list and card on the canvas switch to dark
   theme immediately, with no page reload.
2. **Given** I switch theme and later return to the app, **When** it loads, **Then** my
   last chosen theme is still applied.

---

### User Story 3 - Collapse the sidebar for more board space (Priority: P2)

As a signed-in member, I can collapse the sidebar while viewing a board, so the board
canvas gets more horizontal room to show my lists.

**Why this priority**: Directly useful the moment there's real board content to make
room for; independent of theme and of which board is open.

**Independent Test**: With a board open, collapse the sidebar and confirm the board
canvas immediately expands to use the freed width; expand it again and confirm the
canvas shrinks back and the sidebar's board list is unchanged by the round trip.

**Acceptance Scenarios**:

1. **Given** I am viewing a board with the sidebar expanded, **When** I collapse it,
   **Then** the sidebar disappears and the board canvas expands to fill the freed space.
2. **Given** the sidebar is collapsed, **When** I expand it again, **Then** it reappears
   showing the same boards as before, with the same one highlighted as currently open.

---

### User Story 4 - Operate this view from the keyboard (Priority: P3)

As a signed-in member, I can reach and operate every control this feature provides
(opening a board, collapsing the sidebar, toggling theme) using only the keyboard, so I
am not forced to use a mouse to browse my boards.

**Why this priority**: Accessibility baseline for the controls this feature actually
introduces. Lower priority than Stories 1–3 because it changes how those controls are
reached, not what they do — it has no independent value without them.

**Independent Test**: Using only Tab/Shift+Tab to move focus and Enter/Space to
activate, reach and operate the sidebar's board links, the sidebar collapse control, and
the theme toggle, confirming a visible focus indicator at every step.

**Acceptance Scenarios**:

1. **Given** I am on the board view, **When** I use only the keyboard, **Then** I can
   move focus to any board in the sidebar, the sidebar collapse control, and the theme
   toggle, and activate each with Enter or Space.
2. **Given** I have focused a board in the sidebar, **When** I press Enter, **Then** that
   board opens, matching the mouse-click behavior in Story 1.

### Edge Cases

- What happens when a signed-in user has no board access at all (new workspace, never
  invited to any board)? The sidebar shows an explicit "no boards yet" state — not a
  blank area indistinguishable from a loading or broken state. There is no board
  creation entry point in this feature (see Assumptions), so this state is expected and
  cannot be resolved from within this feature.
- What happens when an open board has no lists yet, or a list has no cards yet? Each
  renders its own explicit empty state, distinct from "not loaded yet."
- What happens if a user's access to the currently open board is revoked while they are
  looking at it? The next time the view re-fetches that board's data, it must reflect
  current access (deny it) — never keep showing previously-loaded content past that
  point, per the server-side re-authorization already established in 002.
- What happens when a board, list, or card exists but has been soft-deleted or archived?
  It is excluded from this read-only view, the same as it is excluded from any other
  view — this feature does not add an "archived" view (that is later scope).

## Visual Inventory *(mandatory when the feature has `screenshots/` — else delete this section)*

### Screenshot: `screenshots/board-canvas.png` — board view, desktop viewport

Source: `docs/product/prototype/preview-board.png` (the prototype's own captured
preview, per `docs/product/prototype/README.md`). The prototype's card detail modal
preview (`preview-card.png`) is explicitly **not** included here — it belongs to
004-card-crud's own Visual Inventory (INV-007, out of scope for this feature).

- **VI-001**: Sidebar, dark theme background. Brand block at top: square logo mark +
  "FlowBoard" (bold) + workspace name in small caps below it (matches this product's
  existing workspace-name display, 002).
- **VI-002**: Sidebar "BOARDS" section label (small caps), then one row per board:
  color swatch (square) + board name + total card count, right-aligned. The currently
  open board's row is visually highlighted (background + bold text) — distinct from the
  others.
- **VI-003**: Sidebar footer: current user's avatar (initials, colored circle) + display
  name + role label below it.
- **VI-004**: Top bar, left-to-right: ☰ (sidebar toggle) · board title (bold) · star
  icon next to the title.
- **VI-005**: Top bar, right of title: search input (icon + placeholder text) · a
  bordered "Filter" button (icon + label) · an overlapping avatar stack (board members)
  · a bordered "+ Invite" button · a theme-toggle icon, in that left-to-right order.
- **VI-006**: Board canvas: lists arranged left-to-right, each a fixed-width card with
  its own white background distinct from the canvas's own background.
- **VI-007**: List header, left-to-right: list name (bold) · a count pill (rounded,
  gray) · a "⋯" menu icon. The count pill shows `count` alone when no WIP limit is set
  visually distinguishable from `count/limit` when one is; the `count/limit` form turns
  the pill red when `count` exceeds `limit`, gray otherwise (matches L-04's rule and
  invariant 3 — this feature only renders the indicator, never sets or enforces it).
- **VI-008**: List body: cards stacked top-to-bottom, each with visible spacing between
  them; a "+ Add a card" text-link footer beneath the last card (present on 3 of the 4
  lists in this capture — treat its presence as the default row for every list in this
  feature, non-interactive per FR-007/Assumptions).
- **VI-009**: Card front, top to bottom, only what applies: one or more label chips
  (colored, rounded, short text) on their own row · the card title · a meta row
  beneath, left-aligned, showing (as applicable) a due-date badge with a calendar icon,
  a checklist progress indicator (`☑ done/total`), a comment-count indicator (icon +
  number); member avatars are right-aligned on the same meta row, overlapping when more
  than one.
- **VI-010**: Due-date badge color carries meaning: a muted/gray badge for a future
  date, an amber badge for a near-term date, a red/pink badge for an overdue date
  (matches FUNCTIONAL_SPEC §4.6's grey/amber/red/green rule — this capture doesn't show
  the completed/green state).
- **VI-011**: A card with no labels, no due date, and no other indicators shows only its
  title — no empty meta row, no placeholder icons (matches FR-005's "only what applies").

**Explicitly not part of this feature's Visual Inventory** (present in the capture but
out of scope): the toast notification ("Moved to…") — X-01, no mutations exist in this
feature to trigger one; the small "Prototype · drag cards…" caption in the bottom-right
— that is the prototype demo's own signage, not a FlowBoard UI element.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST list, in a sidebar, every board the signed-in user has access
  to — as the owning workspace's implicit admin or as an explicit board member/admin/
  observer — and nothing else, re-using the access rules established in
  002-auth-workspaces.
- **FR-002**: System MUST show, for each board in the sidebar, at minimum its name and
  its total (non-archived, non-deleted) card count.
- **FR-003**: System MUST visually indicate which board, if any, is currently open.
- **FR-004**: System MUST render an opened board's lists in their stored left-to-right
  order, and each list's cards in their stored top-to-bottom order.
- **FR-005**: System MUST render, for each card, only the indicators that apply to it
  (labels, due date, description marker, checklist progress, comment count, assigned
  member avatars) — never a placeholder for data the card doesn't have.
- **FR-006**: System MUST deny access to a board's sidebar entry and content alike to
  any user who is not the owning workspace's admin and not an explicit member of that
  board, consistent with 002's existing board-access enforcement — this feature adds no
  new access rule, it only extends the existing one to board content (lists/cards),
  not just board membership.
- **FR-007**: System MUST NOT provide any way, from this view, to create, edit, reorder,
  archive, or delete a board, list, or card — those actions belong to later features.
  Where the visual reference shows a control for one of these actions (e.g., "Add
  another list," inline title editing, star toggle), the layout MUST still match the
  reference, but the control MUST NOT perform the action — see Assumptions for how this
  is handled without presenting a broken or erroring control.
- **FR-008**: System MUST let a signed-in user switch the entire application between
  light and dark theme from this view, applying the change immediately and remembering
  it on return, consistent with the app shell's existing theme behavior (001).
- **FR-009**: System MUST let a signed-in user collapse and expand the sidebar, with the
  board canvas immediately reclaiming or releasing the freed width.
- **FR-010**: System MUST make every control this feature introduces (opening a board,
  collapsing/expanding the sidebar, toggling theme) reachable and operable using only
  the keyboard, with a visible focus indicator.
- **FR-011**: System MUST show an explicit empty state — distinguishable from a loading
  state — when a user has no accessible boards, when an opened board has no lists, or
  when a list has no cards.
- **FR-012**: System MUST exclude archived or soft-deleted boards, lists, and cards from
  this view.

### Key Entities

- **Board** *(extended from 002-auth-workspaces)*: gains the display attributes needed
  to render it in a sidebar/canvas (a color, a starred indicator) — this feature only
  displays these, it does not let a user set or change them.
- **List**: An ordered column within a board, holding a name, a position, and its cards.
  New to this feature — no create/edit/reorder capability yet.
- **Card**: An item within a list, holding a title, position, and whichever of the
  following it has: labels, a due date, a description, a checklist, comments, and
  assigned members. New to this feature — no create/edit capability yet; the data these
  cards carry is seeded, not user-authored.
- **Label**: A board-scoped, named, colored tag a card can carry zero or more of. New to
  this feature as data only — no management UI yet.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user who already has access to a board can go from landing on the app to
  seeing that board's full list/card content in under 3 seconds.
- **SC-002**: 100% of boards ever rendered to a signed-in user are boards that user
  actually has access to — verified directly against the access rules, with zero cases
  of a board appearing that the user cannot open, and zero cases of an accessible board
  failing to appear.
- **SC-003**: Every element on screen (sidebar, top bar, canvas, lists, cards) reflects
  the current theme choice with no unstyled or mismatched element, in both light and
  dark theme.
- **SC-004**: Every control this feature introduces can be reached and activated using
  only the keyboard, with 100% coverage verified directly (no control reachable by mouse
  only).
- **SC-005**: A user with zero accessible boards, or a board with zero lists, or a list
  with zero cards, always sees a distinct explicit empty state — never a screen
  indistinguishable from "still loading" or "broken."

## Assumptions

- **Visual reference source.** `screenshots/board-canvas.png` is a copy of the
  prototype's own `docs/product/prototype/preview-board.png` (a real capture of
  `flowboard-prototype.html`'s board view, per that folder's `README.md`), not a fresh
  capture taken in this session — no browser automation was available. It is a genuine
  rung-1 reference and the Visual Compliance Loop runs against it normally; if the
  implementer wants a second, live capture of the actual prototype file for additional
  states (e.g., a board with fewer lists, or empty-state boards) before implementation,
  that remains available and is a reasonable plan.md-time addition, not a blocker here.
- **Non-functional controls stay visible, not hidden.** Where the prototype shows a
  control this feature doesn't implement yet (board rename, star toggle, "Add a list,"
  "Add a card," search box, filter button, per-board "+ Invite"), the layout keeps
  showing it (never inventing a different layout, per CLAUDE.md), but activating it does
  nothing destructive or broken — most simply, it is non-interactive in this phase.
  Wiring each one up is that capability's own later feature (e.g., 006 for board/list
  management, 007 for search/filter).
- **Card detail modal is explicitly out of scope**, including read-only. It is INV-007,
  assigned to 004-card-crud in `docs/roadmap.md`, which will need real card mutation
  scaffolding (labels, checklist, comments) that doesn't yet exist. This feature's Story
  1 only requires seeing a card's front, not opening it.
- **Keyboard scope is limited to this feature's own controls.** FUNCTIONAL_SPEC.md
  X-03's full acceptance criteria (`/`/`F` focuses search, `Esc` closes modals) name
  controls this feature doesn't introduce (search, modals). Story 4 covers only the
  controls FR-001–FR-009 actually add; the rest of X-03 completes alongside the features
  that add those controls.
- **Seed data for viewing.** This feature needs real lists/cards to render — the
  existing 002 fixture board has neither. A concrete seed (most likely the prototype's
  own three-board content, referenced in `data-model.md`'s Board entity notes as
  belonging to this feature) MUST exist for this feature's stories to be demonstrable;
  exactly which account(s) can see it is a `plan.md` decision, not fixed here. A brand
  new self-signup user with no invitations will legitimately see the empty state from
  Edge Cases — that is expected, not a defect, until board creation ships (006).
- **Archived-board visibility.** B-06's archive/restore concept is out of scope for this
  feature (006's scope); this feature simply excludes anything already archived or
  deleted, per FR-012.
