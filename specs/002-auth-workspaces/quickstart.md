# Quickstart — 002 Auth & Workspaces

How to run and verify this feature locally once implemented.

## Prerequisites

- .NET SDK 10.0.2xx (pinned by `flowboard-api/global.json`)
- Node 22 + npm
- SQL Server LocalDB (`(localdb)\MSSQLLocalDB`) available — ships with the SQL Server
  Express LocalDB feature / Visual Studio installer
- `flowboard-api`: `dotnet tool restore` once, to install the repo-local `dotnet-ef`
  (research R-8)

## 1. Apply the database migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet tool restore
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

Creates `flowboard-db` on `(localdb)\MSSQLLocalDB` with the `User`, `Workspace`,
`Board`, `BoardMember`, `Invitation` tables and the one seeded fixture board
(data-model.md).

## 2. Start the backend

```powershell
dotnet run --project src/Flowboard.Api
```

Verify directly:

```powershell
curl -X POST http://localhost:5111/v1/auth/signup `
  -H "Content-Type: application/json" `
  -d '{"email":"maya@example.com","password":"correct horse battery staple","displayName":"Maya Chen"}'
# → 201, { user, workspace, token, expiresAtUtc }
```

## 3. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Open `http://localhost:3000/signup`.

## 4. Verify the user stories

| Story | Check |
|---|---|
| US1 — signup & sign in | Create an account at `/signup`; land signed in. Sign out, sign back in at `/login` with the same credentials. Reload the page while signed in → still signed in. |
| US1 edge — wrong password | Sign in with a correct email and wrong password → generic "invalid email or password" message, not "wrong password" |
| US1 edge — duplicate email | Sign up twice with the same email → second attempt refused, no duplicate account created |
| US2 — personal workspace | After signup, the shell shows the auto-created workspace name; no separate "create workspace" step was needed |
| US3 — invite to a board | As the signed-in workspace owner, invite a second email (one that already has an account, from a second signup) to the seeded fixture board with role `BoardMember`; confirm that account sees the board on next sign-in |
| US3 edge — invite unregistered email | Invite an email with no account yet; sign up with that exact email afterward → membership appears automatically, no separate "accept invite" step |
| US4 — access denied | Sign in as a third account never invited to the board; confirm it cannot see or act on that board (`404`-style: not silently empty, not an error page — see contracts/board-membership-api.md) |
| US4 — role enforcement | As an `Observer` on the board, confirm invite/remove actions are unavailable in the UI, and confirm the underlying API call is refused (`403`) if attempted directly |
| US5 — sign out | Sign out; confirm the previously visible board/workspace page now requires signing in again |

## 5. Gates (run by the feature owner; agent runs are feedback only — Critical
   Delivery Addendum: human-executed gates only, `docs/sdlc/critical-delivery.md`)

```powershell
cd D:\solutions\flowboard\flowboard-api ; dotnet build --warnaserror && dotnet test
"EXIT: $LASTEXITCODE"
```

```powershell
cd D:\solutions\flowboard\flowboard-web ; npm run lint && npm run build
"EXIT: $LASTEXITCODE"
```

Both must print `EXIT: 0`. Phase A (backend) is certified by the first and merges
first (cross-repository rule, `docs/sdlc/repository-strategy.md`); Phase B (frontend)
is certified by the second. Both phase reviews must include the domain-invariant
item-by-item pass required by the Critical Delivery Addendum.
