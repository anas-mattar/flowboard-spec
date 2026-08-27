# Research — 001 Solution Scaffold

No `NEEDS CLARIFICATION` markers existed in the Technical Context; research resolved
the implementation-approach choices below.

## R-1: Health endpoint — custom minimal endpoint vs ASP.NET Core HealthChecks middleware

- **Decision**: hand-rolled minimal-API endpoint group (`HealthEndpoints` +
  `HealthService`).
- **Rationale**: the built-in `AddHealthChecks`/`MapHealthChecks` middleware returns
  `text/plain "Healthy"` by default and lives outside the endpoint-group shape; this
  feature's whole point is to inaugurate the ADR-1 pattern (endpoint group → thin
  service) with a versioned JSON contract (`/v1/health`). No packages needed either way.
- **Alternatives considered**: `MapHealthChecks` with a custom JSON response writer —
  more code than the endpoint it replaces, and it bypasses the architecture shape the
  scaffold exists to establish. Revisit if later ops needs (liveness vs readiness
  probes, dependency checks) justify the middleware.

## R-2: tRPC version and packages

- **Decision**: tRPC v11 (`@trpc/server`, `@trpc/client`, `@trpc/react-query`) +
  `@tanstack/react-query` v5 + `zod`, wired through a Next.js App Router route handler
  (`app/api/trpc/[trpc]/route.ts`) with the fetch adapter.
- **Rationale**: v11 is the current stable line and the first with first-class React 19
  / App Router support; `@trpc/react-query` is the documented client-hooks package for
  v11. Zod is already the rulebook's validation standard.
- **Alternatives considered**: `@trpc/next` pages-router helpers (legacy, wrong router
  model); TanStack Query alone over REST (loses end-to-end types and violates ADR-2's
  chosen lane); server actions as the transport (not the rulebook's standard, weaker
  read-query story).

## R-3: Theme mechanics under Tailwind CSS v4

- **Decision**: dark mode keyed to a `dark` class on `<html>` via Tailwind v4's
  `@custom-variant dark (&:where(.dark, .dark *))` in `globals.css`; a fixed-literal
  inline script in `layout.tsx` reads `localStorage` (fallback: `matchMedia`) and sets
  the class before first paint; a React context owns toggling and persistence;
  `suppressHydrationWarning` on `<html>` because the class differs from server output.
- **Rationale**: Tailwind v4 defaults dark: to `prefers-color-scheme`; the product needs
  a user override (X-02, FR-005), which requires the class strategy + pre-paint script —
  exactly the §5.1 exception ADR-3 approves.
- **Alternatives considered**: `next-themes` package (does the same thing; a dependency
  the plan would have to approve for ~40 lines of code — rejected, keep it first-party);
  cookie-based server-rendered theme (adds a cookie round-trip and couples theme to
  requests; localStorage is the rulebook-sanctioned slot for this preference).

## R-4: Backend URL configuration for the BFF

- **Decision**: `FLOWBOARD_API_URL` server-only environment variable, read inside
  `lib/api/health-client.ts`; `.env.example` committed with the local default
  (`http://localhost:5111` — the scaffold's launchSettings HTTP port), real `.env*`
  ignored.
- **Rationale**: rulebook Data Flow rule — no `NEXT_PUBLIC*` backend URLs; the
  create-next-app `.gitignore` already excludes `.env*` (known failure mode in
  CLAUDE.md), so the example file documents the contract.
- **Alternatives considered**: hardcoded localhost (breaks the moment environments
  differ; violates configuration rules); `NEXT_PUBLIC_API_URL` (exposes the backend to
  the browser — violates ADR-2).

## R-5: Frontend test runner

- **Decision**: none in this feature; the frontend gate stays `npm run lint && npm run
  build`.
- **Rationale**: FR-006 requires an automated proof for the health endpoint (backend
  integration test). The frontend surface is three states of one component; the gate's
  type check + lint + build covers the scaffold risk. Introducing Vitest/Playwright is
  a package decision belonging to the first feature with real frontend logic to test
  (`docs/sdlc/gate-command.md` already anticipates `npm test` joining later).
- **Alternatives considered**: add Vitest now (speculative package against
  constitution IV's spirit); reuse the prototype's Playwright smoke (tests the
  prototype, not the product).
