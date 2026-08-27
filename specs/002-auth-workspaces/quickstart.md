# Quickstart — 002 Auth & Workspaces

How to run and verify this feature locally once implemented.

## Prerequisites

- .NET SDK 10.0.2xx (pinned by `flowboard-api/global.json`)
- Node 22 + npm
- SQL Server LocalDB (`(localdb)\MSSQLLocalDB`) available — ships with the SQL Server
  Express LocalDB feature / Visual Studio installer
- `flowboard-api`: `dotnet tool restore` once, to install the repo-local `dotnet-ef`
  (research R-8)

## 1. Provision local secrets (one-time per machine)

Neither secret is committed. Each developer generates their own.

**Backend — JWT signing key** (`Jwt:SigningKey`, HMACSHA256, read by `TokenService`/
`Program.cs`'s `AddJwtBearer`): stored in .NET user-secrets, never in `appsettings.json`
(which only holds the non-secret `Jwt:Issuer`/`Jwt:Audience`).

```powershell
cd D:\solutions\flowboard\flowboard-api\src\Flowboard.Api
dotnet user-secrets set "Jwt:SigningKey" "$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")"
```

(Any base64-encoded 32-byte value works — the `node` one-liner is just a convenient
generator; `openssl rand -base64 32` works identically.)

**Frontend — `NEXTAUTH_SECRET`** (encrypts the NextAuth session/JWT cookie): copy
`flowboard-web/.env.example` to `flowboard-web/.env.local` and replace the placeholder:

```powershell
cd D:\solutions\flowboard\flowboard-web
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
# paste the output as NEXTAUTH_SECRET= in .env.local
```

`.env.local` is gitignored; `.env.example` keeps only the placeholder and this generation
command (`docs/rulebooks/frontend-rules.md` Known failure modes).

## 2. Apply the database migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet tool restore
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

Creates `flowboard-db` on `(localdb)\MSSQLLocalDB` with the `User`, `Workspace`,
`Board`, `BoardMember`, `Invitation` tables and one seeded fixture **user, workspace,
and board** (data-model.md; `fixture-owner@flowboard.test`) used by the backend
integration tests. This account cannot be logged into — its seeded `PasswordHash` is a
non-verifiable placeholder (second-model-adversarial-review.md B1); the real test-only
hash is set separately, only in the disposable `flowboard-db-test` database, by the
test host.

## 3. Start the backend

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

## 4. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

Open `http://localhost:3000/signup`.

## 5. Verify the user stories

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

## 6. Gates (run by the feature owner; agent runs are feedback only — Critical
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

## 7. Walkthrough results (T056, 2026-08-27)

Both dev servers were started locally (`dotnet run` on :5111, `npm run dev` on :3000)
and every row above was exercised against the live instance. No doc drift was found —
every step's request/response shape and every status code matched this document as
written; step numbering above was renumbered (this section was added, and step 1
inserted) but no instructional content changed.

| Row | Result |
|---|---|
| US1 signup & sign in | Signup → 201 with `workspace.role: "WorkspaceAdmin"`; login with the same credentials → 200 with a fresh token |
| US1 edge — wrong password | 401, `title: "Invalid email or password"` |
| US1 edge — unknown email | 401, **identical** body to wrong-password (byte-for-byte same `title`) — confirms FR-004 holds on a live instance, not just in the test host |
| US1 edge — duplicate email | 409, `title: "email already in use"` |
| US2 — personal workspace | Signup response already carries `workspace.name: "<Display Name>'s Workspace"` — no separate creation step exists to test |
| US3 — invite to a board | Fixture owner invites a second (already-registered) account as `BoardMember` → 201; that account's `GET /members` immediately lists both the owner and itself |
| US3 edge — invite unregistered email | Invite → 201 pending invitation; signing up with that exact email afterward → the account appears in `GET /members` immediately, no accept step |
| US4 — access denied | A third account, never invited, → `GET /members` on the fixture board → 404 |
| US4 — role enforcement | An `Observer` invitee → `GET /members` succeeds (200, read allowed); `POST /invitations` as that same Observer → 403 |
| US4 — live privilege change | Already covered by an automated test (`BoardMembersEndpointTests.RemovingMember_TakesEffectOnVeryNextRequest_NotJustAfterFreshLogin`, passing) rather than re-derived manually here — see note below |
| US5 — sign out | Not exercised interactively (see note below); statically confirmed instead: an unauthenticated request to `/boards/{id}` on the running frontend returns `307` to `/login` |

**Notes**:
- The login-rate-limiter (F2, `ai-code-review-phase-a.md`) fired for real during this
  walkthrough — repeated scripted logins from one IP hit `429` within the same minute.
  This is the fix working as intended on a live instance, not a defect; it did briefly
  block the "live privilege change" row's manual re-check, which is why that row leans
  on the existing automated test instead of a second manual proof.
- This walkthrough was performed at the HTTP layer (`curl` against the backend,
  page-level `curl` against the frontend's SSR output) plus a scan of both dev servers'
  logs for runtime errors (none found). Interactive browser clicks (typing into the
  actual signup/login forms, clicking the sign-out button, watching toasts) were **not**
  performed — no browser automation session was available in this run. The HTTP-level
  checks above cover every contract behavior these forms depend on (tRPC → backend
  request/response shapes, NextAuth's server-side redirect guard), but a human should
  still click through `/signup` → `/login` → sign out once before considering US1/US5
  fully closed, since that is the one path with zero automated coverage this walkthrough
  could not substitute for.
