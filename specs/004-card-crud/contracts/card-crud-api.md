# Contract: Card CRUD API

Cite this file in a top comment in `CardsEndpoints.cs` and in the frontend's
`lib/api/cards-client.ts` / `server/api/routers/cards.ts`.

Every route below requires `Authorization: Bearer <token>` and resolves the caller's
role for the card's board via 002's `BoardAccessService` (through `Card → List →
Board`), then applies spec §6's matrix (research.md R-2):

- No resolvable role at all → **`404`** (existence not confirmed to a non-member, same
  convention as `board-content-api.md`).
- `Observer` → may call every `GET` and `POST .../comments` only; every other route →
  **`403`**.
- `BoardAdmin` / `BoardMember` → may call every route below.

## `POST /v1/lists/{listPublicId}/cards`

Create a card at the bottom of a list (FR-001).

**Request body**: `{ "title": "string, 1-200 chars" }`

**Response `201 Created`**: the new card's `CardSummary` (003's shape — `publicId`,
`title`, `dueAt: null`, `dueStatus: null`, `hasDescription: false`,
`checklistDone/Total: null`, `commentCount: 0`, `labels: []`, `members: []`).

**Failure responses**: `400` — empty/too-long title. `404` — no access to the list's
board.

## `GET /v1/cards/{cardPublicId}`

Full card detail for the detail modal (FR-002).

**Response `200 OK`**, header `ETag: "<base64 RowVersion>"`:

```json
{
  "publicId": "...",
  "title": "Define SSO requirements for Enterprise",
  "description": null,
  "dueAt": "2026-09-08T00:00:00Z",
  "dueComplete": false,
  "dueStatus": "future",
  "listPublicId": "...",
  "listName": "Backlog",
  "boardPublicId": "...",
  "boardName": "Product Roadmap Q3",
  "labels": [ { "publicId": "...", "name": "Feature", "color": "#16a34a" } ],
  "members": [],
  "checklistItems": []
}
```

**Failure responses**: `404` — no access, or the card doesn't exist/is deleted.

## `PATCH /v1/cards/{cardPublicId}`

Edit title, description, and/or due date fields (FR-003, FR-004, FR-007). Every field
is optional in the body — only supplied fields change. `list_id`/`position` are
rejected (`400`) — this route never moves a card (005's scope, ADR in research.md R-1).

**Request headers**: `If-Match: "<etag from the last GET>"` (**required**).

**Request body** (all fields optional, at least one required):

```json
{
  "title": "string, 1-200 chars",
  "description": "string or null (clears it)",
  "dueAt": "ISO-8601 datetime or null (clears it)",
  "dueComplete": true
}
```

**Response `200 OK`**: the updated `CardDetail` (same shape as `GET`), new `ETag`
header.

**Failure responses**: `400` — validation (empty title, unknown field). `404` — no
access. `409` — `If-Match` doesn't match the card's current `RowVersion` (ADR-17); body
is `{ "message": "This card was changed by someone else." }`; the client MUST re-fetch
via `GET` before retrying, never resend the same write blind.

## `POST /v1/cards/{cardPublicId}/labels`

Assign one of the board's own labels (FR-005).

**Request body**: `{ "labelPublicId": "..." }`

**Response `204 No Content`**.

**Failure responses**: `400` — the label belongs to a different board (invariant 7).
`404` — no access, card or label doesn't exist. Idempotent: assigning an already-
assigned label is a no-op `204`, not an error.

## `DELETE /v1/cards/{cardPublicId}/labels/{labelPublicId}`

Remove a label (FR-005). **Response `204 No Content`** (idempotent — removing an
unassigned label is also `204`). **Failure**: `404` — no access.

## `POST /v1/cards/{cardPublicId}/members`

Assign a member; adds them to the board first if they aren't already a member (FR-006,
invariant 5's sanctioned side effect).

**Request body**: `{ "userPublicId": "..." }`

**Response `204 No Content`**. **Failure responses**: `404` — no access, card or user
doesn't exist.

## `DELETE /v1/cards/{cardPublicId}/members/{userPublicId}`

Remove a member from the card only — does **not** remove them from the board (FR-006
only ever adds board membership as a side effect, never removes it). **Response `204 No
Content`**. **Failure**: `404` — no access.

## `POST /v1/cards/{cardPublicId}/checklist-items`

Add a checklist item (FR-008).

**Request body**: `{ "text": "string, 1-500 chars" }`

**Response `201 Created`**: `{ "publicId": "...", "text": "...", "done": false }`.

**Failure responses**: `400` — empty/too-long text. `404` — no access.

## `PATCH /v1/checklist-items/{checklistItemPublicId}`

Toggle a checklist item's done state (FR-008). **Request body**: `{ "done": true }`.
**Response `200 OK`**: `{ "publicId": "...", "text": "...", "done": true }`. **Failure**:
`404` — no access, or the item doesn't exist.

## `DELETE /v1/checklist-items/{checklistItemPublicId}`

Delete a checklist item (FR-008). **Response `204 No Content`**. **Failure**: `404` —
no access.

## `POST /v1/cards/{cardPublicId}/comments`

Add a comment (FR-009, FR-010). Available to `Observer` too (spec §6).

**Request body**: `{ "body": "string, 1-2000 chars" }`

**Response `201 Created`**: the new `ActivityEntry` (see `data-model.md`), so the
frontend can prepend it to the feed without a full re-fetch.

**Failure responses**: `400` — empty/too-long body. `404` — no access.

## `GET /v1/cards/{cardPublicId}/activity`

Cursor-paginated activity feed, newest first (FR-002, FR-010; ADR-12's shape reused).

Query params: `cursor` (opaque, omit for first page), `limit` (default 20, max 50).

**Response `200 OK`**:

```json
{
  "items": [
    {
      "type": "comment.added",
      "payload": { "body": "Let's confirm this with legal first." },
      "actorDisplayName": "Anas Matar",
      "actorInitials": "AM",
      "actorAvatarColor": "#2563eb",
      "createdAt": "2026-08-26T10:00:00Z"
    },
    {
      "type": "card.created",
      "payload": {},
      "actorDisplayName": "Anas Matar",
      "actorInitials": "AM",
      "actorAvatarColor": "#2563eb",
      "createdAt": "2026-08-24T09:00:00Z"
    }
  ],
  "nextCursor": null
}
```

**Failure responses**: `400` — malformed cursor/limit. `404` — no access.

## `POST /v1/cards/{cardPublicId}/copy`

Copy a card (FR-011; exact algorithm in `research.md` R-3).

**Response `201 Created`**: the new card's `CardSummary` (same shape as create).

**Failure responses**: `404` — no access.

## `DELETE /v1/cards/{cardPublicId}`

Soft-delete a card (FR-012; confirmation is a frontend-only step — this route performs
the delete unconditionally once called).

**Response `204 No Content`**. **Failure responses**: `404` — no access, or already
deleted.

## Explicitly not in this contract

- No `list_id`/`position` in `PATCH /v1/cards/{id}` — moving a card is
  005-drag-drop-ordering's scope.
- No list or board mutation routes — 006-board-list-management's scope.
- No `GET /v1/boards/{id}/search` — 007's endpoint.
- No realtime broadcast of any event this contract defines — 008-realtime-sync's scope;
  other viewers see changes on their next `GET /v1/boards/{id}` fetch, per spec.md's
  Assumptions.
