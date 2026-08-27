# FlowBoard Domain Invariants

> This pack carries constitutional force via constitution principle VII. Agents and
> reviewers MUST treat a violation of any invariant below exactly like a violation of the
> constitution itself. Sources: `docs/product/FUNCTIONAL_SPEC.md` (cited per invariant) and
> the ratification decisions of 2026-08-27 (`docs/roadmap.md`, decisions log).

## 1. Activity Is Append-Only

Every state-changing card action MUST write its `ActivityEvent` (spec §5.2 lists the event
types), and activity events MUST NEVER be updated or deleted — including by migrations,
bulk fixes, or rollbacks. Activity is the audit trail; a card's history is reconstructable
from its events at any time. The realtime channel (spec §7) broadcasts the same event
objects — realtime and history MUST NOT diverge in shape.

**Rationale**: An audit trail that can be edited is not an audit trail; a realtime feed
that differs from stored history makes the two permanently unreconcilable.

## 2. Ordering Integrity

Card and list order within a container is determined ONLY by `position` (sparse float or
lexicographic rank — spec §5.1; the scaffold plan fixes which). A move MUST write only the
moved row — synchronous renumbering of siblings is prohibited; re-balancing exhausted gaps
is a background job, never part of a user-facing mutation. Order MUST be deterministic:
equal or colliding positions are resolved by a documented tiebreaker (e.g. id), never left
to query luck.

**Rationale**: One-row moves are what make drag & drop cheap and concurrency-safe (§7.1's
last-write-wins is defined on a single row); nondeterministic order makes every board
render a coin flip.

## 3. WIP Limits Are Advisory

A WIP limit MUST NEVER block a drop, a move, or a card creation (spec L-04 — settled, spec
§11 Q2 closed). Exceeding the limit is signalled visually (`count / limit` turns red) and
nothing else. No server-side rejection, no confirmation dialog.

**Rationale**: The spec fixes WIP limits as a signal, not a constraint; a "helpful" hard
limit added in code silently changes the product.

## 4. Soft Delete Only, 30-Day Minimum Restorability

Boards, lists and cards MUST use soft delete / archive (constitution VI fields). Physical
deletion is prohibited unless explicitly approved in the technical plan. Archived and
soft-deleted items MUST remain restorable for at least 30 days (B-06, C-13 — a MINIMUM:
extending retention is an amendment, shortening it is a breach). Deleting a list archives
its cards (L-06); restoring never resurrects less than the user deleted. Comments,
checklist items and activity referencing an archived card MUST remain intact and
resolvable.

**Rationale**: Users treat archive as undo; history that references vanished rows breaks
referential and audit integrity.

## 5. Permissions Are Enforced Server-Side

The capability matrix in spec §6 is enforced at the API boundary for every mutation —
UI-only enforcement is prohibited. Observers can view and comment, nothing else. Board
membership is checked on every board-scoped endpoint (a valid token is not board access).
Assigning a card member who is not a board member adds them to the board (C-07) — the one
sanctioned membership side effect; no other mutation changes membership implicitly.

**Rationale**: In a multi-tenant SaaS, a permission enforced only in the client is a
breach, not a bug.

## 6. Optimistic Concurrency — No Silent Overwrites

Card field edits MUST use optimistic concurrency: a stale `If-Match` returns `409` and the
client re-fetches (spec §7.1); silently overwriting a colleague's edit is prohibited. Card
moves are last-write-wins on `(list_id, position)` with an `updated_at` precondition —
moves MUST NOT clobber concurrent field edits, and field edits MUST NOT revert concurrent
moves.

**Rationale**: §7.1 defines exactly which writes may race and how; anything looser loses
user data in the normal multi-user case.

## 7. Labels Are Board-Scoped

A label belongs to exactly one board (`Label.board_id`, spec §5 — ratification decision,
spec §11 Q1 closed). A card MUST only carry labels of its own board; moving or copying a
card across boards MUST NOT drag foreign labels along. Cross-board label reporting, if ever
built, is a mapping layer — not a schema change smuggled into a feature.

**Rationale**: The prototype (rank-1 truth) and the data model both encode Trello's
board-scoped model; widening scope is a product decision, not an implementation detail.

## 8. Opaque Public Identifiers

Internal primary keys (constitution V: `INT IDENTITY`) MUST NEVER appear in API URLs,
response bodies, WebSocket events, or logs visible to clients. Every API-exposed entity
carries an opaque public identifier (unique, indexed, non-sequential); all §7 endpoints
address entities by it. Cross-tenant enumeration by identifier MUST be impossible.

**Rationale**: Sequential ids in a multi-tenant SaaS leak volume and invite enumeration;
the mapping is cheap only if it is universal from day one.

## Rollback interaction

Reverting code or a migration MUST NOT cascade into physical deletion of boards, lists,
cards, comments, or activity events, and MUST NOT edit activity history (invariant 1).
If a rollback would touch them, stop and report (see `docs/sdlc/rollback-process.md`).
