# Review Notes — 004 Card Lifecycle CRUD

## Phase A — backend (Foundational + Card Mutations) (T001–T030)

**Gate**: `dotnet build --warnaserror && dotnet test` in `flowboard-api` — my own fast-feedback
run (allowed mid-implementation for this Standard-delivery feature) shows 0 warnings/0
errors and 71/71 tests passing. The certifying run is the user's, requested after this
review.

**Diff surface**: new `Domain/Entities/ActivityEvent.cs`, `Domain/ActivityEventType.cs`,
`Domain/Ordering.cs` (ADR-18, fulfilling 001's ADR-4 reservation), `Domain/CardDueStatus.cs`
(research R-5, extracted from `BoardContentService`), `Data/Configurations/
ActivityEventConfiguration.cs`, `Endpoints/CardsEndpoints.cs`, `Services/CardService.cs`,
`Migrations/20260828034037_AddCardActivity.{cs,Designer.cs}`, `tests/
CardsEndpointTests.cs`, `tests/OrderingTests.cs`. Edited: `ChecklistItemConfiguration.cs`
(+`PublicId` column and its seed backfill), `ChecklistItem.cs` (+`PublicId` property),
`FlowboardDbContext.cs` (+1 `DbSet`), `Program.cs` (+1 DI registration, +1 endpoint-group
mapping), `BoardContentService.cs` (inline `dueStatus` bucketing replaced by a call to the
new shared `CardDueStatus.Compute`, per R-5 — behavior unchanged),
`FlowboardDbContextModelSnapshot.cs` (EF-generated). No files outside this feature's
schema/service/endpoint scope; 002/003's auth, board-membership, and board-content read
logic are untouched except the R-5 extraction (which is a pure refactor with no behavior
change, confirmed by 003's own `BoardsEndpointTests` still passing unmodified).

**AI review vs `docs/rulebooks/backend-compliance-checklist.md`** (2026-08-28):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `CardsEndpoints.cs` uses `MapCardsEndpoints` + `MapGroup`; handlers are thin (auth check + input-shape parsing, then one service call); both `CardsEndpoints.cs` and `CardService.cs` cite `contracts/card-crud-api.md` in a top comment |
| API Surface | PASS | Title/text/body length validated before any write, returning `ValidationProblem`; every DTO exposes `PublicId` only; `PATCH /v1/cards/{id}` requires `If-Match` and returns `409` on a stale `RowVersion` (via `DbUpdateConcurrencyException`, not a manual check-then-write race); `GET /v1/cards/{id}/activity` is cursor-paginated (ADR-12's shape reused) |
| Domain & Authorization | PASS | Every route resolves the caller's role via `BoardAccessService.ResolveAsync` before acting (invariant 5); `Observer` is permitted only on the three read/comment routes, enforced by one `CanMutate(role)` helper reused everywhere else (R-2's fixed table). Invariant 7 enforced in `AddLabelAsync` (`label.BoardId != card.List.BoardId` → `400`). Invariant 5's sanctioned side effect (`AddMemberAsync` inserting a `BoardMember` row) is scoped to exactly that one path. All position math for card create/copy/checklist-item create goes through `Ordering.cs` — no inline arithmetic elsewhere (invariant 2). Invariant 1 verified two ways: no code path calls `Update`/`Remove` on `ActivityEvents`, and every state-changing card action writes one — including checklist **unchecking**, found missing during this review (see below) |
| Data Access & Performance | PASS (one accepted tradeoff) | Pure-read aggregation queries (`BuildDetailDtoAsync`, `GetActivityAsync`, `CopyCardAsync`'s label/member/checklist reads) use `AsNoTracking()` + `.Select()` projection. `ResolveCardAsync`/`ResolveChecklistItemAsync` intentionally do **not** use `AsNoTracking()` — they're the single shared resolver for both mutating and read paths (avoids duplicating the `Card → List → Board` access-resolution logic across 14 routes), so `GetCardDetailAsync` incurs one tracked single-row query it doesn't strictly need. Accepted as a deliberate simplicity-over-micro-optimization tradeoff (single row, not a collection scan) rather than forking a duplicate untracked resolver. No N+1 (all aggregate reads are flat `.Select()` projections, not per-row loops); all I/O async with `CancellationToken`; no explicit `IgnoreQueryFilters()` in production code (test-only cleanup uses it, appropriately) |
| Security | PASS | `.RequireAuthorization()` on every route; all data access is LINQ (parameterized); no secrets in source; external HTTP N/A |
| Testing | PASS | `CardsEndpointTests.cs` covers all 14 routes: success, validation failure (empty title/text/body, missing `If-Match`, rejected `list_id`/`position`), authorization failure (404 non-member, 403 Observer on every mutating route, Observer-may-comment), and the concurrency conflict (`409` on stale `If-Match`, proven by a real first-writer-wins sequence). `OrderingTests.cs` gives `Ordering.Append`/`InsertBetween` golden-fixture coverage with hand-worked values |
| Process | PASS | No new packages; diff surface above is exactly T001–T030's scope; gate previously only self-run, user confirmation requested below |

**Gap found and fixed during this review**: `UpdateChecklistItemAsync` originally wrote a
`checklist.item.checked` event only when `done == true`, silently dropping unchecking as
an unrecorded state change (an invariant-1 gap — a state-changing card action with no
activity trail). Fixed by adding a `checklist.item.unchecked` type (also documented in
`data-model.md`'s `ActivityEvent.Type` enumeration) and only writing either event when the
value actually changes (so re-sending the same `done` value, e.g. a retried optimistic
update, no longer double-logs). Covered by a new assertion in
`ChecklistItem_AddCheckDelete_Flow`.

**Verdict**: Phase A PASS — one real gap found (missing unchecked-state activity event)
and fixed within this review before recording it; one accepted, disclosed performance
tradeoff; no other FAIL items, no waivers. Cleared to commit once the user runs the
backend gate and confirms exit 0.

## Phase B — frontend (composer, card detail modal + 7 panels, client-driven canvas,
Visual Compliance Loop) (T031–T053)

**Gate**: `npm run lint && npm run build` in `flowboard-web` — my own fast-feedback runs
(allowed mid-implementation for this Standard-delivery feature) are clean after every
change in this phase, most recently after the Visual Compliance Loop's fixes below
(0 lint errors; `next build` compiles, type-checks, and generates all 6 routes with exit
0). The certifying run is the user's, requested after this review.

**Diff surface**: new `lib/cards/schemas.ts`, `lib/cards/due-status.ts` (shared with
`card-front.tsx`), `lib/api/cards-client.ts`, `server/api/routers/cards.ts`, `components/
board/card-composer.tsx`, `components/board/card-detail/` (9 files: `card-detail-modal`,
`card-title-field`, `card-description-panel`, `card-labels-panel`, `card-members-panel`,
`card-due-date-panel`, `card-checklist-panel`, `card-activity-feed`,
`card-add-to-card-menu`), 4 new shadcn primitives (`dialog`, `checkbox`, `popover`,
`textarea` — no new npm packages; a `calendar` primitive was generated then removed
before committing, see Process below). Edited: `board-canvas.tsx` (client-driven,
ADR-19; owns `openCardPublicId` state, ADR-14; derives `boardLabels` — see the disclosed
limitation below), `list-column.tsx` (client, wires the real composer), `card-front.tsx`
(click-to-open; `DUE_STATUS_STYLES`/`formatDueLabel` extracted to the new shared module,
no behavior change), `app/(app)/boards/[boardPublicId]/page.tsx` (passes `initialBoard`
instead of `board`), `server/api/root.ts` (+`cards` router registration). No files
outside this feature's frontend scope; 002/003's auth pages, sidebar, and top bar are
untouched.

**Disclosed limitation (no waiver needed — inherent to this feature's own contract)**:
`contracts/card-crud-api.md` never defines a board-level "list all labels" endpoint —
only assign/remove-by-id. `CardLabelsPanel`'s picker is therefore populated from labels
already assigned to at least one card on the board (derived in `board-canvas.tsx` from
data already fetched for the canvas), not a full label roster. A label with zero cards
today would not appear until assigned some other way. Every one of this board's 5 seeded
labels is already in use, so this is invisible against the seed data; a future feature
adding real label management should also add the missing listing endpoint.

**Two gaps found and fixed during this review**:

1. **`CardTitleField` double-save race (real bug, found during manual QA, not just code
   review)**: pressing Enter to save is separately wired to also fire on `onBlur`; in one
   manual test the two calls raced, the second landing with an already-stale `If-Match`
   and surfacing a spurious `409` immediately after a successful save. Fixed with an
   `updateMutation.isPending` guard at the top of `save()` (idempotent against either
   trigger firing twice) and `onFocus={(e) => e.target.select()}` so entering edit mode
   selects the existing text — the same interaction that made the double-fire visible
   (typing was appending to, not replacing, the pre-filled value).
2. **Visual Compliance Loop, three real structural deviations** (see the table below) —
   fixed before recording this review.

**Visual Compliance Loop** (`docs/sdlc/review-process.md`) against
`screenshots/card-detail-modal.png`, compared structurally (layout, hierarchy, exact
section labels) per the process doc, not pixel-diff:

| # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
|---|---|---|---|---|---|
| 1 | Left-column section headings (VI-004–007) | Uppercase tracked labels: LABELS, DESCRIPTION, CHECKLIST, ACTIVITY | Sentence-case headings, and no heading at all above the label chips | Medium | **Fixed** — added a "Labels" heading and switched every section heading (`card-detail-modal.tsx`, `card-description-panel.tsx`, `card-checklist-panel.tsx`, `card-activity-feed.tsx`, `card-add-to-card-menu.tsx`) to the same uppercase/tracked style |
| 2 | Checklist empty state (VI-006) | Progress-bar track always visible; "No checklist items yet." shown when empty | Progress bar only rendered once an item exists; no empty-state text | Low | **Fixed** — `card-checklist-panel.tsx` now always renders the track and shows the empty-state line when `total === 0` |
| 3 | Breadcrumb line (VI-002) | "in list Backlog · board Product Roadmap Q3 · due Sep 8" | "{boardName} / {listName} [due pill]" (board first, `/` separator) | Low | **Fixed** — reworded to match the reference's "in list … · board …" phrasing and order in `card-detail-modal.tsx`; the due pill itself (color rule, VI-009) was already correct and unchanged |

Primary-action button color (reference uses blue; this app already established a
monochrome black/white primary color in 001–003, used unmodified everywhere else
including this feature's Save/Comment buttons) is **not** listed as a deviation — the
Source-of-Truth Hierarchy's own guidance is to compare structure/specification, not
literal color, and this app's actual color decision was already made and reviewed in
prior features; introducing blue only here would itself be the inconsistency.

Exit rule met: all three rows fixed and re-verified (manually, end-to-end, before the
fixes; logically re-checked against the rendered JSX after, since the Chrome extension
used for this session's browser QA became unresponsive independently of the app — see
Process). Reference screenshot and this table are attached here in lieu of a second
implemented-state capture.

**AI review vs `docs/rulebooks/frontend-compliance-checklist.md`**:

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | New files follow the Project Shape; kebab-case files, PascalCase components, props interfaces above components; `'use client'` only on composer/canvas/modal/panels (state, hooks, mutations) — `card-front.tsx` itself carries no directive, reaching the client bundle transitively through `list-column.tsx`, same as 003's own convention |
| Data Flow | PASS | No direct backend fetches from client code — `cards-client.ts` is imported by client components only via `import type` (erased at compile time, same pattern `boards-client.ts` already established); every mutation invalidates `cards.getDetail`/`boards.getContent` (and `boardMembers.list` where membership can change); all inputs Zod-validated in `lib/cards/schemas.ts`. `dueStatus` is never re-derived client-side (only its display-style mapping, `lib/cards/due-status.ts`, shared with `card-front.tsx`); the checklist done/total shown in the modal is computed from the already-fetched `checklistItems` array itself — not a duplicate of a separately-returned aggregate (`CardDetail` has no such field to diverge from), so this isn't the "two implementations of one formula" duplication the rule targets |
| Forms | PASS (one disclosed convention split) | `CardComposer` and the comment form (new-record submissions) use React Hook Form + `zodResolver` + shadcn `Form`/`FormField`/`FormControl`/`FormMessage` — added during this review after finding they'd been wired directly to `form.register()` without the `Form` wrapper components 002's `board-members-panel.tsx` established. The single-value **inline edits** (title, description, due date, checklist quick-add) intentionally use plain `useState`, not RHF — matching this same checklist's own separate "inline edits match the prototype's contract: Enter commits, Escape cancels" bullet, which treats inline edits as their own category; RHF's schema/resolver ceremony doesn't fit a single controlled field with immediate persistence. `alert()` is never used; every mutation gives Sonner toast feedback (X-01); Enter/Escape semantics verified manually for the composer, title field, and checklist quick-add |
| UI States & Accessibility | PASS | Loading/error/populated states on the modal, activity feed, and members picker; label picker has an explicit empty state; Radix `Dialog`/`Popover` provide focus trap and restore-on-close for free; due-date/label/member indicators always pair color with text or an icon, never color alone |
| State, Styling | PASS | Server state only via tRPC/React Query, no Context/Redux added; per-entity dynamic colors (label/member avatar) stay inline `style` bound to real data, matching `card-front.tsx`'s existing precedent — the only inline `style` usage in this diff; every structural dimension (modal width, right-column width) is a Tailwind utility class, not a hardcoded style, after this review's Visual Compliance fixes replaced two inline dimensions that had been introduced mid-implementation while diagnosing what turned out to be a browser-cache issue, not a real Tailwind-compilation gap (see Process) |
| Security & Performance | PASS (gap found and fixed post-merge, see below) | No backend token reaches the client bundle (server-only `cards-client.ts`, type-only import elsewhere); no new `dangerouslySetInnerHTML`; activity feed is cursor-paginated and accumulates pages in local state rather than re-fetching from scratch; card lists remain far below the 150-card virtualization threshold. Observer-vs-Member/Admin **UI** gating was originally missing entirely (see "Post-merge fix" below) — the backend's own `CanMutate` check (Phase A) was never at risk, but the checklist item itself was wrongly marked PASS before that fix existed |
| Process | PASS | No new npm packages — `radix-ui` (already a dependency) covers every shadcn primitive added this phase; a `calendar` primitive (`react-day-picker` + `date-fns`) was generated once for the due-date picker, found to pull in two new packages outside plan.md's "no new dependencies" commitment, and removed in favor of a plain `<input type="date">` before anything was committed. Diff surface above is exactly T031–T053's scope; gate self-run clean, user confirmation requested below |

**Environment note (not a code defect)**: mid-session browser-based manual QA hit two
unrelated environment issues, both fully diagnosed and not present in the shipped code:
(1) the Next.js dev server's browser-side HTTP cache served a stale JS bundle across
several full process restarts, initially misread as a Tailwind responsive-variant
compilation gap — resolved via a hard reload, confirmed by a fresh production `next
build` containing every class in question; (2) the Chrome extension used for automated
browser QA became unresponsive late in this session, independent of the app (verified
live via direct backend API calls, which kept working). Every user story (US1–US8) was
manually exercised end-to-end and confirmed working, including the two real bugs listed
above, before the extension became unresponsive.

**Post-merge fix (found via `quickstart.md`'s own Observer edge-case row, after Phase B
had already been reviewed, gated, approved, merged, and pushed)**: manually testing
`quickstart.md`'s documented Observer edge case ("every control except the comment box
is absent or disabled") against the just-merged code surfaced that **no frontend
permission gating existed at all** — the AI review above had marked "Permission gating
hides/disables what the role cannot do" PASS without actually verifying it, which was
wrong. An Observer's board showed a fully clickable "+ Add a card" composer and a fully
populated card detail modal (editable title, Save button, checklist add form, the whole
"Add to card" panel); clicking any of them correctly got rejected by the backend's own
enforcement (`403`, surfaced as a toast — confirmed no data ever changed), but the UI
itself did not hide or disable anything, contradicting both `quickstart.md` and
`frontend-rules.md`. Fixed by computing `canMutate` once in `board-canvas.tsx` (session
`publicId` matched against `boardMembers.list`, defaulting to true only while that query
is still loading, so no flash of false lockout) and threading it to `list-column.tsx`
(hides the composer), `card-title-field.tsx` (plain text instead of the edit button),
`card-description-panel.tsx` (read-only text, or nothing when empty), `card-checklist-
panel.tsx` (checkboxes disabled, delete/add controls hidden), and `card-add-to-card-
menu.tsx` (the entire panel renders `null`) — `card-detail-modal.tsx` now receives
`canMutate` as a prop instead of computing its own. Re-verified end-to-end in the browser
signed in as a real Observer account (invited via the API): composer absent on every
list; opening a card shows a read-only title, no description-edit control, a read-only
checklist with no add form, no "Add to card" panel at all, and the comment box still
fully functional (a real comment was posted successfully). This diff is captured as a
**second commit** on top of the already-merged Phase B commit — re-gate and re-approval
requested below cover this fix specifically, not a re-review of everything already
approved.

**Verdict**: Phase B (original review) PASS — two real gaps found and fixed within that
review (the title-field double-save race; three Visual Compliance Loop deviations), one
disclosed data-availability limitation inherent to this feature's own contract (no
waiver — no endpoint to gap-fill from), one disclosed forms-convention split (inline
edits vs. new-record forms). **Post-merge**: one real gap found (missing Observer UI
permission gating, incorrectly marked PASS originally) and fixed, verified end-to-end
against a real Observer account. Cleared to commit this follow-up fix once the user
runs the frontend gate and confirms exit 0.
