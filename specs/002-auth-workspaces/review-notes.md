# Review Notes — 002 Auth & Workspaces (Wrap-up)

Consolidated record for the Critical Delivery Addendum (`docs/sdlc/critical-delivery.md`).
This document does not re-derive Phase A/Phase B's findings — it indexes them and records
the audit evidence the addendum requires be retained in the feature directory.

## Phase index

| Phase | Scope | AI review | Human review | Gate |
|---|---|---|---|---|
| A (backend) | T001–T039, `flowboard-api` | `ai-code-review-phase-a.md` — APPROVE with follow-ups (F1, F2 resolved; F3 process note) | `human-pr-review-phase-a.md` — **APPROVED** 2026-08-27 | `dotnet build --warnaserror && dotnet test` → `EXIT: 0` (user-confirmed 2026-08-27) |
| B (frontend) | T040–T053, `flowboard-web` | `ai-code-review-phase-b.md` — APPROVE with follow-ups (F1–F3 resolved; F4 confirmed) | `human-pr-review-phase-b.md` — **APPROVED** 2026-08-27 | `npm run lint && npm run build` → `EXIT: 0` (user-confirmed 2026-08-27) |
| Wrap-up (this doc) | T054–T058, both repos | `second-model-adversarial-review.md` (Claude Opus 5) — CHANGES REQUESTED → remediated (see below) | `human-pr-review.md` | both gates re-run at merge time (Delivery Mapping table, `tasks.md`) |

## Backend compliance checklist (`docs/rulebooks/backend-rules.md`, `database-rules.md`)

- [x] JWT auth via `Microsoft.IdentityModel.JsonWebTokens.JsonWebTokenHandler`, HMACSHA256,
      identity-only claims (`sub`, `email`) — `TokenService.cs`
- [x] Per-request authorization, never cached-claim-based — `BoardAccessService.ResolveAsync`
      called first by every board-scoped operation, fails closed
- [x] Password hashing via BCrypt work factor 12 — `PasswordHasher.cs`
- [x] Rate limiting on `/v1/auth/login` **and** `/v1/auth/signup`, partitioned per caller
      IP (Phase A F2 fix; wrap-up H1 fix) — `Program.cs`
- [x] Migrations additive only (`AddAuthWorkspaces`, `FixSeededOwnerCredentialLeak`) — no
      `ALTER`/`DROP` on 001's schema
- [x] Every entity has `Id INT IDENTITY` + `PublicId`; only `PublicId` ever serialized
- [x] `dotnet-ef` run via repo-local tool manifest (`dotnet tool restore`), never global
- [x] No working credential in the production migration model (wrap-up B1 fix) —
      `UserConfiguration`'s seeded `PasswordHash` is a non-verifiable placeholder; the
      real test-only hash is set by the test host, only in `flowboard-db-test`
- [x] `CreatedBy`/`UpdatedBy` on invite/role-change/revoke carry the acting user's
      `PublicId` (wrap-up B3 fix) — was hardcoded `"SYSTEM"`, discarding who granted or
      revoked access; `BoardMember` removal remains a hard delete (data-model.md's
      documented exception) and stays unaudited
- [x] 34/34 tests passing (`PasswordHasherTests`, `TokenServiceTests`,
      `BoardAccessServiceTests`, `AuthEndpointTests`, `BoardMembersEndpointTests`) —
      corrects Phase A's retained count, which said 27 but the file actually held 26
      (second-model review D1); 8 tests were added at wrap-up covering the revoke
      endpoint (F2 — previously untested), the `BoardMember`-role and fully-unauthenticated
      403/401 cases (F3 — only `Observer` was tested before), and the B3 audit-actor fix

## Frontend compliance checklist (`docs/rulebooks/frontend-rules.md`, `frontend-forms.md`)

- [x] All backend calls go through tRPC procedures → server-only `lib/api/*-client.ts`
      clients — no component fetches the backend directly
- [x] Browser never holds the backend token — `auth-config.ts`'s `session()` callback
      omits `backendToken`; only read server-side via `next-auth/jwt`'s `getToken()`
- [x] F8a–F8d forms stack (React Hook Form + `zodResolver` + shadcn `Form` + Sonner
      `toast`) — `signup-form.tsx`, `login-form.tsx`, the invite form in
      `board-members-panel.tsx`
- [x] `.env.example` carries only placeholders (`FLOWBOARD_API_URL`, `NEXTAUTH_SECRET`,
      `NEXTAUTH_URL`); real values stay in gitignored `.env.local` (T054)
- [x] Package additions (shadcn/ui, RHF, Sonner) recorded as a plan.md amendment,
      user-confirmed before implementation (constitution IV)
- [x] Server-side `getToken()` calls pass `secureCookie` consistently (wrap-up B2 fix,
      `lib/auth/secure-cookie.ts`) — without it, every protected tRPC/Server-Component
      call would silently 401 under HTTPS (wrong cookie name/salt), invisible to both the
      build gate and the `http://localhost` quickstart walkthrough
- [ ] Automated frontend test coverage — **none exists** (consistent with 001; deferred
      per `docs/sdlc/gate-command.md`'s "`npm test` joins once the first test exists").
      Compensating control: T056's manual walkthrough (`quickstart.md` §7) plus Phase A's
      27 backend tests covering every contract behavior the frontend calls into.

## Domain-invariant review — cross-phase summary (Critical Delivery Addendum item 2)

Both phase reviews carry a full item-by-item pass (`ai-code-review-phase-a.md`,
`ai-code-review-phase-b.md`). Only invariants 5 and 8 apply to this feature; both PASS in
both phases:

- **Invariant 5 (Permissions Enforced Server-Side)** — the backend re-resolves access via
  `BoardAccessService` on every request regardless of cached JWT claims or UI state; the
  frontend's `isAdmin` gating is UX-only and every mutation still round-trips through the
  same protected backend procedure. Verified live during T056's walkthrough: an `Observer`
  token received `200` on a read and `403` on a write against the running instance, not
  just in the test host.
- **Invariant 8 (Opaque Public Identifiers)** — every route, claim, and DTO field uses
  `PublicId` Guids; no internal `INT IDENTITY` value is ever serialized to a client-facing
  type (grepped in both phase reviews; re-confirmed live during T056 — every walkthrough
  request/response used `PublicId` values exclusively).

`second-model-adversarial-review.md` re-derived this pass independently (not from the
phase reviews) and reached the same PASS verdicts on both, with one caveat recorded
against invariant 5: enforcement itself is sound, but for an invitation to an
unregistered email, the *identity* it's keyed to is a self-asserted signup field, not a
verified one (H2 — see the Accepted Residual Risk section below and `spec.md`). It also
noted the fixture entities' sequential/guessable `PublicId`s (`…0001`/`…0002`/`…0003`)
as the opposite of invariant 8's "non-sequential" intent — accepted, since these rows
exist only to give integration tests a fixed target, not as production data.

## Wrap-up remediation (T058 findings, fixed before final sign-off)

The independent second-model adversarial review (`second-model-adversarial-review.md`,
Claude Opus 5 — a different model from every prior review in this feature, per Critical
Delivery Addendum item 5) returned **CHANGES REQUESTED**, catching three blocking issues
none of the four prior same-model reviews had found. Per user direction, all
BLOCKING + HIGH findings were fixed before merge; FINDING/MINOR/DOC-DRIFT items were
recorded as accepted residual risk rather than fixed, to keep this remediation scoped:

| # | Finding | Fix |
|---|---|---|
| B1 BLOCKING | Migration seeded a real, loginable admin account with a published password | `UserConfiguration`'s `HasData` now seeds a non-verifiable placeholder hash; `PasswordHasher.Verify` hardened against a malformed hash (returns `false`, not a 500); new migration `FixSeededOwnerCredentialLeak` neutralizes the row (applied to the local dev DB); the real test-only hash is set by `FlowboardApiFactory` in `flowboard-db-test` only |
| B2 BLOCKING | Server-side `getToken()` calls omitted `secureCookie`, so every protected call would silently 401 under HTTPS (wrong cookie name/salt) | Both call sites (`lib/auth/session.ts`, `app/api/trpc/[trpc]/route.ts`) now pass `secureCookie` from a single shared `lib/auth/secure-cookie.ts` so the two can't drift |
| B3 BLOCKING | `CreatedBy`/`UpdatedBy` hardcoded to `"SYSTEM"` on invite/role-change/revoke — no record of who granted or revoked access | All four sites now record the caller's `PublicId`; covered by a new test (`Invite_RecordsInviterAsCreatedBy`) |
| H1 HIGH | Signup had no rate limit despite `contracts/auth-api.md` requiring one (enumeration + CPU-exhaustion risk) | New partitioned `auth-signup` policy, same per-IP pattern as login; `plan.md` amended (the plan/contract drift itself was D4) |
| H2 HIGH | Invitation claiming trusts a self-asserted email with no ownership verification — spec-permitted but never recorded as a risk | Not code-fixed (email verification is a v1.0 scope decision, not a bug); `spec.md` FR-018 reworded to state what it actually enforces, plus a new **Accepted Residual Risk** section naming both attacks and the deferred mitigation (a per-invitation claim token) |
| F2 (test gap) | `DELETE /v1/invitations/{id}` had zero tests | 4 new tests: success, already-revoked→404, non-admin→403, unrelated-user→404 |
| F3 (test gap) | Only `Observer` was tested for 403; `BoardMember`-role and fully-unauthenticated cases were untested | 2 new tests: `BoardMemberRole_Gets403OnInviteAndRemove`, `Unauthenticated_Gets401OnEveryBoardScopedEndpoint` |

All 34 backend tests pass after remediation (26 pre-existing + 8 new); both gates were
re-run and re-confirmed by the user (see `human-pr-review.md`).

**Deliberately not fixed in this pass** (recorded, not blocking): F1 (login's
identical-401 leaks via BCrypt-skip timing on the unknown-email branch), F4 (a stale
pending invitation isn't marked `Accepted` when the same email is re-invited after
registering), F5 (a concurrent double-invite race surfaces as `500` instead of the
contracted `409`), F6 (the rolling 14-day NextAuth session can outlive the fixed 14-day
backend token, showing the user "backend unavailable" instead of signing them out), and
all MINOR/DOC-DRIFT items (collation, missing index, path-segment validation, proxy
rate-limit partitioning, `AUTH_SECRET` vs `NEXTAUTH_SECRET` naming, etc.) — full list in
`second-model-adversarial-review.md`. None of these were assessed as blocking merge; they
are candidates for a follow-up hardening pass, not this feature's remaining scope.

## Audit evidence retained (Critical Delivery Addendum item 3)

| Evidence | Location |
|---|---|
| Backend gate command + exit code (Phase A) | `human-pr-review-phase-a.md` Gate Result section — `EXIT: 0` |
| Frontend gate command + exit code (Phase B) | `human-pr-review-phase-b.md` Gate Result section — `EXIT: 0` |
| Backend + frontend gates re-run at wrap-up | `human-pr-review.md` Gate Result section |
| `git diff --stat` / `git status --short` scope checks | Embedded in `ai-code-review-phase-a.md` and `ai-code-review-phase-b.md`'s evidence tables |
| Phase A review checklists (AI + human) | `ai-code-review-phase-a.md`, `human-pr-review-phase-a.md` |
| Phase B review checklists (AI + human) | `ai-code-review-phase-b.md`, `human-pr-review-phase-b.md` |
| Independent second-model adversarial review (T058) | `second-model-adversarial-review.md` |
| Rollback plan (written before Phase 1; wrap-up addendum for B1) | `rollback.md` |
| Manual end-to-end walkthrough (T056) | `quickstart.md` §7 |
| Final consolidated human review + approval | `human-pr-review.md` (this phase) |

## Residual items carried forward (not blocking)

- **H2** (`spec.md` Accepted Residual Risk, `second-model-adversarial-review.md`) —
  invitation claiming trusts a self-asserted email; two named attacks accepted as a
  known v1.0 trade-off pending a future claim-token mitigation.
- **F1, F4, F5, F6** and all MINOR/DOC-DRIFT items (`second-model-adversarial-review.md`)
  — a login timing side-channel, a stale-invitation phantom-row edge case, a concurrency
  race that surfaces the wrong status code, a session/token-expiry UX mismatch, and
  assorted hardening items (collation, indexing, path validation, proxy header trust,
  env-var naming). Candidates for a future hardening pass; none assessed as blocking.
- **F4** (`ai-code-review-phase-b.md`, unrelated to the second-model review's F4 above —
  same label, different finding) — `BoardMembersPanel` is a plain list, not a shared
  base-table system (which doesn't exist in this scaffold yet). Accepted for this feature;
  revisit if a future feature needs pagination/search on a similar list.
- **Zero automated frontend tests** — accepted as consistent with 001, not a regression
  introduced by this feature; the first frontend test suite is not this feature's scope to
  introduce unilaterally (would be a plan.md-scale addition).
