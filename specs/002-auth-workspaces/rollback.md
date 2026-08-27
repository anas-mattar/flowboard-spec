# Rollback — 002 Auth & Workspaces

Written before Phase 1 implementation begins, per the Critical Delivery Addendum
(`docs/sdlc/critical-delivery.md` item 1 — this feature is Critical because it
implements authentication and authorization).

## Rollback Method

```bash
git revert [commit-sha]        # one revert per phase commit, newest first
```

Phase B (frontend) commit(s) revert cleanly and independently — no schema involved.
Phase A (backend) commit revert also reverts its EF Core migration **file**, but see
Database Rollback below: reverting the code does not by itself undo an already-applied
migration on a shared database.

## Changed Areas

- `flowboard-api`: new `Data/`, `Domain/Entities/`, `Domain/Result.cs`,
  `Endpoints/ResultMapping.cs`, `Endpoints/AuthEndpoints.cs`,
  `Endpoints/BoardMembersEndpoints.cs`, `Services/PasswordHasher.cs`,
  `Services/TokenService.cs`, `Services/AuthService.cs`,
  `Services/BoardAccessService.cs`, `.config/dotnet-tools.json`, one migration.
  `Program.cs` gains `AddAuthentication`/`AddAuthorization`/`AddDbContext`/rate-limiting
  registrations (additive changes to existing composition root).
- `flowboard-web`: new `app/(auth)/`, `app/api/auth/[...nextauth]/route.ts`,
  `lib/auth/`, `components/auth/`, `server/api/routers/auth.ts`,
  `server/api/routers/board-members.ts`. `server/api/trpc.ts` gains
  `protectedProcedure` (additive); `layout.tsx` gains a `SessionProvider` wrapper
  (additive).
- No changes to 001's `HealthEndpoints`/`health.status` surface — `publicProcedure`
  stays as-is (frontend-trpc.md).

## Database Rollback

- Schema changes in this feature: **additive only** — one new migration creating
  `User`, `Workspace`, `Board`, `BoardMember`, `Invitation` (data-model.md). No existing
  table is altered (001 shipped no tables).
- Migration down-path: the migration's generated `Down()` drops these five new tables —
  safe to run **only if no real user/workspace/board data has been created against
  them yet** (dev/pre-launch). Once real signups exist, running `Down()` destroys that
  data; at that point the correct rollback is a **new forward migration** that disables
  the affected endpoints (e.g., feature-flag signup off) rather than dropping tables,
  per `docs/sdlc/rollback-process.md` ("do not drop tables/columns without explicit
  approval").
- Protected domain data touched: none yet — no `ActivityEvent` rows or other
  invariant-1-protected data exists at this point in the roadmap. This feature does not
  itself create any append-only or 30-day-restorable data (a removed `BoardMember` row
  is a hard delete by design, data-model.md — not protected domain data).
- If this feature is reverted **after** merge to `main` but **before** 003+ have built
  on top of its tables, `Down()` is safe. If 003+ has already added foreign keys into
  `Board`/`User`/`Workspace`, this rollback plan is stale and must be rewritten as part
  of reverting whichever later feature depends on it first (rollback-process.md: "if a
  rollback would touch [dependent] data, stop and report").

## Deployment Rollback

- Environment variables/secrets to remove alongside a code revert: the JWT signing key
  (if newly provisioned for this feature) — no other config/permission changes are
  introduced.
- No feature flags are used in this feature (v1.0 scope, no gradual rollout mechanism
  exists yet); rollback is all-or-nothing per phase commit.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code) — backend:
  `dotnet build --warnaserror && dotnet test`; frontend: `npm run lint && npm run build`
- [ ] `flowboard-db` no longer has `User`/`Workspace`/`Board`/`BoardMember`/`Invitation`
  tables (if `Down()` was run) — or, if data already existed, the new forward migration
  confirms signup/login endpoints are disabled and return a safe, explicit error rather
  than a schema error
- [ ] The home page (001) still renders and shows backend health status — proves 002's
  revert did not regress the 001 baseline
