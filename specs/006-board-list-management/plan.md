# Implementation Plan: Board & List Management

**Branch**: `006-board-list-management` | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-board-list-management/spec.md`

## Summary

Real, user-driven create/rename/star/archive-delete for boards, and create/rename/WIP-
limit/sort/archive-delete for lists — the first feature to write to `Board.Name`,
`Board.Starred`, and `List.Name`/`List.WipLimit` outside of seed data (003 already reads
all of them; 005 already gave `List.Position` its own write path). Board rename/archive/
delete is scoped to Board Admin only — narrower than 004/005's `CanMutate` (admin-or-
member) gate, reusing the exact `access.Role != BoardRole.BoardAdmin` check
`BoardMembershipService` already uses for invites. Board and list renames are field edits,
so they pick up 004's `If-Match`/`409` optimistic-concurrency contract — which requires
adding a `RowVersion` column to both `Board` and `List` (neither carries one today; only
`Card` does). No new frontend or backend package either side.

## Technical Context

**Language/Version**: C# / .NET 10 (backend, unchanged); TypeScript / Next.js 16 App
Router (frontend, unchanged)
**Primary Dependencies**: No new packages either side. Backend reuses EF Core 10,
`Ordering.cs` (list creation appends via the same `Ordering.Append` 004 already uses for
cards), and `BoardAccessService`. Frontend reuses tRPC/React Query and this product's own
existing dialog/composer/toast components (004) — no new UI library.
**Storage**: SQL Server. One migration this feature: adds `RowVersion rowversion NOT NULL`
to `Board` and `List` (mirrors `Card.RowVersion`, added by 003/backend-rules.md's own rule
that any entity with `If-Match` edits requires one). No other schema change — `Board.Name`,
`Board.Starred`, `List.Name`, `List.WipLimit`, and the soft-delete trio on both already
exist (003), unused by any write path until now.
**Testing**: `dotnet test` (xUnit, `WebApplicationFactory`, extending 004/005's pattern) —
new endpoint test files for boards' write paths and lists' write paths, plus a due-date
sort ordering test (nulls-last, stable tiebreak). No frontend test runner exists yet (003
precedent) — frontend verification is the Visual Compliance Loop + `quickstart.md`.
**Target Platform**: Web (existing Next.js/ASP.NET Core stack, unchanged)
**Project Type**: Web application (existing `flowboard-api` + `flowboard-web`, unchanged)
**Performance Goals**: Every write here is a single-row update or a single-row insert
(list create appends via `Ordering.Append`, same O(1) shape 004/005 already established);
"sort by due date" is the one exception — it's an intentional, one-time, bounded rewrite of
every card's `Position` in a single list (bounded by that list's own card count, not the
board's), not a per-drop hot path.
**Constraints**: Board rename/archive/delete MUST be rejected server-side for a plain
`BoardMember` (spec FR-004/FR-010) — this is a *narrower* gate than every other mutation
in 004/005/006 uses, and the two MUST NOT be conflated. A WIP limit MUST NEVER block a
card create or move (invariant 3, restated by spec FR-009) — no new check is being added
here, this is a re-affirmation for this feature's own reviewers, matching 005's own R-6.
**Scale/Scope**: One migration (2 columns). Backend: ~8 new endpoint handlers across the
existing `BoardsEndpoints.cs`/`ListsEndpoints.cs` files (no new endpoint-file). Frontend:
one new create-board affordance, one new create-list affordance, inline rename wired for
both board and list headers, a "Star" toggle in the top bar, and the existing list "⋯"
menu (005) gains four new rows (WIP limit, sort, archive cards, delete) plus a board-level
delete control.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist all-PASS,
  no `NEEDS CLARIFICATION` markers); this plan.md and tasks.md follow before any code.
- [x] **Source of Truth (II)**: Reference screenshots captured live from
  `docs/product/prototype/flowboard-prototype.html` for the three states the prototype
  actually implements (sidebar, list "⋯" menu, WIP-over badge). The prototype has **no**
  board archive/delete UI at all — a genuine gap in rung 1, not a conflict; spec.md's User
  Story 7 and FR-010 are written from `FUNCTIONAL_SPEC.md` (rung lower, but the only source
  that speaks to this capability) plus this product's own existing delete-confirmation
  convention (004). No conflict found between rungs — reported per the gap, not silently
  guessed past.
- [x] **Repository Separation (III)**: `flowboard-api` (endpoints/services/migration) and
  `flowboard-web` (forms, inline rename, menu rows) stay separate; no mixing.
- [x] **Architecture Consistency (IV)**: No new framework, UI library, or persistence
  approach. Reusing `Ordering.cs`, `BoardAccessService`, the existing `If-Match`/`409`
  field-edit contract, and this product's own dialog/composer/toast components. The one
  new *pattern* is a second, narrower permission predicate (Board-Admin-only) alongside
  `CanMutate` — not new architecture, since `BoardMembershipService` already uses the
  identical check for invites; recorded as ADR-25 for visibility, not because it's novel.
- [x] **Data Standards (V)**: New `RowVersion` columns follow the exact same
  `.IsRowVersion()` mapping `Card.RowVersion` already uses (database-rules.md).
- [x] **Auditability (VI)**: No new entities. `Board`/`List` already carry the full
  audit trio (`CreatedDate`/`CreatedBy`, `UpdatedDate`/`UpdatedBy`) and soft-delete trio
  (`IsDeleted`/`DeletedDate`/`DeletedBy`) since 003 — this feature is the first to write
  through any of them for these two entities.
- [x] **Domain Invariants (VII)**: See Domain Invariant Pass below — this feature is the
  first real write path for invariant 4 (soft delete) on `Board` and `List`, and
  re-affirms invariant 3 (WIP is advisory) and invariant 6 (optimistic concurrency,
  extended to two more entities) without changing either rule.
- [x] **Security (VIII)**: Every new endpoint resolves the caller's role via
  `BoardAccessService` before acting, except `POST /v1/boards` — there is no board yet to
  resolve a role on; it authenticates the caller and creates in their own workspace only
  (ADR-26), with no other authorization decision to make.
- [ ] **External Integration Governance (IX)**: N/A — no external integrations.
- [x] **Performance Responsibility (X)**: All writes are single-row except the bounded,
  one-time due-date sort (Scale/Scope above); no N+1 introduced.
- [x] **Testing Requirements (XI)**: Integration tests for every new endpoint (success,
  validation, the two distinct authorization tiers, WIP-limit-not-enforced, cascade-
  archive-on-list-delete, sort ordering with nulls-last and a stable tiebreak).
- [x] **Human Review (XII)**: Same phased AI-then-human review as 001–005, gated per
  phase below.
- [x] **Controlled Delivery (XIII)**: Backend phase implemented and gated before frontend,
  per `docs/sdlc/repository-strategy.md`'s cross-repository rule — same as 004/005.

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`). This feature touches
invariant 4 (soft delete) for the first time on `Board`/`List`, but deletion here is
recoverable for ≥30 days by the same rule already governing card deletion (004) — not a
postings/balances/consent-trail/state-machine case, and not irreversible. Same reasoning
004 and 005 both already applied to the invariants they touched.

## Architecture Decision Records

**ADR-25 — A second, narrower permission predicate: `CanManageBoard`, Board-Admin only**:
`FUNCTIONAL_SPEC.md` §6's own table draws a real line most of 004/005 didn't need to
notice: "Rename / archive / delete board" is Board-Admin-only, while "Create / rename /
delete lists" is Board-Admin-**or**-Board-Member. `CardService`/`ListService`'s existing
`CanMutate(role) => BoardAdmin or BoardMember` stays exactly as-is for every list
mutation this feature adds (create list, rename list, WIP limit, sort, archive-cards,
delete list). A new, separate check — `access.Role != BoardRole.BoardAdmin` — gates board
rename/archive/delete instead. This isn't a new pattern: `BoardMembershipService.
InviteAsync`/`RemoveMemberAsync`/`RevokeInvitationAsync` already use this exact
comparison for board-membership actions; this feature just extends it to board identity/
lifecycle actions. The two checks living side by side in the same feature is the risk
worth naming explicitly, so an implementer doesn't collapse them into one.

**ADR-26 — Board creation needs no eligibility check; it always targets the caller's own
workspace**: 002's `AuthService` gives every user their own `Workspace` automatically at
registration (`OwnerUserId`, one per user, created inline with the account — no separate
"join a workspace" step exists). A user who also holds a `BoardMember` row on someone
else's board (a different workspace entirely) never gains authority to create boards
*there* — `POST /v1/boards` always creates in `db.Workspaces.First(w => w.OwnerUserId ==
caller.Id)`, full stop. Since every authenticated caller already owns exactly one
workspace, there is no case where they lack standing to create a board — B-02's "any
member" is universal, not a gate to implement. No `workspacePublicId` field is accepted in
the request body (there is only ever the caller's own to target).

**ADR-27 — `RowVersion` added to `Board` and `List`; rename uses `If-Match`/`409`, star/
WIP/sort/archive do not**: Board and list *names* are field edits — two admins renaming
the same board around the same time should behave exactly like two people editing the
same card title (004's precedent): a stale save is rejected with `409`, never silently
overwritten (invariant 6). Star, WIP-limit, sort, and archive/delete are **not** given an
`If-Match` precondition: starring is an idempotent boolean flip with no meaningful "conflict"
to detect; a WIP-limit update overwriting another WIP-limit update a moment earlier is the
same low-stakes last-write-wins already accepted for moves (005); sort-by-due-date and
archive/delete are one-shot bulk actions, not concurrent-field-edit scenarios. Requiring
`RowVersion` only where a real edit conflict is meaningful (rename) — not on every mutation
this feature adds — keeps the concurrency contract legible instead of applying it
reflexively everywhere a column exists.

**ADR-28 — List creation reuses `Ordering.Append`, no new ordering primitive**: A newly
created list is appended to the right of a board's existing lists — the exact same
"append at the end" shape `Ordering.cs` already serves for card creation (004) and list
moves (005). `CreateListAsync` loads the board's current highest `List.Position` and calls
`Ordering.Append(lastPosition)`, nothing new.

## Project Structure

### Documentation (this feature)

```text
specs/006-board-list-management/
├── plan.md                     # this file
├── research.md
├── data-model.md
├── contracts/
│   └── board-list-management-api.md
├── quickstart.md
├── screenshots/
│   ├── sidebar-boards-list.jpg
│   ├── list-actions-menu.jpg
│   └── list-wip-over-limit.jpg
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Domain/Entities/
│   │   ├── Board.cs                    # + RowVersion
│   │   └── List.cs                     # + RowVersion
│   ├── Data/Configurations/
│   │   ├── BoardConfiguration.cs       # + .IsRowVersion()
│   │   └── ListConfiguration.cs        # + .IsRowVersion()
│   ├── Migrations/
│   │   └── <timestamp>_AddBoardListRowVersion.cs   # NEW
│   ├── Endpoints/
│   │   ├── BoardsEndpoints.cs          # + POST /, PATCH /{id}, DELETE /{id},
│   │   │                                 POST /{id}/star, POST /{id}/unstar,
│   │   │                                 POST /{id}/lists
│   │   └── ListsEndpoints.cs           # + PATCH /, DELETE /, POST /archive-cards,
│   │                                     POST /sort
│   ├── Services/
│   │   ├── BoardContentService.cs      # + CreateBoardAsync, UpdateBoardAsync,
│   │   │                                 DeleteBoardAsync, StarBoardAsync,
│   │   │                                 UnstarBoardAsync
│   │   └── ListService.cs              # + CreateListAsync, UpdateListAsync,
│   │                                     DeleteListAsync, ArchiveAllCardsAsync,
│   │                                     SortByDueDateAsync
│   └── Program.cs                      # unchanged (existing endpoint groups extended)
└── tests/Flowboard.Api.Tests/
    ├── BoardsEndpointTests.cs          # + create/rename/star/delete cases
    └── ListsEndpointTests.cs           # + create/rename/wip/sort/archive/delete cases

flowboard-web/
├── src/
│   ├── lib/
│   │   ├── boards/schemas.ts           # + create/rename board input schemas
│   │   ├── lists/schemas.ts            # + create/rename/wip input schemas
│   │   └── api/
│   │       ├── boards-client.ts        # + create/rename/star/unstar/delete
│   │       └── lists-client.ts         # + create/rename/wip/sort/archive/delete
│   ├── server/api/routers/
│   │   ├── boards.ts                   # + create/rename/star/unstar/delete procedures
│   │   └── lists.ts                    # + create/rename/wip/sort/archive/delete
│   └── components/
│       ├── layout/
│       │   ├── sidebar.tsx             # + "Create board" inline composer row
│       │   ├── top-bar.tsx             # server component; passes publicId/starred/
│       │   │                             role through to the new client piece below
│       │   │                             instead of the static h1 + disabled Star button
│       │   └── board-title-bar.tsx     # NEW client component — inline board rename,
│       │                                 star toggle, and (Board-Admin only) a small
│       │                                 delete-board control + inline confirm step
│       └── board/
│           ├── list-column.tsx         # + list title inline rename; "⋯" button (003,
│           │                             currently `disabled`) becomes functional,
│           │                             opening list-actions-menu.tsx
│           ├── add-list-composer.tsx   # NEW — "+ Add another list" inline form
│           │                             (mirrors 004's card composer shape)
│           └── list-actions-menu.tsx   # NEW — the list "⋯" popover: WIP limit (inline
│                                         numeric input), sort, archive cards, delete
│                                         list (inline confirm step, research R-7)
```

**Structure Decision**: Extends the existing single-service-per-tier layout from
001–005; no new top-level directories, no new endpoint files. `list-actions-menu.tsx` and
`add-list-composer.tsx` are new *components*, not a new architectural layer — they follow
the same shape `card-move-panel.tsx` (005) and the card composer (004) already
established.

## Domain Invariant Pass

| # | Invariant | How this feature satisfies it |
|---|---|---|
| 1 | Activity Is Append-Only | Unaffected — none of this feature's actions write a `Card`-scoped `ActivityEvent` (deleting a list archives its cards without editing their own activity trails) |
| 2 | Ordering Integrity | List creation appends via `Ordering.Append` (ADR-28); sort-by-due-date rewrites every card's `Position` in one list once, still one row per card, no renumbering scheme change |
| 3 | WIP Limits Are Advisory | FR-009 — re-affirmed, no new check added; setting a limit below the current count never touches the cards themselves |
| 4 | Soft Delete | The reason this feature exists for `Board`/`List` — both already carry the soft-delete trio (003), first real write path here; deleting a list additionally soft-deletes every card it holds (FR-012) |
| 5 | Permissions Enforced Server-Side | Two tiers this time (ADR-25): `CanMutate` for list actions, Board-Admin-only for board identity/lifecycle actions — both enforced in the service layer, never UI-only |
| 6 | Optimistic Concurrency | Extended to `Board.Name`/`List.Name` (+`List.WipLimit`) via the new `RowVersion` columns (ADR-27); star/sort/archive/delete deliberately excluded, same rationale as 005's moves |
| 7 | Labels Are Board-Scoped | Unaffected |
| 8 | Opaque Public Identifiers | Every new endpoint addresses boards/lists by `PublicId` only |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Second permission predicate (`CanManageBoard`, ADR-25) | `FUNCTIONAL_SPEC.md` §6 genuinely draws this line; reusing `CanMutate` for board rename/delete would let a plain board member delete the board out from under its admin | Already-precedented (`BoardMembershipService`), so this is applying an existing pattern twice, not inventing a new one — listed here only because two predicates in one feature is worth a reviewer's attention |
| `RowVersion` added to two more entities (ADR-27) | Board/list rename needs the same no-silent-overwrite guarantee 004 gave card fields (invariant 6) | Skipping concurrency for rename and accepting last-write-wins was rejected — a name is prose two people can genuinely stomp on, unlike a move's single unambiguous "where it landed" outcome (005's own rationale for *not* needing it there) |
