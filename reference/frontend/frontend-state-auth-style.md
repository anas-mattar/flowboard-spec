# Frontend State, Auth, and Style Rules

## State

Use the right state owner:
- React local state: small component UI state.
- React Hook Form: form state.
- tRPC/React Query: server state.
- Redux Toolkit: global UI/session/permission state.

Do not store backend list data in Redux unless the existing project already does so for a clear reason.

## Redux

Redux is **not used** in `fms-frontend`. Global session/permission state lives in
`CurrentUserContext` (`lib/auth/current-user-context.tsx`); scope/theme use React
Context (`lib/legal-entities/scope-context`, `lib/theme/`). Do not introduce Redux
without approval in `plan.md`.

When Redux is used (other projects):
- Store lives in `lib/store.ts`.
- Slices live in `lib/features/`.
- Use typed hooks.
- Do not dispatch from server components.

## Auth

- NextAuth handles session.
- Azure AD / Entra ID is used where configured.
- Server pages should redirect unauthenticated users.
- Client components should render permission-safe UI.
- Permissions must follow existing session/Redux pattern.

## Styling

Use:
- Tailwind CSS
- shadcn/ui primitives
- `cn()` helper
- Existing theme variables

Do not:
- Add new design system.
- Hardcode random colors.
- Replace existing components.
- Break screenshot layout.

## UI Components

- `components/ui/` contains primitives.
- Domain components should compose primitives.
- Data-entry forms go to `components/forms/` (Rule F8d).
- Data tables go to `components/tables/{feature}-tables/` over the shared base in
  `components/tables/base/` (Rule F11c).
- Other feature-scoped domain components (boards, trees, panels, modal shells)
  go to `components/<feature>/` — the established fms-frontend convention.
- Dropdowns shared across features go to `components/dropdowns/`.
