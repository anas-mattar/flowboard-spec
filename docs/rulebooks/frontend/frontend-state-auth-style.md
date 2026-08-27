# Frontend State, Auth, and Style Rules

## State

Use the right state owner:

- React local state: small component UI state (open popovers, drag hover).
- React Hook Form: form state.
- tRPC/React Query: server state (boards, lists, cards, members).
- React Context: session, theme, and board-scope state.

Redux is **not used** in `flowboard-web` and MUST NOT be introduced without approval in
`plan.md`. Global session state lives in a current-user context under **lib/auth/**;
theme uses its own context under **lib/theme/**.

Do not store backend list data in context — server state stays in tRPC/React Query and
is invalidated/refetched after mutations.

## Auth

- The session provider decided in feature 002's `plan.md` handles session (NextAuth is
  the default candidate).
- Server pages should redirect unauthenticated users.
- Client components should render permission-safe UI (spec §6).
- Protected writes go through protected tRPC procedures backed by backend enforcement
  (domain invariant 5).

## Styling

Use:

- Tailwind CSS v4
- shadcn/ui primitives
- `cn()` helper
- Existing theme variables (**styles/globals.css**); both themes must work (X-02)

Do not:

- Add a new design system.
- Hardcode random colors.
- Replace existing components.
- Break screenshot layout — the prototype and per-feature captures are rung-1 truth.

## UI Components

- **components/ui** contains primitives.
- Domain components should compose primitives.
- Data-entry forms go to **components/forms** (Rule F8d).
- Data tables go to **components/tables/{feature}-tables/** over the shared base in
  **components/tables/base** (Rule F11c).
- Other feature-scoped domain components (board canvas, lists, card fronts, modal
  shells, filter bar) go to **components/\<feature\>/** — the established convention.
- Dropdowns shared across features go to **components/dropdowns**.
