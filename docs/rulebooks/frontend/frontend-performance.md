# Frontend Performance Rules

## Purpose

This file defines mandatory frontend performance rules for FlowBoard.

FlowBoard's core screen is a live board that must hold 60 fps drag interaction and
hydrate a 20-list / 1,000-card board in under 1.5 s (spec §8). Frontend performance
must be considered during implementation, not after users complain.

## 1. General Principles

- Server Components by default.
- Client Components only when needed.
- Avoid unnecessary global state.
- Avoid loading large datasets into the browser.
- Keep forms responsive.
- Keep tables paginated.
- Keep bundles small.
- Use loading, empty, and error states.

## 2. Server vs Client Components

Use Server Components for static page layout, server-side reads, and pages that do not
need interactivity.

Use Client Components only for the board canvas, drag & drop, forms, filters, modals,
dropdown interactions, table interactions, stateful UI, and browser APIs.

Do not add `'use client'` at the top of a large page unless required.

## 3. Data Loading

Do not fetch unnecessary data.

Use pagination, filtering, sorting, search, and backend projection. The board hydrates
in one call (spec §7) — do not add per-list or per-card follow-up queries for data the
hydration payload already carries.

Avoid loading all rows, loading full card details for card fronts, loading dropdowns
repeatedly, and duplicate API calls.

## 4. Board Canvas

- List bodies MUST virtualize beyond 150 cards (spec §8).
- Drag interaction must not trigger full-board re-renders: memoize card fronts, keep
  drag state local, and reconcile with the server response after drop (optimistic
  display only — frontend rulebook, Data Flow).
- Search is live-as-you-type (F-01): debounce input and filter over hydrated state;
  switch to the server search endpoint for large boards per its feature plan.

## 5. Tables

All large tables must use server-side pagination and follow
`docs/rulebooks/frontend/frontend-tables.md`.

Required:

- loading state
- empty state
- error state
- pagination
- search
- sorting
- filtering

Do not implement client-side pagination over thousands of rows.

## 6. Forms

Forms must avoid unnecessary re-renders.

Use React Hook Form patterns from `docs/rulebooks/frontend/frontend-forms.md`.

Rules:

- Keep form state inside React Hook Form.
- Use `watch()` carefully.
- Avoid expensive calculations on every keystroke.
- Debounce server-side validation/search fields when needed.
- Disable submit during submission.

## 7. Bundle Size

Avoid adding new packages.

If a new package is needed:

- it must be approved in `plan.md`
- explain why existing tools cannot solve it
- consider bundle impact

Use dynamic import for heavy optional components.

## 8. Rendering

Avoid rendering huge lists without pagination/virtualization, expensive calculations
inside JSX, unnecessary `useEffect`, and unstable callbacks passed to many children.

Consider memoized derived values when needed, stable query keys, and splitting heavy
components.

## 9. Images and Assets

- Optimize images.
- Avoid large uncompressed assets.
- Use appropriate formats.
- Lazy-load non-critical visuals.

## 10. Frontend Performance Review Checklist

Before completing a frontend phase, check:

- [ ] Are Client Components limited to where needed?
- [ ] Are tables server-paginated?
- [ ] Are large datasets avoided (board hydration payload excepted, per spec §7)?
- [ ] Do list bodies virtualize beyond 150 cards where the phase touches them?
- [ ] Are loading/empty/error states present?
- [ ] Are duplicate API calls avoided?
- [ ] Are heavy components lazy-loaded if needed?
- [ ] Are new packages approved?
- [ ] Is global state usage justified?
- [ ] Are forms responsive during input and submit?
