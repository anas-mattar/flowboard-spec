# Quickstart — 006 Board & List Management

How to run and verify this feature locally once implemented. Assumes 005's setup is
already done. This feature has one migration (`RowVersion` added to `Board` and `List`) —
apply it before testing.

## 0. Apply the migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

## 1. Start the backend

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

Verify directly (using a signed-in member's token):

```powershell
curl -X POST http://localhost:5111/v1/boards `
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" `
  -d '{"name":"Q4 Planning"}'
# -> 201, body includes three lists: "To Do", "Doing", "Done"

curl -X POST http://localhost:5111/v1/boards/<board-public-id>/lists `
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" `
  -d '{"name":"Blocked"}'
# -> 201

curl -X PATCH http://localhost:5111/v1/lists/<list-public-id> `
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" `
  -H "If-Match: \"<row-version-base64>\"" `
  -d '{"wipLimit":2}'
# -> 200, body includes the new RowVersion
```

## 2. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Sign in as a board admin, a plain board member, and an Observer in turn — this feature is
the first where those two mutating roles (admin vs. member) genuinely diverge, so both
need checking, not just "member vs. Observer" like 004/005.

## 3. Verify the user stories

| Story | Check |
|---|---|
| US1 — create a board | Create a board named "Q4 Planning"; confirm it appears in the sidebar, becomes active, and shows three empty lists in order: "To Do", "Doing", "Done". Open its member list; confirm the creator shows as Board Admin. |
| US2 — add a list | On a board with existing lists, add one named "Blocked"; confirm it renders rightmost, empty, no WIP limit, and immediately accepts a card. |
| US3 — rename a board inline | As a board admin, edit the header title and blur; confirm the sidebar updates too. Clear the field entirely and blur; confirm the old name is kept. As a plain board member, confirm no rename control is available at all. |
| US4 — rename a list inline | Edit a list's header title and blur; confirm it persists after a reload. |
| US5 — star a board | Star a board that isn't first in the sidebar; confirm it moves to the top. Unstar it; confirm it returns to its normal position. Sign in as a different member of the same board; confirm they see the same starred state (shared, not personal). |
| US6 — WIP limit | Set a list's WIP limit equal to its current card count; confirm the pill shows the normal style. Add one more card; confirm the pill switches to its over-limit style and the card is still accepted. Clear the limit; confirm the pill reverts to a plain count. |
| US7 — archive/delete a board | As a board admin, delete a board through its confirmation step; confirm it disappears from every member's sidebar. As a plain board member, confirm no delete control is available, and a direct API call with that member's token returns `403`. |
| US8 — archive/delete a list | Archive all cards in a list with cards; confirm the list remains, now empty. Delete a list with cards; confirm the list disappears from the board and its cards are gone from the board but still resolvable (e.g. their own comments/activity, if reachable through an existing route). |
| US9 — sort by due date | On a list with a mix of due and undated cards, trigger the sort; confirm ascending order with undated cards last. Trigger it again with nothing changed; confirm the order is unchanged. |
| Edge — Observer | Sign in as an Observer; confirm no create/rename/star/WIP/sort/archive/delete control is visible anywhere in this feature. |
| Edge — permission at the API (member vs. admin) | As a plain board member's token, call `PATCH /v1/boards/{id}` or `DELETE /v1/boards/{id}` directly; confirm `403` even though that same token succeeds against `PATCH /v1/lists/{id}`. |
| Edge — stale rename | Open the same board's title in two tabs signed in as the same admin; rename it in one tab, then attempt to rename it in the second tab using its now-stale `RowVersion`; confirm `409`, not a silent overwrite. |

## 4. Gates (run by the feature owner; this feature is Standard delivery, not Critical —
   an agent-run fast-feedback loop during implementation is allowed per
   `docs/sdlc/gate-command.md`, but the certifying run is always the user's)

```powershell
cd D:\solutions\flowboard\flowboard-api ; dotnet build --warnaserror && dotnet test
"EXIT: $LASTEXITCODE"
```

```powershell
cd D:\solutions\flowboard\flowboard-web ; npm run lint && npm run build
"EXIT: $LASTEXITCODE"
```

Both must print `EXIT: 0`. Phase A (backend, including the migration) gates and merges
first (cross-repository rule, `docs/sdlc/repository-strategy.md`); Phase B (frontend) —
which also runs the Visual Compliance Loop against `screenshots/` before requesting the
gate — follows.
