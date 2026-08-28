# Review Notes — 003 Board View (Read-Only)

## Phase A — backend board content (T001–T024)

**Gate**: `dotnet build --warnaserror && dotnet test` in `flowboard-api` — run by the
user 2026-08-28, **EXIT: 0 confirmed** (build 0 warnings / 0 errors; 40/40 tests
passed). Two more test cases (`ListBoards_LimitOutOfRange_ReturnsValidationProblem`,
`ListBoards_MalformedCursor_ReturnsValidationProblem`) were added immediately
afterward, during this AI review, to close a Testing-checklist gap (see below) — the
confirmed run predates them, so a fresh gate confirmation is needed before commit. My
own fast-feedback re-run (allowed mid-implementation for this Standard-delivery
feature) shows 43/43 passing after the addition.

**Diff surface**: new `Domain/Entities/{List,Card,Label,CardLabel,CardMember,
ChecklistItem,Comment}.cs`, new `Domain/CursorPage.cs` (ADR-12), new
`Data/Configurations/{List,Card,Label,CardLabel,CardMember,ChecklistItem,Comment}
Configuration.cs`, new `Migrations/20260827165840_AddBoardContent.{cs,Designer.cs}`,
new `Services/BoardContentService.cs`, new `Endpoints/BoardsEndpoints.cs`, new
`tests/BoardsEndpointTests.cs`. Edited: `BoardConfiguration.cs` (+`Color`/`Starred`
columns and the three-board seed), `BoardMemberConfiguration.cs` (+5 seeded
memberships), `UserConfiguration.cs` (+5 seeded placeholder users for card-avatar
fidelity), `Board.cs` (+2 properties), `FlowboardDbContext.cs` (+7 `DbSet`s),
`Program.cs` (+2 DI registrations, +1 endpoint-group mapping),
`FlowboardDbContextModelSnapshot.cs` (EF-generated). No files outside this feature's
schema/seed/read-endpoint scope; 002's auth/board-membership business logic is
untouched.

**AI review vs `docs/rulebooks/backend-compliance-checklist.md`** (2026-08-28):

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `BoardsEndpoints.cs` uses `MapBoardsEndpoints` + `MapGroup("/v1/boards")`; handlers are thin (auth check + input shape check, then one service call); both `BoardsEndpoints.cs` and `BoardContentService.cs` cite `contracts/board-content-api.md` in a top comment |
| API Surface | PASS | `limit`/`cursor` validated at the boundary → `ValidationProblem`; every DTO exposes `PublicId` only, never the internal `Id`; `GET /v1/boards` is cursor-paginated (ADR-12); `409`/`If-Match` N/A — no writes in this feature |
| Domain & Authorization | PASS | `GetBoardContentAsync` calls `BoardAccessService.ResolveAsync` before any query (invariant 5); `ListBoardsAsync` has no per-board check by contract design — it queries exactly the boards the caller owns or is an explicit member of, which *is* the enforcement point for a list operation, not a gap. Soft-delete (invariant 4) and board-scoping (invariant 7) both fall out of existing query filters and the `CardLabel`→`Card`→`List`→`Board` FK chain — no leakage path exists. Position sorted, not recomputed — research R-8's deferred `Ordering.cs` module is for write-side move math, which doesn't exist yet; a plain `OrderBy(x => x.Position)` isn't the "inline re-derivation" that rule targets. Invariant 1 (Activity Append-Only) and 6 (Optimistic Concurrency) are N/A — no mutations in this feature |
| Data Access & Performance | PASS | Every query is `AsNoTracking()` + `.Select()` projection; `GetBoardContentAsync` batches lists/cards/checklist-counts/comment-counts/labels/members as flat `WHERE id IN (...)` queries and joins in memory instead of nesting correlated collections three levels deep — avoids both N+1 and an EF translation risk; `ListBoardsAsync`'s per-board `CardCount` is a single correlated scalar subquery inside one SQL statement, not a per-row round trip; no explicit `IgnoreQueryFilters()`; all I/O `async` with `CancellationToken` throughout |
| Security | PASS | `.RequireAuthorization()` on the boards group; all data access is LINQ (parameterized) — the one `migrationBuilder.Sql(...)` call in `AddBoardContent.Up()` interpolates only an internal `DateTime`/`int` computed value, never user input, so it carries no injection surface despite the string-interpolation shape; no secrets in source; external HTTP N/A |
| Testing | PASS (after fix) | Initially missing a validation-failure case (checklist requires success/validation/authz/concurrency coverage) — added `ListBoards_LimitOutOfRange_ReturnsValidationProblem` and `ListBoards_MalformedCursor_ReturnsValidationProblem` during this review. Final coverage: success (list + hydrate), validation failure (bad limit, bad cursor), authorization failure (404 for no access, 404 for unknown board), and the T024 golden-fixture test asserting `dueStatus`/checklist/comment/label/member values against hand-worked expectations; concurrency N/A (no writes) |
| Process | PASS | No new packages; diff surface reviewed above is exactly this feature's schema/seed/read-endpoint scope; gate previously user-confirmed EXIT 0, re-confirmation requested for the two added tests |

**Verdict**: Phase A PASS — one gap found (missing validation-failure tests) and fixed
within this review before recording it; no other FAIL items, no waivers. Cleared to
commit once the gate is re-confirmed against the current diff.

## Phase B — frontend (sidebar, shell, canvas, theme, collapse, keyboard) (T025–T038)

**Gate**: `npm run lint && npm run build` in `flowboard-web` — my own fast-feedback runs
(allowed mid-implementation for this Standard-delivery feature) are clean after every
change in this phase, most recently after the Visual Compliance Loop's fixes below. The
certifying run is the user's, requested after this review.

**Diff surface**: new `app/(app)/layout.tsx` (ADR-13 shell: redirect guard + `Sidebar` +
content frame); `app/(app)/page.tsx` (moved from `app/page.tsx`, content unchanged) and
`app/(app)/boards/[boardPublicId]/page.tsx` (moved from `app/boards/...`, extended to
fetch `boards.getContent` + `boardMembers.list` and render `TopBar`/`BoardCanvas`,
replacing the T053-era `BoardMembersPanel` stub); new
`components/layout/{sidebar,sidebar-context,sidebar-toggle-button}.tsx`; new
`components/board/{board-canvas,list-column,card-front}.tsx`; new
`lib/boards/schemas.ts`, `lib/api/boards-client.ts`, `server/api/routers/boards.ts`.
Edited: `components/layout/top-bar.tsx` (board-aware, R-6), `server/api/root.ts`
(+`boards` router registration), `components/shell/theme-toggle.tsx` (focus-visible ring;
icon-only per the Visual Compliance Loop's VI-005 fix, below), `styles/globals.css` (see
next paragraph). No files outside this feature's frontend scope; 002's auth pages and
`board-members` router/client are untouched (only consumed, for the avatar stack).

**Pre-existing bug fix (user-approved)**: while verifying US2 (theme), found that
`.dark`/`:root` tied on CSS specificity in `globals.css`, and Tailwind's build
(lightningcss) reorders same-specificity top-level custom-property rules during
compilation — `:root`'s light values silently won on `<html>` regardless of source
order, so dark theme never actually rendered anywhere in the app (001/002 included),
despite the toggle/class/localStorage mechanism itself always working. Fixed by moving
`:root` inside `@layer base` so `.dark`'s plain, unlayered rule wins unconditionally
(cascade layers beat specificity/order by spec, immune to the reordering). Confirmed
both themes render correctly across every surface after the fix.

**Visual Compliance Loop** (`docs/sdlc/review-process.md`) against
`screenshots/board-canvas.png`, captured as `screenshots/board-canvas-implemented.jpg`
(fixture owner, light theme; viewport constrained to ~1280×648 by this sandbox's
physical display — not 1440×900 — comparison was structural per the process doc, not
pixel-diff):

| # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
|---|---|---|---|---|---|
| 1 | Sidebar background (VI-001) | Permanently dark navy regardless of app theme | Followed the app-wide light/dark toggle (white in light mode) | High | **Fixed** — `dark` class scoped to the `<aside>` (`sidebar.tsx`) |
| 2 | List column background (VI-006) | Solid white card, distinct from the canvas | Same muted-gray token as the canvas, only a different opacity | Medium | **Fixed** — `bg-card` (`list-column.tsx`) |
| 3 | Top bar star icon (VI-004) | Plain outline star | Filled amber when `board.starred === true` | Low | **Fixed** — always renders as a plain outline; FR-007 lists the star as a decorative, non-reactive control in this feature (`top-bar.tsx`) |
| 4 | Sidebar footer role label (VI-003) | "Workspace admin" (sentence case) | Raw `"WorkspaceAdmin"` (backend's PascalCase enum value) | Low | **Fixed** — humanized in `sidebar.tsx` |
| 5 | Top bar theme toggle (VI-005) | Compact icon-only control | Bordered button with "Light/Dark theme" text | Low | **Fixed** — icon-only (Sun/Moon), `theme-toggle.tsx` |
| 6 | Sidebar board list (VI-002) | Exactly 3 boards | The 3 seeded boards **plus** 002's pre-existing empty "Fixture Board" | Low | **Proposed to accept, user-approved** — correct per FR-001 (this fixture owner really does own that board too); research R-4 explicitly leaves it untouched |
| 7 | Sidebar "+ Create board" link (VI-002) | Present | Absent entirely | Low | **Proposed to accept, user-approved** — board creation is explicitly out of this feature's scope (spec Summary/Assumptions); unlike the enumerated FR-007 controls, it isn't required to render inert, it's just not built yet |
| 8 | Top bar avatar stack count (VI-005) | 4 avatars | 6 avatars (owner + 5 seeded members) | Low | **Proposed to accept, user-approved** — inherited from Phase A's already-reviewed seed (`BoardMemberConfiguration`), not a frontend rendering issue |
| 9 | Sidebar card count / exact due dates (VI-002/VI-009) | "13" cards; fixed dates (Sep 8, Aug 30, …) | "11" cards; relative-to-now dates | Low | **Proposed to accept, user-approved** — both are Phase A decisions already reviewed (computed-truthful count over the screenshot's inconsistent literal digit; dates deliberately seeded relative to "now" so `dueStatus` stays correct forever) |

Exit rule met: rows 1–5 fixed and recaptured; rows 6–9 user-approved as proposed. Both
screenshots (`board-canvas.png`, `board-canvas-implemented.jpg`) are attached in
`screenshots/`.

**AI review vs `docs/rulebooks/frontend-compliance-checklist.md`**:

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | New files follow the Project Shape; kebab-case files, PascalCase components, props interfaces above components throughout; `'use client'` only on `Sidebar`, `SidebarProvider`/`useSidebar`, `SidebarToggleButton`, `ThemeToggle` (state/hooks/event handlers) — layout, pages, `TopBar`, `BoardCanvas`, `ListColumn`, `CardFront` stay server components |
| Data Flow | PASS | No direct backend fetches from UI; `Sidebar` uses `trpc.boards.list.useQuery`; `boards` router validates input with Zod (`lib/boards/schemas.ts`) and calls `lib/api/boards-client.ts`; no client-side recomputation of `dueStatus`/WIP-pill/card-count — all server-sourced and merely rendered |
| Forms | N/A | No data-entry forms this phase |
| UI States & Accessibility | PASS | `Sidebar` has loading/error/empty/populated states for the boards list; `BoardCanvas`/`ListColumn` have empty states; every control is a native `<a>`/`<button>` (no `onClick`-only `div`s); `focus-visible` ring added on every new interactive element plus `ThemeToggle` (previously missing one); color is never the only carrier of meaning (due badges/WIP pill also show text/digits) |
| State, Styling | PASS | Server state only via tRPC/React Query; sidebar-collapse and theme are ephemeral client UI state via React Context — the same sanctioned pattern as the existing `ThemeProvider`, no Redux; Tailwind utilities + `cn()`; per-entity dynamic colors (board/label/avatar) are data, not hardcoded design constants, consistent with `board-members-panel.tsx`'s existing precedent; both themes verified after the Visual Compliance Loop fixes; layout matches the reference (deviation table above, empty of unresolved rows) |
| Security & Performance | PASS | No secrets/tokens reach the client bundle (`boards-client.ts` is server-only, imported by `'use client'` code only via `import type`); no new `dangerouslySetInnerHTML`; permission gating N/A (every role can view); `GET /v1/boards` is server-paginated and the sidebar consumes one page (justified — no in-scope UI needs more at this seed scale); card lists don't need virtualization (`spec.md`'s 150-card threshold, far from this scale) |
| Process | PASS | No new packages (`lucide-react` already present/approved); diff surface above is exactly T025–T038 plus the one pre-existing-bug fix (disclosed, user-approved); gate run requested from the user next |

**Verdict**: Phase B PASS — five real Visual Compliance Loop deviations found and fixed
within this review, four documented and user-approved as accepted, one pre-existing
cross-feature CSS bug found and fixed (user-approved). No other FAIL items, no waivers.
Cleared to commit once the user runs the frontend gate and confirms exit 0.
