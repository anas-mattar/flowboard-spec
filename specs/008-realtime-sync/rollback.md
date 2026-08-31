# Rollback — 008 Realtime Sync & Concurrency

Written before Phase 1 implementation begins, per the Critical Delivery Addendum
(`docs/sdlc/critical-delivery.md` item 1 — this feature is Critical because it touches
domain invariants 1/5/6/8 directly and introduces a new authentication mechanism, the
short-lived realtime token).

## Rollback Method

```bash
git revert [commit-sha]        # one revert per phase commit, newest first
```

Every change in this feature is additive (new endpoint, new hub, new service, new
frontend module) — no existing endpoint, service method, or component is modified in a
way that changes its own prior behavior when the diff is reverted. Reverting the
frontend phase and reverting the backend phase are each independently clean; there is no
shared migration to worry about (this feature adds no migration at all).

## Changed Areas

- `flowboard-api`: new `Hubs/BoardHub.cs`, `Services/BoardEventPublisher.cs` (+
  `IBoardEventPublisher` interface), `Services/BoardConnectionTracker.cs`, a new
  `realtime-token` handler added to `Endpoints/BoardsEndpoints.cs`, a new
  `IssueRealtimeToken` method added to `Services/TokenService.cs`/`ITokenService`.
  `CardService.cs`, `ListService.cs`, `BoardContentService.cs`, and
  `BoardMembershipService.cs` each gain one additional inline call to
  `IBoardEventPublisher.PublishAsync(...)` after their existing `SaveChangesAsync()` —
  additive lines, no existing line changed. `Program.cs` gains `AddSignalR()`,
  `MapHub<BoardHub>("/hubs/board")`, and the new services' DI registrations (additive to
  the existing composition root, same shape as every prior feature's `Program.cs` diff).
  **Amendment (found during T019 manual verification, tasks.md T007)**: `Program.cs` also
  gains a new `"Realtime"` CORS policy (`Cors:RealtimeOrigin` config key, default
  `http://localhost:3000`), applied only to `MapHub<BoardHub>(...).RequireCors("Realtime")`
  — no other route gets CORS. Not anticipated when this rollback plan was first written;
  see the Deployment Rollback section below.
- `flowboard-web`: new `@microsoft/signalr` dependency (package.json/package-lock.json);
  new `lib/api/realtime-client.ts`, `lib/realtime/use-board-realtime.ts`, a new
  `boards.getRealtimeToken` procedure in `server/api/routers/boards.ts`, and a
  connection-status indicator component
  (`components/layout/realtime-status-indicator.tsx`). **Amendment (tasks.md T026)**: the
  hub connection is shared between the board page's `top-bar.tsx` (status indicator) and
  `board-canvas.tsx` (cache invalidation) via a small client Context Provider,
  `components/board/board-realtime-context.tsx` — `use-board-realtime` is called there,
  not directly in `board-canvas.tsx`.
  **Correction (human-pr-review.md, second-model adversarial review, 2026-08-31): the
  claim below that no existing component's rendering logic changes was wrong — three
  existing components' render trees do change, and a revert must undo each:**
  - `app/(app)/boards/[boardPublicId]/page.tsx` — its component tree changes to wrap
    `<TopBar>` and `<BoardCanvas>` in the new `BoardRealtimeProvider`.
  - `components/layout/top-bar.tsx` — now renders the new
    `<RealtimeStatusIndicator />` as part of its own JSX, not just an added sibling file.
  - `components/board/board-canvas.tsx` — gained a new conditional render branch (a
    `boardError?.data?.code === "NOT_FOUND"` early return) for the "no access" state
    (FR-007's live-revocation UI). It does **not** call `useBoardRealtime` or any realtime
    context hook itself — an earlier T019 version did call `useBoardRealtime` directly, but
    T026's refactor (commit `2503c86`, "board-canvas.tsx no longer calls the hook
    directly") moved that call solely into `BoardRealtimeProvider`
    (`board-realtime-context.tsx`), mounted once at the page level in `page.tsx`.
    `board-canvas.tsx` re-renders with fresh data purely because the provider's
    invalidate-on-event calls hit the same shared tRPC query cache
    (`boards.getContent`) that `board-canvas.tsx`'s own `useQuery` already subscribes to —
    no direct call, subscription, or import connects the two.
    **Corrections (re-review, 2026-08-31, two rounds): the previous version of this
    paragraph (a) wrongly attributed the realtime `utils.boards.getContent.invalidate(...)`
    call to `board-canvas.tsx` itself — that call actually lives in
    `lib/realtime/use-board-realtime.ts` — and, once corrected, (b) still wrongly claimed
    `board-canvas.tsx` calls the hook "via `board-realtime-context.tsx`," which is also
    false per the T026 diff above. `board-canvas.tsx` does call `getContent.invalidate(...)`
    itself, but only from its own pre-existing (pre-008) mutation `onSettled` handler (one
    call site, not "handlers") — unrelated to realtime.

  Reverting the feature must restore all three files to their pre-008 JSX, not just
  delete the newly-added files — a plain `git revert` of the phase commits does this
  correctly (per the Rollback Method above), but a partial/manual revert must not skip
  them.
- No existing endpoint's request/response contract changes.

## Database Rollback

- Schema changes in this feature: **none**. No migration is added (data-model.md) — the
  realtime token is a JWT (nothing persisted), the broadcast envelope is a transient
  SignalR message, and the connection tracker is in-process memory only.
- Migration down-path: not applicable — there is nothing to migrate down.
- Protected domain data touched: none. This feature reads `ActivityEvent` rows (to copy
  their `type`/`payload` into the broadcast envelope) but never writes, edits, or deletes
  one — invariant 1 (append-only) is not at risk from a revert or from the feature itself.

## Deployment Rollback

- No environment variable or secret is introduced beyond reusing the existing JWT signing
  key already configured for the backend session token (`JwtOptions`, 002) — the realtime
  token is signed with the same key, just a shorter lifetime and an extra claim. Reverting
  the code fully removes the realtime-token issuance path; no separate secret to rotate
  or revoke.
- **Amendment (found during T019 manual verification, tasks.md T007)**: this feature does
  introduce one piece of configuration beyond reusing the existing JWT signing key — the
  `Cors:RealtimeOrigin` setting (backing the `"Realtime"` CORS policy described above,
  default `http://localhost:3000`). Reverting the code removes the policy and its
  `RequireCors("Realtime")` usage entirely; the config key itself is inert if left behind
  in `appsettings.json`/environment config (nothing reads it once `Program.cs`'s
  registration is gone), but should be removed as part of the same revert for cleanliness.
  No secret, permission grant, or feature flag is introduced. If a SignalR backplane were
  ever added later (research.md R-8 explicitly defers this), that follow-up feature would
  carry its own rollback plan for the added infrastructure — this feature adds none.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code — both repos:
  `dotnet build --warnaserror && dotnet test`, `npm run lint && npm run build`)
- [ ] Boards load and every 003–007 feature (view, CRUD, drag-drop, board/list
  management, search/filter) works exactly as before this feature existed, with no
  console errors from a dangling SignalR client reference
- [ ] No `/hubs/board` route is reachable (confirms the hub registration was actually
  removed, not just unused)
- [ ] No `"Realtime"` CORS policy remains registered in `Program.cs` (confirms the
  cross-origin allowance added for the hub was removed along with it, not left dangling
  for some other route to pick up)
- [ ] `node_modules`/`package-lock.json` no longer reference `@microsoft/signalr` after
  `npm install` on the reverted tree
