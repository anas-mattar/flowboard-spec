# Implementation Plan: Auth & Workspaces

**Branch**: `002-auth-workspaces` | **Date**: 2026-08-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-auth-workspaces/spec.md`
**Delivery Level**: **Critical** (`docs/sdlc/critical-delivery.md`) — see the Critical
Delivery Addendum section below for the additional requirements this triggers.

## Summary

Give FlowBoard its first real identity: email/password signup and sign-in, one
auto-provisioned workspace per user, board-scoped roles (Board admin / Board member /
Observer) granted via email invitation, and server-enforced authorization on every
board-scoped request. This is also the first feature to introduce a database — EF Core,
SQL Server, and the first migration all land here. Two delivery phases, cross-repository:
Phase A (backend: schema, auth, authorization) gates and merges first per
`docs/sdlc/repository-strategy.md`'s cross-repository rule; Phase B (frontend: NextAuth
wiring, signup/login UI, `protectedProcedure`) follows against the stable contract.

## Technical Context

**Language/Version**: C# / .NET 10 (unchanged from 001); TypeScript 5 strict / Node 22 (unchanged)
**Primary Dependencies**: ASP.NET Core minimal APIs (existing, ADR-1); NEW backend:
`Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.EntityFrameworkCore.Design`,
`Microsoft.AspNetCore.Authentication.JwtBearer`, `BCrypt.Net-Next`; NEW frontend:
`next-auth@beta` (Auth.js v5, still npm's `beta` tag — research R-4) — reusing tRPC v11 + Zod (001)
**Storage**: SQL Server — dev `(localdb)\MSSQLLocalDB` db `flowboard-db`; tests use a
disposable `flowboard-db-test`, migrated and reset per test run (CLAUDE.md stack
profile). **First feature to introduce a database** — DbContext, entity configurations,
and the first migration are created here.
**Testing**: backend — xUnit + `WebApplicationFactory` integration tests against
`flowboard-db-test`, covering success/validation-failure/authorization-failure per role
(backend rulebook Testing section); frontend — gate stays `npm run lint && npm run
build` (no frontend test runner yet, per 001 research R-5)
**Target Platform**: unchanged — web, latest two versions of Chrome/Edge/Firefox/Safari;
dev on Windows
**Project Type**: web application, two nested repos (unchanged, constitution III)
**Performance Goals**: signup/login at normal request latency; every board-scoped
request adds at most one indexed authorization lookup (`BoardAccessService`) — no N+1
**Constraints**: the browser never holds the raw backend JWT (ADR-2 continuation — it
lives only inside NextAuth's server-side, httpOnly-cookie-encrypted session token); the
JWT signing key is a secret (user-secrets/env var, never source, constitution VIII);
authorization is re-derived from the database on every request — never cached in a JWT
claim (spec edge case: a role change or removal must take effect on the very next
request, not next login)
**Scale/Scope**: 2 backend endpoint groups (auth; board membership/invitations) + 1
`DbContext` + 1 migration; frontend: signup/login pages, NextAuth wiring,
`protectedProcedure`, workspace identity surfaced in the existing shell

## Critical Delivery Addendum (`docs/sdlc/critical-delivery.md`)

This feature touches authentication and authorization — an explicit must-be-Critical
trigger. Additive requirements, on top of the standard workflow:

1. **Rollback plan before Phase 1** — `specs/002-auth-workspaces/rollback.md` is written
   as part of this planning pass (see Phase 1 outputs below), before any implementation
   task starts.
2. **Domain-invariant review** — both the AI review and the human review for each phase
   MUST include an explicit item-by-item pass over
   `docs/domain/flowboard-invariants.md` (invariants 5 and 8 are load-bearing for this
   feature), recorded in the phase's review notes.
3. **Audit evidence retained** — gate command + exit code, `git diff --stat` output, and
   both completed review checklists stay in `specs/002-auth-workspaces/`.
4. **Human-executed gates only** — no agent-run fast-feedback loop counts toward Done
   for this feature; every gate run that certifies a phase is run by the user.
5. **Independent approval** — solo-developer project: substitute a second-model
   adversarial review (`adoption/existing-system.md` step 6) plus a cooling-off period
   before merge, in place of a second human reviewer.

## Architecture Decisions (constitution IV — extending 001's founding record)

001's `plan.md` fixed the founding architecture (ADR-1..4). This feature does not
change any of them; it adds the decisions 001 explicitly deferred to "002+" and the new
ones a database/auth slice requires.

### ADR-5 — Introduce `Result<T>` / `ToHttpResult()` (fulfills 001 ADR-1's deferred item)

- **Decision**: `Flowboard.Api/Domain/Result.cs` defines a minimal `Result<T>` (success
  value or a typed failure: `Validation`, `Unauthorized`, `Forbidden`, `NotFound`,
  `Conflict`). `Endpoints/ResultMapping.cs` adds `ToHttpResult()` mapping each failure
  kind to the matching status code (400/401/403/404/409) as `ProblemDetails`
  (RFC 9457, backend rulebook API Surface). Every new endpoint handler in this feature
  returns through this mapping — no hand-rolled status-code switches.
- **Consequences**: this becomes the shared pattern for every endpoint with failure
  modes from here on (003+ inherit it rather than re-inventing per feature).

### ADR-6 — Database & ORM: EF Core, single `Flowboard.Api` project, one `DbContext`

- **Options considered**: (a) keep the current single-project layout and add
  `Data/FlowboardDbContext.cs` + `Data/Configurations/` + `Migrations/` inside it; (b)
  split out a new `Flowboard.Infrastructure` project now, ahead of need.
- **Decision**: (a). The project is still small; ADR-1's own text is explicit that new
  projects are added only when a feature's plan justifies them, and nothing here does.
  `Microsoft.EntityFrameworkCore.SqlServer` + `Microsoft.EntityFrameworkCore.Design` are
  added to `Flowboard.Api`; `dotnet-ef` is installed as a **repo-local tool**
  (`.config/dotnet-tools.json`, `dotnet tool restore` — CLAUDE.md known-failure-mode:
  never a global install). Migrations run with `Flowboard.Api` as the startup project
  (database rulebook).
- **Consequences**: entity classes under `Domain/Entities/`; EF configurations under
  `Data/Configurations/` (one `IEntityTypeConfiguration<T>` per entity, per the database
  standards example); `Migrations/` alongside. Revisit the single-project decision only
  when a future feature's plan demonstrates real pain, not preemptively.

### ADR-7 — Authentication: FlowBoard-issued JWT bearer tokens, BCrypt password hashing

- **Options considered**: (a) full ASP.NET Core Identity (`IdentityDbContext`,
  `UserManager`/`SignInManager`); (b) a hand-rolled `User` entity following this
  project's own `BaseEntity`/`PublicId` conventions, with `BCrypt.Net-Next` for hashing
  and `Microsoft.AspNetCore.Authentication.JwtBearer` for issuing/validating short-lived
  JWTs; (c) delegate to an external IdP (Auth0/Clerk) now.
- **Decision**: (b). Full ASP.NET Core Identity's default schema (string/GUID keys,
  `AspNetRoles`/`AspNetUserClaims`/etc.) does not fit constitution V's `INT IDENTITY` +
  `PublicId` standard and brings a global-role model FlowBoard doesn't use — every role
  here is board-scoped (invariant 5), not a system-wide `AspNetRole`. (c) is explicitly
  the Enterprise-tier plan (FUNCTIONAL_SPEC §8) and is not needed for v1.0 self-serve
  signup. BCrypt matches the product spec's own security requirement (§8:
  "bcrypt/argon2 password hashing") more directly than the framework's default PBKDF2
  hasher.
- **JWT shape**: claims are identity-only — `sub` (User.`PublicId`), `email`, `iat`,
  `exp`. Deliberately excludes workspace/board/role claims: authorization is always
  re-derived from the database per request (`BoardAccessService`, ADR-9) so a role
  change or removal takes effect on the caller's very next request, not next login
  (spec edge case). Lifetime: 14 days, matching the frontend session lifetime (below) —
  no refresh-token rotation in v1.0 scope (see Assumptions in spec.md and the Deferred
  section below).
- **Consequences**: `Services/PasswordHasher.cs` wraps BCrypt; `Services/TokenService.cs`
  issues/validates JWTs; `Program.cs` adds `AddAuthentication().AddJwtBearer(...)` +
  `AddAuthorization()`. The JWT signing key is a secret (user-secrets in dev, an
  environment variable in every other environment) — never `appsettings.json`.

### ADR-8 — Session provider (frontend): NextAuth (Auth.js) v5, Credentials provider

- **Options considered**: (a) hand-rolled cookie/session code in Next.js; (b) NextAuth
  (Auth.js) v5 with a `Credentials` provider whose `authorize()` calls the backend login
  endpoint server-side; (c) client-side token storage (rejected outright — violates
  frontend-security.md §9 and ADR-2's "browser never holds the backend token").
- **Decision**: (b) — this is the rulebook's own "default candidate"
  (`frontend-state-auth-style.md`). JWT session strategy: `callbacks.jwt` stores the
  backend-issued token inside NextAuth's own encrypted, httpOnly session token (never
  read by browser JS); `callbacks.session` exposes to the client ONLY
  `{ user: { publicId, email, displayName, workspacePublicId, workspaceRole } }` —
  the raw backend JWT is deliberately never copied into the client-visible `session`
  object. Session `maxAge`: 14 days, matching ADR-7's backend token lifetime.
- **Consequences**: `lib/auth/auth-config.ts` (NextAuth config), `lib/auth/session.ts`
  (server-side current-user helpers, per the frontend rulebook's `lib/auth/`
  convention), `app/api/auth/[...nextauth]/route.ts`. tRPC context (created per request,
  server-side) reads the full token — including the backend JWT — via NextAuth's
  server-side session accessor, and attaches `Authorization: Bearer <token>` when
  `lib/api/*-client.ts` calls the .NET API. This is the trigger `frontend-trpc.md`
  names for adding `protectedProcedure` — done here; existing `health.status` stays on
  `publicProcedure` (no change).

### ADR-9 — Authorization: per-request `BoardAccessService`, no cached role claims

- **Decision**: one backend service resolves a caller's effective role for a board on
  every protected request: (1) resolve `Board` by `PublicId` → `WorkspaceId`; (2) if
  `Workspace.OwnerUserId` is the caller, effective role is `BoardAdmin` (ADR-10's
  implicit-admin rule, FR-015) — no separate `BoardMember` row required; (3) else look
  up the caller's `BoardMember` row for that board; (4) else the caller has no access.
  Every board-scoped endpoint calls this service before doing anything else (backend
  rulebook: "board-membership-scoped... a valid token is not board access").
- **Consequences**: this is the shared authorization primitive 003+ reuse — later
  features add board-scoped endpoints by calling the same service, not re-deriving the
  check. A caller with no access gets `404` (existence is not confirmed to a
  non-member); a caller with access but an insufficient role for the specific action
  gets `403`.

### ADR-10 — Workspace admin model: single owner, no workspace-member table

- **Decision**: `Workspace.OwnerUserId` (FK → `User.Id`) is the workspace admin — set
  once at signup, never reassigned in this feature. No `WorkspaceMember` join table:
  FUNCTIONAL_SPEC has no workspace-membership user story (only board membership, B-05),
  and "multiple workspaces per account" being out of v1.0 scope (§1.2) implies exactly
  one admin-owner per workspace. This is spec.md's own documented assumption; recorded
  here as the schema decision that implements it.
- **Consequences**: adding multiple workspace admins or workspace-level invites is an
  amendment to this ADR (and to spec.md's assumption), not a silent schema change in a
  later feature.

### ADR-11 — Board table: minimal placeholder schema, full CRUD deferred to 006

- **Decision**: this feature creates the `Board` table with only the columns
  `BoardMember`/`Invitation` foreign keys and this feature's own tests need:
  `Id`, `PublicId`, `WorkspaceId`, `Name`, plus audit + soft-delete fields. Color,
  starred, and the three-board prototype seed belong to 003 (read-only render) and 006
  (board CRUD) per `docs/roadmap.md` — this feature adds one deterministic
  `HasData` seed board (fixed id/timestamps, database rulebook) solely so its own
  integration tests have a real board to invite/authorize against.
- **Consequences**: 003/006 extend this same table (add columns via their own
  migrations) rather than redefining it. No board-creation or board-rename endpoint
  ships in this feature — inviting/authorizing is all that's in scope (spec.md FR-008
  onward).

### Package approvals (constitution IV)

- Backend NEW: `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.EntityFrameworkCore.Design`
  (EF Core 10, matching the stack profile), `Microsoft.AspNetCore.Authentication.JwtBearer`,
  `BCrypt.Net-Next`. Tooling: `dotnet-ef` as a repo-local tool
  (`.config/dotnet-tools.json`), not a global install.
- Frontend NEW: `next-auth@beta` (Auth.js v5, `5.0.0-beta.32` — still on npm's `beta`
  tag, no GA exists; accepted deliberately for this Critical feature, user-confirmed —
  research R-4).
- Explicitly deferred (not this feature): any email-delivery provider (invitations take
  effect by matching email at signup/login — no email is sent, so no External
  Integration Governance (IX) contract is needed yet); refresh-token rotation /
  server-side token revocation (denylist) — v1.0 relies on a 14-day token lifetime and
  the frontend discarding its session on sign-out; ASP.NET Core Identity, SSO/SAML.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist PASS); this
  plan precedes tasks.md and implementation.
- [x] **Source of Truth (II)**: No visual references exist for auth/signup/login
  screens — the prototype explicitly stubs authentication out (FUNCTIONAL_SPEC §9), so
  there is nothing to conflict with. Frontend pages follow the rulebook's structure and
  the existing shell's styling; no Visual Compliance Loop applies (no screenshots to
  compare against). spec.md → this plan → contracts have no conflicts.
- [x] **Repository Separation (III)**: Backend work lands only in `flowboard-api`
  (schema, auth, authorization); frontend only in `flowboard-web` (NextAuth, pages,
  `protectedProcedure`). No mixing.
- [x] **Architecture Consistency (IV)**: ADR-5..11 above, approved in this plan; no
  contradiction of 001's ADR-1..4.
- [x] **Data Standards (V)**: All new entities use `Id INT IDENTITY` + `PublicId
  UNIQUEIDENTIFIER UNIQUE` where API-addressed (`User`, `Workspace`, `Board`,
  `Invitation`). `BoardMember` is a pure join entity never addressed by a bare
  identifier (always via board+user `PublicId`s) — still given a surrogate `Id` for
  uniformity (no PK deviation to justify).
- [x] **Auditability (VI)**: `Workspace` and `Board` get full audit + soft-delete
  fields (they are in the database standards' soft-delete entity list). `User` gets
  audit fields only (not in that list — no account soft-delete/erasure flow in this
  feature, per spec.md Assumptions). `BoardMember` gets `CreatedDate`/`CreatedBy` only
  (removal is a hard delete of the membership row, not of business master data).
  `Invitation` gets audit fields plus its own `Status` lifecycle (Pending/Accepted/
  Revoked) in place of soft-delete.
- [x] **Domain Invariants (VII)**: Invariant 5 (server-side, board-membership-scoped
  permissions) is this feature's core deliverable (ADR-9). Invariant 8 (opaque public
  identifiers) applied to every new entity's API surface. Invariants 1/2/3/4/6/7 are
  N/A — no activity events, ordering, WIP limits, cards, concurrency edits, or labels
  exist yet.
- [x] **Security (VIII)**: Authentication (JWT) required for every protected endpoint;
  authorization enforced per the §6 matrix via `BoardAccessService` on every
  board-scoped request; BCrypt password hashing; JWT signing key from user-secrets/env,
  never source; no passwords/tokens logged (backend-security.md §7); rate limiting
  planned for `/v1/auth/login` (§12).
- [x] **External Integration Governance (IX)**: No external integrations in this
  feature (no email delivery, no SSO) — explicitly deferred, documented above.
- [x] **Performance Responsibility (X)**: One indexed lookup per board-scoped
  authorization check; login/signup are single-row lookups; no N+1 introduced.
- [x] **Testing Requirements (XI)**: Business-critical logic (password hashing,
  JWT issuance/validation, board-membership authorization for all four roles,
  invitation dedup/claim-at-signup) gets `WebApplicationFactory` integration tests
  covering success, validation failure, and authorization failure per role
  (backend rulebook Testing section) — enumerated in `tasks.md`.
- [x] **Human Review (XII)**: Standard human review PLUS the Critical addendum's
  independent-approval substitute (second-model adversarial review + cooling-off
  period) before merge.
- [x] **Controlled Delivery (XIII)**: Two phases (A backend, B frontend), cross-repo
  ordering per `docs/sdlc/repository-strategy.md` (provider/backend gates and merges
  before the consuming frontend); PLUS the Critical addendum's human-executed-gates-only
  rule — no agent-run gate loop counts toward Done for either phase.

## Project Structure

### Documentation (this feature)

```text
specs/002-auth-workspaces/
├── spec.md
├── plan.md                       # This file
├── research.md                   # Phase 0 output
├── data-model.md                 # Phase 1 output
├── quickstart.md                 # Phase 1 output
├── rollback.md                   # Critical addendum — written before Phase 1 begins
├── contracts/
│   ├── auth-api.md               # Phase 1 output
│   └── board-membership-api.md   # Phase 1 output
└── tasks.md                      # /speckit.tasks output (next step)
```

### Source Code (both nested repos)

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Program.cs                          # + DbContext, AddAuthentication/AddAuthorization, rate limiting
│   ├── Data/
│   │   ├── FlowboardDbContext.cs
│   │   └── Configurations/
│   │       ├── UserConfiguration.cs
│   │       ├── WorkspaceConfiguration.cs
│   │       ├── BoardConfiguration.cs
│   │       ├── BoardMemberConfiguration.cs
│   │       └── InvitationConfiguration.cs
│   ├── Migrations/                          # EF Core's default output path (not nested under Data/ — corrected during implementation)
│   │   └── <timestamp>_AddAuthWorkspaces.cs
│   ├── Domain/
│   │   ├── Entities/
│   │   │   ├── User.cs
│   │   │   ├── Workspace.cs
│   │   │   ├── Board.cs
│   │   │   ├── BoardMember.cs
│   │   │   ├── Invitation.cs
│   │   │   └── BoardRole.cs                # enum: BoardAdmin, BoardMember, Observer
│   │   └── Result.cs                       # ADR-5
│   ├── Endpoints/
│   │   ├── ResultMapping.cs                # ADR-5
│   │   ├── AuthEndpoints.cs                # POST /v1/auth/signup, POST /v1/auth/login
│   │   └── BoardMembersEndpoints.cs        # GET members, POST invitations, DELETE invitation, DELETE member
│   └── Services/
│       ├── PasswordHasher.cs               # BCrypt wrapper (ADR-7)
│       ├── TokenService.cs                 # JWT issuance/validation (ADR-7)
│       ├── AuthService.cs                  # signup/login orchestration
│       └── BoardAccessService.cs           # ADR-9
├── .config/dotnet-tools.json                # dotnet-ef repo-local tool (ADR-6)
└── tests/Flowboard.Api.Tests/
    ├── TestFixtures/FlowboardApiFactory.cs  # WebApplicationFactory against flowboard-db-test
    ├── AuthEndpointTests.cs
    └── BoardMembersEndpointTests.cs

flowboard-web/
└── src/
    ├── app/
    │   ├── (auth)/
    │   │   ├── signup/page.tsx
    │   │   └── login/page.tsx
    │   ├── api/auth/[...nextauth]/route.ts # NextAuth route handler (ADR-8)
    │   └── layout.tsx                      # + NextAuth SessionProvider
    ├── server/api/
    │   ├── trpc.ts                         # + protectedProcedure (ADR-8)
    │   └── routers/
    │       ├── auth.ts                     # signup (publicProcedure mutation only — login is NextAuth's job)
    │       └── board-members.ts            # list / invite / revoke invitation / remove member (protectedProcedure)
    ├── lib/
    │   ├── auth/
    │   │   ├── auth-config.ts              # NextAuth config, Credentials provider (ADR-8)
    │   │   └── session.ts                  # server-side current-user helpers
    │   └── api/
    │       ├── auth-client.ts              # server-only fetch: signup, login
    │       └── board-members-client.ts     # server-only fetch: invite/list/revoke
    └── components/
        └── auth/
            ├── signup-form.tsx
            └── login-form.tsx
```

**Structure Decision**: extends 001's structure without new top-level folders on either
side. Backend stays a single project (ADR-6); `Data/` and `Domain/Entities/` are new
subfolders under the existing project, matching the layering ADR-1 already promised
("EF Core entities + `Migrations/` in the data layer"). Frontend adds `lib/auth/` and
`components/auth/` — both already named as conventions in the frontend rulebook, not
invented here.

## Implementation Phases (constitution XIII)

- **Phase A — backend (provider tier, gates and merges first per repository-strategy.md)**:
  DbContext + entities + first migration; `Result<T>`/`ResultMapping`; `PasswordHasher`/
  `TokenService`/`AuthService`; `BoardAccessService`; `AuthEndpoints` (signup, login);
  `BoardMembersEndpoints` (invite, list, revoke); integration tests per role. Ends: user
  runs the backend gate (`dotnet build --warnaserror && dotnet test`), confirms exit 0
  (Critical addendum: human-executed, no agent-run loop counts); AI + human review
  including the domain-invariant pass; commit.
- **Phase B — frontend (consuming tier, starts once Phase A's contract is stable)**:
  NextAuth wiring (`protectedProcedure`), signup/login pages, `board-members` router.
  Ends: user runs the frontend gate (`npm run lint && npm run build`), confirms exit 0;
  AI + human review including the domain-invariant pass; commit. Then the Critical
  addendum's independent-approval step (second-model adversarial review + cooling-off)
  before merge.

## Complexity Tracking

No unjustified constitution violations. All new patterns (database, JWT auth, NextAuth,
`Result<T>`) are approved above through ADR-5..11, not exceptions — this is exactly the
mechanism constitution IV requires for introducing them.
