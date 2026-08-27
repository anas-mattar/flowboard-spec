# Frontend Compliance Checklist — MANDATORY

> **Binding**: This checklist is part of Definition of Done item 5
> (`docs/sdlc/definition-of-done.md`). The AI completes it for every phase touching the
> frontend tier and records the result in the phase's review notes. **Any FAIL blocks the
> phase.**
>
> **Adopted**: 2026-08-27, before feature 001 — no grandfathered code exists.

## Structure (`docs/rulebooks/frontend-rules.md`)

- [ ] New files follow the Project Shape (`src/` layout; schemas in
      `lib/<feature>/schemas.ts`; tRPC client from `@/lib/trpc/client`).
- [ ] Component files kebab-case; exported components PascalCase; props interfaces above
      components.
- [ ] `'use client'` only where state/effects/hooks/browser APIs/event handlers require it.

## Data Flow

- [ ] No direct backend fetches from UI code (no `fetch(<backend URL>)`, no axios, no
      `NEXT_PUBLIC_API*` reads in components/pages); realtime SignalR wiring appears only
      in feature 008+ per its approved plan.
- [ ] Client data access uses `trpc.<router>.<procedure>` hooks; mutations
      invalidate/refetch affected queries.
- [ ] tRPC procedures validate input with Zod and call the feature's server-only client
      in `lib/api/*-client.ts`.
- [ ] No client-side re-computation of backend-owned values for storage; optimistic
      updates reconcile with the server response.

## Forms (`docs/rulebooks/frontend-rules.md`)

- [ ] Every data-entry form uses React Hook Form + `zodResolver` — no `useState` field
      state, no manual validation guards.
- [ ] Form UI uses shadcn/ui `Form` components; errors render via `<FormMessage />`.
- [ ] Success/error feedback uses Sonner `toast` — no `alert()`, no silently swallowed
      errors (spec X-01: every state-changing action gives feedback).
- [ ] Inline edits match the prototype's contract: Enter commits, Escape cancels, card
      composer stays open after Enter (C-01).

## UI States & Accessibility

- [ ] Loading / empty / error / populated states exist for every new data surface; error
      is distinguishable from empty; filtered-to-nothing shows the explicit F-04 message.
- [ ] Every drag action shipped in this phase has its keyboard/menu equivalent (C-11);
      modals trap focus and restore it on close; color is never the only carrier of
      meaning.

## State, Styling

- [ ] Server state in tRPC/React Query only — not duplicated into context or a store; no
      Redux.
- [ ] Tailwind utilities + `cn()`; theme CSS variables from **styles/globals.css**; no
      hardcoded hex colors; both themes verified (X-02).
- [ ] Layout matches `specs/[feature]/screenshots/` when they exist; deviations are in
      the Visual Compliance Loop table, not silent.

## Security & Performance (`docs/rulebooks/frontend-rules.md`)

- [ ] No secrets or backend tokens reach the client bundle; no auth data in
      `localStorage`.
- [ ] No new `dangerouslySetInnerHTML` with dynamic content; rich-text rendering goes
      through the plan-approved sanitizer.
- [ ] Permission gating hides/disables what the role cannot do (spec §6) — as UX only;
      writes rely on backend enforcement.
- [ ] Lists are paginated or justified-bounded; search inputs debounced; card lists
      virtualize beyond 150 cards (spec §8) where the phase touches them.

## Process

- [ ] No new packages beyond those approved in the feature's `plan.md` (constitution IV).
- [ ] Only the approved phase's files changed (`git diff --stat` reviewed).
- [ ] Gate run by the user with confirmed exit code 0 (constitution XIII).
