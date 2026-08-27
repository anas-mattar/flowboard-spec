# Research: Board View (Read-Only)

Phase 0 output. All Technical Context unknowns resolved below; no
`NEEDS CLARIFICATION` markers remain.

## R-1: Data model scope — full normalized entities, read-only endpoints only

**Decision**: Introduce the full FUNCTIONAL_SPEC §5 data model this feature needs to
render a card front faithfully — real `List`, `Card`, `Label`, `CardLabel`, `CardMember`,
`ChecklistItem`, and `Comment` tables — not denormalized summary counts on `Card`. Only
**read** endpoints ship this feature (`GET /v1/boards`, `GET /v1/boards/{id}`); every
insert/update/delete endpoint for these tables is 004/005/006's scope.

**Rationale**: `database-rules.md` requires the seed to "mirror the prototype's three
boards" so it doubles as the Visual Compliance Loop fixture — that only works if the
seed is real, relationally correct data (actual `ChecklistItem` rows, actual `Comment`
rows), not synthetic counters. Building the real tables now also means 004 extends this
schema with `INSERT`/`UPDATE` migrations against existing tables, rather than 004 having
to convert denormalized counters into real rows as its own migration cost.

**Alternatives considered**: denormalized counts (`Card.ChecklistDoneCount`,
`Card.CommentCount`) — cheaper to query today, but every count would need to become a
real child table the moment 004 lets a user check a checklist item or post a comment,
turning this feature's read-only convenience into 004's migration debt. Rejected.

## R-2: `ActivityEvent` is out of scope for this feature

**Decision**: No `ActivityEvent` table ships in this feature.

**Rationale**: Invariant 1 only requires an event for a *state-changing card action* —
this feature has none (read-only). The one place `ActivityEvent` would be visible (the
card detail modal's activity feed) is itself out of scope (INV-007, 004). Introducing an
always-empty table now has no reader and no writer in this feature; 004 introduces it
alongside the first action that actually writes to it.

## R-3: `GET /v1/boards` pagination

**Decision**: Cursor-paginated per FUNCTIONAL_SPEC §7 ("all list endpoints are
cursor-paginated") — request: optional `cursor` (opaque, base64 of the last item's sort
key) and `limit` (default 20, max 50); response: `{ items: [...], nextCursor: string |
null }`. Sort order: starred boards first (display-only rendering of B-04's rule, not an
interactive sort — this feature doesn't let a user star/unstar), then by `CreatedDate`
ascending, `Id` ascending as the tiebreaker (same tiebreak convention as invariant 2).

**Rationale**: `backend-rules.md`'s "List endpoints MUST be paginated server-side" is
unconditional — a real user's board count is small in v1.0, but the contract is fixed
once and not re-litigated per feature (consistency with how every other list endpoint in
this API will look). Cursor over offset avoids the classic "item shifts under a page
boundary" bug if boards are created/starred between page fetches.

**Alternatives considered**: no pagination (return everything) — simpler today, but
violates the explicit rulebook requirement and would need a breaking contract change the
day pagination actually matters. Offset/page-number pagination — rejected in favor of
cursor, matching FUNCTIONAL_SPEC's own explicit choice.

## R-4: Seed data — the prototype's three boards

**Decision**: Extend the existing fixture workspace from 002
(`fixture-owner@flowboard.test`, `WorkspaceConfiguration.FixtureWorkspaceId`) with three
new `Board` rows reproducing the prototype's "Product Roadmap Q3," "Marketing Launch,"
and "Customer Support" boards (`docs/product/prototype/preview-board.png`,
`specs/003-board-view-readonly/screenshots/board-canvas.png`) — colors, star state,
lists, cards, labels, due dates, checklists, comments, and member assignments matching
the capture exactly where visible. 002's original bare "Fixture Board" (`Id=1`, no
content) is left untouched — it is still what 002's own authorization tests exercise;
the three new boards are additive, deterministic `HasData` seed rows purely for this
feature's rendering and Visual Compliance Loop.

**Rationale**: `database-rules.md` names this exact seed ("the seed mirrors the
prototype's three boards... doubles as the Visual Compliance Loop fixture and as golden
fixtures for read tests"), and `plan.md`'s ADR-11 (002) explicitly reserved this seed for
003. Reusing the existing fixture workspace (rather than a new one) keeps one demo
account able to demonstrate every shipped feature to date, and avoids 002's tests having
to change to accommodate a second seeded workspace.

**Alternatives considered**: a dedicated new seed user/workspace for board content only
— rejected as unnecessary indirection; the existing fixture owner already has exactly
the right role (workspace admin) to own new boards, and 002's tests never assert an
exact *count* of the owner's boards, only interact with the one they already know by
`PublicId`.

## R-5: Sidebar/app-shell layout — new `(app)` route group

**Decision**: Introduce `app/(app)/layout.tsx`, an authenticated shell (redirects to
`/login` if unauthenticated, matching the existing board page's guard) that renders the
`Sidebar` + `TopBar` around `{children}`. Move the existing home page
(`app/page.tsx` → `app/(app)/page.tsx`) and the board page
(`app/boards/[boardPublicId]/page.tsx` → `app/(app)/boards/[boardPublicId]/page.tsx`)
under it — URLs are unchanged (route groups don't add path segments), but both pages now
share one persistent sidebar instead of each page owning its own shell fragment.

**Rationale**: No sidebar exists anywhere in the app yet — 001 built only a top bar, and
002's board page renders standalone (its own comment: "T053: the seam 003 extends into
the full board canvas"). Every authenticated screen needs the same sidebar per FR-001,
so it belongs in a shared layout, not duplicated per page. This is the natural place the
existing App Router structure was already heading (a route group per audience — `(auth)`
already exists for signed-out pages).

**Alternatives considered**: keep the sidebar as a component each page imports
individually — rejected, duplicates the "is this board currently open" highlighting
logic and the boards-list data fetch across every page that needs it, and drifts the
moment one page's copy is updated and another isn't.

## R-6: `TopBar` gains the board title and its own decorative controls only when a board is open

**Decision**: `TopBar` becomes board-aware: it accepts the currently-open board's
summary (name, star state, member avatars) as a prop from the page that renders it, and
renders VI-004/VI-005's layout (title, star icon, search box, filter button, avatar
stack, invite button, theme toggle) only when a board is open; on the home page (no
board open) it renders its existing 002-era content (workspace name/role, sign-out)
unchanged. The non-interactive controls (star, search, filter, invite-from-top-bar) are
visually present but inert per FR-007/spec.md Assumptions.

**Rationale**: Keeps `TopBar` a single shared component (matches `frontend-rules.md`'s
`components/layout/` convention) without forking it into a board-specific and
board-less variant, while not inventing board-title UI on pages that have no board
open (the home page has no title to show).

## R-7: `List.WipLimit` is a display-only column in this feature

**Decision**: `List` gets a nullable `WipLimit INT` column, set only by this feature's
seed data (to reproduce VI-007's `count/limit` pill, including the red-when-exceeded
state on "In Progress"). No endpoint in this feature sets or changes it — that's L-04
(006).

**Rationale**: Rendering the reference screenshot faithfully requires the underlying
data to exist; inventing a different seed without WIP limits to avoid adding the column
early would violate "never invent a new UI layout when visual references exist"
(constitution II) by silently changing what the capture shows into something this
feature can render without the column. Invariant 3 (WIP limits are advisory) is
respected trivially — there is no code path in this feature that could enforce it.

## R-8: Ordering module (`Flowboard.Api/Domain/Ordering.cs`) is not introduced yet

**Decision**: `List.Position` / `Card.Position` are `float` columns (fixed by 001's
plan.md), populated directly by this feature's seed data with fixed, well-spaced values
(e.g., 1000, 2000, 3000 per sibling) and read back in ascending order, `Id` ascending as
tiebreaker (invariant 2's documented tiebreak). The shared midpoint-insertion/
re-balancing module named in 001's plan.md is **not** created in this feature — it has
no writer yet (nothing moves anything until 005's drag-and-drop).

**Rationale**: 001's plan.md says the module is "golden-fixture tested when
introduced" — introduced means when the first write path needs midpoint math, not when
the first `Position` column exists. Creating an unused module now with no real
call site to test against would produce fixture tests asserting nothing meaningful.
