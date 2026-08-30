# Implementation Plan: Search & Filter

**Branch**: `007-search-filter` | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-search-filter/spec.md`

## Summary

Activate the search box and Filter button already rendered (disabled) in the top bar
since 003 — live client-side text search over title+description, label/member/due-date-
bucket filters (AND across categories, OR within), a removable filter chip bar, and a
per-list "No cards match the filter" empty state. Entirely a display-layer transform over
data the board page already fetches (`trpc.boards.getContent`); the one gap found during
research is that card descriptions aren't in that payload yet, so `CardSummaryDto` gains
one additive `Description` field (no migration, no new endpoint — research.md R-2).

## Technical Context

**Language/Version**: C# / .NET 10 (backend, unchanged); TypeScript / Next.js 16 App
Router (frontend, unchanged)
**Primary Dependencies**: No new packages either side. Backend: one additive field on an
existing DTO (`BoardContentService.cs`), no new service method. Frontend: React Context
(matching `sidebar-context.tsx`'s existing pattern) — no new state library, no URL-param
library.
**Storage**: SQL Server — no migration. `Card.Description` already exists (004); this
feature only forwards a value the backend already loads into memory (research.md R-2).
**Testing**: `dotnet test` — one updated assertion in the existing
`GetBoardContentAsync`/`BoardsEndpointTests` coverage confirming `description` is present
in the response (no new endpoint to test). Frontend: no test runner exists yet (003
precedent) — verification is the Visual Compliance Loop + `quickstart.md`.
**Target Platform**: Web (existing Next.js/ASP.NET Core stack, unchanged)
**Project Type**: Web application (existing `flowboard-api` + `flowboard-web`, unchanged)
**Performance Goals**: Zero additional database queries and zero additional API calls
per search keystroke or filter selection (SC-002) — filtering is a synchronous, in-memory
array transform over data already in the `getContent` React Query cache. The one backend
change adds a field already resident in memory to an existing response, not a new query.
**Constraints**: Filtering MUST NOT alter `list.cardCount` or trigger any write (FR-007/
FR-008) — the WIP/count pill (006) always reflects the true, unfiltered `list.cards`
array; only what `ListColumn` *renders* is filtered, never the array method already used
for the pill's own count (research.md, `list-column.tsx:80,95` — `cardCount: cards.length`
already only ever runs against the true underlying array during drag/move, unaffected by
this feature).
**Scale/Scope**: No migration. Backend: one field added to one existing DTO record, one
line in one existing service method. Frontend: one new Context provider, one new hook
consumed by `TopBar`'s search input, a new `FilterPopover` component, a new
`FilterChipBar` component, and a filtering utility consumed by `ListColumn` where it
already renders `list.cards.map(...)`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist all-PASS, no
  `NEEDS CLARIFICATION` markers); this plan.md and tasks.md follow before any code.
- [x] **Source of Truth (II)**: Reference screenshots captured live from
  `docs/product/prototype/flowboard-prototype.html` for all three states this feature
  needs (search+chips+empty-state, filter popover, multi-filter AND) — see spec.md's
  Visual Inventory (VI-001…011). No conflict found between the prototype, spec.md, and
  `FUNCTIONAL_SPEC.md` §3.4/§4.2/§4.3 (research.md R-5).
- [x] **Repository Separation (III)**: `flowboard-api` (one additive DTO field) and
  `flowboard-web` (Context, popover, chip bar, filter predicate) stay separate; no mixing.
- [x] **Architecture Consistency (IV)**: No new framework, UI library, or persistence
  approach. Reuses the existing `sidebar-context.tsx` React Context pattern (research.md
  R-4), the existing `getContent` query as the single data source (no new tRPC procedure),
  and the existing popover/chip UI primitives (shadcn/ui `Popover`, already used by
  `list-actions-menu.tsx`).
- [x] **Data Standards (V)**: No new entity, no new primary key.
- [x] **Auditability (VI)**: No new entity; no write path at all in this feature, so no
  audit-field question arises.
- [x] **Domain Invariants (VII)**: See Domain Invariant Pass below.
- [x] **Security (VIII)**: No new endpoint, no new authorization surface — the additive
  `description` field is returned to exactly the same already-authorized caller
  `GetBoardContentAsync` already authorizes today, at the same read.
- [ ] **External Integration Governance (IX)**: N/A — no external integrations.
- [x] **Performance Responsibility (X)**: See Technical Context — zero new queries, zero
  new API calls per interaction; the one payload-size increase (`description` per card) is
  data already loaded into memory for every request today, not new transfer from the
  database, and is the minimum necessary for an approved requirement (FR-001/F-01).
- [x] **Testing Requirements (XI)**: Backend: an updated response-shape assertion for the
  new field. Frontend filtering (search-match, AND/OR combination logic, due-date bucket
  windows) is presentation logic without a frontend test runner (003 precedent) — verified
  via `quickstart.md`'s manual walkthrough and the Visual Compliance Loop, consistent with
  how 004/005/006 verified frontend logic.
- [x] **Human Review (XII)**: Same phased AI-then-human review as 001–006.
- [x] **Controlled Delivery (XIII)**: Backend phase (the one additive DTO field)
  implemented and gated before frontend, per `docs/sdlc/repository-strategy.md`'s
  cross-repository rule — same as 004/005/006, even though this backend phase is
  unusually small.

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`). This feature touches
no domain invariant newly, adds no write path, and is fully reversible (a display-only
filter) — clearly not a Critical-tier case.

## Architecture Decision Records

**ADR-29 — `description` forwarded on the existing board-content read, no new endpoint**:
`GetBoardContentAsync` (003/006) already selects `Card.Description` from the database on
every board load, today used only to compute the `HasDescription` boolean
(`BoardContentService.cs:157,209`). Search (FR-001) needs the actual text, not just its
presence. Rather than add a new endpoint or a lazy per-card fetch (which would defeat
"live, zero additional API calls" — FR-001/SC-002), `CardSummaryDto` gains one additive
`Description` field carrying a value already resident in memory. This is the same shape of
change 006 already made adding `RowVersion` to `BoardContentDto`/`ListContentDto` —
additive, no migration, no new endpoint (research.md R-2).

**ADR-30 — Filter/search state lives in a new `BoardFilterProvider` React Context, not
lifted state or URL params**: `TopBar` (search box, Filter trigger) and `BoardCanvas`
(chip bar, actual card filtering) are page-level siblings under
`app/(app)/boards/[boardPublicId]/page.tsx`, not parent/child — the same shape
`sidebar-context.tsx` already solves for collapse state shared between `TopBar`'s ☰
control and the layout-rendered `Sidebar`. `frontend-rules.md`'s State rule sanctions
Context for exactly this class of ephemeral, non-server UI state. The provider is keyed
per board page mount, so switching boards naturally resets filter state (FR-009) without
a manual reset effect (research.md R-4).

**ADR-31 — "Next 7 days" is a new client-side window check; "Overdue"/"No due date" reuse
the existing `dueStatus`/`dueAt` fields as-is**: There is no existing backend-computed
value equivalent to "Next 7 days" (the existing `dueStatus` enum's `"soon"` bucket means
"≤ 2 days," a different display-badge concept — FUNCTIONAL_SPEC's card-badge color rule,
unrelated to this filter). Inventing a bespoke backend field purely to satisfy
`frontend-rules.md`'s "don't re-derive backend-owned values" rule would add single-use
backend surface for a value nothing else needs, sorts by, or persists. "Overdue" and "No
due date," by contrast, already have an exact backend-computed equivalent
(`dueStatus === "overdue"`, `dueAt === null`) and reuse it directly, keeping the "don't
re-derive" rule meaningful rather than stretched past what it was protecting
(research.md R-3).

## Project Structure

### Documentation (this feature)

```text
specs/007-search-filter/
├── plan.md                              # this file
├── research.md
├── data-model.md
├── contracts/
│   └── search-filter-addendum.md
├── quickstart.md
├── screenshots/
│   ├── search-active-empty-state.jpg
│   ├── filter-popover.jpg
│   └── multi-filter-chips.jpg
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code

```text
flowboard-api/
├── src/Flowboard.Api/
│   └── Services/
│       └── BoardContentService.cs      # CardSummaryDto + Description field;
│                                          GetBoardContentAsync forwards c.Description
│                                          (already selected, ADR-29)
└── tests/Flowboard.Api.Tests/
    └── BoardsEndpointTests.cs           # + assertion: getContent response includes
                                           description per card

flowboard-web/
├── src/
│   ├── lib/
│   │   └── api/
│   │       └── boards-client.ts        # CardSummary + description: string | null
│   ├── app/(app)/boards/[boardPublicId]/
│   │   └── page.tsx                    # wraps <TopBar>+<BoardCanvas> in
│   │                                     <BoardFilterProvider key={boardPublicId}> —
│   │                                     TopBar and BoardCanvas are page-level siblings,
│   │                                     not parent/child (corrected during
│   │                                     implementation; plan originally placed the
│   │                                     provider inside board-canvas.tsx, which cannot
│   │                                     reach TopBar's search input)
│   ├── components/
│   │   ├── layout/
│   │   │   └── top-bar.tsx             # search input becomes functional (useBoardFilter);
│   │   │                                 Filter button opens FilterPopover
│   │   └── board/
│   │       ├── board-filter-context.tsx    # NEW — BoardFilterProvider/useBoardFilter
│   │       │                                 (ADR-30): { text, labelIds, memberIds, due },
│   │       │                                 setters, clearAll()
│   │       ├── filter-popover.tsx          # NEW — labels/members/due-date sections
│   │       │                                 (VI-005…009), mirrors list-actions-menu.tsx's
│   │       │                                 popover shape
│   │       ├── filter-chip-bar.tsx         # NEW — one chip per active constraint +
│   │       │                                 Clear all (VI-002/VI-010), hidden when empty
│   │       ├── board-canvas.tsx            # renders FilterChipBar above the list row
│   │       └── list-column.tsx             # list.cards.map(...) filters through
│   │                                         passesBoardFilter(card, filter) before
│   │                                         rendering; empty-state branch distinguishes
│   │                                         "no cards" vs "no cards match the filter"
│   │                                         (FR-006) — list.cardCount/pill untouched
│   └── lib/
│       └── board/
│           ├── passes-board-filter.ts      # NEW — pure predicate, research.md R-5
│           │                                 (search substring match, OR-within/AND-across,
│           │                                 due-date bucket windows)
│           └── board-labels.ts             # NEW — deriveBoardLabels(board), extracted
│                                             from board-canvas.tsx's inline useMemo during
│                                             T009 so filter-popover.tsx (a TopBar sibling,
│                                             not a BoardCanvas child) can reuse the same
│                                             label-roster derivation instead of
│                                             duplicating it
```

**Structure Decision**: Extends the existing single-service-per-tier layout from
001–006; no new top-level directories. `board-filter-context.tsx`, `filter-popover.tsx`,
`filter-chip-bar.tsx`, and `passes-board-filter.ts` are new files following the existing
`components/board/` and `lib/<feature>/` conventions (frontend-rules.md Structure), not a
new architectural layer.

## Domain Invariant Pass

| # | Invariant | How this feature satisfies it |
|---|---|---|
| 1 | Activity Is Append-Only | Unaffected — no write path exists in this feature at all |
| 2 | Ordering Integrity | Unaffected — filtering never reorders `list.cards`/`board.lists`, only changes what a subset renders |
| 3 | WIP Limits Are Advisory | Unaffected — the WIP/count pill continues reading `list.cardCount` (the true, unfiltered count), never a filtered length (FR-008, Technical Context Constraints) |
| 4 | Soft Delete | Unaffected — no delete path; a filtered-out card is never soft-deleted, only hidden from render |
| 5 | Permissions Enforced Server-Side | Unaffected — no new authorization decision; the additive `description` field is returned to the same already-authorized caller at the same read |
| 6 | Optimistic Concurrency | Unaffected — no write path, so no `RowVersion`/`If-Match` question arises |
| 7 | Labels Are Board-Scoped | Unaffected — label filter reads `boardLabels`, already board-scoped (004's known-limitation note in `board-canvas.tsx`) |
| 8 | Opaque Public Identifiers | Unaffected — filtering addresses nothing by ID; label/member filter selections are keyed by the `publicId`s already present in `CardSummaryDto.Labels`/`Members` |

## Complexity Tracking

No violations to justify — this feature adds no new pattern, framework, persistence
approach, or endpoint; both ADRs above apply an already-established pattern
(`sidebar-context.tsx`'s Context shape, 006's additive-DTO-field shape) rather than
introducing a new one.
