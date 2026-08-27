# AI Code Review — 002 Auth & Workspaces — Phase B (Frontend)

**Reviewer**: Claude (Sonnet 5)
**Date**: 2026-08-27
**Branches**: flowboard-web `002-auth-workspaces` (uncommitted working tree)
**Scope reviewed**: All files touched by T040–T053 — NextAuth config/route handler,
server-only `auth-client.ts`/`board-members-client.ts`, `protectedProcedure` + the
`auth`/`boardMembers` tRPC routers, signup/login forms + pages, `SessionProvider` wiring,
top-bar identity/sign-out, `BoardMembersPanel`, the board page, the shadcn/ui foundation
added mid-phase (`components.json`, `components/ui/*`, `lib/utils.ts`), and
`src/types/next-auth.d.ts`.
**Feature contract**: Critical delivery (auth/authz). Frontend-only this phase; Phase A
(backend) already gated, reviewed, and merged to `main`. No packages beyond what's
approved (plan.md, amended mid-phase — see Findings). No schema/backend changes.

## Verdict

**APPROVE with follow-ups.** Every US1/US2/US3/US4/US5 frontend surface in tasks.md is
implemented against the Phase A contract: NextAuth Credentials sign-in/sign-up flow,
workspace identity + sign-out in the shell, and the board-membership panel with
role-gated admin controls. One real type-safety bug was caught and fixed before it ever
ran (F1); the mandatory forms stack had to be freshly installed and one library gap
worked around (F2, F3) — both are infrastructure additions, not workarounds of the
feature's own logic. Because this is a Critical feature, no agent-run gate exists to
confirm compilation — the diff has been read function-by-function against the actual
installed library type definitions (next-auth, `@auth/core`, `@trpc/server`, zod, shadcn)
rather than assumed from training data, precisely because this session cannot self-certify
with a build. Residual risk is concentrated in exactly that: the user-run gate is the
first real TypeScript compilation this code will see.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | `signup-form.tsx`/`login-form.tsx` implement contracts/auth-api.md's fields exactly (email/password/displayName, 10-char minimum mirroring backend R-10). `board-members-panel.tsx` implements every contracts/board-membership-api.md action (list/invite/revoke/remove) with the exact 201-vs-200 (new vs. role-updated-in-place) distinction preserved through `board-members-client.ts`. |
| Feature contract held (no unapproved package/architecture) | `git status --short` (below) matches T040–T053's file list exactly, plus the plan.md-amended shadcn/RHF/Sonner addition (user-confirmed, documented in plan.md's Package approvals). No other new dependency. |
| Constitution / domain invariants | See dedicated section below (Critical Delivery Addendum item 2). |
| Security (authn/authz, secrets, sensitive logging) | Backend JWT never reaches the browser: `auth-config.ts`'s `session()` callback explicitly omits `backendToken` from what's returned to `useSession()`/the client; verified by reading every tRPC procedure's return shape (`auth.ts`, `board-members.ts`) for an accidental token/credential leak — none found. The one place the raw token is read server-side (`app/api/trpc/[trpc]/route.ts`'s `createContext`, and `lib/auth/session.ts` for Server Components) uses `next-auth/jwt`'s `getToken()` directly against the request/cookies, never through the client-facing session. `NEXTAUTH_SECRET` is a real generated value in the gitignored `.env.local`, a placeholder in `.env.example`. |
| Scope guard (`git status --short` — only intended files) | See below — health endpoint, `BackendStatus`, `theme-toggle.tsx`, `theme-context.tsx` from 001 untouched. |
| Rollback safety | All additive: new routes, new components, new tRPC procedures. No existing route, component, or procedure was deleted; `top-bar.tsx` and `app/layout.tsx` were edited in place but only to add optional session-dependent UI (renders identically to before when there's no session). |

```text
$ git status --short   (flowboard-web, branch 002-auth-workspaces)
 M .env.example
 M package-lock.json
 M package.json
 M src/app/api/trpc/[trpc]/route.ts
 M src/app/layout.tsx
 M src/components/layout/top-bar.tsx
 M src/server/api/root.ts
 M src/server/api/trpc.ts
 M src/styles/globals.css
?? components.json
?? src/app/(auth)/
?? src/app/api/auth/
?? src/app/boards/
?? src/components/auth/
?? src/components/board-members/
?? src/components/layout/sign-out-button.tsx
?? src/components/ui/
?? src/lib/api/auth-client.ts
?? src/lib/api/board-members-client.ts
?? src/lib/auth/
?? src/lib/board-members/
?? src/lib/utils.ts
?? src/server/api/caller.ts
?? src/server/api/routers/auth.ts
?? src/server/api/routers/board-members.ts
?? src/types/
```

## Findings

### F1 — Module augmentation targeted the wrong module (would have silently no-opped) — RESOLVED

`next-auth`'s `User`/`Session` types are re-exports (`export type {...} from "@auth/core/types"`),
not local interface declarations. TypeScript's declaration-merging only augments the
module that *declares* an interface — `declare module "next-auth" { interface User {...} }`
would have compiled without error but never actually added `publicId`/`workspaceRole`/etc.
to the type the Credentials provider's `authorize()` and the `session()`/`jwt()` callbacks
actually see (confirmed by reading `node_modules/next-auth/index.d.ts` and
`@auth/core/providers/credentials.d.ts`'s real import source). This would not have failed
the build — `token.publicId` etc. would just have silently typed as `any`/`unknown` with
no compile error, and a later refactor could easily introduce a real bug with no type
safety net. Fixed by augmenting `@auth/core/types` and `@auth/core/jwt` directly in
`src/types/next-auth.d.ts`, which is where `User`/`Session`/`JWT` are actually declared.
*Action: none — fixed in this diff before any code depended on the (silently wrong)
augmentation.*

### F2 — shadcn CLI's "form" registry item is an empty stub in this installation — RESOLVED

`npx shadcn@latest add form` (CLI `4.19.0`, `radix-nova` preset/base `radix`) resolves
the item and reports success but writes no file — `npx shadcn@latest view form` confirms
the registry entry has no `files` array, only `{name: "form", type: "registry:ui"}`.
`react-hook-form`/`@hookform/resolvers` were also not installed by the "form" add (since
nothing was added). Fixed by installing `react-hook-form`/`@hookform/resolvers` directly
via npm and hand-authoring `components/ui/form.tsx` from the well-known, stable shadcn/ui
Form source (`Form`, `FormField`, `FormItem`, `FormLabel`, `FormControl`, `FormMessage`) —
the same public API `frontend-forms.md`'s F8a names — adapted only to import `Slot` from
this project's unified `radix-ui` package (matching `button.tsx`'s existing pattern) and
this project's own `Label`.
*Action: none — the resulting API surface matches F8a exactly; flagging as CONFIRM-worthy
only in that it's hand-authored rather than CLI-generated, should the CLI's registry gap
get fixed upstream later.*

### F3 — shadcn's default `sonner.tsx`/theme template assumed `next-themes` and replaced the existing color theme — RESOLVED

Two issues from `npx shadcn@latest init`: (1) the generated `components/ui/sonner.tsx`
imported `useTheme` from `next-themes`, a library this project does not use — 001 built
its own `ThemeProvider`/`useTheme` (ADR-3, `lib/theme/theme-context.tsx`) with a specific
class-toggle + bootstrap-script design frontend-rules.md requires stay the single
implementation. Fixed by rewriting `sonner.tsx` to import this project's own `useTheme`
instead, and removing `next-themes` as an unused dependency. (2) `init` rewrote
`globals.css`'s `--font-sans` to a self-referencing `var(--font-sans)` (dropping the
`--font-geist-sans` mapping), which would have silently fallen back to Arial — fixed by
restoring the Geist mapping. The rest of `init`'s theme rewrite (the full shadcn OKLCH
color token set: `--card`, `--popover`, `--primary`, etc.) was kept — the new UI
components need those tokens to render, and the `.dark` class selector convention this
project already uses is unchanged, so both themes still work (X-02) through the same
`ThemeProvider`.
*Action: none — both bugs fixed before commit; worth a quick visual check in the human
review pass since neither bug would throw at build time.*

### F4 — `BoardMembersPanel` is a plain list, not the shared base-table system — CONFIRM

`frontend-state-auth-style.md`/`frontend-tables.md` say tabular list screens should
compose a shared `components/tables/base` system (which does not exist in this scaffold
yet — another gap like F2, never needed before this feature). Judgment call: a single
board's membership is a short, unpaginated, unsearchable list (typically single digits to
low tens of people) — not the kind of "tabular list screen" those rules are aimed at
(pagination/search/sort/URL-state), and tasks.md's own T051 names the file
`board-members-panel.tsx`, not a `components/tables/board-members-tables/` path. Built as
a plain styled list instead of standing up a new shared table system from scratch (which
would be materially larger scope than this feature's plan.md approves). *Action: confirm
this interpretation is acceptable, or flag if a future admin-list feature should
retroactively justify building the shared table system now instead of later.*

## Constitution re-check (post-implementation)

- **I. Specification First** — PASS. Every page/component maps to a tasks.md item and
  cites its contract in a header comment.
- **II. Source of Truth Hierarchy** — PASS. plan.md documents no visual references exist
  for auth/signup/login (prototype stubs auth out) — no Visual Compliance Loop applies;
  pages follow the existing shell's Tailwind/shadcn styling.
- **III. Repository Separation** — PASS. All changes in `flowboard-web`; no backend files
  touched this phase.
- **IV. Architecture Consistency** — PASS with the plan.md amendment recorded for the
  shadcn/RHF/Sonner addition (Findings F2/F3; user-confirmed before implementation began).
- **V–VI. Data Standards / Auditability** — N/A this phase (no schema).
- **VII. Domain Invariants** — PASS, see item-by-item pass below.
- **VIII. Security** — PASS. See the Security evidence row above.
- **IX. External Integration Governance** — N/A.
- **X. Performance Responsibility** — PASS. `BoardMembersPanel` invalidates only its own
  query (`utils.boardMembers.list.invalidate({boardPublicId})`) after mutations, not a
  broader cache sweep.
- **XI. Testing Requirements** — **No automated frontend tests exist for this phase**
  (see Test coverage below) — flagged, not blocking: `docs/sdlc/gate-command.md` notes
  "`npm test` joins the frontend gate once the first test exists," meaning this repo has
  never had one yet at any phase (001 shipped with none either), not a regression
  introduced here.
- **XII. Human Review Requirement** — PENDING (this document + the human review that
  follows it).
- **XIII. Controlled Delivery** — PASS. Exactly T040–T053 implemented; Phase A untouched;
  Wrap-up (T054–T058) not started.

## Domain-invariant item-by-item pass (Critical Delivery Addendum item 2)

| # | Invariant | Applies? | Verdict | Evidence |
|---|---|---|---|---|
| 1 | Activity Is Append-Only | No | N/A | No activity/history concept in this feature. |
| 2 | Ordering Integrity | No | N/A | No ordering in this feature's UI. |
| 3 | WIP Limits Are Advisory | No | N/A | Not applicable to auth/membership UI. |
| 4 | Soft Delete, 30-Day Minimum Restorability | No | N/A | The frontend never deletes anything directly — `removeMember`/`revokeInvitation` are thin wrappers over the already-reviewed backend endpoints (Phase A); no new deletion semantics introduced here. |
| 5 | Permissions Are Enforced Server-Side | Yes | PASS | `BoardMembersPanel`'s `isAdmin` check (T052) only hides/shows buttons — every mutation (`invite`/`revokeInvitation`/`removeMember`) still calls the backend via `board-members.ts`'s protectedProcedures, which the backend re-authorizes through `BoardAccessService` regardless of what the UI attempted to hide (verified: the client sends the same request whether or not the button was visible — there is no separate "trusted" code path). `protectedProcedure` itself fails closed (`TRPCError UNAUTHORIZED`) when there's no session, so an unauthenticated caller can't reach any board-scoped procedure at all. |
| 6 | Optimistic Concurrency | No | N/A | No card/field edits in this feature. |
| 7 | Labels Are Board-Scoped | No | N/A | No labels in this feature. |
| 8 | Opaque Public Identifiers | Yes | PASS | Every client-side and server-side call uses `boardPublicId`/`userPublicId`/`invitationPublicId` (all `Guid`-shaped strings from the backend's own opaque identifiers) — grepped `board-members-client.ts`, `board-members.ts`, and `board-members-panel.tsx` for any numeric/internal id; none found. The dynamic route segment itself is named `[boardPublicId]`, not `[id]` or `[boardId]`. |

## Test coverage observed

**None added this phase.** `flowboard-web` has never had a test suite at any phase (001
shipped none; `docs/sdlc/gate-command.md` explicitly defers `npm test` joining the gate
until "the first test exists"). This feature's frontend logic (NextAuth callbacks, the
tRPC routers' error-code mapping, `BoardMembersPanel`'s admin-gating) is exercised only by
manual verification per `quickstart.md`'s US1–US5 rows, which the user should walk before
approving this phase — the backend equivalents of every one of these paths (auth
endpoints, board-membership endpoints, authorization) already have the 27 passing tests
from Phase A.

## Residual risk

**Concentrated in unverified compilation.** Per the Critical Delivery Addendum
(`docs/sdlc/gate-command.md`: "Critical features go further: agent-run gates are not
used at all"), no `npm run lint`/`npm run build` was run during this phase — every type
signature above was checked by reading the actual installed `.d.ts` files rather than
assumed, specifically to reduce this risk, but the first real TypeScript compilation of
this code is the gate the user is about to run. If it surfaces errors, they should be
mechanical (a wrong import path, a type mismatch) rather than logic bugs, since the logic
itself traces directly to contracts/auth-api.md and contracts/board-membership-api.md.
Recommend: run the gate, and if `npm run dev` is available afterward, manually walk
quickstart.md's US1/US2/US3/US4/US5 rows before final sign-off — this phase has zero
automated test coverage to catch a behavioral regression the type checker wouldn't catch.
