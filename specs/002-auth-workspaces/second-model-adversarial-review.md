# Second-Model Adversarial Review — 002 Auth & Workspaces

**Reviewer**: Claude Opus 5 (independent second model — Critical Delivery Addendum item 5)
**Date**: 2026-08-27
**Scope**: `flowboard-api` `main` @ `b97856d` ("feat: auth + board membership backend"), `flowboard-web` `main` @ `9d29af5` ("feat: auth + board membership frontend"), read as the files exist now — not as diffs, and not through the prior reviews' summaries.
**Method**: spec → plan → contracts → data-model → invariants → constitution read first; then every backend service/endpoint/configuration/migration/test and every frontend auth/BFF/component file listed in the assignment, plus the installed `next-auth`/`@auth/core` sources in `node_modules` where behaviour depended on library defaults. The four prior reviews and `review-notes.md` were read **last**, after my findings were fixed.

## Verdict

**CHANGES REQUESTED — do not treat this feature as merge-complete.**

The core authorization design is genuinely sound and I could not break it: authorization is re-derived from the database on every request with no cached-claim path, the role matrix is enforced at the service boundary before any data is touched, the frontend's role gating is provably UI-only, and the browser never receives the backend JWT. The prior reviews are correct on all of those points, and I verified each myself rather than accepting them.

However, I found **three blocking issues that all four prior reviews missed**, one of which is a credentialed backdoor account shipped in the production migration, and one of which means every protected call in this feature fails in any HTTPS deployment. I also found a category of risk (invitation claiming on an unverified email) that the spec formally satisfies while providing no actual security, and which is recorded nowhere as an accepted residual risk.

Counts: **3 BLOCKING**, **2 HIGH**, **6 FINDING**, **11 MINOR**, **5 DOC DRIFT**.

---

## BLOCKING findings

### B1 — The production migration seeds a working account whose password is published in source control

`src/Flowboard.Api/Data/Configurations/UserConfiguration.cs:11-18` and `:44-55` seed a `User` via `HasData`:

```csharp
// Known test password: "FixtureOwner!2026" — BCrypt hash pre-computed offline ...
public const string FixtureOwnerEmail = "fixture-owner@flowboard.test";
public const string FixtureOwnerPasswordHash = "$2a$12$QaQbHkSBz2bsEVMr5NPkfun1/.UNcfh5Hthg57fglJoMnzCrxhIJy";
```

This is not test-project code. It is in the application assembly's model, so it is emitted into the **production** migration — `Migrations/20260827130245_AddAuthWorkspaces.cs:158-161` (`InsertData` into `User`), `:163-166` (its `Workspace`), `:168-171` (its `Board`). Any environment that runs `dotnet ef database update` — which `quickstart.md` instructs the developer to do against `flowboard-db`, and which is the documented deploy path — gets:

- a real, loginable account (`POST /v1/auth/login` with `fixture-owner@flowboard.test` / `FixtureOwner!2026` returns a valid 14-day JWT — the tests themselves prove this works end-to-end at `tests/.../BoardMembersEndpointTests.cs:19,72` and `AuthEndpointTests.cs:182`),
- which owns a workspace, and therefore
- holds **implicit `BoardAdmin`** on every board in that workspace via `BoardAccessService.ResolveAsync` (`Services/BoardAccessService.cs:36-39`), with the standing ability to invite anyone to it at any role.

The plaintext password is in a committed source comment and in two committed test files. This is a straight violation of constitution VIII ("Secrets MUST NEVER be stored in source code") and it is *beyond* what the plan approved: ADR-11 and `data-model.md:70-73` authorise exactly one thing — a seeded fixture **Board** with `CreatedBy = 'MIGRATION'`. Neither document authorises a seeded `User` carrying a live credential, and `rollback.md`'s Deployment Rollback section (which lists what to remove alongside a revert) does not mention it either.

The mitigating facts do not rescue it: the domain is `.test` (unroutable, so no mail can reach it — irrelevant, the login endpoint doesn't need mail), and the hash is BCrypt cost 12 (irrelevant, the plaintext is published).

**Required fix**: move the fixture user/workspace/board out of the production model. Either (a) seed them from the test fixture (`FlowboardApiFactory.InitializeAsync`, after `MigrateAsync`) rather than `HasData`, or (b) if a seed row must stay in the migration for the board, seed the user with a **non-verifiable** `PasswordHash` sentinel (e.g. `"DISABLED"`, which BCrypt `Verify` rejects) and have the test fixture set a real hash only in `flowboard-db-test`. Then write a forward migration that deletes/neutralises the row in any database the current migration already touched. Option (b) keeps the deterministic-seed property ADR-11 wanted without shipping a credential.

### B2 — `getToken()` reads the wrong cookie name (and wrong decryption salt) under HTTPS: every protected call fails in production

Both server-side token readers call `getToken` without `secureCookie`:

- `src/lib/auth/session.ts:21-24` — used by `server/api/caller.ts` for every Server Component call
- `src/app/api/trpc/[trpc]/route.ts:15` — used by every client-side tRPC call

In the installed library, `@auth/core/jwt.js:86` defaults the cookie name from `secureCookie ?? false`:

```js
const { secureCookie, cookieName = defaultCookies(secureCookie ?? false).sessionToken.name,
        salt = cookieName, ... } = params;
```

so it looks for `authjs.session-token` and derives its HKDF salt from that name. But NextAuth **writes** the cookie with a `__Secure-` prefix whenever the resolved URL is HTTPS — `@auth/core/lib/init.js:69`:

```js
cookies: merge(cookie.defaultCookies(config.useSecureCookies ?? url.protocol === "https:"), config.cookies)
```

and `@auth/core/lib/utils/cookie.js:44-45` (`cookiePrefix = useSecureCookies ? "__Secure-" : ""`).

Consequence in any deployment where Auth.js resolves an `https:` URL (i.e. every real one): the session cookie is `__Secure-authjs.session-token`, `getToken` looks for `authjs.session-token`, finds nothing, returns `null`. `getBackendSession()` returns `null` → `protectedProcedure` throws `UNAUTHORIZED` (`server/api/trpc.ts:27-30`) for **every** board-membership procedure. Meanwhile `auth()` (used by `app/boards/[boardPublicId]/page.tsx:19` and `components/layout/top-bar.tsx:9`) uses NextAuth's own cookie config and succeeds — so the UI renders as signed in, shows the workspace name, and then nothing works. Even if the cookie name were patched alone, `salt = cookieName` means decryption would still fail; both must be set consistently.

This is not a security hole — it fails closed (denies access), which is the safe direction. But it makes the entire feature non-functional over HTTPS, and it is invisible to both gates and to the quickstart walkthrough, because `quickstart.md` exercises everything over `http://localhost` where the unprefixed cookie name is correct. `npm run build` cannot catch it; there are no frontend tests.

**Required fix**: pass `secureCookie` (and let `salt` follow) consistently in both call sites, e.g. `secureCookie: process.env.NODE_ENV === "production"`, or better, export the cookie name from a single module shared with the NextAuth config so the two can't drift. Add a note to `quickstart.md` that the walkthrough over `http://` does not exercise production cookie naming.

### B3 — The audit actor is discarded on every membership-granting and membership-revoking write (data-model deviation)

`data-model.md:90` specifies `BoardMember.CreatedBy` as **"the inviter's `PublicId`, or `SYSTEM` for the workspace-owner's implicit access"**. The implementation hardcodes `"SYSTEM"` unconditionally:

- `Services/BoardMembershipService.cs:126` — `CreatedBy = "SYSTEM"` when an admin invites an existing user (the `caller` is already loaded two lines later at `:138`, so the correct value is trivially available)
- `Services/BoardMembershipService.cs:168` — `Invitation.CreatedBy = "SYSTEM"`
- `Services/BoardMembershipService.cs:149-150` — role changed in place, `UpdatedBy = "SYSTEM"`
- `Services/BoardMembershipService.cs:206` — **revoke**, `UpdatedBy = "SYSTEM"`
- `Services/AuthService.cs:91,94-95` — invitation-claim path (defensible here: the actor genuinely is the system)

Combine this with the hard delete at `Services/BoardMembershipService.cs:234` (`db.BoardMembers.Remove(member)`) and the result is that for the highest-value security actions in the feature there is **no record of who did it**:

| Action | Actor recorded? |
|---|---|
| Grant board access to an existing user | No — `BoardMember.CreatedBy = "SYSTEM"`, and no `Invitation` row is created on this path at all |
| Change a pending invitation's role | No — `UpdatedBy = "SYSTEM"` |
| Revoke a pending invitation | No — `UpdatedBy = "SYSTEM"` |
| Remove a member | No — row is hard-deleted, nothing survives |

`contracts/board-membership-api.md:80-82` explicitly justifies revoke-as-status-change on audit grounds ("`UpdatedDate`/`UpdatedBy` set … not physically deleted (audit trail, backend-security §13)") — the field is set, but to a constant that carries no information, so the stated purpose is not met. Constitution VI requires `CreatedBy`/`UpdatedBy` as an audit facility, not as a filled-in string.

The `BoardMember` hard delete is defensible against invariant 4 (whose literal scope is boards/lists/cards, and `data-model.md:80-81` approves it) — but it *does* create an audit gap for a security-relevant action, and that gap is made total rather than partial by the `"SYSTEM"` constant. Either fix `CreatedBy`/`UpdatedBy` to carry the acting user's `PublicId` (cheap, restores the invite/revoke trail), or accept that member removal is unauditable and say so explicitly in `data-model.md` — but not both silently.

**Required fix**: pass the caller's `PublicId` into `CreatedBy`/`UpdatedBy` on all four paths above. Removal remains unauditable until a later feature adds activity events; that should be a recorded, named residual risk rather than an omission.

---

## HIGH findings

### H1 — `POST /v1/auth/signup` is not rate-limited, contrary to its own contract, and it is an enumeration oracle

`contracts/auth-api.md:9` states for signup: *"Public (no auth required). **Rate-limited** (backend-security.md §12)."* Only login is limited — `Endpoints/AuthEndpoints.cs:21-22`:

```csharp
group.MapPost("/signup", Signup);                                        // no limiter
group.MapPost("/login", Login).RequireRateLimiting("auth-login");
```

`plan.md`'s Security check (VIII) mentions login only, so the plan and the contract diverge. Impact is concrete:

- Signup deliberately returns `409 "email already in use"` (`Services/AuthService.cs:47-50`, required by FR-002) — an unlimited, unauthenticated **account-existence oracle** for arbitrary email lists.
- Every signup attempt runs BCrypt at work factor 12 *before* the DB write (`AuthService.cs:59`), so unmetered signup is also a cheap CPU-exhaustion vector.

**Fix**: add a second partitioned policy (e.g. `auth-signup`, tighter window) and `RequireRateLimiting` on signup, or move it onto the `/v1/auth` group.

### H2 — An invitation to an unregistered email is effectively a bearer token for board access, because email ownership is never verified

FR-018 promises: *"System MUST prevent a pending invitation from being claimed by anyone other than the exact invited email address."* The implementation satisfies this literally — matching is exact — but there is **no** other check: no token, no nonce, no confirmation link, and `spec.md:249-250` explicitly puts email verification out of scope for v1.0. So "the exact invited email address" is a self-asserted string. Two concrete attacks:

1. **Claim someone else's invitation** — sign up with a known-invited email before its real owner does, and immediately inherit that email's pending board membership.
2. **Force a stranger into your board** — pre-create a pending invitation for an email you don't own; when the real owner signs up (for any reason, unrelated to this board), they're silently added to your board with no accept step, and their profile is disclosed to every existing member.

Not BLOCKING because it's an openly-made spec scope decision, but it must be an explicitly recorded and accepted residual risk with a named mitigation — and it is recorded **nowhere** currently.

**Fix (documentation, minimum)**: correct FR-018's wording so it doesn't over-claim, and add both attacks to a residual-risk register. **Fix (cheap, code)**: a per-invitation claim token, required at signup, would close attack (1) without needing email delivery.

---

## FINDING (real defects/gaps, non-blocking)

- **F1** — Identical-401 holds in status/message but leaks via **timing**: unknown-email skips BCrypt entirely (`||` short-circuit in `AuthService.cs:124-131`), known-email pays ~250-500ms. Fix: verify against a fixed dummy hash when the user isn't found.
- **F2** — `DELETE /v1/invitations/{id}` (revoke) has **zero tests** — no success, no 403, no 404, no cross-board test. Contradicts Phase A review's claim of covering "every contract endpoint's success/failure paths."
- **F3** — Per-role authorization-failure coverage incomplete: only `Observer` is tested for 403; `BoardMember` (named explicitly in spec.md US4) is untested. No test asserts unauthenticated (no header) → 401 on any board-scoped endpoint.
- **F4** — Stale pending invitations become permanent phantoms: re-inviting an email that has since registered creates a `BoardMember` row but never marks the old `Pending` invitation `Accepted`, leaving an unclaimable ghost entry.
- **F5** — Concurrent invites of the same email/board surface as unhandled `500` (unique-index violation), not the contracted `409` — `AuthService.SignUpAsync` has the retry-on-conflict pattern; `BoardMembershipService`'s invite/pending paths don't.
- **F6** — The 14-day NextAuth session (rolling) and the fixed 14-day backend token (never refreshed) diverge: a continuously active user eventually gets a valid-looking session but every backend call 401s, surfaced to them as "The FlowBoard backend is unavailable" instead of being signed out. `backendTokenExpiresAtUtc` is stored but never read.

## MINOR (11 items) — see summary below; full detail was in the agent's report

Notable ones: email uniqueness relies on default DB collation rather than an explicit one (M1); no index supports the signup-time invitation-claim lookup, causing a table scan on every signup (M2); board/invitation/user public-id path segments aren't validated as UUIDs before being interpolated into backend URLs (M3); the rate limiter's per-IP partition collapses into one shared bucket behind any reverse proxy unless `ForwardedHeaders` is configured with a trusted-proxy allowlist (M4); rate limiting itself has no test (M5); pending invitees' emails are visible to `Observer`s while members' emails are hidden — contract-sanctioned but asymmetric (M6); no max password length, so BCrypt silently truncates past 72 bytes (M7); the role parser also accepts numeric strings like `"0"`/`"1"`/`"2"` (M8); no minimum-length guard on the JWT signing key (M9); `AUTH_SECRET` (Auth.js v5's own documented name) vs. hardcoded `NEXTAUTH_SECRET` is a silent-failure trap for a deployer following upstream docs (M10); the board page fetches membership twice (server probe + client refetch) and `shadcn` sits in `dependencies` instead of `devDependencies` (M11).

## DOC DRIFT (5 items)

- **D1** — Retained audit evidence overstates the test count: reviews/`review-notes.md` say 27 tests; actual count is 26.
- **D2** — Phase A review's "every contract endpoint's success/failure paths" claim is false (see F2).
- **D3** — `quickstart.md`/`rollback.md` describe the migration seed as "the one seeded fixture board," omitting that it also seeds a user+workspace with a known working password (B1).
- **D4** — `plan.md` and `contracts/auth-api.md` disagree on whether signup is rate-limited (H1) — should have been stopped and reported per CLAUDE.md's conflict rule, not resolved silently.
- **D5** — `spec.md` FR-016 requires every board-membership identifier to be opaque; `data-model.md` gives `BoardMember` no `PublicId` at all. Outcome is safe (nothing internal leaks) but the conflict wasn't surfaced.

## Domain-invariant pass (independent)

Confirms invariants 5 and 8 both PASS (with H2 noted as a scope caveat on invariant 5 — enforcement is sound, but the *identity* it's keyed to for an unregistered invitee is self-asserted, not verified). Also flags that invariant 4 applies more directly than the prior reviews stated (Board/Workspace both PASS with full soft-delete + query filter) and that the fixture entities' sequential/guessable PublicIds (`…0001`/`…0002`/`…0003`) are the opposite of "non-sequential," compounding B1's exposure.

## Residual risk (agent's closing assessment)

The **design** is sound — re-derive-on-every-request, the token-never-reaches-the-browser boundary, 404-not-403 for non-members, fail-closed throughout — all real and correctly implemented. The blocking findings are implementation/packaging defects sitting on top of that good design, each a small and well-contained fix. Recommendation: fix B1, B2, B3; fix-or-formally-record H1/H2; add F2/F3's missing tests; then re-run both gates and re-confirm exit codes before treating the feature as merge-complete.
