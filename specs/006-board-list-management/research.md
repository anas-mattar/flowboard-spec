# Research: Board & List Management

Phase 0 output. No `NEEDS CLARIFICATION` markers remain in spec.md. The larger
architecture calls (a second permission predicate, board-creation eligibility, where
`RowVersion` applies, list-creation ordering) are recorded as ADR-25 through ADR-28 in
`plan.md`; this document covers the remaining operational decisions those ADRs depend on.

## R-1: Sort by due date — exact ordering, including ties and nulls

**Decision**: `SortByDueDateAsync` re-orders a list's cards ascending by `DueAt`, with
`DueAt IS NULL` cards placed after every dated card, and rewrites each card's `Position`
to match that new order using repeated `Ordering.Append` calls (one per card, in the
resolved order) rather than trying to preserve old gaps. SQL Server's own `ORDER BY DueAt`
puts `NULL` *first* by default, so the query must order by `CASE WHEN DueAt IS NULL THEN 1
ELSE 0 END, DueAt` explicitly. Ties (identical `DueAt`, including two `NULL`s) break by
each card's *current* `Position` — i.e. `.ThenBy(c => c.Position)` — so triggering the sort
twice in a row with no cards changed produces the same order both times (spec User Story
9's second acceptance scenario), and cards that were already in a sensible relative order
don't visibly shuffle for no reason.

**Rationale**: Matches the prototype's own comparator exactly
(`(a,b) => (a.due||'9999').localeCompare(b.due||'9999')` — undated sorts as `'9999'`,
i.e. last) while giving it a real, deterministic tiebreak the prototype's array `.sort()`
gets for free from JavaScript's stable-sort guarantee but SQL `ORDER BY` does not.

**Alternatives considered**: Leaving ties in whatever order the database happens to
return them — rejected, `ORDER BY` with no full tiebreak key is explicitly
non-deterministic per the SQL standard and would make the feature's own "sort again,
nothing changes" acceptance scenario flaky.

## R-2: Two permission tiers, not one — confirmed against the actual codebase, not just the spec

**Decision**: `ListService`'s existing `CanMutate(role) => BoardAdmin or BoardMember`
(introduced by 005) is reused unchanged for every list-scoped write this feature adds.
A second predicate, `CanManageBoard(role) => role == BoardRole.BoardAdmin`, gates every
board-scoped write. This second predicate is not new: `BoardMembershipService.
InviteAsync`/`RemoveMemberAsync`/`RevokeInvitationAsync` (002) already write `if
(access.Role != BoardRole.BoardAdmin) return Failure.Forbidden();` verbatim — this
feature's `BoardContentService` additions copy that exact line, not a new concept.

**Rationale**: `FUNCTIONAL_SPEC.md` §6's table is unambiguous on this split, and
`BoardAccessService.ResolveAsync` already collapses "workspace owner" into an implicit
`BoardRole.BoardAdmin` (`IsWorkspaceOwner: true`) — so `CanManageBoard` alone correctly
covers both the "Workspace admin" and "Board admin" columns of that table with one check,
no separate workspace-role lookup needed.

## R-3: Board creation — always the caller's own workspace, no eligibility check needed

**Decision**: `CreateBoardAsync(callerPublicId, name)` takes no workspace parameter at
all. It resolves `db.Workspaces.First(w => w.OwnerUserId == caller.Id)` and creates the
board there. This is the one write in this feature that runs *before*
`BoardAccessService.ResolveAsync` has anything to resolve (the board doesn't exist yet),
but no separate authorization decision is needed beyond "is this a valid authenticated
caller" — every registered user owns exactly one workspace (002's `AuthService` creates
it inline at registration), so there is no state in which an authenticated caller lacks a
workspace to create into.

**Rationale**: See plan.md ADR-26. A user who also holds `BoardMember` rows on boards in
*other* people's workspaces (entirely possible — `ListBoardsAsync`'s own query already
unions "my workspace's boards" with "boards I'm a member of elsewhere") never gains any
authority to create boards inside those other workspaces; this endpoint simply never looks
at that membership at all, avoiding the wrong question entirely rather than answering it
narrowly.

## R-4: List creation — reuses `Ordering.Append`, mirrors card creation exactly

**Decision**: `CreateListAsync(boardPublicId, callerPublicId, name)` loads the board's
current highest `List.Position` (or none, for a board somehow left with zero lists) and
calls `Ordering.Append(lastPosition)` — the identical call `CardService.CreateCardAsync`
already makes for a new card's position within a list, just scoped to lists within a
board instead.

**Rationale**: No new ordering primitive; `Ordering.cs` already generalizes over "the
thing being positioned," it doesn't care whether that's a card or a list (005 already
proved this by using `Ordering.InsertBetween`/`Append` for list moves too).

## R-5: Delete-list cascade — soft-delete every card in the same transaction

**Decision**: `DeleteListAsync` sets the list's own soft-delete trio
(`IsDeleted`/`DeletedDate`/`DeletedBy`) and, in the same `SaveChangesAsync` call, sets the
identical trio on every non-deleted `Card` currently in that list. No cascade delete
constraint is added at the database level — this is an explicit application-level fan-out,
matching how 004 already treats a card's own child rows (comments, checklist items,
activity) as "remain intact, referencing an archived parent" rather than a DB-level
cascade.

**Rationale**: Invariant 4 states this exact requirement ("Deleting a list archives its
cards (L-06)") and explicitly requires the cards stay resolvable afterward — a hard
`ON DELETE CASCADE` at the schema level would be a physical delete, which invariant 4
separately prohibits outright.

## R-6: Frontend create/rename UI — replaces the prototype's native `prompt()`, reuses 004's composer shape

**Decision**: "Create board" and "Add list" both use a small inline form (a text input
plus Save/Cancel, opened in place of the trigger button) — the same interaction shape
004's card composer already established — rather than the prototype's `window.prompt()`.
"Set WIP limit" becomes a small inline numeric input inside the existing list "⋯" popover
row itself (matching how that popover already avoids any other native browser control),
not a second native prompt either.

**Rationale**: `window.prompt()`/`confirm()` cannot be styled, blocks the main thread, and
is explicitly the kind of prototype-only shortcut spec.md's own Assumptions section
already calls out as excluded (mirroring 005's identical treatment of a different
prototype flourish). Reusing 004's composer shape means no new interaction pattern is
introduced anywhere in this feature.

## R-7: Delete confirmation — reuses 004's existing inline confirm-step pattern, not a new dialog component

**Decision**: 004 never built a shared confirmation-dialog component — `card-add-to-
card-menu.tsx`'s own card-delete control is a local `confirmingDelete` boolean that swaps
the "Delete" button for an inline "Delete this card? This can be undone by an admin." row
with its own Delete/Cancel buttons, all within the same popover. Board delete, list
delete, and "archive all cards" all repeat this exact same inline two-step shape (local
state toggle, no modal/dialog primitive) in their own respective components, rather than
extracting a new shared component this feature doesn't otherwise need.

**Rationale**: Constitution IV (no new UI pattern or abstraction without justification) —
the existing shape already works and is already precedented three times over (labels/
members/due-date pickers in the same menu use the analogous "click to reveal an inline
panel" shape); extracting a generic `ConfirmDialog` now would be a premature abstraction
for three call sites that don't yet show any sign of needing to vary independently.
