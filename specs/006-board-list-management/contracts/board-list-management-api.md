# Contract: Board & List Management API

Cite this file in a top comment in `BoardsEndpoints.cs`'s new handlers, `ListsEndpoints.cs`'s
new handlers, and the frontend's `lib/api/boards-client.ts` / `lib/api/lists-client.ts`.

Every route requires `Authorization: Bearer <token>`. Two distinct authorization tiers
apply (research.md R-2) — do not confuse them:

- **List-scoped routes** (`CanMutate`): no resolvable board role → `404`; `Observer` →
  `403`; `BoardAdmin`/`BoardMember` → may call.
- **Board identity/lifecycle routes** (`CanManageBoard`): no resolvable board role → `404`;
  `Observer` or plain `BoardMember` → `403`; `BoardAdmin` only → may call.
- **`POST /v1/boards`** is the one exception — it runs before any board (and therefore any
  board role) exists; see its own section below.

Board rename and list rename/WIP-limit edits require `If-Match: "<base64 RowVersion>"`
(ADR-27) — a stale value returns `409`, matching `PATCH /v1/cards/{id}`'s existing
contract exactly. No other route in this contract uses `If-Match`.

## `POST /v1/boards` — create a board

FR-001, FR-002, User Story 1. **No board role to resolve and no eligibility check** —
every authenticated caller already owns exactly one workspace (created automatically at
registration, 002); the board is always created there (research.md R-3, ADR-26). There is
no request field to target a different workspace.

**Request body**:

```json
{ "name": "Q4 Planning" }
```

- `name` (required, non-empty after trimming — FR-006).

**Response `201 Created`**:

```json
{
  "publicId": "...", "name": "Q4 Planning", "color": "#3d6df0", "starred": false,
  "cardCount": 0,
  "lists": [
    { "publicId": "...", "name": "To Do" },
    { "publicId": "...", "name": "Doing" },
    { "publicId": "...", "name": "Done" }
  ]
}
```

**Failure responses**:

- `400` — `name` empty/whitespace-only.
- `401` — unauthenticated.

**Side effects**: creates the board (in the caller's own workspace) and its three starter
lists (`Ordering.Append`, in order). No `BoardMember` row is created for the caller —
they're the workspace owner, so `BoardAccessService` already resolves them as this new
board's implicit `BoardAdmin`, same as any other board in their workspace.

## `PATCH /v1/boards/{boardPublicId}` — rename a board

FR-004. `CanManageBoard` only.

**Request headers**: `If-Match: "<base64 RowVersion>"` (required).

**Request body**:

```json
{ "name": "Marketing Launch Q4" }
```

**Response `200 OK`**: `{ "name": "...", "rowVersion": "<base64>" }`.

**Failure responses**:

- `400` — `name` empty/whitespace-only.
- `403` — caller is a plain `BoardMember` or `Observer`.
- `404` — no access, or board doesn't exist.
- `409` — `If-Match` doesn't match the board's current `RowVersion` (someone else renamed
  or otherwise updated it first).

## `POST /v1/boards/{boardPublicId}/star` / `POST /v1/boards/{boardPublicId}/unstar`

FR-007. `CanMutate` — starring is available to `BoardAdmin`/`BoardMember`, not `Observer`
(spec.md's Assumptions: extending invariant 5's "Observer views and comments, nothing
else" by inference, since starring changes a shared, board-wide flag). No `If-Match` — an
idempotent boolean flip, not a field edit with a meaningful conflict.

**Request body**: none. **Response `204 No Content`**.

**Failure responses**: `403` — `Observer`. `404` — no access, or board doesn't exist.

## `DELETE /v1/boards/{boardPublicId}` — archive/delete a board

FR-010, User Story 7. `CanManageBoard` only. Soft-delete (invariant 4) — never a physical
row delete.

**Response `204 No Content`**.

**Failure responses**: `403` — plain `BoardMember` or `Observer`. `404` — no access, or
board doesn't exist, or already deleted.

**Side effects**: sets the board's soft-delete trio. Does **not** cascade-delete its
lists or cards (unlike list deletion, research R-5) — they remain exactly as they were,
simply unreachable through any route that first resolves board access, since a deleted
board has none to grant.

## `POST /v1/boards/{boardPublicId}/lists` — add a list

FR-003, User Story 2. `CanMutate`.

**Request body**:

```json
{ "name": "Blocked" }
```

**Response `201 Created`**: `{ "publicId": "...", "name": "Blocked", "wipLimit": null, "cardCount": 0 }`.

**Failure responses**: `400` — empty/whitespace name. `403` — `Observer`. `404` — no
access, or board doesn't exist.

**Side effects**: appends the list via `Ordering.Append` (ADR-28, research R-4) — always
rightmost among the board's current lists.

## `PATCH /v1/lists/{listPublicId}` — rename a list and/or set its WIP limit

FR-005, FR-008, User Stories 4 and 6. `CanMutate`.

**Request headers**: `If-Match: "<base64 RowVersion>"` (required).

**Request body** (either or both fields; at least one required):

```json
{ "name": "In Progress", "wipLimit": 3 }
```

- `name` (optional): non-empty after trimming if present (FR-006).
- `wipLimit` (optional): `null` clears the limit ("none"); a non-negative integer sets it.
  A negative value is rejected.

**Response `200 OK`**: `{ "name": "...", "wipLimit": 3, "rowVersion": "<base64>" }`.

**Failure responses**:

- `400` — empty/whitespace `name`, or a negative `wipLimit`, or neither field supplied.
- `403` — `Observer`.
- `404` — no access, or list doesn't exist.
- `409` — stale `If-Match`.

**Side effects**: never blocks or affects any existing card, regardless of how far the
new limit puts the list over capacity (invariant 3, FR-009).

## `POST /v1/lists/{listPublicId}/sort` — sort by due date

FR-013, User Story 9. `CanMutate`. No `If-Match`, no request body.

**Response `204 No Content`**.

**Failure responses**: `403` — `Observer`. `404` — no access, or list doesn't exist.

**Side effects**: rewrites every card's `Position` in this list, ascending by `DueAt`,
undated cards last, ties broken by each card's own current `Position` (research R-1) — a
one-time reordering, not a persistent mode; a card added afterward is not auto-sorted.

## `POST /v1/lists/{listPublicId}/archive-cards` — archive every card in a list

FR-011, User Story 8 (first half). `CanMutate`. No request body.

**Response `204 No Content`**.

**Failure responses**: `403` — `Observer`. `404` — no access, or list doesn't exist.

**Side effects**: soft-deletes every non-deleted card currently in the list; the list
itself is untouched (remains on the board, now empty). A no-op (still `204`) if the list
is already empty.

## `DELETE /v1/lists/{listPublicId}` — delete a list

FR-012, User Story 8 (second half). `CanMutate`. No request body.

**Response `204 No Content`**.

**Failure responses**: `403` — `Observer`. `404` — no access, or list doesn't exist, or
already deleted.

**Side effects**: soft-deletes the list **and**, in the same transaction, every
non-deleted card it currently holds (research R-5, invariant 4) — never a physical
delete of either.

## Explicitly not in this contract

- No board `color` field in any request body — assigned automatically at creation,
  never user-editable in this feature (data-model.md).
- No restore/undo endpoint for a deleted board, list, or archived card — the 30-day
  restorability is a data guarantee (invariant 4), not a self-service UI this feature
  ships (spec.md Assumptions, mirroring 004's identical precedent for card deletion).
- No `If-Match` on star, sort, archive-cards, or either delete route — see ADR-27's
  rationale for exactly which routes get a concurrency precondition and which don't.
- No cross-workspace board creation — `POST /v1/boards` always targets the caller's own
  (single, per 002) workspace; this contract doesn't add a `workspacePublicId` field to
  the request body because there is only ever one to choose from today.
