# Implementation Plan: Solution Scaffold

**Branch**: `001-solution-scaffold` | **Date**: 2026-08-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-solution-scaffold/spec.md`

## Summary

Give both gate-green empty scaffolds their first real behavior — a versioned backend
health endpoint and a frontend app shell that reports backend status through the BFF,
with a flash-free theme toggle — and, per the constitution IV bootstrap clause, record
the founding architecture decisions this plan's ADR section fixes for every later
feature. Two phases: Phase A backend, Phase B frontend; each ends with the user-run
gate.

## Technical Context

**Language/Version**: C# / .NET 10 (SDK 10.0.202 pinned); TypeScript 5 strict / Node 22
**Primary Dependencies**: ASP.NET Core minimal APIs, xUnit + `WebApplicationFactory`;
Next.js 16.3.3, React 19.2.8, Tailwind CSS v4; NEW this feature: tRPC v11
(`@trpc/server`, `@trpc/client`, `@trpc/react-query`), TanStack React Query v5, Zod
(approved below under constitution IV)
**Storage**: N/A — FR-007 forbids database and domain entities in this feature
**Testing**: backend — xUnit integration test via `WebApplicationFactory`; frontend —
gate is `npm run lint && npm run build` (no frontend test runner yet; joins the gate
when the first frontend test lands per `docs/sdlc/gate-command.md`)
**Target Platform**: web — latest two versions of Chrome, Edge, Firefox, Safari
(product spec §8); dev on Windows
**Project Type**: web application, two nested repos (`flowboard-api`, `flowboard-web`)
per constitution III
**Performance Goals**: trivial for this feature — shell shows healthy status within 5 s
(SC-001); the founding structure must not preclude the product budgets (board hydration
< 1.5 s, spec §8)
**Constraints**: no auth, no DB, no domain entities (FR-007); backend URL reaches the
BFF via server-only env var (never `NEXT_PUBLIC*`)
**Scale/Scope**: scaffold only — 1 endpoint, 1 page, 1 toggle, 1 integration test

## Architecture Decision Record *(constitution IV bootstrap clause — this becomes "the existing architecture" when 001 merges)*

### ADR-1 — Backend internal shape: minimal-API endpoint groups over a thin service layer, single project

- **Options considered**: (a) MVC `[ApiController]` controllers; (b) Clean Architecture
  multi-project split (Api/Application/Domain/Infrastructure) from day one; (c) CQRS +
  MediatR; (d) minimal-API endpoint groups + thin service layer inside the existing
  `src/Flowboard.Api` project.
- **Decision**: (d). One static `{Feature}Endpoints` class per bounded context under
  `Endpoints/`, registered via `Map{Feature}Endpoints` + `MapGroup`; handlers are thin
  and call services under `Services/`; domain logic (when it arrives) lives under
  `Domain/` in the same project. New projects are added only when a feature's plan
  justifies them.
- **Consequences**: matches `docs/rulebooks/backend-rules.md`; no controller/CQRS/
  MediatR code may be introduced without a future plan's approval. Layering direction
  inside the project: Endpoints → Services → Domain; nothing references Endpoints.
  The shared `Result<T>` → `ToHttpResult()` mapping (`Endpoints/ResultMapping.cs`) is
  introduced by the first feature with failure modes to map (002+), not speculatively
  here — the health handler returns `Results.Ok(...)` directly.

### ADR-2 — Frontend data flow: tRPC BFF

- **Options considered**: (a) browser calls the REST API directly with a public base
  URL; (b) plain Next.js route handlers proxying REST; (c) tRPC BFF — browser → tRPC
  procedure (server-side) → server-only fetch wrapper → .NET API.
- **Decision**: (c), per `docs/rulebooks/frontend-rules.md` and
  `docs/rulebooks/frontend/frontend-trpc.md`. Procedures live in `src/server/api/`,
  validate input with Zod, and call server-only clients in `src/lib/api/*-client.ts`;
  the backend base URL is a server-only env var.
- **Consequences**: the browser never holds a backend token or URL; end-to-end types
  from procedure to component; every later read/write goes through this path. The one
  sanctioned exception remains the SignalR client (feature 008 decides its wiring).
  Until feature 002 adds session context, only `publicProcedure` exists.

### ADR-3 — Theme system: class on `<html>` + fixed-literal bootstrap script

- **Options considered**: (a) CSS `prefers-color-scheme` only (no user override);
  (b) React-state theme applied after hydration (flashes on load); (c) `dark` class on
  `<html>`, persisted to `localStorage`, applied by a fixed-literal inline script
  before first paint.
- **Decision**: (c). Tailwind v4 dark variant keyed to the `dark` class; a theme
  context + toggle updates the class and `localStorage`; the inline bootstrap script is
  the pre-approved §5.1 exception in `docs/rulebooks/frontend/frontend-security.md` —
  **this plan grants that approval**. The script body is a fixed string literal; first
  visit follows `matchMedia` system preference.
- **Consequences**: no wrong-theme flash (FR-005); any change to the script must keep
  it a fixed literal; no other `dangerouslySetInnerHTML` exists or is approved.

### ADR-4 — Ordering model (recorded now per `docs/rulebooks/database-rules.md`, first used by feature 003+)

- **Options considered**: (a) dense integer positions (renumber siblings on move);
  (b) lexicographic rank strings (LexoRank-style); (c) sparse `float` (SQL `float`/C#
  `double`) positions with midpoint insertion and background re-balancing.
- **Decision**: (c) — the product spec's own default (§5.1) and the simplest correct
  implementation of domain invariant 2 (one-row moves). Ordering math lives in ONE
  module: `Flowboard.Api/Domain/Ordering.cs` (namespace `Flowboard.Api.Domain`),
  golden-fixture tested when introduced.
- **Consequences**: `Position` columns are `float`; ties broken by `Id` (invariant 2's
  documented tiebreaker); re-balance is a background job, never part of a user-facing
  mutation. Switching to rank strings later would be a constitution IV amendment.

### Package approvals (constitution IV)

- Backend: `Microsoft.OpenApi` 2.12.2 pin — ratifies the scaffold-time fix for the
  template's vulnerable transitive 2.0.0 (NU1903 vs the `--warnaserror` gate). No other
  backend packages.
- Frontend NEW: `@trpc/server`, `@trpc/client`, `@trpc/react-query` (v11),
  `@tanstack/react-query` (v5), `zod` — the BFF foundation (ADR-2).
- Explicitly deferred: shadcn/ui and its dependencies — the theme toggle is a plain
  button; primitives arrive with the first form/table feature that needs them.
  No `superjson` (health payload is plain JSON; add only when a feature needs rich
  serialization, via its plan).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md approved by the user 2026-08-27 ("please go
  ahead"); this plan precedes tasks.md and implementation.
- [x] **Source of Truth (II)**: No visual references for this feature (spec
  Assumptions); no conflicts among spec → plan → contracts.
- [x] **Repository Separation (III)**: Backend work lands only in `flowboard-api`,
  frontend only in `flowboard-web`; no mixing. The governance repo holds only docs.
- [x] **Architecture Consistency (IV)**: This IS the founding architecture record
  (bootstrap clause) — ADR-1..4 above; new packages approved above.
- [x] **Data Standards (V)**: No tables created. PK standard (`INT IDENTITY` + opaque
  `PublicId`) unaffected; first applied by the first data feature.
- [x] **Auditability (VI)**: No business entities in this feature.
- [x] **Domain Invariants (VII)**: Nothing in this plan touches
  `docs/domain/flowboard-invariants.md`; ADR-4 implements invariant 2's required
  decision.
- [x] **Security (VIII)**: Health endpoint is public liveness (spec Assumption) — no
  protected functionality exists yet; no secrets in source (backend URL via env var);
  theme script exception granted per rulebook §5.1 with fixed-literal constraint.
- [x] **External Integration Governance (IX)**: No external integrations. The
  FE↔BE health contract is documented in `contracts/health-api.md`.
- [x] **Performance Responsibility (X)**: One query per page load through the BFF; no
  polling; React Query defaults (no aggressive refetch) — trivial surface.
- [x] **Testing Requirements (XI)**: Health endpoint covered by a
  `WebApplicationFactory` integration test (FR-006). No business calculations exist.
- [x] **Human Review (XII)**: Phase completion requires AI review (compliance
  checklists) then human review before merge, per `docs/sdlc/review-process.md`.
- [x] **Controlled Delivery (XIII)**: Two phases (A backend, B frontend), each gated by
  the user; no unrelated changes — scaffold repos are otherwise untouched.

## Project Structure

### Documentation (this feature)

```text
specs/001-solution-scaffold/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── health-api.md    # Phase 1 output
└── tasks.md             # /speckit.tasks output (next step)
```

No `data-model.md`: the feature involves no data (FR-007).

### Source Code (both nested repos)

```text
flowboard-api/
├── src/Flowboard.Api/
│   ├── Program.cs                      # composition root; maps endpoint groups
│   ├── Endpoints/
│   │   └── HealthEndpoints.cs          # GET /v1/health (ADR-1 shape)
│   └── Services/
│       └── HealthService.cs            # thin service returning status + version
└── tests/Flowboard.Api.Tests/
    └── HealthEndpointTests.cs          # WebApplicationFactory integration test

flowboard-web/
└── src/
    ├── app/
    │   ├── layout.tsx                  # shell chrome + theme bootstrap script (ADR-3)
    │   ├── page.tsx                    # home: product name + backend status
    │   └── api/trpc/[trpc]/route.ts    # tRPC route handler
    ├── server/api/
    │   ├── root.ts                     # appRouter
    │   ├── trpc.ts                     # init; publicProcedure only (ADR-2)
    │   └── routers/health.ts           # health.status procedure
    ├── lib/
    │   ├── api/health-client.ts        # server-only fetch to FLOWBOARD_API_URL
    │   ├── trpc/client.tsx             # tRPC React client + QueryClient provider
    │   └── theme/theme-context.tsx     # theme state, localStorage persistence
    ├── components/
    │   ├── layout/top-bar.tsx          # product name + theme toggle slot
    │   └── shell/
    │       ├── backend-status.tsx      # loading / ok / error states (FR-004)
    │       └── theme-toggle.tsx        # ◐ toggle (FR-005)
    └── styles/globals.css              # moved from app/globals.css per rulebook shape
```

**Structure Decision**: two nested repos per constitution III; backend stays a single
project (ADR-1); frontend adopts the rulebook's project shape now (`server/api`,
`lib/api`, `lib/trpc`, `components/...`, `styles/`) so later features extend rather
than restructure. `globals.css` moves to `src/styles/` to match the binding rulebook.

## Implementation Phases (constitution XIII)

- **Phase A — backend health slice**: `HealthEndpoints` + `HealthService` + integration
  test. Ends: user runs backend gate (`dotnet build --warnaserror && dotnet test`),
  confirms exit 0; AI review vs backend compliance checklist; commit.
- **Phase B — frontend shell slice**: tRPC foundation, health router + client, shell
  page, backend-status states, theme system. Ends: user runs frontend gate
  (`npm run lint && npm run build`), confirms exit 0; AI review vs frontend compliance
  checklist; commit. Then human PR review → merge (governance + both repos).

## Complexity Tracking

No constitution violations to justify. (New packages and the theme-script exception are
approved through the designated mechanisms above, not exceptions.)
