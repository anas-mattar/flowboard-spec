# Frontend Rules

This file summarizes frontend architecture rules from the uploaded `CLAUDE.md`, `AGENTS.md`, `frontend-forms.md`, and `frontend-tables.md`.

> **MANDATORY**: every frontend phase must pass
> `docs/frontend/frontend-compliance-checklist.md` before it is marked complete.
> The checklist is part of Definition of Done item 5 (AI review).

## Stack

- Next.js 16 with App Router.
- TypeScript strict mode.
- tRPC API layer.
- NextAuth with Azure AD where the project uses it.
- Redux Toolkit + React Query where already used.
- Tailwind CSS v4 + shadcn/ui where already used.
- Yarn 4.12.0 when declared in `packageManager`.

## Project Shape

Authoritative shape for `fms-frontend` (codified 2026-06-12, feature 008):

```text
fms-frontend/
  src/
    app/                  # App Router pages/layouts
    components/
      ui/                 # primitives (shadcn/ui style)
      forms/              # ALL data-entry forms (Rule F8d)
      tables/
        base/             # BaseDataTable + QueryDataTable
        {feature}-tables/ # feature table folders (Rule F11c)
      layout/             # app shell, header, nav
      <feature>/          # feature-scoped domain components (non-form, non-table)
    server/
      api/
        root.ts
        trpc.ts
        routers/<feature>/
    lib/
      api/                # server-only backend fetch wrappers (*-client.ts)
      trpc/               # tRPC React client (exports `trpc`)
      auth/               # session/current-user helpers
      <feature>/          # schemas.ts + feature helpers
    styles/               # globals.css (theme CSS variables)
    types/                # ambient/global TypeScript shapes
```

Notes:

- Zod schemas are **feature-scoped**: `lib/<feature>/schemas.ts`. A top-level
  `schema/` directory is NOT used in this project.
- The tRPC React client lives at `lib/trpc/client.tsx`, not a top-level `trpc/`.

## App Router Rules

- Use `app/[route]/page.tsx` for pages.
- Use `layout.tsx` for section layout.
- Use dynamic route folders like `[code]`.
- Server Components by default.
- Add `'use client'` only when using state, effects, browser APIs, event handlers, React Hook Form, tRPC client hooks, or Redux hooks.

## Component Rules

- File names use kebab-case.
- Exported components use PascalCase.
- Define props interfaces above components.
- Compose existing components from `components/ui/`.
- Do not invent duplicate primitives.
- Do not introduce a new UI library without approval in `plan.md`.

## Data Flow

Standard project flow:

```text
Browser
 -> Next.js App Router page
 -> tRPC procedure
 -> backend API fetch wrapper
 -> .NET backend
 -> database/external services
```

Rules:
- UI must not call backend URLs directly.
- Use `trpc.<router>.<procedure>` from `@/lib/trpc/client` on the client.
- Use server tRPC caller where project pattern supports it.
- tRPC procedures call the existing backend fetch wrappers in `lib/api/*-client.ts`.
- Prisma in frontend is only for auth/session/reporting tables when the existing project uses it.
- Business entities live in the backend API unless project plan says otherwise.

## Forms

Forms must follow `docs/frontend/frontend-forms.md`.

Key rules:
- React Hook Form.
- Zod resolver.
- shadcn/ui Form components.
- Sonner toast.
- tRPC mutations.
- Forms live in `components/forms/`.
- Schemas live in `lib/<feature>/schemas.ts`.
- Dual create/update mode through `data` prop (where the entity supports both).

## Tables

Tables must follow `docs/frontend/frontend-tables.md`.

Key rules:
- Use `QueryDataTable` for server-paged lists; `BaseDataTable` alone is allowed
  only for matrix-style grids with no server paging (see `frontend-tables.md`).
- Do not duplicate pagination/search/sort/URL state logic.
- Feature table folder contains `table.tsx`, `columns.tsx`, and `cell-action.tsx`
  (`cell-action.tsx` only when rows have actions).
- Columns live in `columns.tsx`.
- Actions column is last.
- Selection column is first when used.

## State

- Use Redux Toolkit for global UI/session state only when already present.
- Use tRPC/React Query for server state.
- Use React Hook Form for form state.
- Do not duplicate server state in Redux.
- Invalidate/refetch after mutations.

## Auth

- Server pages should check session using the existing auth helper.
- Client components use `useSession()` only when needed.
- Permission data should follow the existing session/Redux pattern.
- Protected writes must use protected tRPC procedures.

## Styling

- Use Tailwind utilities.
- Use the project `cn()` helper when combining classes.
- Follow existing CSS variables and theme.
- Do not invent colors, spacing, or layout when screenshots exist.
- Follow mobile-first responsive design.

## Types and Schemas

- `types/` holds ambient/global TypeScript shapes (e.g. `next-auth.d.ts`).
- `lib/<feature>/schemas.ts` holds Zod schemas and their inferred types.
- Prefer `z.infer` for form data.
- Avoid `any`.
- Keep request and response types explicit.

## Forbidden

- Inline table columns in page files.
- Inline large Zod schemas in forms.
- Direct backend fetches from UI components.
- New UI library without approved plan.
- Duplicated form/table boilerplate.
- `alert()` for production flows.
- Hiding validation or API errors.
