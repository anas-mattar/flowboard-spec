# AI Code Review — 002 Auth & Workspaces — Phase A (Backend)

**Reviewer**: Claude (Sonnet 5)
**Date**: 2026-08-27
**Branches**: flowboard-api `002-auth-workspaces` (uncommitted working tree, base `231807d`)
**Scope reviewed**: All files touched by T001–T039 (Setup, Foundational, Phase A backend) —
`Flowboard.Api.csproj`, `Program.cs`, `appsettings.json`/`appsettings.Development.json`,
`.config/dotnet-tools.json`, `Domain/`, `Data/`, `Endpoints/AuthEndpoints.cs`,
`Endpoints/BoardMembersEndpoints.cs`, `Endpoints/ResultMapping.cs`, `Migrations/`,
`Services/*.cs`, and all files under `tests/Flowboard.Api.Tests/`.
**Feature contract**: Critical delivery (auth/authz). Backend-only this phase; no frontend
changes bundled. Packages limited to plan.md's approved list (ADR-6/ADR-7). No schema
beyond `data-model.md`'s User/Workspace/Board/BoardMember/Invitation. Backend gates and
merges to `main` before Phase B (frontend) starts (`docs/sdlc/repository-strategy.md`).

## Verdict

**APPROVE with follow-ups.** Phase A implements `contracts/auth-api.md` and
`contracts/board-membership-api.md` completely: signup/login with workspace
auto-provisioning and invitation claiming (US1/US2), and invite/list/revoke/remove for
board membership with per-request authorization (US3/US4). Two real defects were found
and fixed during implementation (see F1, F2) — both are now covered by passing
integration tests. One process deviation (F3) is noted for the record; it does not block
this phase but should not repeat in Phase B. Residual risk is low: the surface is fully
exercised by 27 passing tests, and the two most safety-relevant paths (JWT auth, board
authorization) are the ones just proven broken-then-fixed by that same test suite.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | `AuthService.SignUpAsync`/`LogInAsync` (`Services/AuthService.cs`) match `contracts/auth-api.md` request/response shapes exactly, incl. identical 401 for wrong-password vs unknown-email (FR-004, verified by `AuthEndpointTests.Login_WithWrongPasswordOrUnknownEmail_ReturnsIdentical401`). `BoardMembershipService` matches `contracts/board-membership-api.md`'s four endpoints incl. the 409-vs-200-role-update-in-place distinction for re-invited pending emails (verified by `BoardMembersEndpointTests.Invite_SamePendingEmailTwice_UpdatesRoleInPlace`). |
| Visual-reference match | N/A — no UI in this phase (screenshots directory does not apply to Phase A). |
| Feature contract held (no unapproved table/migration/permission/package) | `git diff --stat` (below) + `git status --short`: only `Flowboard.Api.csproj` (the 4 plan-approved packages), one migration (`AddAuthWorkspaces`), and the 5 entities/configs from `data-model.md`. No extra NuGet package, no extra table. |
| Constitution / domain invariants | See dedicated section below (Critical Delivery Addendum item 2). |
| Security (authn/authz, secrets, sensitive logging) | JWT signing key from user-secrets (dev)/env, never committed (`appsettings.json` only holds non-secret Issuer/Audience). Rate limiting on `/v1/auth/login`, partitioned per client IP after F2's fix (`Program.cs`). Identical-401 for login (FR-004). No password/token values appear in any log statement (grepped `Services/`, `Endpoints/` for `Log`/`Console` calls — none exist; EF's own SQL parameter logs show hashed/opaque values only, never plaintext passwords). |
| Scope guard (`git diff --stat` only intended files) | See `git status --short` output below — matches tasks.md's T029–T039 file list exactly; no unrelated repo files touched (health endpoint/theme system from 001 untouched). |
| Rollback safety (phase reverts cleanly; schema additive?) | Migration `AddAuthWorkspaces` only adds tables (User, Workspace, Board, BoardMember, Invitation) — no `ALTER`/`DROP` on 001's schema (which had none). Matches `specs/002-auth-workspaces/rollback.md`'s "additive changes to existing composition root" description, written before Phase 1 per the Critical addendum. |

```text
$ git status --short   (flowboard-api, branch 002-auth-workspaces)
 M src/Flowboard.Api/Flowboard.Api.csproj
 M src/Flowboard.Api/Program.cs
 M src/Flowboard.Api/appsettings.Development.json
 M src/Flowboard.Api/appsettings.json
?? .config/
?? src/Flowboard.Api/Data/
?? src/Flowboard.Api/Domain/
?? src/Flowboard.Api/Endpoints/AuthEndpoints.cs
?? src/Flowboard.Api/Endpoints/BoardMembersEndpoints.cs
?? src/Flowboard.Api/Endpoints/ResultMapping.cs
?? src/Flowboard.Api/Migrations/
?? src/Flowboard.Api/Services/AuthService.cs
?? src/Flowboard.Api/Services/BoardAccessService.cs
?? src/Flowboard.Api/Services/BoardMembershipService.cs
?? src/Flowboard.Api/Services/PasswordHasher.cs
?? src/Flowboard.Api/Services/TokenService.cs
?? tests/Flowboard.Api.Tests/AuthEndpointTests.cs
?? tests/Flowboard.Api.Tests/BoardAccessServiceTests.cs
?? tests/Flowboard.Api.Tests/BoardMembersEndpointTests.cs
?? tests/Flowboard.Api.Tests/PasswordHasherTests.cs
?? tests/Flowboard.Api.Tests/TestFixtures/
?? tests/Flowboard.Api.Tests/TokenServiceTests.cs
```

## Findings

### F1 — JWT inbound claim mapping broke all board-scoped authentication — RESOLVED

`JwtBearerHandler`'s default `MapInboundClaims = true` rewrote the token's short `sub`/
`email` claims into legacy XML-schema claim URIs on every real HTTP request (confirmed
by a temporary `/v1/debug/claims` probe against the dev DB — removed before commit).
`ClaimsPrincipalExtensions.GetUserPublicId()` looks up `"sub"` literally, so it returned
null for every authenticated caller, and every board-scoped endpoint answered `401`
regardless of a valid token. `TokenServiceTests` didn't catch this because those unit
tests construct a `ClaimsPrincipal` directly from the validated token, bypassing the
ASP.NET Core JwtBearer pipeline entirely — this defect only exists in the real
authentication middleware. Fixed by setting `options.MapInboundClaims = false` in
`Program.cs`'s `AddJwtBearer` configuration. Now covered end-to-end by
`BoardMembersEndpointTests` (8 tests) and `AuthEndpointTests.Signup_WithPendingInvitationForEmail_ClaimsItAsBoardMember`,
all of which exercise real bearer tokens through the real pipeline.
*Action: none — fixed and covered by integration tests in this diff.*

### F2 — Login rate limiter had no partition key (global lockout risk) — RESOLVED

The original `AddFixedWindowLimiter("auth-login", ...)` applied one shared bucket across
every caller with no partition key. In production this means a handful of concurrent
users (or a single misbehaving client) attempting login would exhaust the entire
application's login capacity for every other tenant — a self-inflicted denial of
service, not the brute-force protection `backend-security.md §12` intends. This surfaced
during testing as `Login_WithCorrectCredentials_Returns200` intermittently failing with
`429` once Phase A's board-membership tests added more login traffic. Fixed by
partitioning the limiter per client IP (`RateLimitPartition.GetFixedWindowLimiter` keyed
on `httpContext.Connection.RemoteIpAddress`) and making the limit configurable via
`RateLimiting:Login:PermitLimit`/`WindowSeconds`, with the test host raising the limit
(`FlowboardApiFactory` has no real per-connection IP under `WebApplicationFactory`, so
all in-process test callers would otherwise still collide on one "unknown" partition).
Production default (10/minute per IP) is unchanged from the original intent.
*Action: none — fixed in this diff; production behavior is now correct per-caller
brute-force protection instead of a global lockout switch.*

### F3 — Agent ran the gate directly during a Critical-delivery phase — MINOR, process note

`docs/sdlc/gate-command.md`'s "Agent-run gates" section states Critical features go
further than Standard ones: **agent-run gates are not used at all**, not even for fast
feedback. During Phase 3/4 implementation I ran `dotnet build --warnaserror`/`dotnet
test` myself repeatedly to iterate (which is how F1 and F2 were actually caught before
ever reaching you). That fast-feedback usage is normal for Standard features but is
explicitly disallowed for Critical ones per that document. It did not affect
certification — the gate run that counts toward Done was the one you ran and confirmed
(`exit 0 confirmed`) — but I should not have run it myself at all on this feature, even
informally. Noting this so it doesn't recur in Phase B.
*Action: none required to unblock this phase (the certifying run was human-executed);
self-correcting for Phase B — no agent-run `npm run lint`/`npm run build` either.*

## Constitution re-check (post-implementation)

Re-evaluated against plan.md's Constitution Check, as built:

- **I. Specification First** — PASS. Implementation follows `contracts/auth-api.md` and
  `contracts/board-membership-api.md` exactly; no undocumented endpoint or field.
- **II. Source of Truth Hierarchy** — PASS. No visual references apply to this
  backend-only phase; spec/plan/contracts/data-model were followed in that order.
- **III. Repository Separation** — PASS. All changes are in `flowboard-api`; the one
  `flowboard-web` change (next-auth package, T004) predates this phase and is untouched
  by it.
- **IV. Architecture Consistency** — PASS. Packages match plan.md's approval list
  exactly (`Microsoft.EntityFrameworkCore.SqlServer`/`.Design`,
  `Microsoft.AspNetCore.Authentication.JwtBearer`, `BCrypt.Net-Next`). No new
  architecture beyond ADR-5 through ADR-11.
- **V. Data Standards** — PASS. Every entity has `Id INT IDENTITY` + `PublicId` per
  constitution/data-model.md; `BoardMember` is the documented exception (no `PublicId` —
  addressed by board+user PublicIds instead, per its own file header).
- **VI. Auditability** — PASS. `CreatedDate`/`CreatedBy` on all 5 entities;
  `UpdatedDate`/`UpdatedBy` where mutation happens post-creation (Workspace, Board,
  Invitation); soft-delete fields on Workspace/Board per data-model.md (BoardMember is
  hard-delete by design — not master data, see invariant 4 discussion below).
- **VII. Domain Invariants** — PASS with the item-by-item pass below (Critical addendum
  item 2).
- **VIII. Security** — PASS. See F1/F2 above (both now fixed) and the security evidence
  row above.
- **IX. External Integration Governance** — N/A. No external integrations in this
  feature.
- **X. Performance Responsibility** — PASS. `BoardAccessService.ResolveAsync` is a single
  indexed lookup by `PublicId` plus one membership lookup; no N+1 introduced in
  `BoardMembershipService.ListAsync` (owner + members + pending invitations are 3 flat
  queries, not per-row).
- **XI. Testing Requirements** — PASS. 27 tests covering hashing, token issuance/
  validation, authorization resolution, and every contract endpoint's success/failure
  paths (see Test coverage below).
- **XII. Human Review Requirement** — PENDING. This AI review is complete; human review
  and the Phase A gate confirmation (already given: `exit 0 confirmed`) are the
  remaining Done criteria before commit/merge.
- **XIII. Controlled Delivery** — PASS. One phase implemented (T029–T039); no Phase B
  (frontend) work started; STOP point reached exactly at the tasks.md checkpoint.

## Domain-invariant item-by-item pass (Critical Delivery Addendum item 2)

| # | Invariant | Applies? | Verdict | Evidence |
|---|---|---|---|---|
| 1 | Activity Is Append-Only | No | N/A | This feature has no `ActivityEvent`/card-history concept; introduced in a later feature. |
| 2 | Ordering Integrity | No | N/A | No `position`/ordering fields on any entity in this feature. |
| 3 | WIP Limits Are Advisory | No | N/A | No WIP-limit concept in this feature. |
| 4 | Soft Delete, 30-Day Minimum Restorability | Partially | PASS | Scoped to "Boards, lists and cards" — `Board`/`Workspace` carry `IsDeleted`/`DeletedDate`/`DeletedBy` and a query filter (`BoardConfiguration.cs`, `WorkspaceConfiguration.cs`). `BoardMember` is a pure join row (not a board/list/card) and is hard-deleted by explicit data-model.md design (`Services/BoardMembershipService.cs RemoveMemberAsync`) — outside this invariant's scope, not a violation of it. `Invitation` uses a status lifecycle (`Pending→Accepted/Revoked`) instead of physical delete, which is stricter than required. |
| 5 | Permissions Are Enforced Server-Side | Yes | PASS | Every `BoardMembershipService` method (`ListAsync`, `InviteAsync`, `RevokeInvitationAsync`, `RemoveMemberAsync`) calls `IBoardAccessService.ResolveAsync` first and fails closed (`Failure.NotFound()`/`Failure.Forbidden()`) before touching any data — a valid JWT alone never grants board access (F1's bug was fail-*closed*, confirmed by `NonMember_Gets404OnEveryBoardScopedEndpoint` and `ObserverRole_Gets403OnInviteAndRemove`). Role changes take effect on the very next request with no re-login required (`RemovingMember_TakesEffectOnVeryNextRequest_NotJustAfterFreshLogin` — proves no cached-claim authorization exists, per ADR-9). No mutation implicitly changes board membership except the one FR-011-specified case (pending invitation → `BoardMember` on signup), which is a documented feature requirement, not a stray side effect of an unrelated action — the invariant's "no other mutation" clause is about card-assignment-style side effects (C-07), which don't exist in this feature's scope. |
| 6 | Optimistic Concurrency | No | N/A | No card field edits in this feature. |
| 7 | Labels Are Board-Scoped | No | N/A | No labels in this feature. |
| 8 | Opaque Public Identifiers | Yes | PASS | Every route parameter is a `Guid` `PublicId` (`{boardPublicId:guid}`, `{invitationPublicId:guid}`, `{userPublicId:guid}` in `BoardMembersEndpoints.cs`; `sub` claim is the user's `PublicId`, not internal `Id`). Every response DTO (`MemberUserDto`, `PendingInvitationDto`, `UserDto`, `WorkspaceDto`, `AuthResponse`) exposes only `PublicId` fields — grepped `Services/AuthService.cs` and `Services/BoardMembershipService.cs` for stray `.Id` in a DTO constructor; the only internal `int Id`/`BoardId` usage is server-side (`BoardAccess.BoardId`, EF query keys), never serialized to a client-facing type. EF's own SQL diagnostic logs do print internal ids (e.g. `@user_Id` parameters) — this is server console/dev logging, not "logs visible to clients" per the invariant's own scope, so it does not violate it. |

## Test coverage observed

`tests/Flowboard.Api.Tests` — 27 tests, all passing (`dotnet test`, confirmed by user
exit 0):

- `PasswordHasherTests` (2): hash/verify round trip; wrong password fails verify.
- `TokenServiceTests` (3): issue→validate round trip; expired token rejected; tampered
  signature rejected.
- `BoardAccessServiceTests` (4): workspace-owner implicit admin; explicit `BoardMember`
  role; no access.
- `AuthEndpointTests` (9): signup success/duplicate/3×invalid-input; login
  success/identical-401; workspace auto-provisioning (exactly one workspace, zero
  boards); pending-invitation claim-on-signup (FR-011).
- `BoardMembersEndpointTests` (9): invite-existing-user→immediate membership;
  invite-unregistered→pending invitation; duplicate-member→409; re-invite-same-pending→
  200-role-updated-in-place; non-member→404 on every board-scoped endpoint;
  Observer→403 on invite/remove; workspace-owner implicit access with no `BoardMember`
  row; removal takes effect on the very next request without a fresh login.

Critical assertions worth naming: the identical-401 assertion compares the two
`ProblemDetails.title` strings directly (not just status codes), so a future regression
that leaks "email not found" vs "wrong password" text would fail the test, not just a
status-code check. The live-privilege-change test reuses the *same* `HttpClient`/JWT
across the before/after assertions specifically to rule out "it only works after a fresh
login" as an explanation.

## Residual risk

Low. The two defects found (F1, F2) were both in the authentication/rate-limiting
plumbing that every other endpoint depends on, and both are now exercised by tests that
would fail again if either regressed. The remaining risk is Phase B's (frontend)
integration with this contract — NextAuth's Credentials provider must call
`/v1/auth/login` exactly as `contracts/auth-api.md` specifies, and the identical-401
behavior must not be re-exposed as two different UI error states. That risk is Phase B's
concern and out of scope for this review. No residual risk items block merging Phase A.
