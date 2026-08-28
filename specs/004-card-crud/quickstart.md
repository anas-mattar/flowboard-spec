# Quickstart — 004 Card Lifecycle CRUD

How to run and verify this feature locally once implemented. Assumes 003's setup is
already done (migrated `flowboard-db`, a signed-in session with at least one accessible
board carrying real lists and cards).

## 1. Apply the database migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

Adds `ActivityEvent` and `ChecklistItem.PublicId` (data-model.md). No seed changes —
existing 003 boards/cards are unaffected; every mutation this feature adds is exercised
against them directly.

## 2. Start the backend

```powershell
dotnet run --project src/Flowboard.Api
```

Verify directly (using a signed-in member's token):

```powershell
curl -X POST http://localhost:5111/v1/lists/<list-public-id>/cards `
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" `
  -d '{"title":"Quickstart test card"}'
# -> 201, a CardSummary with the new title
```

## 3. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Sign in as a board member or admin (an Observer account demonstrates the read-only
edge case in the table below).

## 4. Verify the user stories

| Story | Check |
|---|---|
| US1 — add a card | Open a board, click "+ Add a card" on any list, type a title, press Enter; confirm it appears at the bottom of that list and the composer stays open. Press Escape on a fresh composer with text typed; confirm it closes and adds nothing. |
| US2 — open a card | Click any card (seeded or just-added); confirm the detail modal opens showing title, breadcrumb, labels/members/description/checklist sections (empty or populated), and an activity feed with at least a "created this card" entry. Close via ✕, an outside click, and Escape — confirm each returns to the unchanged board. |
| US3 — edit title/description | Rename a card from the modal; confirm the board and modal header both update. Add a description and Save; confirm the card front gains a description indicator; clear it and Save again, confirm the indicator disappears. Open the same card in two browser windows, edit the description in both, save the first, then the second — confirm the second save is rejected with a "changed by someone else" message. |
| US4 — labels/members | Assign an existing label; confirm its chip appears on the card front. Assign a board member; confirm their avatar appears. Assign someone who is not yet a board member; confirm they appear in the board's own membership afterward. |
| US5 — due date | Set a near-future due date; confirm an amber badge. Set a past date; confirm red. Mark complete; confirm green. Clear it; confirm the badge disappears entirely. |
| US6 — checklist | Add three checklist items; confirm "0/3" on the card front. Tick one; confirm "1/3" and the modal's progress bar update together. Delete one; confirm the total drops to 2. |
| US7 — comments/activity | Post a comment; confirm it appears at the top of the activity feed with your name and a timestamp, and the card front's comment-count badge increases. Confirm every other edit made above (rename, label, member, due date, checklist) has its own entry in the same feed. |
| US8 — copy/delete | Copy a card with a label, a member, and a due date; confirm the copy appears directly below it with " (copy)" appended, the same label/member/due date, and a fresh activity feed. Delete a different card with confirmation; confirm it no longer appears anywhere on the board. |
| Edge — Observer | Sign in as an Observer; open a card; confirm every control except the comment box is absent or disabled, and posting a comment still works. |
| Edge — permission at the API | As an Observer, call any mutating route directly (e.g. the `PATCH` above) with that account's token; confirm `403`, not just a hidden button. |

## 5. Gates (run by the feature owner; this feature is Standard delivery, not Critical —
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
Visual Compliance Loop against `screenshots/card-detail-modal.png` before requesting the
gate — follows.
