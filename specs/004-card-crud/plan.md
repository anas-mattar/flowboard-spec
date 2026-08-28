# Implementation Plan: Card Lifecycle CRUD

**Branch**: `004-card-crud` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-card-crud/spec.md`
**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — this feature adds
new mutations, but none of them touch authentication, authorization *logic* (it reuses
002's `BoardAccessService` unchanged, only applying it to new resources), and every
mutation is soft-delete/reversible. No Critical trigger applies.

## Summary

Turn 003's read-only board view into a real, working card lifecycle: create, open,
rename, describe, label, assign, date, checklist, comment, copy, and delete a card, plus
the activity feed that proves every one of those actions actually happened. Two
delivery phases, cross-repository (`docs/sdlc/repository-strategy.md`): Phase A
(backend — one migration, one endpoint group, one activity/ordering module) gates and
merges first; Phase B (frontend — composer, the first modal this product has ever had,
and the first client-driven board canvas) follows against the stable contract, running
the Visual Compliance Loop against `screenshots/card-detail-modal.png` before its gate.

## Technical Context

**Language/Version**: C# / .NET 10 (unchanged); TypeScript 5 strict / Node 22
(unchanged)
**Primary Dependencies**: unchanged from 001–003 — no new NuGet or npm package.
Frontend already carries everything this feature needs: `sonner` (X-01 toasts —
`<Toaster />` is already mounted in the root layout and already used by 002's auth/
board-member forms), `react-hook-form` + `@hookform/resolvers/zod` (every data-entry
form here follows that existing pattern), `@tanstack/react-query` via tRPC (the existing
invalidate-on-mutate pattern from `board-members-panel.tsx`). No rich-text editor
package is added — see ADR-15.
**Storage**: SQL Server, same `flowboard-db`/`flowboard-db-test`. One migration
(`AddCardActivity`): one new table (`ActivityEvent`) and one new column
(`ChecklistItem.PublicId`) — every other table this feature writes to (`Card`,
`CardLabel`, `CardMember`, `ChecklistItem`, `Comment`) already exists from 003's
forward-looking schema (data-model.md there flagged exactly this).
**Testing**: backend — `WebApplicationFactory` integration tests per endpoint (success,
validation failure, authorization failure, and a genuine concurrency-conflict test for
the one endpoint that takes `If-Match`); a golden-fixture test for the ordering module's
midpoint math (`backend-rules.md`'s requirement for position/ranking logic). Frontend
gate stays `npm run lint && npm run build` (still no frontend test runner).
**Target Platform**: unchanged — web, latest two browser versions; dev on Windows.
**Project Type**: web application, two nested repos (unchanged, constitution III).
**Performance Goals**: `GET /v1/cards/{id}` and `GET /v1/cards/{id}/activity` are each a
small, fixed number of projected queries (no N+1); every mutation is a single
`SaveChangesAsync()` plus exactly one `ActivityEvent` insert, never a loop of writes.
**Constraints**: `dueStatus` stays server-computed (unchanged rule from 003, exercised
by writes for the first time here); positions use the sparse-`float` model fixed in
001's ADR-4, never renumbered; WIP limits stay display-only (invariant 3) — card
creation MUST NOT be blocked by an exceeded limit; every mutation this feature performs
appends exactly one `ActivityEvent`, never edits or deletes one (invariant 1).
**Scale/Scope**: 1 migration; 1 new backend endpoint group (`CardsEndpoints`, ~14
routes) over 1 new service (`CardService`) plus the first real use of the
`Flowboard.Api/Domain/Ordering.cs` module 001 reserved; frontend: an inline card
composer, the product's first modal (`CardDetailModal` and its sub-panels), the board
canvas's first client-driven data layer, and a `cards` tRPC router.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist PASS, all
  items); this plan precedes tasks.md and implementation.
- [x] **Source of Truth (II)**: `screenshots/card-detail-modal.png` (a real prototype
  capture, reserved for this feature by 003's own spec) is rung 1 and governs the
  frontend phase's Visual Compliance Loop; spec → this plan → contracts → data model
  checked for conflicts below (none found).
- [x] **Repository Separation (III)**: Backend work (schema, endpoints, ordering module)
  lands only in `flowboard-api`; frontend (composer, modal, router) only in
  `flowboard-web`.
- [x] **Architecture Consistency (IV)**: ADR-14 through ADR-18 below, approved in this
  plan; no new package; no contradiction of 001–003's ADRs. New entity/column follow
  002/003's existing EF Core + `Data/Configurations/` pattern unmodified.
- [x] **Data Standards (V)**: `ActivityEvent` gets `Id INT IDENTITY` — no `PublicId`
  (not individually addressed by URL, only listed inside its card's feed, same
  reasoning 003 already applied to `Comment`/`ChecklistItem`). `ChecklistItem` gains
  `PublicId` now that it's individually addressed (tick/delete by id) — exactly what
  003's data-model.md flagged this feature would need.
- [x] **Auditability (VI)**: `ActivityEvent` is append-only by design (invariant 1) —
  `CreatedDate`/`CreatedBy` only, no `Updated*`/soft-delete fields (there is no update or
  delete path for an event, ever). `ChecklistItem` keeps its existing audit fields;
  `Card`'s existing soft-delete trio is exercised for the first time by FR-012.
- [x] **Domain Invariants (VII)**: full pass below — every invariant from 1–8 engages
  in this feature except none are N/A this time (unlike 003, which had five inert
  invariants with nothing yet to violate).
- [x] **Security (VIII)**: no change to authentication/authorization mechanism — every
  new endpoint resolves the caller's role via 002's existing `BoardAccessService`
  (through the card's list → board), then applies spec §6's matrix (Observer:
  view+comment only). No secret introduced. Card `Description`/`Comment.Body` are
  rendered as plain text, never `dangerouslySetInnerHTML` (ADR-15) — no new XSS surface.
- [x] **External Integration Governance (IX)**: no external integrations.
- [x] **Performance Responsibility (X)**: every mutation is one `SaveChangesAsync()` +
  one event insert; `GET /v1/cards/{id}` and the activity feed are both projected with
  `.Select()`, `AsNoTracking()`; the activity feed is cursor-paginated (ADR-12 reused).
- [x] **Testing Requirements (XI)**: every endpoint gets success/validation/
  authorization-failure integration tests; the concurrency-conflict path gets its own
  test (two sequential edits, second rejected); `Ordering.cs`'s midpoint math gets a
  golden-fixture test (hand-worked expected positions) per `backend-rules.md`.
- [x] **Human Review (XII)**: standard human review (not Critical — no independent-
  approval substitute required).
- [x] **Controlled Delivery (XIII)**: two phases (A backend, B frontend), cross-repo
  ordering per `repository-strategy.md`. Standard delivery: an agent-run fast-feedback
  gate loop is permitted during implementation; the certifying run is always the
  user's.

## Architecture Decisions (constitution IV — extending 001–003's founding record)

### ADR-14 — Card detail modal: client-side dialog state, no deep-link route

- **Options considered**: (a) a Next.js intercepting/parallel route (`@modal` slot) so a
  card has its own URL and refresh-persists; (b) a plain client-side dialog (shadcn
  `Dialog`) opened by local state when a card is clicked, closed by state, no URL
  change.
- **Decision**: (b). This is the first modal this product has ever built — introducing
  parallel/intercepting routes at the same time would be two new architectural patterns
  in one feature for a capability (deep-linking directly to a card) nothing in spec.md
  or the prototype asks for. The prototype itself has no URL for an open card either.
- **Consequences**: opening a card is `useState<string | null>` (the open card's
  `publicId`) lifted to the client-driven canvas (ADR-16); sharing a direct link to one
  card is not possible from this feature — a reasonable, low-cost future addition if a
  later feature needs it, not a blocker here.

### ADR-15 — Card description: plain text, not rich text

- **Options considered**: (a) a WYSIWYG/rich-text editor producing HTML, rendered with
  `dangerouslySetInnerHTML` behind a sanitizer (what FUNCTIONAL_SPEC's C-05 wording,
  "rich-text description," suggests); (b) plain multi-line text, rendered as text.
- **Decision**: (b). Per constitution II's Source of Truth Hierarchy, the prototype
  screenshot (`screenshots/card-detail-modal.png`, rung 1) — which FUNCTIONAL_SPEC.md
  itself is derived from — shows a plain `<textarea>` with no formatting toolbar; the
  higher-fidelity rung overrides C-05's "rich-text" wording. `frontend-rules.md`
  explicitly deferred this exact call to this plan ("card descriptions (C-05 rich text)
  render through a sanitizing renderer decided in 004's plan.md").
- **Consequences**: `Card.Description` stays plain `NVARCHAR(MAX)` (already the schema
  from 003, unchanged); the frontend renders it as text with `whitespace-pre-wrap` for
  line breaks, never through `dangerouslySetInnerHTML` — no sanitizer is needed because
  no HTML is ever produced or rendered. If a real rich-text editor is wanted later,
  that's a new feature's explicit decision, not a silent scope-creep here.

### ADR-16 — Activity feed sourced from one append-only table; comments embed their body

- **Options considered**: (a) the feed endpoint joins/merges `Comment` and
  `ActivityEvent` by timestamp at read time; (b) every mutation — including adding a
  comment — writes exactly one `ActivityEvent` row, with a small `Payload` (JSON)
  carrying whatever that event type needs to render (a comment's body, a rename's new
  title, a due-date's new value); `Comment` stays as the normalized, secondary record of
  a comment's body (already modeled in 003) but the feed itself never reads it.
- **Decision**: (b) — already committed to in spec.md's Key Entities section
  ("ActivityEvent... the sole source of the activity feed"). One table, one query, one
  chronological order; no cross-table merge logic to get right or keep right.
- **Consequences**: `POST .../comments` writes both a `Comment` row (FK'd, in case a
  later feature needs to query/edit/delete a comment on its own — out of this feature's
  scope) and a `comment.added` `ActivityEvent` whose `Payload` embeds the comment's body
  directly. `ActivityEvent.Payload` is a small JSON blob per event type (`card.renamed`:
  `{title}`; `label.added`/`removed`: `{labelName, labelColor}`; `member.assigned`/
  `unassigned`: `{displayName}`; `due.set`/`cleared`/`completed`: `{dueAt}` or none;
  `checklist.item.added`/`checked`: `{text, done}`; `comment.added`: `{body}`) — decoded
  only by the feed's own DTO mapper, never by another feature.

### ADR-17 — Optimistic concurrency via standard HTTP conditional headers

- **Options considered**: (a) a version number/token in the request/response JSON body;
  (b) standard HTTP `ETag` (response) / `If-Match` (request) headers, mapped to `Card`'s
  existing `RowVersion` column.
- **Decision**: (b) — `backend-rules.md` and invariant 6 both already say "`If-Match`"
  by name; this is the standard HTTP mechanism the rules were written against, not a
  new one invented here. `GET /v1/cards/{id}` returns `ETag: "<base64 RowVersion>"`;
  `PATCH /v1/cards/{id}` requires `If-Match` with that value; a mismatch → `409`.
- **Consequences**: only `PATCH /v1/cards/{id}` (title/description/due-date fields)
  needs this — the discrete add/remove endpoints (labels, members, checklist items,
  comments) are idempotent joins/appends, not field overwrites, so they don't race the
  same way and don't need a token (`docs/domain/flowboard-invariants.md` invariant 6
  scopes the rule to "card field edits"). The frontend's 409 handler re-fetches the card
  (via the same tRPC query invalidation the rest of this feature already uses) and
  surfaces the "changed by someone else" toast from spec.md's FR-013 — it never retries
  the write automatically.

### ADR-18 — Ordering module gets its first real use (copy, and append-to-bottom)

- 001's ADR-4 already reserved `Flowboard.Api/Domain/Ordering.cs` for all
  position/ranking math (invariant 2) and required it to be golden-fixture tested "when
  introduced." This feature introduces it: `Ordering.Append(lastPosition)` (new cards,
  C-01 — placed after the current last card, or a fixed start value on an empty list)
  and `Ordering.InsertBetween(lowerPosition, upperPosition)` (card copy, C-12 —
  "directly below the original," i.e. the midpoint between the original's position and
  whatever came after it, or `Append` if the original was last).
- **Consequences**: no other feature re-implements midpoint math inline (backend-rules
  "one named module" requirement); 005-drag-drop-ordering reuses the same module for
  its own moves rather than writing a second version.

### ADR-19 — Board canvas becomes client-driven (extends 003's ADR-13, doesn't replace it)

- **Options considered**: (a) every mutation triggers a full page reload/server
  re-render (`router.refresh()`); (b) the board page's server component still does the
  first fetch (auth gate, fast first paint — ADR-13 unchanged), but hands it to a client
  component as `initialData` for `trpc.boards.getContent.useQuery`, so every mutation in
  this feature invalidates that query and the canvas re-renders from React Query's
  cache — the exact pattern `board-members-panel.tsx` already established for 002's
  membership mutations.
- **Decision**: (b). Introducing a second update mechanism (full reloads) alongside the
  React-Query-invalidate pattern this codebase already has would be a second pattern for
  the same problem — `frontend-rules.md`'s "Server state lives in tRPC/React Query
  ONLY" already settles this in one direction.
- **Consequences**: `BoardCanvas` (and everything under it — `ListColumn`, `CardFront`)
  gains a `"use client"` boundary and an owning client wrapper that also holds "which
  card is open" state (ADR-14); `TopBar`/`Sidebar` are unaffected (003's ADR-13 stands).

## Package approvals (constitution IV)

None. Every dependency this feature needs (`sonner`, `react-hook-form`,
`@hookform/resolvers/zod`, `@tanstack/react-query` via tRPC) is already present from
001–003 (Technical Context above).

## Project Structure

### Documentation (this feature)

```text
specs/004-card-crud/
├── spec.md
├── plan.md                          # This file
├── research.md                      # Phase 0 output
├── data-model.md                    # Phase 1 output
├── quickstart.md                    # Phase 1 output
├── screenshots/
│   └── card-detail-modal.png        # rung-1 visual reference (copy of the prototype's own preview-card.png)
├── contracts/
│   └── card-crud-api.md             # Phase 1 output
└── tasks.md                         # /speckit.tasks output (next step)
```

### Source Code (both nested repos)

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Data/
│   │   └── Configurations/
│   │       ├── ChecklistItemConfiguration.cs  # EDITED: + PublicId unique index
│   │       └── ActivityEventConfiguration.cs  # NEW — no soft delete, no PublicId
│   ├── Migrations/
│   │   └── <timestamp>_AddCardActivity.cs     # NEW — ActivityEvent table + ChecklistItem.PublicId
│   ├── Domain/
│   │   ├── Entities/
│   │   │   └── ActivityEvent.cs               # NEW
│   │   └── Ordering.cs                        # NEW — ADR-18, golden-fixture tested
│   ├── Endpoints/
│   │   └── CardsEndpoints.cs                  # NEW — ~14 routes (contracts/card-crud-api.md)
│   └── Services/
│       └── CardService.cs                     # NEW — every card query/mutation this feature needs
└── tests/Flowboard.Api.Tests/
    ├── CardsEndpointTests.cs                  # NEW
    └── OrderingTests.cs                       # NEW — golden fixture

flowboard-web/
└── src/
    ├── components/
    │   └── board/
    │       ├── board-canvas.tsx               # EDITED — "use client" (ADR-19), owns open-card state
    │       ├── list-column.tsx                # EDITED — "use client", real composer (C-01)
    │       ├── card-front.tsx                 # EDITED — onClick opens the modal (ADR-14)
    │       ├── card-composer.tsx              # NEW — inline add-card form (React Hook Form)
    │       └── card-detail/                   # NEW — the modal and its sub-panels
    │           ├── card-detail-modal.tsx
    │           ├── card-title-field.tsx
    │           ├── card-description-panel.tsx
    │           ├── card-labels-panel.tsx
    │           ├── card-members-panel.tsx
    │           ├── card-due-date-panel.tsx
    │           ├── card-checklist-panel.tsx
    │           ├── card-activity-feed.tsx
    │           └── card-add-to-card-menu.tsx  # Members/Labels/Due date/Move(inert)/Copy/Delete
    ├── server/api/
    │   └── routers/
    │       └── cards.ts                       # NEW — mirrors contracts/card-crud-api.md 1:1
    └── lib/
        ├── api/
        │   └── cards-client.ts                # NEW — server-only fetch for every card endpoint
        └── cards/
            └── schemas.ts                     # NEW — Zod input schemas (composer, edits, etc.)
```

**Structure Decision**: extends 001–003's structure without new top-level folders.
`components/board/card-detail/` is a feature-scoped sub-folder of the existing
`components/<feature>/` convention (`frontend-rules.md`), chosen because the modal has
eight distinct panels that would otherwise crowd `components/board/` flat. Backend adds
no new project or layer — same `Endpoints` → `Services` → `Domain`/`Data` shape 002/003
already used.

## Implementation Phases (constitution XIII)

- **Phase A — backend (provider tier, gates and merges first per
  repository-strategy.md)**: `AddCardActivity` migration; `Ordering.cs` (+ golden-fixture
  test); `ActivityEvent` entity/configuration; `CardService` (every query + mutation);
  `CardsEndpoints` (~14 routes); integration tests (success/validation/authorization/
  concurrency-conflict per endpoint). Ends: user runs the backend gate, confirms exit 0;
  AI + human review; commit.
- **Phase B — frontend (consuming tier, starts once Phase A's contract is stable)**:
  in priority order matching spec.md's stories — composer (US1) → modal shell + open/
  close (US2) → title/description edit (US3) → labels/members (US4) → due date (US5) →
  checklist (US6) → comments/activity feed (US7) → copy/delete (US8); toasts (X-01)
  wired into every mutation as it lands, not as a separate pass. Runs the **Visual
  Compliance Loop** against `screenshots/card-detail-modal.png` before requesting the
  gate. Ends: user runs the frontend gate, confirms exit 0; AI + human review (including
  the UI-vs-reference check); commit.

## Domain-invariant pass

| # | Invariant | Applies? | How this plan satisfies it |
|---|---|---|---|
| 1 | Activity Is Append-Only | Yes | Every mutation writes exactly one `ActivityEvent`; no code path updates or deletes one (ADR-16); no `Updated*`/soft-delete columns exist on the entity to even attempt it through. |
| 2 | Ordering Integrity | Yes | New cards and copies get their position from the one `Ordering.cs` module (ADR-18) — never inline midpoint math; ties still break on `Id`. |
| 3 | WIP Limits Are Advisory | Yes | Card creation (C-01) is never rejected for exceeding a list's `WipLimit` — no check exists in `CardService.CreateCard`. |
| 4 | Soft Delete, 30-Day Restorability | Yes | `DELETE /v1/cards/{id}` sets `Card`'s existing soft-delete trio (schema already there from 003); comments/checklist items/activity referencing a deleted card are untouched and remain resolvable (FR-012, invariant text). |
| 5 | Permissions Enforced Server-Side | Yes | Every `CardsEndpoints` route resolves the caller's role via 002's `BoardAccessService` (through `Card → List → Board`) before doing anything; Observer gets everything except comment rejected server-side, not just hidden in the UI (FR-015). Assigning a non-member (C-07) is the one sanctioned membership side effect. |
| 6 | Optimistic Concurrency | Yes | `PATCH /v1/cards/{id}` requires `If-Match`; a stale value returns `409` (ADR-17) — the only endpoint in this feature that overwrites a field wholesale. |
| 7 | Labels Are Board-Scoped | Yes | `POST .../labels` validates the label's `BoardId` matches the card's board before inserting the `CardLabel` row — the first code that actually enforces invariant 7 (003 only trusted seed data). |
| 8 | Opaque Public Identifiers | Yes | Every new/edited route addresses `Card`/`Label`/`User`/`ChecklistItem` by `PublicId`; `ActivityEvent`/`Comment` stay internal-`Id`-only (never individually addressed by a URL, per Data Standards above). |

## Complexity Tracking

No unjustified constitution violations. The six new patterns (client-side modal, plain-
text description, single-table activity feed, `If-Match` concurrency, the ordering
module's first use, a client-driven canvas) are each approved above through ADR-14
through ADR-19, not exceptions.
