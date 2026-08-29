# Data Model: Board & List Management

Phase 1 output. One migration: `RowVersion` added to `Board` and `List`. Every other
column this feature writes to (`Board.Name`, `Board.Starred`, `List.Name`,
`List.WipLimit`, and both entities' soft-delete trio) already exists since 003, unused by
any write path until now. All entities follow `docs/rulebooks/database-rules.md`.

## Board *(schema change — `+ RowVersion`)*

| Column | Type | Notes |
|---|---|---|
| `RowVersion` | `rowversion` (`byte[]`, EF `.IsRowVersion()`) | **New.** Backs `If-Match`/`409` on board rename (ADR-27), mirroring `Card.RowVersion` exactly. |
| `Name` | `nvarchar` | Existing (002/003). First write path: `POST /v1/boards` (create) and `PATCH /v1/boards/{id}` (rename). |
| `Starred` | `bit` | Existing (003) — already read by `ListBoardsAsync`'s `OrderByDescending(b => b.Starred)`. First write path: `POST /{id}/star` / `POST /{id}/unstar`. Shared across every viewer (spec.md Assumptions) — no per-user table. |
| `IsDeleted`/`DeletedDate`/`DeletedBy` | soft-delete trio | Existing (003). First write path: `DELETE /v1/boards/{id}`. |
| `Color` | `nvarchar` | Existing, unchanged — assigned automatically at creation (rotating palette, matching the prototype's own `colors[boards.length % colors.length]`), never user-editable in this feature. |

## List *(schema change — `+ RowVersion`)*

| Column | Type | Notes |
|---|---|---|
| `RowVersion` | `rowversion` (`byte[]`, EF `.IsRowVersion()`) | **New.** Backs `If-Match`/`409` on list rename and WIP-limit edits (ADR-27). |
| `Name` | `nvarchar` | Existing (003). First user-driven write path: `POST /v1/boards/{id}/lists` (create) and `PATCH /v1/lists/{id}` (rename) — previously fixed at seed/board-creation time. |
| `WipLimit` | `int?` | Existing (003), display-only until now. First write path: `PATCH /v1/lists/{id}`; `null`/`0` both mean "no limit" (matching the prototype's own `Math.max(0, ...)` convention — this feature stores `null` for "none", not `0`, so the existing `list.wipLimit ? ... : ...` display check in 003/004/005 keeps working unchanged). |
| `Position` | `double` | Existing (001/005). First write path for list *creation* specifically (`Ordering.Append`, ADR-28) and for the due-date sort's per-card rewrite (on `Card.Position`, not `List.Position` — see below). |
| `IsDeleted`/`DeletedDate`/`DeletedBy` | soft-delete trio | Existing (003). First write path: `DELETE /v1/lists/{id}` — cascades to every `Card` currently in the list (research R-5). |

## Card *(unchanged schema — `Position` gets a second write trigger)*

No new column. `Card.Position` is rewritten for every card in a list when that list's
"sort by due date" action runs (research R-1) — the same column 005 already made
writable via drag/move, now written in bulk by one list-scoped action instead of one
card at a time. `Card.IsDeleted`/`DeletedDate`/`DeletedBy` are set for every card
belonging to a list that gets deleted (research R-5), using the same soft-delete
convention 004 already established for a single deleted card.

## Response DTOs

- `POST /v1/boards` → `201 Created`, body `BoardSummaryDto` (existing shape from 003's
  `ListBoardsAsync`: `{ publicId, name, color, starred, cardCount }`) plus the three
  created lists' `{ publicId, name }` so the client can navigate straight to the new
  board with its starter lists already known, no extra round-trip.
- `PATCH /v1/boards/{id}` → `200 OK`, body `{ name }` + the new `RowVersion` (base64,
  matching `PATCH /v1/cards/{id}`'s existing `If-Match` response convention exactly) so
  the client can immediately re-arm its next edit's precondition.
- `POST /v1/boards/{id}/star` / `.../unstar` → `204 No Content` (matches `DELETE
  /v1/cards/{id}`'s existing no-body convention — the caller already knows the outcome it
  requested).
- `DELETE /v1/boards/{id}` → `204 No Content`.
- `POST /v1/boards/{id}/lists` → `201 Created`, body `{ publicId, name, wipLimit: null,
  cardCount: 0 }` (matches `POST /v1/lists/{id}/cards`'s existing `CardSummaryDto` shape
  convention, sized for a list instead of a card).
- `PATCH /v1/lists/{id}` → `200 OK`, body `{ name, wipLimit }` + the new `RowVersion`.
- `POST /v1/lists/{id}/archive-cards` → `204 No Content`.
- `POST /v1/lists/{id}/sort` → `204 No Content` (the client's own next `boards.
  getContent` refetch shows the new order — no optimistic client-side sort is attempted,
  unlike drag/move's ADR-22, since this isn't a pointer-tracked interaction that needs to
  feel instantaneous).
- `DELETE /v1/lists/{id}` → `204 No Content`.
