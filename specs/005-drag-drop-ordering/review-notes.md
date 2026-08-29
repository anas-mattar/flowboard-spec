# Review Notes — 005 Drag & Drop Ordering

## Phase A — backend (card move, list move) (T001–T008)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-28
**Branches**: `flowboard-api` `main` (merged, commit `c16939d`)
**Scope reviewed**: `src/Flowboard.Api/Domain/ActivityEventType.cs`,
`src/Flowboard.Api/Services/CardService.cs` (`MoveCardAsync` addition),
`src/Flowboard.Api/Services/ListService.cs` (new),
`src/Flowboard.Api/Endpoints/CardsEndpoints.cs` (`/move` addition),
`src/Flowboard.Api/Endpoints/ListsEndpoints.cs` (new), `src/Flowboard.Api/Program.cs`
(DI + route registration), `tests/Flowboard.Api.Tests/CardsEndpointTests.cs` (move tests),
`tests/Flowboard.Api.Tests/ListsEndpointTests.cs` (new),
`tests/Flowboard.Api.Tests/OrderingTests.cs` (golden-fixture additions).
**Feature contract**: plan.md ADR-20 (dedicated move endpoints, not a `PATCH` extension),
ADR-21 (no concurrency precondition on moves, ever), ADR-24 (no rebalancing job); no new
package, no migration/schema change (data-model.md).

## Verdict

**APPROVE**. Both move endpoints match contracts/move-api.md exactly: request/response
shapes, failure codes, and the `card.moved`-only-on-list-change activity rule. The one
non-obvious design point — bypassing EF's `RowVersion` concurrency token on the move path
via `ExecuteUpdateAsync` rather than a normal tracked `SaveChangesAsync` — is necessary to
actually deliver ADR-21 (Card.RowVersion is a real concurrency token per 004's
`CardConfiguration.IsRowVersion()`; a plain save would have silently reintroduced a `409`
that ADR-21 explicitly forbids) and is covered by a dedicated test. No residual risk found.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-001–FR-012 implemented as specified) | Read spec.md's Acceptance Scenarios against `MoveCardAsync`/`MoveListAsync`; same-list reorder writes no event (`MoveCard_SameList_ReordersAndWritesNoActivityEntry`), cross-list writes exactly one (`MoveCard_CrossList_MovesAndWritesOneActivityEntry`), WIP never blocks (`MoveCard_DestinationOverWipLimit_StillSucceeds`) |
| Visual-reference match | N/A — Phase A is backend-only, no UI this phase |
| Feature contract held (no unapproved table/migration/permission/package) | `git diff --stat` (below) — no migration added; `Flowboard.Api.csproj`/`Flowboard.Api.Tests.csproj` untouched; no new NuGet reference |
| Constitution / domain invariants | See table below |
| Security (authn/authz, secrets, sensitive logging) | Both endpoints `.RequireAuthorization()` via their `MapGroup`; `BoardAccessService.ResolveAsync` re-resolved per-request (ADR-9), no cached role; no secrets/PII in the `card.moved` payload (list names only) |
| Scope guard (`git diff --stat` — only intended files) | 9 files touched, all named in tasks.md T001–T008; no unrelated file changed |
| Rollback safety (phase reverts cleanly; schema additive?) | No schema change at all this phase — a revert is a pure code revert, no migration to roll back |

```
 src/Flowboard.Api/Domain/ActivityEventType.cs   |   1 +
 src/Flowboard.Api/Endpoints/CardsEndpoints.cs   |  18 ++++
 src/Flowboard.Api/Program.cs                    |   2 +
 src/Flowboard.Api/Services/CardService.cs       |  99 +++++++++++++++++
 tests/Flowboard.Api.Tests/CardsEndpointTests.cs | 136 +++++++++++++++++++++++-
 tests/Flowboard.Api.Tests/OrderingTests.cs      |  55 ++++++++++
 (new) src/Flowboard.Api/Endpoints/ListsEndpoints.cs
 (new) src/Flowboard.Api/Services/ListService.cs
 (new) tests/Flowboard.Api.Tests/ListsEndpointTests.cs
 9 files changed, 309 insertions(+), 2 deletions(-)
```

## Findings

### F1 — Move bypasses the RowVersion concurrency token via `ExecuteUpdateAsync` — ACCEPTED

`CardService.MoveCardAsync` writes `ListId`/`Position`/`UpdatedDate`/`UpdatedBy` through
`db.Cards.Where(...).ExecuteUpdateAsync(...)` instead of mutating the tracked `card` entity
and calling `SaveChangesAsync`. A normal tracked save would have included `Card.RowVersion`
(configured `IsRowVersion()` in 004's `CardConfiguration`) as an implicit concurrency token
in the `UPDATE`'s `WHERE` clause — reintroducing exactly the `409` ADR-21 says must never
happen on this path. `ExecuteUpdateAsync` issues the SQL directly with no concurrency-token
predicate, which is the correct implementation of an already-approved ADR, not a new
architectural pattern requiring separate plan.md sign-off.
*Action: none — covered by `MoveCard_TwoSuccessiveMoves_NeitherIsRejected_LastWriteWins`,
which proves two successive moves against the same card both return `204`.*

### F2 — `ListService`/`CardService` each keep their own private `CanMutate(role)` — ACCEPTED

Duplicates the one-line role check 004's `CardService` already had, rather than
introducing a new shared `BoardRole` helper class. No such shared utility exists anywhere
in the codebase yet; adding one now for a single line would be exactly the kind of
unapproved abstraction `backend-rules.md`'s "New code MUST follow the existing layout"
warns against introducing without a plan.md justification.
*Action: none.*

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS. Implementation follows spec.md/plan.md/tasks.md;
  no undocumented behavior added.
- **II. Source of Truth Hierarchy** — PASS. No visual references engaged this phase
  (backend-only); no conflicts encountered.
- **III. Repository Separation** — PASS. `flowboard-api` only touched.
- **IV. Architecture Consistency** — PASS. Minimal-API endpoint groups over a service
  layer, matching 001–004's established layout; no new package; `ListsEndpoints.cs` is a
  new file but the same shape as `CardsEndpoints.cs`, per plan.md's own Complexity
  Tracking entry for this feature.
- **V. Data Standards** — N/A this phase (no schema change).
- **VI. Auditability** — PASS. `card.moved` carries `CreatedBy`/`CreatedDate` like every
  other `ActivityEvent`; `UpdatedBy`/`UpdatedDate` set on every move (both Card and List).
- **VII. Domain Invariants** — PASS, see below.
- **VIII. Security** — PASS. Both routes require auth + board-role resolution; Observer
  gets `403`, no access gets `404`.
- **IX. External Integration Governance** — N/A (no external integration this feature).
- **X. Performance Responsibility** — PASS. Sibling-position lookups are indexed
  (`(ListId, Position)` / `(BoardId, Position)`, both from 001/003's schema); no N+1.
- **XI. Testing Requirements** — PASS. Every endpoint has an integration test; ordering
  resolution has a golden-fixture test.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Backend gates and merges before frontend begins,
  per `docs/sdlc/repository-strategy.md`.

### Domain invariant pass

| # | Invariant | How satisfied |
|---|---|---|
| 1 | Activity append-only | `card.moved` is `Add`-only; no move path updates/deletes an `ActivityEvent` |
| 2 | Ordering integrity | Both move paths resolve positions exclusively through `Ordering.Append`/`InsertBetween`; no inline arithmetic |
| 3 | WIP limits advisory | Neither endpoint checks `WipLimit`; `MoveCard_DestinationOverWipLimit_StillSucceeds` proves it |
| 4 | Soft delete | Move endpoints operate through the existing `!IsDeleted` query filters (no `IgnoreQueryFilters()` used) |
| 5 | Permissions server-side | `BoardAccessService.ResolveAsync` re-checked per request on both endpoints |
| 6 | Optimistic concurrency | Deliberately NOT applied to moves (ADR-21) — Card field-edits (004's `PATCH`) keep their own `If-Match`/`409` untouched |
| 7 | Labels board-scoped | N/A — this feature never touches labels |
| 8 | Opaque public IDs | Both move endpoints address exclusively by `PublicId`; internal `Id` never crosses the API boundary |

## Test coverage observed

- `CardsEndpointTests.cs`: 8 new facts — same-list reorder (no activity), cross-list move
  (exactly one `card.moved`), destination over its WIP limit (still `204`), two successive
  moves (both `204`, no `409`), cross-board `listPublicId` (`400`), cross-board/foreign-list
  `beforeCardPublicId` (`400`), non-member (`404`), Observer (`403`).
- `ListsEndpointTests.cs` (new): 5 facts — reorder persists on refetch, same-position move
  is an observable no-op, cross-board `beforeListPublicId` (`400`), non-member (`404`),
  Observer (`403`). `DisposeAsync` restores the four seeded Product Roadmap lists' fixed
  positions after every test so `BoardsEndpointTests`'s stored-order assertion (which
  shares the same database) is never affected by this class's moves.
- `OrderingTests.cs`: 5 new facts — a pure, DB-free restatement of the insertion-point
  resolution algorithm (research.md R-1) against hand-worked sibling-position tables:
  before-first (no predecessor), before-middle, before-last, append (last-position + 1
  step), append into an empty list.
- Full suite: 89/89 passing (71 pre-existing + 18 new), user-confirmed
  `dotnet build --warnaserror && dotnet test` → `EXIT: 0`.

## Residual risk

None identified for this phase. The one non-obvious technique (F1) is isolated to a
single method and directly tested; list-move is a genuinely new endpoint group but follows
the existing card-endpoint shape exactly, so no new review burden for future features.

## Phase B — frontend, Visual Compliance Loop (T009–T021)

**Scope of this entry**: the Visual Compliance Loop (`docs/sdlc/review-process.md`) against
the already-implemented T009–T020 drag/move UI (card drag, the "Move to list" menu, list
drag), run before the Phase B gate per this repo's workflow order (`../CLAUDE.md`:
implement → Visual Compliance Loop → gate → commit → AI review). The gate was then
user-run and confirmed `EXIT: 0`, the phase was committed, and the full frontend AI-review
checklist below was completed against that commit.

**Render method**: `flowboard-web` dev server, signed in as the existing WorkspaceAdmin
fixture session, board "Product Roadmap Q3" (same board the reference screenshots were
captured from). Card and list drag are native HTML5 drag-and-drop
(`draggable`/`dragstart`/`dragover`, plan.md ADR-23); a mid-drag frame can't be captured by
a scripted mouse-drag (the whole gesture completes atomically before a screenshot can be
taken), so each mid-drag frame was staged by dispatching the same native `dragstart`/
`dragenter`/`dragover` DOM events the browser would dispatch during a real drag (real
`DataTransfer`, real event bubbling, real React handlers in `card-front.tsx`/
`list-column.tsx`/`board-canvas.tsx` — no CSS or state was set directly). No `drop` event
was dispatched, so no card or list was actually moved; a `dragend`/`dragleave` pair reset
the state afterward.

**Environment note (not a code defect)**: the first dev-server boot served a `next dev`
HTML response that never linked the route's real compiled Tailwind chunk (only a small
shared `[root-of-the-server]` chunk), so `opacity-40`/`outline-2 outline-dashed
outline-ring` had no effect despite being correctly present in every className — the same
class of dev-server/browser-cache artifact 004's review-notes.md already recorded for this
codebase. Confirmed not a source defect by running `npm run build && npm run start`: the
production CSS bundle contains `.opacity-40`, `.outline-2`, and the `dashed` outline-style
rule exactly as authored. Worked around for this capture session by loading the dev
server's own already-correctly-compiled chunk
(`.next/dev/static/chunks/src_styles_globals_css_*.single.css`) directly into the page; no
application code was touched.

**Visual Compliance Loop** against `screenshots/board-canvas-dragging.jpg`,
`screenshots/card-move-to-list-popup.jpg`, `screenshots/list-reorder-dragging.jpg`,
compared structurally (layout, hierarchy, states) per the process doc, not pixel-diff —
implemented captures: `screenshots/board-canvas-dragging-implemented.jpg`,
`screenshots/card-move-to-list-popup-implemented.jpg`,
`screenshots/list-reorder-dragging-implemented.jpg`:

| # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
|---|---|---|---|---|---|

Table is empty — no deviations found. Item-by-item:

- VI-001 (dragged card faded, ~40% opacity, stays in its original slot): matches —
  "Research competitor onboarding flows" fades in place in `In Progress` while dragged.
- VI-002 (hovered list gets a dashed accent outline, exactly one list at a time): matches —
  `Design` alone gained the dashed outline while under the pointer.
- VI-003 (every other card/list renders normally): matches — no other list or card in the
  captured frame shows any drag-related styling.
- VI-004 (popover titled "MOVE TO LIST", anchored below "Move"): matches exactly, including
  the uppercase title.
- VI-005 (every list as a plain-text row, top-to-bottom in board order, not a dropdown):
  matches — Backlog, Design, In Progress, Review in that order (this board has no "Done"
  list, unlike the reference's fixture data — a data difference, not a structural one).
- VI-006 (checkmark beside the card's current list only): matches — `In Progress` alone
  carries the checkmark.
- VI-007 (no icon but the list name; choosing a row is the entire interaction): matches —
  confirmed against `card-move-panel.tsx`'s implementation as well as the rendered popover.
- VI-008 (dragged list fades as one unit — header, cards, footer together): matches —
  `Backlog`'s header, all three cards, and its "+ Add a card" composer all fade together.
- VI-009 (hovered list during a list drag shows the identical VI-002 dashed outline):
  matches — `In Progress` gained the same dashed outline style during the list drag.

The reference prototype's dashed-outline/accent color reads more saturated (purple-blue)
than this app's actual (grayish, `--ring`) accent — not logged as a deviation, following
004's review-notes.md precedent: this app's monochrome color system was already an
established, reviewed decision in 001–003, and the Source-of-Truth Hierarchy calls for
comparing structure/specification, not literal color, against the prototype.

Exit rule met: table is empty on the first pass, no fixes were required.

**Gate**: `npm run lint && npm run build` in `flowboard-web` — user-run, confirmed
`EXIT: 0`.

**Diff surface** (`git diff --stat`, commit `1b939b2`): new
`components/board/card-detail/card-move-panel.tsx`, `components/board/drag-data-types.ts`,
`lib/api/lists-client.ts`, `lib/lists/schemas.ts`, `server/api/routers/lists.ts`. Edited:
`components/board/board-canvas.tsx` (list drop zone, US3), `components/board/card-detail/
card-add-to-card-menu.tsx` (wires the Move button), `components/board/card-detail/
card-detail-modal.tsx` (threads `boardLists`), `components/board/card-front.tsx`
(draggable, VI-001), `components/board/list-column.tsx` (card drop zone + draggable list
header, US1/US3), `lib/api/cards-client.ts`/`lib/cards/schemas.ts`/`server/api/routers/
cards.ts` (`move` procedure), `server/api/root.ts` (+`lists` router registration). 14 files,
exactly tasks.md's T009–T020 file list — no unrelated files touched, no new npm package
(`package.json`/`package-lock.json` untouched, confirmed via `git diff`).

**AI review vs `docs/rulebooks/frontend-compliance-checklist.md`**:

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `card-move-panel.tsx` mirrors `card-labels-panel.tsx`'s shape exactly (same props style, same `errorMessage`/`isTRPCClientError` helper, same panel layout) as tasks.md required; `lists-client.ts`/`lists/schemas.ts`/`routers/lists.ts` mirror the cards-side files 1:1; `'use client'` present only on `card-move-panel.tsx`/`card-add-to-card-menu.tsx` (both use hooks/mutations) — `drag-data-types.ts` and the server-only `lists-client.ts`/`routers/lists.ts` correctly carry none |
| Data Flow | PASS | `cards-client.ts`/`lists-client.ts` are called only from their own `protectedProcedure` routers, never imported into client components except as `import type` (erased at compile, `card-move-panel.tsx`'s `ListContent` import); both new/extended `move` procedures validate input with Zod (`moveCardInputSchema`/`moveListInputSchema`); `applyOptimisticCardMove`/`applyOptimisticListMove` only reorder already-fetched arrays for display (comment states this explicitly) — the server-owned `Position` is never computed or written client-side (invariant 2); `onSettled` invalidation reconciles both optimistic paths with the server (ADR-22) |
| Forms | N/A | No new data-entry form this phase — `CardMovePanel` is a selection list (click a row), same non-RHF category 004's review-notes.md already established for single-action pickers (`card-labels-panel.tsx` precedent), not a form needing RHF/Zod-resolver ceremony |
| UI States & Accessibility | PASS, one pre-existing/approved gap noted (see F1) | `Escape` closes the Move popover with no move (Radix `Popover`, verified manually); color is never the only drag-state signal (opacity + outline, both paired with the drag itself, not a standalone color cue) |
| State, Styling | PASS, dark theme not re-verified this session (see below) | No Context/Redux added; `opacity-40`/`outline-2 outline-dashed outline-ring` are Tailwind utilities via `cn()`, not hardcoded styles; the pre-existing inline `style={{ backgroundColor: ... }}` for label/member colors is untouched 004-era code, not introduced here. Layout matches `screenshots/` (Visual Compliance Loop above, empty table) |
| Security & Performance | PASS | No backend token reaches the client bundle (same server-only-client pattern as 004); no new `dangerouslySetInnerHTML`; `canMutate` correctly gates both new interactions — `draggable={canMutate}` on both `CardFront` and the list header, `onCardDragOver`/`onCardDrop`/`onListDragOver`/`onListDrop` all short-circuit `if (!canMutate)`, and `CardAddToCardMenu` (which now also renders the Move button) already returns `null` entirely for a non-mutating viewer — Observer gets neither a draggable surface nor the menu, matching 004's post-merge-fixed pattern from the start rather than repeating that gap |
| Process | PASS | No new package; diff surface is exactly T009–T020; gate user-run, `EXIT: 0` |

### F1 — List reorder (US3) has no keyboard/menu equivalent — ACCEPTED (pre-approved, plan.md ADR-23)

`docs/rulebooks/frontend-rules.md` states "every drag interaction MUST have a keyboard/
menu equivalent (C-11) in the same phase — not deferred," and this phase ships a second
new drag interaction (list reorder, US3/L-03) with no non-drag path at all — the list
header's "⋯" menu stays `disabled` (`aria-label="List options (not available yet)"`,
unchanged from 004, list management itself is out of scope until 006). This was not an
oversight introduced during implementation: `plan.md` ADR-23 explicitly reasons through
this exact question and concludes the keyboard-operable "Move" menu (US2) alone satisfies
`FUNCTIONAL_SPEC.md` §8's accessibility requirement for the whole feature, treating native
drag's own lack of keyboard support for list reorder specifically as "not a compliance
gap" — an approved plan-time decision (constitution IV), not something this review is
positioned to silently overrule.
*Action: none from this review — flagging for the human reviewer to make the same judgment
call explicitly (agree with ADR-23's scoping of C-11 to C-02, or send back for a list-level
keyboard equivalent) rather than this passing unnoticed.*

**Dark theme**: not manually re-verified this session (no dark-mode screenshot exists for
this feature; the reference screenshots are light-mode only, matching 003/004's own
practice). Low risk — `opacity-40` is theme-independent and `outline-ring` resolves through
the same `--ring` CSS variable both themes already define (`styles/globals.css`), so no new
theme-conditional styling was introduced this phase.

**Verdict**: Phase B **APPROVE**. Visual Compliance Loop passed with an empty deviation
table; frontend-compliance-checklist all PASS except one disclosed, pre-approved
accessibility scoping decision (F1, ADR-23) surfaced for the human reviewer's explicit
sign-off, and dark theme left unverified (low risk, no theme-conditional code added). No
unrelated files touched, no new package, gate user-confirmed `EXIT: 0`. Cleared to proceed
to human review.

## Post-merge fix — `card.moved` activity text never rendered

**Date**: 2026-08-29
**Found via**: `quickstart.md`'s own T022 walkthrough (US1/US2 activity-feed checks), after
Phase B above was already reviewed, gated, approved, merged, and pushed — the same
discovery path 004's own post-merge fix took.

**Diff surface**: `src/components/board/card-detail/card-activity-feed.tsx` — one line
added to the `describe()` switch:

```diff
+    case "card.moved":
+      return `moved this card from ${payload.fromListName} to ${payload.toListName}`;
```

**What was found**: the backend correctly writes a `card.moved` `ActivityEvent` with
`{fromListName, toListName}` on every cross-list move — confirmed directly via
`cards.getActivity`'s raw response for both a drag-based move and a Move-menu move — but
`CardActivityFeed`'s `describe()` function had no case for that type, silently falling
through to `default: return null`. The rendered feed showed only the actor's name and a
timestamp with no description at all, instead of spec.md's own quoted "moved this card
from X to Y" — a real, silent regression against FR-003/quickstart's own US1 and US2
rows, missed during Phase B because the Visual Compliance Loop's VI-001–VI-009 never
touch the activity feed, and none of T009–T020 named `card-activity-feed.tsx` as a file to
touch (a genuine task-list gap, not a corner someone cut).

**Verification note**: confirming the fix took two passes because of an unrelated
environment issue — after editing the file, the running `next dev` server (even after a
full `.next` cache wipe and clean restart) kept serving a JS chunk for this exact URL that
did not contain the new code, while the file on disk and a fresh `npm run build`'s output
both did. This is the same category of dev-server/browser staleness already recorded in
Phase B's Visual Compliance Loop entry above (that one was a missing CSS `<link>`; this one
a stale JS chunk body at a stable URL) and in 004's own review-notes.md before that. The
fix was confirmed correct by grepping the `npm run build` output for the new string, not by
trusting the dev server's rendered page.

**AI review**: `git diff` limited to the one-line addition above; no other file touched; no
new package. `npm run lint && npm run build` clean (self-run, `EXIT: 0`; certifying run is
the user's). Low risk — a display-only fix with no data or permission implications; the
underlying `card.moved` event and its payload were already correct and already covered by
Phase A's own backend tests.

**Verdict**: **APPROVE**. Recommend committing on a small `fix/card-moved-activity-text`
branch (`docs/sdlc/branch-strategy.md`'s `fix/<name>` lane) and merging the same way as
Phase B, once the user confirms the gate.

## Wrap-up note (T022–T023)

Phase B (T009–T021) is reviewed and gated (`EXIT: 0`); commit `1b939b2` on
`005-drag-drop-ordering`, merged to `main` (`6e871ac`) and pushed. `quickstart.md` was
walked end-to-end against that merged `main` (T022) — every US1–US3 row and both testable
edge-case rows matched, one real gap found and fixed (above); the last-write-wins edge row
was substituted with its existing automated-test coverage after a same-profile login
switch overwrote the admin browser session mid-walkthrough, the same substitution 002's own
quickstart walkthrough made for a different blocked row. See `quickstart.md` §5 for the
full per-row results table.
