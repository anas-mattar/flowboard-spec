# Quickstart — 003 Board View (Read-Only)

How to run and verify this feature locally once implemented. Assumes 002's setup is
already done (JWT signing key, `NEXTAUTH_SECRET`, an existing `flowboard-db`).

## 1. Apply the database migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

Adds `Color`/`Starred` to `Board`, creates `List`, `Card`, `Label`, `CardLabel`,
`CardMember`, `ChecklistItem`, `Comment`, and seeds three boards under the existing
fixture workspace (`fixture-owner@flowboard.test`) reproducing
`screenshots/board-canvas.png` (data-model.md).

## 2. Start the backend

```powershell
dotnet run --project src/Flowboard.Api
```

Verify directly (using the fixture owner's token from 002's quickstart login step):

```powershell
curl http://localhost:5111/v1/boards -H "Authorization: Bearer <token>"
# -> 200, { items: [4 boards], nextCursor: null }
# (the 3 seeded here, plus 002's bare "Fixture Board" — the fixture owner owns its
# workspace directly, so it's visible too; this migration also gives it a Color)
```

## 3. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Sign in as the fixture owner at `http://localhost:3000/login`
(`fixture-owner@flowboard.test` — see 002's quickstart for how to set that account's
password in your local dev database, since the migration seed itself ships a disabled
placeholder credential, not a real one).

## 4. Verify the user stories

| Story | Check |
|---|---|
| US1 — view my boards and open one | Sidebar lists the 3 seeded boards (plus any from 002's bare fixture board, if it has a name/color too) with correct card counts; click "Product Roadmap Q3" and confirm its 4 lists and cards render in the same order and with the same labels/badges/avatars as `screenshots/board-canvas.png` |
| US1 — card front indicators | Confirm a card with no due date/labels/checklist/comments shows only its title (VI-011); confirm a card with all of them shows every applicable indicator and nothing else |
| US1 edge — no access | Sign in as an account with zero board access; confirm the sidebar shows an explicit empty state, not a blank area |
| US1 edge — access denied by URL | Open a board URL you don't have access to; confirm the same access-denied outcome as 002's board-members page (not the board's content) |
| US2 — theme | With a board open, toggle theme; confirm the sidebar, top bar, canvas, lists, and cards all switch immediately |
| US3 — sidebar collapse | Collapse the sidebar; confirm the canvas expands to use the freed width; expand it again and confirm the same boards still show, with the open one still highlighted |
| US4 — keyboard | Using only Tab/Shift+Tab and Enter/Space, reach and activate a sidebar board link, the sidebar collapse control, and the theme toggle |

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
Visual Compliance Loop against `screenshots/board-canvas.png` before requesting the
gate — follows.
