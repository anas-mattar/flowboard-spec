# Tasks: Auth & Workspaces

**Input**: Design documents from `/specs/002-auth-workspaces/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/auth-api.md, contracts/board-membership-api.md, quickstart.md,
rollback.md (Critical Delivery Addendum — already written)

**Delivery Level**: **Critical** (`docs/sdlc/critical-delivery.md`). On top of the
gates below: human-executed gates only, a domain-invariant item-by-item pass in both
AI and human review, audit evidence retained, and independent approval (for this
solo-developer project: a second-model adversarial review + cooling-off period
before merge).

**Tests**: Included throughout — this feature is Critical and constitution XI requires
automated/deterministic coverage for business-critical logic (password hashing, JWT
issuance/validation, board-scoped authorization for every role, invitation dedup).

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
`docs/sdlc/repository-strategy.md`'s cross-repository rule: backend gates and merges
before frontend starts), with `[Story]` labels for traceability back to spec.md's user
stories (US1 signup/sign-in, US2 personal workspace, US3 invite with a role, US4
access denied without the right role, US5 sign out). See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5); Setup/Foundational/
  Polish tasks carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 [P] Add `Microsoft.EntityFrameworkCore.SqlServer` and `Microsoft.EntityFrameworkCore.Design` to flowboard-api/src/Flowboard.Api/Flowboard.Api.csproj (plan-approved, ADR-6)
- [x] T002 [P] Add `Microsoft.AspNetCore.Authentication.JwtBearer` and `BCrypt.Net-Next` to flowboard-api/src/Flowboard.Api/Flowboard.Api.csproj (plan-approved, ADR-7)
- [x] T003 [P] Create flowboard-api/.config/dotnet-tools.json installing `dotnet-ef` as a repo-local tool (research R-8); run `dotnet tool restore`
- [x] T004 [P] Add `next-auth` to flowboard-web (plan-approved, ADR-8): `npm install next-auth`

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 3+) may begin until this phase is complete —
every endpoint depends on the schema, password hashing, tokens, and the authorization
service built here.

- [x] T005 Create `Result<T>` (Validation/Unauthorized/Forbidden/NotFound/Conflict failure kinds) in flowboard-api/src/Flowboard.Api/Domain/Result.cs (ADR-5)
- [x] T006 Create `ResultMapping.ToHttpResult()` (→ RFC 9457 `ProblemDetails`, 400/401/403/404/409) in flowboard-api/src/Flowboard.Api/Endpoints/ResultMapping.cs (ADR-5, cite backend rulebook API Surface)
- [x] T007 [P] Create `BoardRole` enum (`BoardAdmin`, `BoardMember`, `Observer`) in flowboard-api/src/Flowboard.Api/Domain/Entities/BoardRole.cs (FUNCTIONAL_SPEC §6)
- [x] T008 [P] Create `User` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/User.cs (data-model.md User — audit fields only, no soft delete)
- [x] T009 [P] Create `Workspace` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/Workspace.cs (data-model.md Workspace — `OwnerUserId`, audit + soft-delete fields)
- [x] T010 [P] Create `Board` entity (minimal placeholder, ADR-11) in flowboard-api/src/Flowboard.Api/Domain/Entities/Board.cs (data-model.md Board)
- [x] T011 [P] Create `BoardMember` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/BoardMember.cs (data-model.md BoardMember — no `PublicId`, audit-created-only)
- [x] T012 [P] Create `Invitation` entity in flowboard-api/src/Flowboard.Api/Domain/Entities/Invitation.cs (data-model.md Invitation — `Status` lifecycle)
- [x] T013 Create `FlowboardDbContext` registering all 5 entities in flowboard-api/src/Flowboard.Api/Data/FlowboardDbContext.cs (depends on T008–T012)
- [x] T014 [P] Create `UserConfiguration` (unique case-insensitive email index, `PublicId` unique index) in flowboard-api/src/Flowboard.Api/Data/Configurations/UserConfiguration.cs (depends on T008)
- [x] T015 [P] Create `WorkspaceConfiguration` (unique `OwnerUserId` index, soft-delete query filter) in flowboard-api/src/Flowboard.Api/Data/Configurations/WorkspaceConfiguration.cs (depends on T009)
- [x] T016 [P] Create `BoardConfiguration` (soft-delete query filter, deterministic `HasData` fixture board — ADR-11, data-model.md) in flowboard-api/src/Flowboard.Api/Data/Configurations/BoardConfiguration.cs (depends on T010)
- [x] T017 [P] Create `BoardMemberConfiguration` (`UNIQUE(BoardId,UserId)`, `CHECK` on `Role`, restrict-delete FK to `Board`) in flowboard-api/src/Flowboard.Api/Data/Configurations/BoardMemberConfiguration.cs (depends on T011)
- [x] T018 [P] Create `InvitationConfiguration` (filtered `UNIQUE(BoardId,Email) WHERE Status='Pending'`, `CHECK` on `Role`/`Status`) in flowboard-api/src/Flowboard.Api/Data/Configurations/InvitationConfiguration.cs (depends on T012)
- [x] T019 Generate the first EF Core migration (`dotnet ef migrations add AddAuthWorkspaces`, repo-local tool) in flowboard-api/src/Flowboard.Api/Migrations/ (EF Core's default output path); register `FlowboardDbContext` + LocalDB connection string (`flowboard-db`) in Program.cs and appsettings.Development.json; JWT signing key via dev user-secrets (depends on T013–T018)
- [x] T020 Create `PasswordHasher` (BCrypt wrapper, work factor 12) in flowboard-api/src/Flowboard.Api/Services/PasswordHasher.cs (research R-1, R-2)
- [x] T021 [P] Unit test `PasswordHasher` (hash/verify round trip; wrong password fails verify) in flowboard-api/tests/Flowboard.Api.Tests/PasswordHasherTests.cs
- [x] T022 Create `TokenService` (issue/validate JWT via `JsonWebTokenHandler`, HMACSHA256, identity-only claims `sub`/`email`/`iat`/`exp`, 14-day lifetime) in flowboard-api/src/Flowboard.Api/Services/TokenService.cs (ADR-7, research R-3); signing key from user-secrets (dev) / env var
- [x] T023 [P] Unit test `TokenService` (issue→validate round trip; expired token rejected; tampered signature rejected) in flowboard-api/tests/Flowboard.Api.Tests/TokenServiceTests.cs
- [x] T024 Register JWT bearer authentication + authorization (`AddAuthentication().AddJwtBearer()`, `AddAuthorization()`) in flowboard-api/src/Flowboard.Api/Program.cs (depends on T022)
- [x] T025 Add rate limiting for `/v1/auth/login` in flowboard-api/src/Flowboard.Api/Program.cs (backend-security.md §12)
- [x] T026 Create `BoardAccessService` (resolves caller's effective role: workspace-owner implicit `BoardAdmin` → explicit `BoardMember` row → no access) in flowboard-api/src/Flowboard.Api/Services/BoardAccessService.cs (ADR-9, depends on T013)
- [x] T027 [P] Unit test `BoardAccessService` (workspace-owner implicit admin; explicit `BoardMember` role; no access) in flowboard-api/tests/Flowboard.Api.Tests/BoardAccessServiceTests.cs
- [x] T028 Create `FlowboardApiFactory` (`WebApplicationFactory<Program>` against disposable `flowboard-db-test`, migrate once per collection, per-test row cleanup) in flowboard-api/tests/Flowboard.Api.Tests/TestFixtures/FlowboardApiFactory.cs (research R-9)

**Checkpoint**: Foundation ready — schema, hashing, tokens, and authorization all exist
and are unit-tested. Backend endpoint work (Phase 3–4) can now begin.

---

## Phase 3: Backend — Auth (Priority: P1) 🎯 MVP — delivery Phase A, part 1

**Goal**: `POST /v1/auth/signup` and `POST /v1/auth/login` per `contracts/auth-api.md`;
signup auto-creates the caller's workspace (US2) and claims any pending invitations
for that email (US3's FR-011).

**Independent Test**: quickstart.md §4 US1/US2 rows — sign up, get a token + workspace
back; sign in with the same credentials; wrong password and duplicate email are
refused per contract.

- [x] T029 [US1] Create `AuthService` (signup: hash password, create `User` + `Workspace` in one transaction, claim matching `Pending` invitations into `BoardMember` rows; login: verify credentials) in flowboard-api/src/Flowboard.Api/Services/AuthService.cs (cite contracts/auth-api.md)
- [x] T030 [US1] Create `AuthEndpoints` (`POST /v1/auth/signup`, `POST /v1/auth/login`) in flowboard-api/src/Flowboard.Api/Endpoints/AuthEndpoints.cs (cite contracts/auth-api.md); register in Program.cs
- [x] T031 [P] [US1] Integration test: signup success (201 + contract shape); duplicate email (409); validation failures — bad email, short password, missing displayName (400) in flowboard-api/tests/Flowboard.Api.Tests/AuthEndpointTests.cs
- [x] T032 [P] [US1] Integration test: login success (200); wrong password and unknown email both return the identical generic 401 (FR-004) in flowboard-api/tests/Flowboard.Api.Tests/AuthEndpointTests.cs
- [x] T033 [US2] Integration test: signup creates exactly one `Workspace` with the caller as `OwnerUserId`/`WorkspaceAdmin`, zero boards beyond the fixture seed (FR-006, FR-007) in flowboard-api/tests/Flowboard.Api.Tests/AuthEndpointTests.cs

**Checkpoint**: US1 and US2 fully functional and testable independently against the API.

---

## Phase 4: Backend — Board Membership (Priority: P2) — delivery Phase A, part 2

**Goal**: Invite-with-role, list members/pending invitations, revoke, and remove, per
`contracts/board-membership-api.md`; every action authorized through
`BoardAccessService` (US4).

**Independent Test**: quickstart.md §4 US3/US4 rows — invite an existing user and an
unregistered email; confirm duplicate-membership and re-invite-updates-role behavior;
confirm a non-member gets 404, a wrong-role caller gets 403, and a role change/removal
takes effect on the very next request.

- [x] T034 [US3] Create `BoardMembershipService` (invite: immediate `BoardMember` if the invitee has an account, else upsert a `Pending` `Invitation`; list members + pending invitations; revoke invitation; remove member) in flowboard-api/src/Flowboard.Api/Services/BoardMembershipService.cs (cite contracts/board-membership-api.md)
- [x] T035 [US3] Create `BoardMembersEndpoints` (`GET members`, `POST invitations`, `DELETE invitation`, `DELETE member`) in flowboard-api/src/Flowboard.Api/Endpoints/BoardMembersEndpoints.cs (cite contracts/board-membership-api.md); register in Program.cs
- [x] T036 [P] [US3] Integration test: invite existing user → immediate membership; invite unregistered email → pending invitation; duplicate-member invite → 409; re-inviting the same pending email updates its role in place in flowboard-api/tests/Flowboard.Api.Tests/BoardMembersEndpointTests.cs
- [x] T037 [P] [US3] Integration test: a pending invitation auto-converts to a `BoardMember` row when that email completes signup (FR-011) in flowboard-api/tests/Flowboard.Api.Tests/AuthEndpointTests.cs
- [x] T038 [P] [US4] Integration test: non-member → 404 on every board-scoped endpoint; `Observer`/`BoardMember` → 403 on invite/remove; workspace owner has implicit `BoardAdmin` access with no `BoardMember` row (FR-012, FR-013, FR-014, FR-015) in flowboard-api/tests/Flowboard.Api.Tests/BoardMembersEndpointTests.cs
- [x] T039 [US4] Integration test: removing/downgrading a member's role takes effect on that member's very next request in the same test — not just after a fresh login (spec edge case, research R-6) in flowboard-api/tests/Flowboard.Api.Tests/BoardMembersEndpointTests.cs

**Checkpoint — Phase A gate**: STOP. User runs
`dotnet build --warnaserror && dotnet test` in flowboard-api and confirms EXIT 0
(Critical addendum: human-executed — no agent-run loop counts). AI review AND human
review each include the domain-invariant item-by-item pass (invariants 5 and 8).
Commit Phase A. Per `docs/sdlc/repository-strategy.md`'s cross-repository rule, the
backend gates and merges to `main` **before** Phase B (frontend) begins.

---

## Phase 5: Frontend — Auth (Priority: P1/P2/P3) — delivery Phase B, part 1

**Goal**: NextAuth wiring, `protectedProcedure`, signup/login pages, workspace identity
in the shell, sign-out (US1, US2, US5).

**Independent Test**: quickstart.md §4 US1/US2/US5 rows — sign up and sign in through
the UI; workspace name appears in the shell with no extra step; sign out ends the
session and protected pages require signing in again.

- [x] T040 [US1] Configure NextAuth (`Credentials` provider calling the backend login endpoint server-side, JWT session strategy per research R-5, 14-day `maxAge`) in flowboard-web/src/lib/auth/auth-config.ts (ADR-8); create the route handler in flowboard-web/src/app/api/auth/[...nextauth]/route.ts
- [x] T041 [P] [US1] Create server-only auth client (`signup`, `login` fetch wrappers to `/v1/auth/*`) in flowboard-web/src/lib/api/auth-client.ts (cite contracts/auth-api.md)
- [x] T042 [US1] Add `protectedProcedure` to flowboard-web/src/server/api/trpc.ts (frontend-trpc.md's named trigger for this feature); create `auth.signup` (`publicProcedure` mutation — login stays NextAuth's job) in flowboard-web/src/server/api/routers/auth.ts; register in root.ts
- [x] T043 [P] [US1] Create signup form + page (React Hook Form + `zodResolver`, minimum-10-char password validated client-side mirroring research R-10) in flowboard-web/src/components/auth/signup-form.tsx and flowboard-web/src/app/(auth)/signup/page.tsx
- [x] T044 [P] [US1] Create login form + page (calls `next-auth`'s `signIn()`) in flowboard-web/src/components/auth/login-form.tsx and flowboard-web/src/app/(auth)/login/page.tsx
- [x] T045 [US1] Wrap the app with NextAuth's `SessionProvider` in flowboard-web/src/app/layout.tsx
- [x] T046 [US2] Surface the workspace name and the caller's role from the session in the existing top bar in flowboard-web/src/components/layout/top-bar.tsx — no separate workspace-management UI (ADR-10)
- [x] T047 [US5] Add a sign-out action (`next-auth`'s `signOut()`) to flowboard-web/src/components/layout/top-bar.tsx

**Checkpoint**: US1, US2, and US5 verifiable end-to-end through the browser.

---

## Phase 6: Frontend — Board Membership UI (Priority: P2) — delivery Phase B, part 2

**Goal**: Invite/list/remove board members through the UI, with admin-only controls
(US3, US4).

**Independent Test**: quickstart.md §4 US3/US4 rows — invite a teammate from the UI
with a chosen role; confirm an `Observer`/`BoardMember` sees the list but not the
invite/remove controls; confirm a non-member visiting the board URL directly sees an
access-denied state, not the panel.

- [x] T048 [P] [US3] Create server-only board-members client (invite, list, revoke invitation, remove member) in flowboard-web/src/lib/api/board-members-client.ts (cite contracts/board-membership-api.md)
- [x] T049 [US3] Create the invite-input Zod schema in flowboard-web/src/lib/board-members/schemas.ts (mirrors contracts/board-membership-api.md)
- [x] T050 [US3] Create the `board-members` router (`protectedProcedure`: `list`, `invite`, `revokeInvitation`, `removeMember`, validated with T049's schema) in flowboard-web/src/server/api/routers/board-members.ts; register in root.ts
- [x] T051 [P] [US3] Create `BoardMembersPanel` (member list + pending invitations + invite form, React Hook Form + `zodResolver`) in flowboard-web/src/components/board-members/board-members-panel.tsx
- [x] T052 [US4] Gate the invite/remove controls in `BoardMembersPanel` to the caller's `BoardAdmin`/workspace-owner role only — `BoardMember`/`Observer` see the list with no admin controls (frontend-security.md §3; backend remains authoritative regardless of what the UI hides)
- [x] T053 [US3] Create a minimal board page — server component, redirects unauthenticated visitors to `/login` (frontend-state-auth-style.md), shows an access-denied state (not the panel) when the backend returns 404 for a non-member, otherwise renders `BoardMembersPanel` — in flowboard-web/src/app/boards/[boardPublicId]/page.tsx (the seam 003 extends into the full board canvas; not a throwaway page)

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0 (Critical addendum: human-executed). AI review AND
human review each include the domain-invariant item-by-item pass. Commit Phase B.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T054 [P] Update flowboard-web/.env.example with `NEXTAUTH_SECRET` and `NEXTAUTH_URL` placeholders (no real secrets committed)
- [ ] T055 [P] Document JWT signing key (flowboard-api user-secrets) and `NEXTAUTH_SECRET` (flowboard-web `.env.local`) provisioning in specs/002-auth-workspaces/quickstart.md
- [ ] T056 Walk quickstart.md end-to-end (all US1–US5 rows, both edge-case rows) and fix any doc drift in specs/002-auth-workspaces/quickstart.md
- [ ] T057 Write phase review notes (backend + frontend compliance checklists, gate evidence, the Critical addendum's domain-invariant review pass, audit evidence retained) in specs/002-auth-workspaces/review-notes.md; write specs/002-auth-workspaces/human-pr-review.md; on merge, set roadmap row 002 → shipped in docs/roadmap.md
- [ ] T058 Independent approval: second-model adversarial review + cooling-off period (Critical Delivery Addendum item 5) before merge

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Setup + Foundational | T001–T028 | none (no endpoint surface yet); unit tests run as part of `dotnet test` |
| Phase A — backend (auth + board membership) | T029–T039 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (auth UI + board-membership UI) | T040–T053 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T054–T058 | both gates re-run at merge time; independent approval (T058) |

## Dependencies & Execution Order

- Setup (T001–T004) has no dependencies — can start immediately, all four in parallel.
- Foundational (T005–T028) depends on Setup and blocks every user-story task. Within
  it: entities (T007–T012) before `DbContext` (T013) before configurations
  (T014–T018) before the migration (T019); `PasswordHasher`(T020)/`TokenService`(T022)
  before their unit tests (T021/T023) and before JWT registration (T024);
  `BoardAccessService` (T026) depends on `DbContext` (T013) and precedes its unit test
  (T027); the test fixture (T028) can be built any time after T019.
- Phase A part 1 (T029–T033, US1/US2) depends only on Foundational — can start as soon
  as Phase 2 is done.
- Phase A part 2 (T034–T039, US3/US4) depends on Foundational's `BoardAccessService`
  (T026) and on `Board`/`BoardMember`/`Invitation` existing (T019) — does NOT depend on
  Phase A part 1's `AuthEndpoints`, except T037 which needs a working signup endpoint
  (T030) to test the claim-on-signup behavior.
- Phase B (T040–T053) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule) — the contract must be stable before
  the consuming tier implements against it. Within Phase B: T040 (NextAuth config)
  before T041–T045; T048–T050 (board-members client/schema/router) before T051
  (panel); T051 before T052 (gating) and T053 (page).
- Polish (T054–T058) is last, after both phase gates pass.

## Parallel Opportunities

- All of Setup (T001–T004) together.
- Within Foundational: entity creation T007–T012 together; then configurations
  T014–T018 together; unit tests T021/T023/T027 together (each depends only on its own
  service, not on each other).
- Within Phase A part 1: integration tests T031/T032 together (different concerns, same
  file — safe to parallelize authoring, run is sequential per xUnit collection).
- Within Phase A part 2: integration tests T036/T037/T038 together.
- Within Phase B part 1: T041 (client), T043 (signup form), T044 (login form) together
  once T040 (NextAuth config) exists.
- Within Phase B part 2: T048 (client) and T051 (panel, once T050's router exists)
  overlap partially — T048 has no dependency on T049/T050 and can start immediately.

## Implementation Strategy

MVP = Phase 1–3 (Setup, Foundational, Phase A part 1 — US1 signup/sign-in + US2
auto-workspace) gated on the backend alone; this proves identity and workspace
provisioning end-to-end before board-membership complexity (Phase 4) or any frontend
work (Phase 5–6) begins. Backend (Phase A, all of it) ships and gates as one unit before
frontend starts, per the cross-repository rule — not per user story — because every
frontend page in this feature needs the backend's contract to be stable first. One
phase at a time; no unrelated changes; 001's scaffold surface (health endpoint, theme
system) is untouched.
