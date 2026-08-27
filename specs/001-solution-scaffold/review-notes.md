# Review Notes — 001 Solution Scaffold

## Phase A — backend health slice (T001–T003)

**Gate**: `dotnet build --warnaserror && dotnet test` in `flowboard-api` — run by the
user 2026-08-27, **EXIT: 0 confirmed** (build 0 warnings / 0 errors; tests 1/1 passed).

**Diff surface**: `Program.cs`, `Flowboard.Api.csproj` (Version 0.1.0), new
`Endpoints/HealthEndpoints.cs`, new `Services/HealthService.cs`, test csproj
(+ `Microsoft.AspNetCore.Mvc.Testing`, plan-approved), new `HealthEndpointTests.cs`,
deleted placeholder `UnitTest1.cs`. No files outside the approved phase.

**AI review vs `docs/rulebooks/backend-compliance-checklist.md`** (2026-08-27):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | Endpoint group pattern (`MapHealthEndpoints` + `MapGroup`); no controllers/CQRS/MediatR/repositories; handler is thin (service call only); both code files cite `contracts/health-api.md` |
| API Surface | PASS | No inputs to validate (none exist); DTO record serialized, no entities (none exist); no internal `Id` anywhere; 409/pagination N/A — no `If-Match` endpoints or lists in this phase |
| Domain & Authorization | PASS (N/A) | No board-scoped operations, no invariant-touching code, no ordering math, no activity events in this phase; endpoint is public liveness by spec assumption, explicitly `.AllowAnonymous()` |
| Data Access & Performance | PASS (N/A) | No EF Core, no queries, no I/O in the handler; no SignalR yet |
| Security | PASS | No secrets in source or logs; no SQL; no external HTTP; safe payload only |
| Testing | PASS | `WebApplicationFactory` integration test asserts 200 + full contract payload shape incl. UTC timestamp kind; validation/authz/concurrency cases N/A (no inputs, anonymous, no writes) |
| Process | PASS | Only Phase A files changed (`git status` reviewed); packages match plan approvals; gate user-certified EXIT 0 |

**Verdict**: Phase A PASS — no FAIL items, no waivers. Cleared to commit.

## Phase B — frontend shell slice (T004–T017)

**Gate**: `npm run lint && npm run build` in `flowboard-web` — run by the user
2026-08-27, **EXIT: 0 confirmed** (ESLint clean; production build + TypeScript clean).

**Diff surface** (18 files, staged review): `package.json`/`package-lock.json` (T004
plan-approved packages only), `.gitignore` (+`!.env.example` — the template's `.env*`
pattern would have silently excluded T006's file), `.env.example`, `globals.css` moved
`app/` → `styles/` with dark variant + theme variables, `layout.tsx` (providers, §5.1
bootstrap script, FlowBoard metadata), `page.tsx`, and new files under `server/api/`,
`app/api/trpc/[trpc]/`, `lib/{api,trpc,theme}/`, `components/{shell,layout}/`. No files
outside the approved phase.

**Runtime smoke (AI, pre-gate)**: healthy path — `/api/trpc/health.status` returned the
contract payload end-to-end (browser → tRPC → server-only client → API); unavailable
path — backend stopped → safe `SERVICE_UNAVAILABLE` message, shell still HTTP 200.

**AI review vs `docs/rulebooks/frontend-compliance-checklist.md`** (2026-08-27):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | Rulebook project shape throughout; kebab-case files / PascalCase exports; `'use client'` only on the four files needing hooks/handlers — top bar and page stay server components. Note: the health Zod schema validates the upstream *response* and is colocated with its router; the `lib/<feature>/schemas.ts` rule targets input schemas (this procedure takes no input) |
| Data Flow | PASS | Only `fetch` lives in server-only `lib/api/health-client.ts`; UI uses `trpc.health.status.useQuery`; procedure validates the payload with Zod mirroring `contracts/health-api.md`; no mutations, no backend-owned recomputation |
| Forms | PASS (N/A) | No data-entry forms in this phase |
| UI States & Accessibility | PASS | Loading/healthy/unavailable all implemented, distinct via `data-state` + `role` (status/alert) + non-color ✓/✕ cue; no empty state applies to a status pill; no drag/modals this phase |
| State, Styling | PASS | Server state in React Query only; theme in context (sanctioned); Tailwind utilities; hex only as theme variables in `styles/globals.css` (the sanctioned spot); no screenshots exist for 001 → no Visual Compliance Loop; both themes verified in dev, re-verified in T018 walkthrough |
| Security & Performance | PASS | `FLOWBOARD_API_URL` server-only; no secrets/tokens client-side; the single `dangerouslySetInnerHTML` is the §5.1 pre-approved fixed-literal theme script (ADR-3); error message user-safe; permission gating & pagination N/A |
| Process | PASS | Packages exactly the plan-approved set (tRPC v11 ×3, React Query v5, zod); diff surface reviewed above; gate user-certified EXIT 0 |

**Deviation note (T014)**: the scaffold's ESLint (react-hooks v6,
`set-state-in-effect`) rejects the classic setState-in-effect theme initializer, so
`theme-context.tsx` uses `useSyncExternalStore` with the `<html>` class as the runtime
source of truth. The localStorage/matchMedia default logic exists exactly once — in the
§5.1 bootstrap script. Behavior matches T014; mechanism differs. Not a waiver: no rule
is violated, and the single-implementation outcome is stronger than the task's letter.

**Verdict**: Phase B PASS — no FAIL items, no waivers. Cleared to commit.
