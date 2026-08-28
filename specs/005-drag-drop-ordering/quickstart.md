# Quickstart — 005 Drag & Drop Ordering

How to run and verify this feature locally once implemented. Assumes 004's setup is
already done. No migration this feature — `Card.Position`/`Card.ListId`/`List.Position`
already exist; nothing to apply.

## 1. Start the backend

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

Verify directly (using a signed-in member's token):

```powershell
curl -X POST http://localhost:5111/v1/cards/<card-public-id>/move `
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" `
  -d '{"listPublicId":"<a-different-list-public-id>"}'
# -> 204, and the card's activity feed gains a "moved this card from X to Y" entry
```

## 2. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Sign in as a board member or admin (an Observer account demonstrates the read-only edge
case below).

## 3. Verify the user stories

| Story | Check |
|---|---|
| US1 — reorder or move a card by dragging | Drag a card to a new spot within its own list; confirm it lands exactly there and stays there after a reload. Drag a card into a different list, dropping it in the middle of that list's cards; confirm it lands at that spot, disappears from the source list, and its activity feed gains a "moved this card from X to Y" entry. Drag a card within the same list only (no list change); confirm no new activity entry appears. Drop a card into a list already at/over its WIP limit; confirm the drop still succeeds and the existing over-limit pill just updates its count. |
| US2 — move a card via an accessible menu | Open a card, click "Move", confirm a "Move to list" popover lists every list on the board with a checkmark next to the current one. Choose a different list; confirm the card moves to the end of that list, the same activity entry appears, and a toast confirms it. Choose the card's own current list; confirm nothing happens. Open the menu and press Escape; confirm it closes with no move. |
| US3 — reorder lists by dragging | Drag a list to a new position among the others; confirm the new left-to-right order persists after a reload. Drop a list back into its starting position; confirm nothing changes. |
| Edge — Observer | Sign in as an Observer; confirm no card or list is draggable and the "Move" button is unavailable inside an open card. |
| Edge — permission at the API | As an Observer, call `POST /v1/cards/{id}/move` directly with that account's token; confirm `403`, not just an unavailable button. |
| Edge — last-write-wins | Open the same board in two windows signed in as different members; move the same card from both at nearly the same time; confirm neither request is rejected — the later one simply wins, with no conflict error shown to either window. |

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

Both must print `EXIT: 0`. Phase A (backend) gates and merges first (cross-repository
rule, `docs/sdlc/repository-strategy.md`); Phase B (frontend) — which also runs the
Visual Compliance Loop against `screenshots/` before requesting the gate — follows.
