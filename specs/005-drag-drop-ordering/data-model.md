# Data Model: Drag & Drop Ordering

Phase 1 output. No new entities, no migration — this feature is the first to give three
already-existing columns a real, repeated, user-driven write path. All entities follow
`docs/rulebooks/database-rules.md`.

## Card *(unchanged schema, extended from 001/003/004 — first real move write path)*

`ListId` and `Position` (both existing since 001) are now written by a real user action
for the first time, outside of seed data and 004's create/copy paths. `RowVersion`
still advances on a move (any tracked-entity update bumps SQL Server's `rowversion`
column automatically) but the move endpoint never reads or checks it — ADR-21's
deliberate no-precondition design. `UpdatedDate`/`UpdatedBy` are set on every move,
matching every other mutation's audit-field convention.

## List *(unchanged schema, extended from 001/003 — first real move write path)*

`Position` (existing since 001) is now written by a real user action for the first time
— previously fixed at seed time (003's own data-model.md, research R-8, explicitly
deferred this until a real write path needed it). `UpdatedDate`/`UpdatedBy` set on every
reorder, same convention.

## ActivityEvent *(extended — one new `Type` value)*

| Value | Written when | Payload |
|---|---|---|
| `card.moved` | A card's resolved destination list differs from its current list (research R-3) — never for a same-list reorder | `{ "fromListName": "...", "toListName": "..." }` |

No new columns; this is an addition to the existing enumerated `Type` values 004 already
established (`data-model.md`'s own `ActivityEvent.Type` list), not a schema change.

## Response DTOs

Neither move endpoint returns a body (both `204 No Content`, matching `DELETE
/v1/cards/{id}`'s existing precedent) — the caller already knows the outcome it
requested optimistically (plan.md ADR-22), and `boards.getContent`'s next
invalidation/refetch is the reconciled source of truth. No new DTO shapes this feature
introduces.
