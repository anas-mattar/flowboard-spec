# Frontend Compliance Checklist (MANDATORY)

Every frontend phase MUST pass this checklist before it is marked complete. It is
part of Definition of Done item 5 (AI review) — see
`docs/sdlc/definition-of-done.md`. The AI completes it and records the result in
the phase's review notes; any FAIL blocks the phase.

> Adopted 2026-06-12 (feature 008). Surfaces built before feature 008 are brought
> into compliance by feature 008 itself; this checklist applies to ALL new work
> immediately.

## Structure

- [ ] New files follow the Project Shape in `docs/frontend/frontend-rules.md`
      (`src/` layout; schemas in `lib/<feature>/schemas.ts`; tRPC client from
      `@/lib/trpc/client`).
- [ ] Component files are kebab-case; exported components PascalCase; props
      interfaces defined above components.
- [ ] `'use client'` only where state/effects/hooks/browser APIs/event handlers
      require it.

## Data Flow

- [ ] No direct backend fetches from UI code (no `fetch(<backend URL>)`, no axios,
      no `NEXT_PUBLIC_API*` reads in components/pages).
- [ ] Client data access uses `trpc.<router>.<procedure>` hooks; mutations
      invalidate/refetch affected queries via `trpc.useUtils()`.
- [ ] tRPC procedures validate input with Zod and call the feature's server-only
      client in `lib/api/*-client.ts`.

## Forms (`docs/frontend/frontend-forms.md`)

- [ ] Every data-entry form uses React Hook Form + `zodResolver` — no `useState`
      field state, no manual validation guards.
- [ ] Form UI uses shadcn/ui `Form` components; required fields show the red `*`;
      errors render via `<FormMessage />`.
- [ ] Success/error feedback uses Sonner `toast` — no `alert()`, no silently
      swallowed errors.
- [ ] Dual create/update via `data` prop where the entity supports both.
- [ ] Forms live in `components/forms/`; schemas in `lib/<feature>/schemas.ts`.

## Tables (`docs/frontend/frontend-tables.md`)

- [ ] No hand-rolled `<table>` for data lists. Server-paged lists compose
      `QueryDataTable`; matrix grids may compose `BaseDataTable` directly.
- [ ] Columns live in `columns.tsx` (never inline in pages/components);
      `id: 'actions'` last; `id: 'select'` first when present.
- [ ] Feature tables live in `components/tables/{feature}-tables/`.
- [ ] Server-paged lists drive page/limit/search/sortBy/sortDir from URL params.

## State, Auth, Styling

- [ ] Server state in tRPC/React Query only — not duplicated into context/Redux.
- [ ] Permission gating uses `useHasPermission`/`RequirePermission` as UX hints;
      writes rely on backend enforcement.
- [ ] **No second legal-entity dropdown** (feature 023, FR-011). Reporting/legal-entity
      scope comes exclusively from the global header selector (`useGlobalScope()`); no
      feature page renders its own legal-entity `<select>`/combobox. Forms display the
      active entity read-only ("from top selector") and use the shared single-entity
      guard (`RequireSingleEntity` / `SelectEntityNotice`) when a single entity is required.
- [ ] Tailwind utilities + `cn()`; theme CSS variables from `styles/globals.css`;
      no hardcoded hex colors; layout matches screenshots when they exist.

## Security & Performance

- [ ] No secrets or backend tokens reach the client bundle; no auth data in
      `localStorage`.
- [ ] No new `dangerouslySetInnerHTML` with dynamic content.
- [ ] Lists are paginated or justified-bounded; loading/empty/error states exist;
      search inputs debounced.
- [ ] No new packages beyond those approved in the feature's `plan.md`.

## Process

- [ ] Only the approved phase's files changed (`git diff --stat` reviewed).
- [ ] Gate run by the user with confirmed exit code 0.
