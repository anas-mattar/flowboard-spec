# Tasks: Solution Scaffold

**Input**: Design documents from `/specs/001-solution-scaffold/`
**Prerequisites**: plan.md, spec.md, research.md, contracts/health-api.md, quickstart.md

**Tests**: Included for the backend health endpoint only — explicitly required by
FR-006. No frontend test runner exists in this feature (plan, research R-5).

**Organization**: Tasks are grouped by user story. Delivery gating follows the plan's
two phases (constitution XIII): **Phase A** = backend tasks (T001–T003), certified by
the user-run backend gate; **Phase B** = frontend tasks (T004–T017), certified by the
user-run frontend gate. See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

## Phase 1: Setup (Shared Infrastructure)

No setup tasks. Both repos exist as gate-green scaffolds (adoption step 3, certified
2026-08-27); frontend package installation is the first Phase B task (T004) because
Phase A must ship and gate first.

## Phase 2: Foundational (Blocking Prerequisites)

No foundational tasks beyond the existing scaffolds. The tRPC foundation (T007–T008)
is US1's frontend slice — later features inherit it, but nothing in this feature blocks
on it except US1/US3 frontend work.

---

## Phase 3: User Story 1 - See the system alive end-to-end (Priority: P1) 🎯 MVP

**Goal**: Backend answers `GET /v1/health` per `contracts/health-api.md`; the web app's
home page shows the FlowBoard name and the backend status through the tRPC BFF.

**Independent Test**: quickstart.md §1–§3 row US1 — start both apps, open the home
page, see product name + healthy status within 5 s; `curl /v1/health` returns the
contract payload; backend integration test passes.

### Backend (delivery Phase A)

- [X] T001 [US1] Implement `HealthService` returning status/service/version/timestampUtc in flowboard-api/src/Flowboard.Api/Services/HealthService.cs (cite contracts/health-api.md in a top comment)
- [X] T002 [US1] Implement `HealthEndpoints` static class (`MapHealthEndpoints`, `MapGroup("/v1/health")`, thin handler → HealthService, `.WithTags("Health")`, anonymous access) in flowboard-api/src/Flowboard.Api/Endpoints/HealthEndpoints.cs; register in flowboard-api/src/Flowboard.Api/Program.cs and delete the template's weatherforecast sample; expose `public partial class Program` for test hosting
- [X] T003 [US1] Add `Microsoft.AspNetCore.Mvc.Testing` to flowboard-api/tests/Flowboard.Api.Tests/Flowboard.Api.Tests.csproj (plan-approved) and write `WebApplicationFactory` integration test asserting 200 + contract payload shape in flowboard-api/tests/Flowboard.Api.Tests/HealthEndpointTests.cs; remove the placeholder UnitTest1.cs

**Checkpoint — Phase A gate**: STOP. User runs
`dotnet build --warnaserror && dotnet test` in flowboard-api and confirms EXIT 0.
AI review against `docs/rulebooks/backend-compliance-checklist.md`, result recorded in
the phase review notes. Commit Phase A. Only then start T004.

### Frontend (delivery Phase B)

- [X] T004 [US1] Install plan-approved packages in flowboard-web: `@trpc/server@^11 @trpc/client@^11 @trpc/react-query@^11 @tanstack/react-query@^5 zod` (updates package.json + package-lock.json)
- [X] T005 [P] [US1] Move flowboard-web/src/app/globals.css → flowboard-web/src/styles/globals.css and update the import in flowboard-web/src/app/layout.tsx (rulebook project shape)
- [X] T006 [P] [US1] Create flowboard-web/.env.example with `FLOWBOARD_API_URL=http://localhost:5111` and a comment that developers copy it to .env.local (research R-4)
- [X] T007 [US1] Create tRPC foundation: init + `publicProcedure` in flowboard-web/src/server/api/trpc.ts, `appRouter` in flowboard-web/src/server/api/root.ts, fetch-adapter route handler in flowboard-web/src/app/api/trpc/[trpc]/route.ts (ADR-2; publicProcedure only until 002)
- [X] T008 [US1] Create tRPC React client + QueryClient provider in flowboard-web/src/lib/trpc/client.tsx and wrap the app in flowboard-web/src/app/layout.tsx
- [X] T009 [P] [US1] Create server-only health client (reads `FLOWBOARD_API_URL`, 5 s timeout, cite contracts/health-api.md) in flowboard-web/src/lib/api/health-client.ts
- [X] T010 [US1] Create `health.status` query procedure validating the upstream payload with a Zod schema mirroring the contract in flowboard-web/src/server/api/routers/health.ts; register in root.ts
- [X] T011 [US1] Create `BackendStatus` client component with loading / healthy / unavailable states (visually + programmatically distinct, FR-004) using `trpc.health.status` in flowboard-web/src/components/shell/backend-status.tsx
- [X] T012 [US1] Create top bar (FlowBoard product name + slot for theme toggle) in flowboard-web/src/components/layout/top-bar.tsx and compose the home page (top bar + BackendStatus) in flowboard-web/src/app/page.tsx, replacing the create-next-app placeholder

**Checkpoint**: US1 verifiable end-to-end per quickstart §3 row US1.

---

## Phase 4: User Story 2 - Switch between light and dark theme (Priority: P2)

**Goal**: Theme toggle switches the whole page instantly, persists per browser, renders
the stored choice from first paint with no flash.

**Independent Test**: quickstart.md §3 row US2 — toggle, reload, observe persistence
and no wrong-theme flash; first visit follows OS preference.

### Implementation for User Story 2

- [X] T013 [US2] Add Tailwind v4 dark variant keyed to the `dark` class (`@custom-variant dark`) and base light/dark theme variables in flowboard-web/src/styles/globals.css (research R-3)
- [X] T014 [US2] Create theme context (reads localStorage, toggles `dark` class on `<html>`, persists choice, defaults to `matchMedia` system preference) in flowboard-web/src/lib/theme/theme-context.tsx
- [X] T015 [US2] Add the fixed-literal theme bootstrap inline script + `suppressHydrationWarning` to flowboard-web/src/app/layout.tsx (ADR-3 / security rulebook §5.1 — script body MUST stay a fixed string literal) and create the toggle button wired into the top bar in flowboard-web/src/components/shell/theme-toggle.tsx

**Checkpoint**: US1 and US2 both work; page styled correctly in both themes.

---

## Phase 5: User Story 3 - Backend unavailable is visible, not silent (Priority: P3)

**Goal**: With the backend stopped, the shell still renders and the status area shows
an explicit error state — never blank, never stuck loading, never fake-healthy.

**Independent Test**: quickstart.md §3 row US3 — stop the backend, reload, observe the
distinct unavailable state while name + toggle still render.

### Implementation for User Story 3

- [X] T016 [US3] Harden the unavailable path: health client maps network failure/timeout/non-200/bad payload to a typed failure (never throws raw provider errors to the page) in flowboard-web/src/lib/api/health-client.ts and flowboard-web/src/server/api/routers/health.ts (edge cases: slow response stays loading until the 5 s timeout; unexpected payload → error, never healthy)
- [X] T017 [US3] Verify shell isolation: page.tsx renders top bar and theme toggle regardless of query outcome; error state carries a distinguishing role/test-id and non-color cue in flowboard-web/src/components/shell/backend-status.tsx

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0. AI review against
`docs/rulebooks/frontend-compliance-checklist.md`, result recorded in the phase review
notes. Commit Phase B.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T018 Walk quickstart.md end-to-end (both apps running; all four verification rows) and fix any doc drift in specs/001-solution-scaffold/quickstart.md
- [X] T019 Write the phase review notes (backend + frontend compliance checklist results, gate evidence) in specs/001-solution-scaffold/review-notes.md per docs/sdlc/review-process.md, then hand to human PR review; on merge, set roadmap row 001 → shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Phase A — backend | T001–T003 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend | T004–T017 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T018–T019 | both gates re-run at merge time |

## Dependencies & Execution Order

- T001 → T002 → T003 (service → endpoint → test). Phase A gate blocks everything after.
- T004 blocks T007–T011 (packages first). T005, T006 parallel with T004.
- T007 → T008 → T010 → T011 → T012 (foundation → client → router → component → page);
  T009 parallel with T007/T008, needed by T010.
- US2 (T013–T015) depends only on T005 (globals.css location) and T012 (top bar slot) —
  independent of tRPC.
- US3 (T016–T017) refines US1 files; runs after T011/T012.
- T018–T019 last.

## Parallel Opportunities

- After T004: T005 + T006 + T009 in parallel.
- US2 (T013–T014) can proceed in parallel with US1 frontend tasks T007–T011 (different
  files), converging at T015 (top bar wiring after T012).

## Implementation Strategy

MVP = US1 alone (both gates). US2/US3 land inside the same Phase B commit window but
each is independently verifiable per its quickstart row. One phase at a time; no
unrelated changes; the scaffold repos are otherwise untouched.
