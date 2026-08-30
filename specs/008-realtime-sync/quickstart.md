# Quickstart — 008 Realtime Sync & Concurrency

How to run and verify this feature locally once implemented. No migration.

## 1. Start both services

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

## 2. Verify the realtime token endpoint

```powershell
curl -X POST http://localhost:5111/v1/boards/<board-public-id>/realtime-token `
  -H "Authorization: Bearer <backend session token>"
# -> 200 { "token": "<jwt>", "expiresAt": "..." }
# decode the JWT (jwt.io or `dotnet user-jwts`-style inspection) and confirm claims:
# sub = your user PublicId, boardId = the board's PublicId, purpose = "realtime",
# exp ~2 minutes from now.
```

## 3. Verify live propagation (US1)

1. Open the same board in two browser windows/profiles, signed in as two different board
   members (or one member + one observer).
2. In window A: create a card. Confirm it appears in window B within about half a second,
   with no reload.
3. In window A: move a card to a different list. Confirm window B shows the move.
4. In window A: rename a list, edit a card's description, and add a comment. Confirm
   each appears live in window B.
5. Open a **second** board in window B. Make a change in window A's (different) board.
   Confirm nothing changes in window B — updates are scoped per board (FR-002).

## 4. Verify concurrency (US2)

1. Open the same card's detail modal in both windows.
2. In window A, edit the description and save.
3. In window B (still showing the pre-edit description), edit the description differently
   and save. Confirm window B's save is rejected and window B ends up showing window A's
   saved text — not a silent overwrite.
4. Drag the same card from both windows at nearly the same time. Confirm the card ends up
   in exactly one list/position in both windows after they settle — no duplicate, no
   phantom card.

## 5. Verify reconnect/catch-up (US3)

1. Open a board in one window. Open the browser devtools Network tab and go offline
   (or disable Wi-Fi briefly).
2. Confirm a visible "reconnecting"/"offline" indicator appears.
3. While offline, make several changes to the same board from a second, still-connected
   window.
4. Go back online. Confirm the first window's board updates to the current state without
   a manual page reload, and the indicator clears.

## 6. Verify graceful degradation (US4)

1. Block the hub connection (e.g. block requests to `/hubs/board` in devtools, or block
   the dev server's websocket port).
2. Open a board. Confirm it still loads and every existing 003–007 feature (create/edit/
   move cards, board/list management, search/filter) still works.
3. Confirm a manual refresh still reflects another window's changes even though the live
   indicator shows unavailable.

## 7. Verify access revocation (edge case, FR-007)

1. Open a board as a board member (window A) while a board admin (window B) removes that
   member from the board.
2. Confirm window A stops receiving updates and is shown the "you don't have access to
   this board" state within a few seconds.
