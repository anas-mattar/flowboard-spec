# Quickstart — 007 Search & Filter

How to run and verify this feature locally once implemented. No migration — one additive
DTO field on an existing endpoint (`contracts/search-filter-addendum.md`).

## 1. Start both services

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

## 2. Verify the backend response gained `description`

```powershell
curl http://localhost:5111/v1/boards/<board-public-id> `
  -H "Authorization: Bearer <token>"
# -> 200, every card object under lists[].cards[] now has a "description" field
#    (string or null), alongside the existing "hasDescription" boolean.
```

## 3. Verify search (US1)

1. Open a board with cards spread across at least two lists.
2. Type a fragment of one card's title into the top-bar search box.
3. Confirm only matching cards remain visible, updating after every keystroke, with no
   page reload.
4. Type a fragment that only appears in a card's *description* (not its title) and
   confirm that card still appears.
5. Clear the search box and confirm every card reappears.

## 4. Verify filters (US2) and chips (US3)

1. Click **Filter**, select one label — confirm only cards carrying that label remain,
   and a chip `Label: <name>` appears in the chip bar under the top bar, with "Clear all".
2. Select a member too — confirm the visible set narrows further (AND across categories:
   label **and** member).
3. Select a due-date bucket (Overdue / Due in the next 7 days / No due date) — confirm it
   combines with the existing filters the same way.
4. Click one chip's ✕ — confirm only that filter is removed, others stay active.
5. Click **Clear all** — confirm every card reappears and the chip bar disappears
   entirely.

## 5. Verify the empty state (US4)

1. With a filter active, find a list where zero cards match.
2. Confirm that list shows "No cards match the filter" instead of its ordinary empty-list
   state, while its header's count/WIP pill still shows the list's true, unfiltered count.
3. Clear the filter and confirm a genuinely empty list instead shows its ordinary
   empty-list affordance ("No cards yet." + the "+ Add a card" composer, per 004 — not the
   prototype's own "Drop cards here" wording), not the filter message.

## 6. Verify board-switch reset

1. With a search term and a filter active, switch to a different board in the sidebar.
2. Confirm the search box is empty, the chip bar is gone, and every card on the new board
   is visible — the previous board's filter must not carry over.

## 7. Verify the keyboard shortcut (X-03)

1. Click anywhere on the board canvas (not inside a text field).
2. Press `/` (or `F`) — confirm focus moves to the search box.
