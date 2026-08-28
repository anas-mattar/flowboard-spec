# Contract: Move API

Cite this file in a top comment in `CardsEndpoints.cs`'s move handler, the new
`ListsEndpoints.cs`, and the frontend's `lib/api/cards-client.ts` /
`lib/api/lists-client.ts`.

Every route requires `Authorization: Bearer <token>` and resolves the caller's role for
the card's/list's own board via `BoardAccessService` (research.md R-2):

- No resolvable role at all → **`404`**.
- `Observer` → **`403`**.
- `BoardAdmin` / `BoardMember` → may call both routes.

Neither route uses `If-Match`/`ETag` — moves have no concurrency precondition
(plan.md ADR-21).

## `POST /v1/cards/{cardPublicId}/move`

Move a card within its current list, or into a different list on the same board
(FR-001, FR-002, FR-005 — this is also what the "Move" menu calls, US2).

**Request body**:

```json
{ "listPublicId": "...", "beforeCardPublicId": "..." }
```

- `listPublicId` (required): the destination list. May be the card's current list (a
  pure reorder).
- `beforeCardPublicId` (optional, omit or `null` for "append at the end of the
  destination list"): the sibling this card should land immediately before, within
  `listPublicId`'s current order.

**Response `204 No Content`**.

**Failure responses**:

- `400` — `listPublicId` doesn't belong to the same board as the card's current list;
  or `beforeCardPublicId` doesn't belong to `listPublicId`.
- `403` — caller is an Observer.
- `404` — no access to the card, or the card/`listPublicId`/`beforeCardPublicId`
  doesn't exist.

**Side effects**: writes a `card.moved` `ActivityEvent` only when `listPublicId` differs
from the card's list *before* the move (research.md R-3); a same-list reorder writes
nothing. Never blocked by the destination list's `WipLimit` (invariant 3).

## `POST /v1/lists/{listPublicId}/move`

Reorder a list among the other lists on the same board (FR-007, US3).

**Request body**:

```json
{ "beforeListPublicId": "..." }
```

- `beforeListPublicId` (optional, omit or `null` for "append at the end of the board's
  list order"): the sibling list this one should land immediately before.

**Response `204 No Content`**.

**Failure responses**:

- `400` — `beforeListPublicId` belongs to a different board than `listPublicId`.
- `403` — caller is an Observer.
- `404` — no access, or either list doesn't exist.

**Side effects**: none besides the position write — list moves are not card-scoped and
never write to any card's `ActivityEvent` trail (spec.md, User Story 1's "Why this
priority" note; FR-003 is scoped to cards only).

## Explicitly not in this contract

- No position-within-list choice from the "Move" menu (US2) — it always appends at the
  end of the chosen list, matching the prototype reference exactly (spec.md
  Assumptions). `beforeCardPublicId` exists for drag-and-drop's finer-grained drop
  point, not for the menu.
- No `If-Match`/`409` — see plan.md ADR-21.
- No board-to-board move — both routes only ever operate within one board; the UI never
  presents a cross-board drop surface.
- No list/board CRUD, rename, WIP-limit editing, or archive (006-board-list-management's
  scope) — this contract only ever repositions.
