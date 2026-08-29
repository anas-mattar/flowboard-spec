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

## 5. Walkthrough results (T022, 2026-08-29)

Both dev servers were exercised against the just-merged `main` on both repos (backend
`c16939d`, frontend `6e871ac`), driven live through a real browser session against the
seeded "Product Roadmap Q3" board. One row's check surfaced a real gap, fixed and
re-verified below; every other row matched this document exactly.

| Row | Result |
|---|---|
| US1 — same-list reorder | Dragging "Prototype smoke card" to the top of Backlog landed it there and the position survived a full page reload; its activity feed gained no new entry |
| US1 — cross-list move | Dragging "Accessibility audit" from Backlog into the middle of Design's cards landed it exactly there, removed it from Backlog, and wrote one `card.moved` event (`fromListName: "Backlog", toListName: "Design"`) — confirmed via the raw `cards.getActivity` response |
| US1 — WIP limit never blocks | Dropping "Empty-state illustrations" into "In Progress" (already 4/3, over limit) still succeeded; the pill just updated to 5/3 |
| US2 — Move menu, different list | Opening "Card detail redesign" and choosing "Review" moved it to the end of that list, showed a "Moved to \"Review\"" toast, and wrote the same `card.moved` event shape as a drag |
| US2 — Move menu, own list | Choosing the card's own current list ("Design") did nothing — no request fired, no toast, checkmark unchanged |
| US2 — Escape | Pressing Escape closed the "Move to list" popover with the card unmoved |
| US3 — list reorder | Dragging "Review" (last) to the first position moved it there and the new order survived a full page reload |
| US3 — same-position drop | Dropping "Review" back onto itself left the board's list order unchanged |
| Edge — Observer | A freshly invited Observer account saw every card/list with `draggable === false`, no "Add a card" composer on any list, and no "Move" button or "Add to card" panel at all inside an open card |
| Edge — permission at the API | The same Observer's token called `POST /v1/cards/{id}/move` directly against the backend → `403`, matching the UI-level gating rather than relying on it |
| Edge — last-write-wins | Not re-derived live this walkthrough — a same-browser-profile login switch (testing the Observer edge case above) overwrote the admin session's cookie before this row could be exercised, and no second known-password admin/member account remained to restore it without touching the dev database directly. Already covered by an automated, passing test (`MoveCard_TwoSuccessiveMoves_NeitherIsRejected_LastWriteWins`, `flowboard-api`), the same substitution 002's own quickstart walkthrough made for its blocked "live privilege change" row |

**Gap found and fixed**: the US1/US2 activity-feed checks above ("wrote one `card.moved`
event") were confirmed at the API layer first because the *rendered* activity feed showed
nothing at all — `CardActivityFeed`'s `describe()` switch (`card-activity-feed.tsx`) had no
`case "card.moved"`, so it silently fell through to `default: return null` instead of
rendering "moved this card from X to Y" (spec.md's own quoted wording for this exact row).
Fixed by adding that case; re-verified via a `next build` bundle inspection because the
`next dev` server serving this session's browser tab would not reflect the new component
code no matter how many clean cache-and-restart cycles were tried (see review-notes.md's
environment notes — the same class of dev-server-only staleness already recorded twice
elsewhere this feature, never present in a production build). See
`specs/005-drag-drop-ordering/review-notes.md`'s Wrap-up section for the fix's own
gate/review/merge record.
