# Frontend Rules — FlowBoard

> **Binding**: this rulebook is enforced through the frontend tier's compliance checklist
> (`docs/rulebooks/frontend-compliance-checklist.md`, Definition of Done item 5): the
> checklist asserts, this rulebook explains. Visual references (rung 1 of Source of Truth)
> outrank it: never invent a layout when screenshots exist, and UI phases with visual
> references run the Visual Compliance Loop (`docs/sdlc/review-process.md`). Detailed shop
> guidance: `reference/frontend/` (read its README first).

## Structure

- Code layout (shop project shape, confirmed in **specs/001-solution-scaffold/plan.md**):

  ```text
  flowboard-web/src/
    app/                  # App Router pages/layouts; server components by default
    components/
      ui/                 # primitives (shadcn/ui style)
      forms/              # ALL data-entry forms
      layout/             # app shell, sidebar, top bar
      <feature>/          # feature-scoped domain components (board canvas, lists, cards, modals)
    server/api/           # tRPC: root.ts, trpc.ts, routers/<feature>/
    lib/
      api/                # server-only backend fetch wrappers (*-client.ts)
      trpc/               # tRPC React client (exports `trpc`)
      auth/               # session/current-user helpers
      <feature>/          # schemas.ts + feature helpers
    styles/               # globals.css (theme CSS variables)
    types/                # ambient/global TypeScript shapes
  ```

- File names kebab-case; exported components PascalCase; props interfaces above
  components; `'use client'` only where state/effects/hooks/browser APIs require it.
- New routes, folders, or shared components follow this layout; new top-level structure
  requires approval in the feature's `plan.md`.

## Data Flow

- ALL backend calls MUST go through tRPC procedures (**server/api/routers/**) that call the
  feature's server-only client in `lib/api/*-client.ts`; UI components MUST NOT call the
  backend directly — no `fetch(<backend URL>)`, no axios, no `NEXT_PUBLIC_API*` reads in
  components. **Why**: one place for base URL, auth, timeouts, and error mapping; the
  browser never holds the backend token.
- Every procedure that takes input MUST validate it with Zod (`.input(schema)`); schemas
  live in `lib/<feature>/schemas.ts`. Client data access uses `trpc.<router>.<procedure>`
  hooks; mutations invalidate/refetch affected queries.
- Realtime is the ONE sanctioned exception to the BFF path: the SignalR client connects
  to the board channel directly with a short-lived scoped token. Its wiring is decided in
  feature 008's `plan.md`; until 008, no realtime code ships at all.
- Response types MUST mirror the feature's contract (the feature's `contracts/`
  directory) and cite it in a comment. **Why**: the citation makes rung-checking possible.
- Derived values the backend owns (positions after a move, WIP counts, due-date buckets'
  server side) MUST come from the backend; the frontend renders them and MUST NOT
  re-compute them for storage — optimistic UI updates are display-only and reconcile with
  the server response. **Why**: two implementations of one formula always diverge.

## UI States

- Every data surface MUST implement all states that apply: loading, empty,
  error/unavailable, and populated — and the error state MUST be visually and
  programmatically distinguishable from empty. A board filtered to nothing shows the
  explicit "No cards match the filter" empty state (spec F-04), never a blank list.
  **Why**: an error rendered as an empty list is silent data loss to the user.

## Forms & Input

- React Hook Form + `zodResolver` for ALL data entry — manual `useState` field state and
  hand-rolled validation guards are prohibited. Form UI composes shadcn/ui `Form`
  components; errors render via `<FormMessage />`; success/error feedback uses Sonner
  `toast` — `alert()` is prohibited. Forms live in **components/forms/**.
- Inline edits (board/list/card titles, the card composer) follow the prototype's
  interaction contract exactly: Enter commits, Escape cancels, blur commits titles, the
  card composer stays open after Enter (C-01). **Why**: the prototype is rung-1 truth for
  interaction, not just pixels.
- Detail pack: `reference/frontend/frontend-forms.md`.

## Accessibility (spec §8 — WCAG 2.2 AA)

- Every drag interaction MUST have a keyboard/menu equivalent (C-11) in the same phase —
  not deferred. Focus MUST be trapped in modals and restored on close. Color MUST never be
  the only carrier of meaning (due-date badges carry text). `/` focuses search, `Esc`
  closes modals/popovers (X-03).
  **Why**: §8 makes AA a requirement, not a nice-to-have; retrofitting focus management is
  costlier than building it in.

## Styling

- Tailwind CSS v4 utilities + shadcn/ui primitives + the `cn()` helper; theme CSS
  variables in **styles/globals.css**; light/dark theme switch applies app-wide (X-02).
  Hardcoded hex colors are prohibited; no new UI library or design system without
  approval in `plan.md`.
- When screenshots exist, layout matches them — deviations go in the Visual Compliance
  Loop's deviation table, never silently.

## State

- Server state lives in tRPC/React Query ONLY — never duplicated into context or a store.
  Session/theme use React Context. Redux MUST NOT be introduced (shop precedent:
  `fms-frontend` runs without it). Form state lives in React Hook Form.

## Security

- Server-only secrets and env vars MUST NOT reach client-side code or be exposed through
  public-prefixed variables; no auth tokens in `localStorage`. **Why**: everything shipped
  to the browser is public.
- `dangerouslySetInnerHTML` with dynamic content is prohibited without plan approval +
  sanitization; card descriptions (C-05 rich text) render through a sanitizing renderer
  decided in 004's `plan.md`. Frontend permission gating (spec §6 — hide/disable what the
  role cannot do) is UX only; the backend remains authoritative (invariant 5).
- Detail pack: `reference/frontend/frontend-security.md`.
