# Implementation Plan: Board View (Read-Only)

**Branch**: `003-board-view-readonly` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-board-view-readonly/spec.md`
**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — this feature
extends existing read access (002's `BoardAccessService`) to board content; it does not
change authentication, authorization logic, or perform any irreversible operation, so
none of the Critical triggers apply. Full Definition of Done still applies in full.

## Summary

Give every board FlowBoard has authorized a user for somewhere real to be seen: a
persistent sidebar listing the boards a signed-in user has access to, and a board canvas
rendering that board's actual lists and cards — read-only, matching the prototype's
visual layout exactly, reusing 002's server-side access enforcement unchanged. This is
also the first feature to introduce the core Kanban data model (`List`, `Card`, `Label`
and their join/child tables) and a real content seed (the prototype's three boards),
which every later board feature (004–007) builds on. Two delivery phases,
cross-repository: Phase A (backend: schema, seed, read endpoints) gates and merges first
per `docs/sdlc/repository-strategy.md`; Phase B (frontend: sidebar, app shell, board
canvas) follows against the stable contract, and runs the Visual Compliance Loop against
`screenshots/board-canvas.png` before requesting its gate.

## Technical Context

**Language/Version**: C# / .NET 10 (unchanged); TypeScript 5 strict / Node 22 (unchanged)
**Primary Dependencies**: unchanged from 002 — no new NuGet or npm package is needed for
this feature (EF Core, minimal APIs, tRPC, Tailwind/shadcn already present); the board
canvas is built from existing primitives, not a new drag/grid/virtualization library
(none of those are needed yet — no drag-and-drop until 005, no virtualization needed at
this feature's seed scale).
**Storage**: SQL Server — same `flowboard-db`/`flowboard-db-test` as 002. One new
migration (`AddBoardContent`) adding `List`, `Card`, `Label`, `CardLabel`, `CardMember`,
`ChecklistItem`, `Comment`, plus two additive columns on the existing `Board` table.
**Testing**: backend — `WebApplicationFactory` integration tests against
`flowboard-db-test`, covering success/empty-state/access-denied for both endpoints and a
golden-fixture-style assertion on the seeded board's exact rendered shape (card counts,
due-date bucketing, WIP-limit-exceeded flag) so a future migration can't silently drift
the fixture the Visual Compliance Loop depends on; frontend — gate stays `npm run lint &&
npm run build` (still no frontend test runner, unchanged since 001).
**Target Platform**: unchanged — web, latest two versions of Chrome/Edge/Firefox/Safari;
dev on Windows.
**Project Type**: web application, two nested repos (unchanged, constitution III).
**Performance Goals**: `GET /v1/boards/{id}` single-hydration call stays a small, fixed
number of queries (one per entity type, projected with `.Select()`, no N+1 across
lists→cards→labels/members) regardless of board size at this feature's seed scale;
`GET /v1/boards` is one indexed, cursor-paginated query.
**Constraints**: due-date bucketing (`dueStatus`) is computed server-side, never
re-derived client-side (`frontend-rules.md`); lists/cards render in stored `Position`
order — the frontend MUST NOT re-sort; WIP limits are display-only, never enforced
(invariant 3); no card, list, or board mutation ships in this feature at all.
**Scale/Scope**: 1 new backend endpoint group (`BoardsEndpoints`) with 2 endpoints + 1
migration (7 new tables, 2 new columns); frontend: a new authenticated app-shell layout,
`Sidebar`, board canvas + `List`/`Card` components, `boards` tRPC router.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist PASS, all
  items); this plan precedes tasks.md and implementation.
- [x] **Source of Truth (II)**: `screenshots/board-canvas.png` (a real prototype capture)
  is rung 1 and governs the frontend phase's Visual Compliance Loop; spec → this plan →
  contracts → data model have no conflicts (checked below, post-design).
- [x] **Repository Separation (III)**: Backend work (schema, endpoints) lands only in
  `flowboard-api`; frontend (shell, sidebar, canvas, router) only in `flowboard-web`.
- [x] **Architecture Consistency (IV)**: ADR-12/ADR-13 below, approved in this plan; no
  new package, no contradiction of 001/002's ADRs. New entities follow 002's existing
  EF Core + `Data/Configurations/` pattern (ADR-6) without modification.
- [x] **Data Standards (V)**: Every new entity uses `Id INT IDENTITY` + `PublicId` where
  this feature's API returns it as an individually identified item (`List`, `Card`,
  `Label`); `CardLabel`/`CardMember` are pure joins (no `PublicId`, like `BoardMember`);
  `ChecklistItem`/`Comment` have no `PublicId` yet — not exposed individually by this
  feature's API (data-model.md).
- [x] **Auditability (VI)**: `List`/`Card` get full audit + soft-delete fields (invariant
  4's list). `Label`/`CardLabel`/`CardMember`/`ChecklistItem`/`Comment` get audit fields
  only (none are named in invariant 4's soft-delete list; no delete endpoint exists yet
  for any of them in this feature to make the question live).
- [x] **Domain Invariants (VII)**: See the dedicated pass below — invariants 2, 3, 4, 5,
  7, 8 all engage; 1 and 6 are N/A (no mutations exist in this feature to append an
  activity event for or to race).
- [x] **Security (VIII)**: No change to authentication/authorization — both new
  endpoints reuse 002's `BoardAccessService`/JWT bearer auth unchanged. No secret is
  introduced. No sensitive data in the new tables' logs (no logging exists in this
  backend at all, per 002's precedent).
- [x] **External Integration Governance (IX)**: No external integrations in this
  feature.
- [x] **Performance Responsibility (X)**: Every list-returning query projects with
  `.Select()` into DTOs, `AsNoTracking()`, no navigation-property access in a loop;
  `GET /v1/boards` is cursor-paginated (R-3) per `backend-rules.md`'s unconditional
  requirement for list endpoints.
- [x] **Testing Requirements (XI)**: Both endpoints get success/empty/access-denied
  integration tests; the seeded board's exact rendered shape (counts, `dueStatus`
  values, WIP-exceeded flag) is asserted as a golden fixture so a future change can't
  silently break what the Visual Compliance Loop's reference screenshot depends on.
- [x] **Human Review (XII)**: Standard human review (this feature is not Critical — no
  independent-approval substitute required, unlike 002).
- [x] **Controlled Delivery (XIII)**: Two phases (A backend, B frontend), cross-repo
  ordering per `docs/sdlc/repository-strategy.md`. Standard delivery: an agent-run
  fast-feedback gate loop is permitted during implementation (`docs/sdlc/gate-command.md`)
  — unlike 002, this is not restricted to human-only runs — but the certifying run
  toward Done is always the user's.

## Architecture Decisions (constitution IV — extending 001/002's founding record)

### ADR-12 — Cursor pagination pattern for list endpoints

- **Options considered**: (a) no pagination (return every board); (b) offset/page-number
  pagination; (c) opaque cursor pagination (`cursor`/`limit` request params,
  `{items, nextCursor}` response shape).
- **Decision**: (c). `backend-rules.md` requires server-side pagination for list
  endpoints unconditionally, and FUNCTIONAL_SPEC §7 states "all list endpoints are
  cursor-paginated" as the project-wide contract, not a per-feature choice. This is the
  first list endpoint built since that rule was written, so the concrete shape is fixed
  here: `cursor` is an opaque string (implementation detail: a serialized sort key, not
  a raw offset — never parsed or constructed by the client), `limit` defaults to 20/caps
  at 50, response is `{ items: T[], nextCursor: string | null }`.
- **Consequences**: every later list endpoint (search results, archived-item lists,
  activity feeds) reuses this exact shape rather than inventing its own — a shared
  `CursorPage<T>` DTO type lives alongside `Result<T>` in `Domain/` for that reuse.

### ADR-13 — Frontend: authenticated app-shell route group (`(app)`)

- **Options considered**: (a) each authenticated page renders its own `Sidebar`
  instance; (b) a shared `app/(app)/layout.tsx` route group wrapping every
  authenticated page (home, board) with one persistent `Sidebar` + board-aware `TopBar`.
- **Decision**: (b). No sidebar exists anywhere yet (001 built only a top bar; 002's
  board page renders standalone, per its own "T053: the seam 003 extends into" comment).
  Every authenticated screen needs the same sidebar (FR-001) and the same
  "which board is open" highlighting state — that belongs in one shared layout, not
  duplicated per page. `app/page.tsx` and `app/boards/[boardPublicId]/page.tsx` move
  under `app/(app)/` (URLs unchanged — route groups add no path segment); `app/(auth)/`
  is untouched.
- **Consequences**: `TopBar` (existing, `components/layout/top-bar.tsx`) gains an
  optional board-summary prop and renders the full VI-004/VI-005 layout only when a
  board is open, keeping one component instead of forking it (R-6). 004+ extend this
  same layout rather than re-deciding where the shell lives.

## Package approvals (constitution IV)

None. No new NuGet or npm package this feature (Technical Context above).

## Project Structure

### Documentation (this feature)

```text
specs/003-board-view-readonly/
├── spec.md
├── plan.md                       # This file
├── research.md                   # Phase 0 output
├── data-model.md                 # Phase 1 output
├── quickstart.md                 # Phase 1 output
├── screenshots/
│   └── board-canvas.png          # rung-1 visual reference (copy of the prototype's own preview-board.png)
├── contracts/
│   └── board-content-api.md      # Phase 1 output
└── tasks.md                      # /speckit.tasks output (next step)
```

### Source Code (both nested repos)

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Data/
│   │   └── Configurations/
│   │       ├── BoardConfiguration.cs          # EDITED: + Color, Starred
│   │       ├── ListConfiguration.cs           # NEW
│   │       ├── CardConfiguration.cs           # NEW
│   │       ├── LabelConfiguration.cs          # NEW
│   │       ├── CardLabelConfiguration.cs      # NEW
│   │       ├── CardMemberConfiguration.cs     # NEW
│   │       ├── ChecklistItemConfiguration.cs  # NEW
│   │       └── CommentConfiguration.cs        # NEW
│   ├── Migrations/
│   │   └── <timestamp>_AddBoardContent.cs     # NEW — schema + HasData seed (R-4)
│   ├── Domain/
│   │   ├── Entities/
│   │   │   ├── List.cs, Card.cs, Label.cs, CardLabel.cs, CardMember.cs,
│   │   │   │   ChecklistItem.cs, Comment.cs   # NEW
│   │   └── CursorPage.cs                      # NEW — ADR-12's shared pagination DTO
│   ├── Endpoints/
│   │   └── BoardsEndpoints.cs                 # NEW — GET /v1/boards, GET /v1/boards/{id}
│   └── Services/
│       └── BoardContentService.cs             # NEW — read-only queries behind both endpoints
└── tests/Flowboard.Api.Tests/
    └── BoardsEndpointTests.cs                 # NEW

flowboard-web/
└── src/
    ├── app/
    │   └── (app)/                             # NEW route group
    │       ├── layout.tsx                     # NEW — Sidebar + TopBar shell, auth guard
    │       ├── page.tsx                       # MOVED from app/page.tsx (unchanged content)
    │       └── boards/[boardPublicId]/page.tsx # MOVED from app/boards/... ; extended to render the canvas
    ├── components/
    │   ├── layout/
    │   │   ├── sidebar.tsx                    # NEW
    │   │   └── top-bar.tsx                    # EDITED — board-aware (ADR-13/R-6)
    │   └── board/                             # NEW — feature-scoped domain components
    │       ├── board-canvas.tsx
    │       ├── list-column.tsx
    │       └── card-front.tsx
    ├── server/api/
    │   └── routers/
    │       └── boards.ts                      # NEW — list / getContent (protectedProcedure)
    └── lib/
        └── api/
            └── boards-client.ts                # NEW — server-only fetch: list, getContent
```

**Structure Decision**: extends 001/002's structure without new top-level folders.
Backend stays the single `Flowboard.Api` project (ADR-6, unchanged); new entities and
their configurations follow the exact pattern 002 established. Frontend adds
`app/(app)/` (ADR-13) and `components/board/` — both already named as conventions in
`frontend-rules.md`'s Structure section ("`<feature>/` — feature-scoped domain
components (board canvas, lists, cards, modals)"), not invented here.

## Implementation Phases (constitution XIII)

- **Phase A — backend (provider tier, gates and merges first per repository-strategy.md)**:
  `AddBoardContent` migration (schema + seed); `BoardContentService`; `BoardsEndpoints`
  (`GET /v1/boards`, `GET /v1/boards/{id}`); `CursorPage<T>`; integration tests
  (success/empty/access-denied + the golden-fixture shape assertion). Ends: user runs
  the backend gate (`dotnet build --warnaserror && dotnet test`), confirms exit 0; AI +
  human review; commit.
- **Phase B — frontend (consuming tier, starts once Phase A's contract is stable)**:
  `app/(app)/` route group + `Sidebar` + board-aware `TopBar`; `BoardCanvas`/
  `ListColumn`/`CardFront` components; `boards` tRPC router +
  `lib/api/boards-client.ts`. Runs the **Visual Compliance Loop**
  (`docs/sdlc/review-process.md`) against `screenshots/board-canvas.png` before
  requesting the gate — the deviation table must be empty or user-approved. Ends: user
  runs the frontend gate (`npm run lint && npm run build`), confirms exit 0; AI + human
  review (including the UI-vs-reference check); commit.

## Domain-invariant pass (recorded here since this is Standard, not Critical — no
separate addendum requires it, but the plan should still show the reasoning)

| # | Invariant | Applies? | How this plan satisfies it |
|---|---|---|---|
| 1 | Activity Is Append-Only | No | No state-changing card action exists in this feature (R-2). |
| 2 | Ordering Integrity | Yes | `List.Position`/`Card.Position` are `float`, seed-assigned; reads are ascending-order, `Id`-tiebreak; no move endpoint, so no renumbering risk this feature (R-8). |
| 3 | WIP Limits Are Advisory | Yes | `List.WipLimit` is rendered, never enforced — no code path in this feature could block anything on it (R-7). |
| 4 | Soft Delete, 30-Day Restorability | Yes | `List`/`Card` carry the full soft-delete trio + query filter, matching `Board`/`Workspace`'s existing pattern; unused (no delete endpoint) but present per the standard. |
| 5 | Permissions Enforced Server-Side | Yes | `GET /v1/boards/{id}` calls `BoardAccessService.ResolveAsync` first, unchanged from 002 — this feature adds no new authorization logic, only a new resource that logic gates. |
| 6 | Optimistic Concurrency | No | `Card.RowVersion` exists (schema-ready for 004) but no endpoint in this feature performs a field edit to race. |
| 7 | Labels Are Board-Scoped | Yes | `Label.BoardId` FK; seed data is trusted correct (no write endpoint yet to violate it). |
| 8 | Opaque Public Identifiers | Yes | Every entity this feature's API returns as an individually identified item (`Board`, `List`, `Card`, `Label`) carries `PublicId`; internal `Id` never leaves `BoardContentService`. |

## Complexity Tracking

No unjustified constitution violations. The two new patterns (cursor pagination, the
`(app)` route group) are approved above through ADR-12/ADR-13, not exceptions.
