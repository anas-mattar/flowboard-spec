# Research: Auth & Workspaces

Phase 0 output. All Technical Context unknowns resolved below; no
`NEEDS CLARIFICATION` markers remain.

## R-1: Password hashing

**Decision**: `BCrypt.Net-Next`, work factor 12 (current OWASP-reasonable default for
bcrypt as of 2026; revisit if hardware moves the recommendation).

**Rationale**: FUNCTIONAL_SPEC §8 names "bcrypt/argon2 password hashing" explicitly.
ASP.NET Core's built-in `PasswordHasher<TUser>` (PBKDF2) would need zero new packages
but doesn't match the product spec's literal requirement. BCrypt.Net-Next is a mature,
widely-used, dependency-free implementation with a simple `HashPassword`/`Verify` API.

**Alternatives considered**: Argon2 (`Konscious.Security.Cryptography.Argon2`) —
stronger against GPU cracking but less battle-tested in the .NET ecosystem and adds
tuning parameters (memory/parallelism) this v1.0 feature doesn't need to get right on
day one; can be swapped later behind `PasswordHasher` without a data migration if hashes
are versioned (see R-2). ASP.NET Core Identity's built-in hasher — rejected with the
full-Identity option in ADR-7 (schema mismatch, global-role model FlowBoard doesn't use).

## R-2: Hash format / future migration path

**Decision**: Store the full BCrypt-encoded hash string (includes algorithm version,
cost factor, and salt) in `User.PasswordHash NVARCHAR(200)`. No separate salt column.

**Rationale**: BCrypt's own encoded format is self-describing — verification doesn't
need a separately stored salt or work factor. This also means the hashing scheme can be
upgraded later (e.g., to Argon2) by checking the encoded prefix and re-hashing on next
successful login, without a breaking migration.

## R-3: JWT issuance/validation

**Decision**: `Microsoft.AspNetCore.Authentication.JwtBearer` for validating incoming
bearer tokens (`AddAuthentication().AddJwtBearer()`), and its transitive
`Microsoft.IdentityModel.JsonWebTokens` (`JsonWebTokenHandler`) for issuing them in
`TokenService`. Symmetric signing (`HMACSHA256`) with a 256-bit random key.

**Rationale**: Standard ASP.NET Core building blocks; no extra token library needed.
Symmetric signing is sufficient for a single backend service that both issues and
validates its own tokens — asymmetric (RS256) only earns its complexity once a second
service needs to validate tokens independently (not the case in v1.0).

**Alternatives considered**: `System.IdentityModel.Tokens.Jwt` (`JwtSecurityTokenHandler`)
— the older API; `JsonWebTokenHandler` is Microsoft's current recommended replacement
(faster, less allocation) and ships from the same package tree pulled in transitively.

## R-4: Session provider (frontend)

**Decision**: `next-auth@beta` (Auth.js v5, currently `5.0.0-beta.32` — **no GA release
exists as of this feature's implementation**), `Credentials` provider, JWT session
strategy, `maxAge: 14 days` (matches the backend token lifetime, ADR-7).

**Rationale**: Named as the rulebook's "default candidate"
(`frontend-state-auth-style.md`). v5's App Router-native `auth()` helper fits Next.js 16
server components and route handlers directly (no `getServerSession` boilerplate). The
`Credentials` provider's `authorize()` runs server-side in the Node process, so it can
call the server-only backend login client (`lib/api/auth-client.ts`) directly — the
backend password check stays server-side always.

**Beta-dependency risk — explicitly accepted, not overlooked**: v5 has stayed on the
`beta` npm tag through this entire project timeline. It is nonetheless in widespread
production use for Next.js App Router apps (the v4 branch has no equivalent
App-Router-native API). Accepted deliberately (user-confirmed) for this Critical
feature rather than silently installed; revisit if Auth.js ships a v5 GA or a breaking
beta change lands — pin the exact beta version in `package-lock.json` (already the
project's practice) rather than floating `^5.0.0-beta.x` loosely across installs.

**Alternatives considered**: `next-auth` v4 (GA-stable, but `getServerSession`-based —
less idiomatic for the App Router and would need its own ADR revision); Lucia
(discontinued as a maintained library going into 2026 — ruled out); hand-rolled
cookie/JWT session code — rejected, reinvents what NextAuth already solves correctly
(CSRF protection, cookie encryption, session rotation) and the rulebook already names a
default.

## R-5: What goes in the NextAuth session vs. stays server-only

**Decision**: `callbacks.jwt` receives the backend's `{ token, user, workspace }`
login/signup response once (at sign-in) and stores the **entire** backend JWT plus
`userPublicId`/`workspacePublicId`/`workspaceRole`/`email`/`displayName` inside
NextAuth's own internal JWT payload — which is itself encrypted (JWE) and stored in an
httpOnly cookie, never readable by browser JS. `callbacks.session` then builds the
object returned to `useSession()`/`auth()` on the client, copying over only
`user: { publicId, email, displayName, workspacePublicId, workspaceRole }` —
**deliberately omitting the backend JWT** from that returned shape.

**Rationale**: satisfies frontend-security.md §9 ("no auth tokens in localStorage... use
the project-approved session/auth provider") and ADR-2's "browser never holds the
backend token" without adding a second store. Server-side code (tRPC context, server
components) reads the full internal token — including the backend JWT — via NextAuth's
server-side accessor; client code only ever sees the safe projection.

## R-6: Authorization model — claims vs. per-request DB check

**Decision**: JWT claims are identity-only (`sub`, `email`, `iat`, `exp`) — no
workspace/board/role claims. Every board-scoped backend endpoint calls
`BoardAccessService`, which re-resolves the caller's effective role from the database
on every request.

**Rationale**: spec.md's edge case is explicit — a role downgrade or membership removal
must take effect on the caller's very next request, not their next login. A cached
claim in a 14-day token would violate that outright. The extra query is one indexed
lookup (`BoardMember` composite unique index, or `Workspace.OwnerUserId` compare) — well
within the performance budget.

**Alternatives considered**: short-lived access tokens (5 min) + silent refresh to keep
claims fresh — adds a refresh-token endpoint, rotation, and revocation-on-refresh logic
that spec.md doesn't require for v1.0 and that the Technical Context explicitly defers
(no refresh-token rotation this feature). Re-deriving per request is simpler and
strictly more correct for the staleness requirement.

## R-7: Invitation delivery — no email in this feature

**Decision**: An invitation is a database record only. It takes effect automatically
the moment the invited email address signs up (spec FR-011) or, if the account already
exists, immediately (FR-010) — discovered on the invitee's next sign-in/session refresh.
No email is sent.

**Rationale**: Sending real invitation email would be a new external integration
requiring a full contract under constitution IX (purpose, auth, endpoints, retry,
audit) — out of proportion for this feature and not required by any FR. The prototype
itself stubs email invitations out (FUNCTIONAL_SPEC §9). A later feature can add email
delivery purely additively (send a notification pointing at an invitation that already
exists) without touching this data model.

## R-8: EF Core migrations tooling

**Decision**: `dotnet-ef` installed as a repo-local tool via
`flowboard-api/.config/dotnet-tools.json` (`dotnet tool restore` before first use, per
CLAUDE.md's documented known-failure-mode — never a global install). Migrations
generated with `Flowboard.Api` as both the target and startup project (single-project
layout, ADR-6).

**Rationale**: matches `docs/rulebooks/database-rules.md` exactly ("Schema changes ship
ONLY as EF Core migrations via the repo-local `dotnet-ef` tool").

## R-9: Test database strategy

**Decision**: `FlowboardApiFactory : WebApplicationFactory<Program>` overrides the
connection string to `flowboard-db-test`, calls `Database.Migrate()` once per test
collection (xUnit `ICollectionFixture`), and each test class cleans up the rows it
created (delete-by-id in `IAsyncLifetime.DisposeAsync`, scoped to that test's own seeded
data) rather than truncating shared tables — avoids cross-test interference without a
full database recreate per test.

**Rationale**: matches 001's existing `WebApplicationFactory` pattern for
`HealthEndpointTests`, extended for a real (disposable) database per the stack profile
("tests use a disposable `flowboard-db-test`"). Full-recreate-per-test would be safer in
isolation but is materially slower with the migration-run cost repeated every test; the
collection-scoped migrate + per-test cleanup gives correctness at a fraction of the
runtime cost, and is the same trade every EF Core-based test suite in this style makes.

## R-10: Password strength rule

**Decision**: minimum 10 characters; no other composition rules (no forced
uppercase/digit/symbol mix). Reject shorter passwords with the specific rule that
failed (spec FR-003).

**Rationale**: current NIST guidance (SP 800-63B) favors length over composition rules;
composition requirements push users toward predictable substitutions without adding
real entropy. A simple, well-documented minimum is enough for v1.0 and easy for the
frontend to validate identically with Zod (mirrors this exact rule, no drift).
