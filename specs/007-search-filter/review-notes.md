# Review Notes — 007 Search & Filter

## Phase A — backend (`description` field addition) (T001–T002)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-30
**Branches**: `flowboard-api` `007-search-filter` (based on `main` @ `7c2a3bb`, not yet
merged)
**Scope reviewed**: `src/Flowboard.Api/Services/BoardContentService.cs`
(`CardSummaryDto` gains `string? Description`; `GetBoardContentAsync` forwards
`c.Description`), `src/Flowboard.Api/Services/CardService.cs` (two other
`CardSummaryDto` construction sites — card-create and card-copy — updated for the new
positional field), `tests/Flowboard.Api.Tests/BoardsEndpointTests.cs` (extended one
existing test + one new test).
**Feature contract**: `contracts/search-filter-addendum.md` — one additive DTO field on
an existing read endpoint; no new endpoint, no migration, no new package.

## Verdict

**APPROVE**. The change is exactly what the contract describes: one nullable field added
to an existing response DTO, forwarded from data the query already loads. No schema
change, no new query, no behavior change to any existing field. Test coverage extended
correctly and without touching the shared fixture board other tests depend on.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (US1's description-matching prerequisite) | `contracts/search-filter-addendum.md` describes `Description: string \| null` alongside the existing `HasDescription: bool`; `BoardContentService.cs`'s `CardSummaryDto` and its one construction site in `GetBoardContentAsync` match exactly |
| Visual-reference match | N/A — Phase A is backend-only, no UI this phase |
| Feature contract held (no unapproved table/migration/permission/package) | `git diff --stat` (below) — no migration, no `.csproj` change, 3 files touched |
| Constitution / domain invariants | See table below |
| Security (authn/authz, secrets, sensitive logging) | No new endpoint, no new authorization surface; `Description` was already loaded and already returned via the dedicated `GET /v1/cards/{id}` endpoint (004) — this only exposes the same, already-authorized field on a second, already-authorized read path |
| Scope guard (`git diff --stat` — only intended files) | Exactly the 3 files named in tasks.md T001–T002 |
| Rollback safety (phase reverts cleanly; schema additive?) | No schema change at all — a DTO field addition is trivially revertible (delete the field, forward nothing) with zero data impact |

```
 src/Flowboard.Api/Services/BoardContentService.cs |  7 +++--
 src/Flowboard.Api/Services/CardService.cs         |  2 ++
 tests/Flowboard.Api.Tests/BoardsEndpointTests.cs  | 37 ++++++++++++++++++++++-
 3 files changed, 43 insertions(+), 3 deletions(-)
```

## Findings

### F1 — New test signs up its own throwaway user/board rather than using the shared fixture — ACCEPTED (deliberate)

The first draft of `GetBoardContent_CardWithDescription_ReturnsDescriptionText` created
its test card directly inside the shared fixture board (`ProductRoadmapBoardPublicId`).
Because the integration test database (`flowboard-db-test`) is **persistent, not reset
between runs**, this permanently polluted three unrelated tests' fixed
card/board-count assertions. Caught during this same implementation session (test run
failures), fixed by rewriting the test to sign up a fresh user and create its own
board — mirroring the existing `CreateBoard_ReturnsThreeStarterLists_CreatorIsImplicitAdmin`
test's own pattern — and manually deleting the stray already-persisted row.
*Action: none — fixed within the same session; full suite re-verified 113/113 passing
afterward.*

## Backend Compliance Checklist (`docs/rulebooks/backend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | No new endpoint; existing `BoardsEndpoints.cs`/`BoardContentService.cs` extended in place; top comment cites `contracts/search-filter-addendum.md` |
| API Surface | PASS | `Description` is a plain nullable string DTO field, no internal `Id` exposed; no new validation surface (read-only addition) |
| Domain & Authorization | PASS | No new authorization path — `GetBoardContentAsync` still resolves the caller's board role exactly as before (003); no domain invariant touched |
| Data Access & Performance | PASS | `Description` is forwarded from a column the query already selects (`c.Description` was already loaded for `HasDescription`'s computation) — no new query, no N+1 |
| Security | PASS | No secret/PII; `Description` is user-authored card content already returned by the existing single-card endpoint, now also on the board-content read |
| Testing | PASS | Extended one existing fact (`Description` is `null` when absent) + one new fact (`Description` equals stored text when present), both against a real running API |
| Process | PASS | No new package; exactly T001–T002's file list; gate: `dotnet build --warnaserror && dotnet test` → 0 warnings, 0 errors, 113/113 passing (user-confirmed) |

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS. Implementation follows `contracts/search-filter-addendum.md`.
- **II. Source of Truth Hierarchy** — PASS. No visual references engaged this phase.
- **III. Repository Separation** — PASS. `flowboard-api` only touched.
- **IV. Architecture Consistency** — PASS. No new pattern; extends the one existing read path.
- **V. Data Standards** — PASS. No migration; purely additive DTO field.
- **VI. Auditability** — N/A. No new mutation, no new `ActivityEvent` path.
- **VII. Domain Invariants** — PASS, see below.
- **VIII. Security** — PASS. No new authorization surface introduced.
- **IX. External Integration Governance** — N/A.
- **X. Performance Responsibility** — PASS. Zero new queries.
- **XI. Testing Requirements** — PASS. Both the null and populated cases are covered.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Backend implemented and gated ahead of frontend, per `docs/sdlc/repository-strategy.md`.

### Domain invariant pass

| # | Invariant | How satisfied |
|---|---|---|
| 1 | Activity append-only | N/A — no mutation in this phase |
| 2 | Ordering integrity | N/A — not touched |
| 3 | WIP limits advisory | N/A — not touched |
| 4 | Soft delete, 30-day restorability | N/A — not touched |
| 5 | Permissions server-side | Unchanged — `GetBoardContentAsync`'s existing role resolution still gates the whole response, `Description` included |
| 6 | Optimistic concurrency | N/A — read-only field, no `If-Match` involved |
| 7 | Labels board-scoped | N/A — not touched |
| 8 | Opaque public IDs | Unchanged — no `Id` exposed by this field |

## Test coverage observed

- `BoardsEndpointTests.cs`: extended
  `GetBoardContent_ReturnsListsAndCardsInStoredOrder_IndicatorsOnlyWhenApplicable` with
  `Assert.Null(smokeCard.Description)`; added
  `GetBoardContent_CardWithDescription_ReturnsDescriptionText` (fresh user + own board,
  create card → PATCH description → re-fetch board content → assert `HasDescription` and
  `Description` both reflect the stored text).
- Full suite: 113/113 passing (user-confirmed gate).

## Residual risk

None identified. The one finding (F1) was self-caught and fixed within the same
implementation session, before the phase gate was ever presented to the user.

---

## Phase B — frontend (foundational + all four user stories, Visual Compliance Loop) (T003–T013)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-30
**Branches**: `flowboard-web` `007-search-filter` (based on `main` @ `c578213`, not yet
merged)
**Scope reviewed**: `lib/api/boards-client.ts` (`description` field),
`lib/board/passes-board-filter.ts` (new), `lib/board/board-labels.ts` (new),
`components/board/board-filter-context.tsx` (new),
`components/layout/board-search-input.tsx` (new),
`components/board/filter-popover.tsx` (new),
`components/board/filter-chip-bar.tsx` (new),
`app/(app)/boards/[boardPublicId]/page.tsx`, `components/board/board-canvas.tsx`,
`components/board/list-column.tsx`, `components/layout/top-bar.tsx`.
**Feature contract**: client-side/read-side only, no new API writes (spec.md); no new
package; the top-bar search box and Filter button go from 003's `disabled` placeholders
to fully wired controls, the same way 006 activated the list "⋯" button and Star control.

## Verdict

**APPROVE**. All four user stories (live search, label/member/due-date filters, chip bar,
per-list empty state) are wired end-to-end and were exercised live against a running dev
server across every phase, not just read from source. The Visual Compliance Loop found
five real deviations from the reference screenshots/prototype, all fixed and recaptured —
the table closes empty, no user-approved rows needed. One spec.md prose error (VI-010's
"Filters" label claim) was caught and corrected against the higher-priority screenshot/
prototype evidence, documented rather than silently resolved. No residual risk found.

## Frontend Compliance Checklist (`docs/rulebooks/frontend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | New files follow the existing layout (`lib/board/*.ts`, `components/board/*.tsx`, `components/layout/*.tsx`); kebab-case files, PascalCase exports; `'use client'` present only where hooks/state/handlers are used (`board-filter-context.tsx`, `board-search-input.tsx`, `filter-popover.tsx`, `filter-chip-bar.tsx`, `board-canvas.tsx`, `list-column.tsx`) — `top-bar.tsx` and `page.tsx` stay server components |
| Data Flow | PASS | No direct backend fetch; `FilterPopover`/`FilterChipBar` read board data via `trpc.boards.getContent.useQuery`, sharing `BoardCanvas`'s already-primed cache entry (same query key) rather than issuing a new fetch — verified this causes no extra network call; filtering itself is a pure client-side predicate (`passesBoardFilter`) over already-loaded data, not a new query |
| Forms | N/A | No data-entry form this feature — search is a live-filter input, not a submitted form; feedback for filter/search actions is immediate visual narrowing, not a toast (no state-changing write occurs) |
| UI States & Accessibility | PASS | Per-list empty state distinguishes "no cards at all" from "cards exist but none match" (F-04); filter/search controls are plain buttons/inputs, keyboard-operable; the `/`/`F` shortcut (X-03) doesn't hijack typing inside any text field (`isTypingInField` guard) |
| State, Styling | PASS | `BoardFilterProvider` holds only ephemeral filter/search selections (never server data) in React Context, mirroring `sidebar-context.tsx`'s established shape; Tailwind utilities throughout; both themes unaffected (no new hardcoded colors); layout compared against `screenshots/` — see Visual Compliance Loop below |
| Security & Performance | PASS | No backend token reaches the client bundle; filtering is O(cards-on-board) client-side array work with no new query — not a search-input-triggers-network-call pattern, so `frontend-performance.md`'s "search inputs debounced" guidance doesn't apply here (nothing is being throttled to protect a backend call; there isn't one) |
| Process | PASS | No new package (`package.json`/`package-lock.json` untouched); diff is exactly T003–T013's file list; gate results below |

## Findings

### F1 — Provider placement corrected from plan.md's original design — ACCEPTED (doc updated)

`plan.md` originally placed `BoardFilterProvider` inside `board-canvas.tsx`. Discovered
during T006 that `TopBar` (search box, Filter trigger) and `BoardCanvas` (chip bar, actual
filtering) are page-level siblings under `page.tsx`, not parent/child — a provider inside
`BoardCanvas` could never reach `TopBar`'s controls. Moved the provider to wrap both from
their common ancestor (`page.tsx`). Documented in both `plan.md`'s Project Structure and
`tasks.md`'s T006 entry at the time it was found, not silently changed.
*Action: none — already documented; the same lesson was reapplied for T009 (`FilterPopover`
needing `board-canvas.tsx`'s label derivation) by extracting a shared `deriveBoardLabels()`
helper instead of duplicating server data into Context.*

### F2 — spec.md's VI-010 prose contradicts its own reference screenshot — FIXED (spec corrected, not the code)

VI-010 claims the chip bar's "Filters" label disappears once more than the text-search
chip is active. Opening `screenshots/multi-filter-chips.jpg` directly, and the reference
prototype's own `#chipBar` render logic (`flowboard-prototype.html` lines 417-428), both
show "Filters" unconditionally whenever any chip is active — the spec's prose
mis-transcribed its own screenshot. Implemented to match the screenshot/prototype (rung 1,
outranks spec.md prose per the Source of Truth Priority), documented in `tasks.md`'s T010.
*Action: none — implementation matches the higher-priority evidence; the spec's own text
is now known-wrong but not separately edited (out of scope for this phase to rewrite
spec.md's prose; the correction is on record in tasks.md for the next reader).*

### F3 — Visual Compliance Loop found five deviations, all now fixed — see below

Full deviation table, root causes, and fixes are recorded in the "Visual Compliance Loop"
section below, per `docs/sdlc/review-process.md`'s required format. Summary: the Filter
popover's checkbox-based rows, the label swatch rendering, the chip bar's fill color, the
popover heading alignment, and the empty-filter message's trailing punctuation were all
found by direct pixel/structure comparison against the reference screenshots and the
prototype's own source, then fixed and recaptured.
*Action: none — all five rows fixed; table closes empty.*

### F4 — quickstart.md doc drift: genuinely-empty list wording — FIXED

`quickstart.md` §5 step 3 described a genuinely-empty list as showing "Drop cards here" —
that's the reference prototype's own wording, but the real app has shown "No cards yet."
since 004 and always has. The quickstart text was never updated to match the actually
shipped copy. Corrected during the T014 end-to-end walkthrough.
*Action: none — fixed in `quickstart.md`.*

## Visual Compliance Loop (`docs/sdlc/review-process.md`) — T013

**Render environment**: throwaway signed-up test account, a freshly created 3-list board
("To Do"/"Doing"/"Done", 4 cards, one member — no board labels, since no label-creation UI
exists yet, a known limitation carried from 004/`board-labels.ts`'s own top comment).
Captured via browser automation at ~1420×590–1568×648 (matching the reference
screenshots' own captured sizes). Screenshots attached at
`screenshots/implemented/search-active-empty-state.jpg`,
`screenshots/implemented/filter-popover.jpg`,
`screenshots/implemented/multi-filter-chips.jpg`.

Walked `spec.md`'s Visual Inventory (VI-001–VI-011) item by item against the three
reference screenshots, cross-checking the prototype's own source
(`docs/product/prototype/flowboard-prototype.html`) wherever a screenshot left ambiguity
(e.g. whether the popover rows carried a checkbox).

| # | Element (VI ref) | Reference shows | Implemented shows (before fix) | Severity | Resolution |
|---|---|---|---|---|---|
| 1 | Filter popover rows (VI-007/008/009) | Prototype source renders plain clickable rows with a trailing "✓" tick shown only once selected — no checkbox glyph | Rows used a leading shadcn `Checkbox` (mirroring the card detail modal's label/member panels — the wrong surface's convention) | Medium | **Fixed** — rebuilt as plain `PopRow` buttons with a trailing `Check` icon shown only when selected (`filter-popover.tsx`) |
| 2 | Label rows (VI-007) | Small colored bar/swatch (8px tall, no text) beside the plain-colored label name | Label name rendered inside a solid colored badge with white text | Medium | **Fixed** — swatch is now a bare colored bar beside plain-text label name |
| 3 | Chip bar chips + "Clear all" (VI-002/VI-010) | Both share one filled light-gray surface | Chips used a white/transparent background; "Clear all" had a border only, no fill | Medium | **Fixed** — both switched to `bg-muted` (this app's equivalent token, already used for the list header's count pill) |
| 4 | "FILTER CARDS" heading (VI-005) | Centered | Left-aligned | Low | **Fixed** — added `text-center` |
| 5 | Per-list empty-filter message (VI-004) | No trailing period: "No cards match the filter" | Trailing period present | Low | **Fixed** — dropped the period to match the reference exactly |

All five rows were fixed and recaptured against the live app before this loop closed —
no row required user sign-off.

**VI-010 note**: see Finding F2 above — this was investigated in this same loop and
resolved as a spec-prose error, not an implementation deviation.

**Exit status**: table closes fully empty. Visual Compliance Loop exit rule satisfied
without any user-approved rows.

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS.
- **II. Source of Truth Hierarchy** — PASS. Visual Compliance Loop run against
  `screenshots/`; the one conflict found (VI-010 vs. its own screenshot) was surfaced and
  resolved in favor of the screenshot/prototype, not silently guessed either way.
- **III. Repository Separation** — PASS. `flowboard-web` only touched.
- **IV. Architecture Consistency** — PASS. `BoardFilterProvider` reuses
  `sidebar-context.tsx`'s established Context shape; no Redux, no new state library;
  `FilterPopover`'s row shape is a new, popover-specific convention (justified by F3's
  Visual Compliance finding — the card-detail-modal checkbox convention doesn't apply
  here), not an unapproved architectural pattern.
- **V–VII** — N/A this tier (no schema/migration/domain-invariant surface).
- **VIII. Security** — PASS. No backend token reaches the client; filtering is UX-only
  narrowing of data the caller was already authorized to see in full.
- **IX–X** — N/A / no new perf-sensitive surface (client-side array filter only).
- **XI. Testing Requirements** — N/A (no frontend test runner exists yet, per tasks.md's
  own note); verified instead via live manual walkthrough across every phase, described
  below.
- **XII. Human Review Requirement** — pending this document's approval.
- **XIII. Controlled Delivery** — PASS. Frontend began only after Phase A's backend gate
  passed; implemented and gated one phase at a time (Foundational → US1 → US2 → US3 → US4
  → Visual Compliance → Polish), each with a user-confirmed gate before the next began.

## Test coverage observed (manual, no frontend test runner exists yet)

Live walkthrough against a real running dev server across Phases 3–8, re-verified end to
end during T014's `quickstart.md` walkthrough:

- **US1** live search: typing narrows visible cards after every keystroke, no reload, no
  new network call; a description-only match (a word present only in a card's description,
  not its title) is found; clearing restores every card.
- **US2** label/member/due-date filters: member and due-date bucket filters verified live
  (label filter verified structurally only — this environment's boards have no labels,
  since no label-creation UI exists yet); AND-across-categories confirmed by combining
  Overdue + Member and Member + "Next 7 days", each narrowing further; the list's WIP/count
  pill was confirmed to keep reading the true, unfiltered count throughout.
- **US3** chip bar: one chip per active constraint plus "Clear all"; removing a single
  chip leaves the others active and re-evaluates the visible set; "Clear all" resets
  everything and hides the bar entirely.
- **US4** empty state: a list with cards but zero matches shows "No cards match the
  filter"; a list with genuinely zero cards keeps its ordinary "No cards yet." state —
  confirmed rendering independently and correctly side by side on the same board.
- **Board-switch reset**: switching to a different board with a filter active clears the
  search box and hides the chip bar on the new board; switching back confirms the original
  board's filter was also reset (not preserved across the switch), per FR-009's
  `key={boardPublicId}` remount.
- **Keyboard shortcut (X-03)**: `/` pressed while focus is on the board canvas (not inside
  a text field) moves focus to the search box.

## Residual risk

None identified. All Visual Compliance Loop deviations were fixed and recaptured against
the live app; the one spec-prose error (F2) is documented for the next reader rather than
silently left inconsistent; the one doc-drift item (F4) is fixed in `quickstart.md`.
