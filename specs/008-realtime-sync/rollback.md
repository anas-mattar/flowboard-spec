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
- `flowboard-web`: new `@microsoft/signalr` dependency (package.json/package-lock.json);
  new `lib/api/realtime-client.ts`, `lib/realtime/board-connection.ts` (or equivalent
  hook, e.g. `use-board-realtime.ts`), a new `boards.getRealtimeToken` procedure in
  `server/api/routers/boards.ts`, and a small connection-status indicator component. The
  board page (`app/(app)/boards/[boardPublicId]/page.tsx`) and `board-canvas.tsx` gain a
  realtime-connection hook call that invalidates the existing `boards.getContent` query —
  additive, does not change either file's existing rendering logic.
- No existing endpoint's request/response contract changes. No existing frontend
  component's props or rendering logic changes — the realtime hook only ever calls
  `utils.boards.getContent.invalidate(...)`, a function every mutation already calls
  today.

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
- No permission grant, feature flag, or infrastructure change is introduced. If a
  SignalR backplane were ever added later (research.md R-8 explicitly defers this), that
  follow-up feature would carry its own rollback plan for the added infrastructure — this
  feature adds none.

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code — both repos:
  `dotnet build --warnaserror && dotnet test`, `npm run lint && npm run build`)
- [ ] Boards load and every 003–007 feature (view, CRUD, drag-drop, board/list
  management, search/filter) works exactly as before this feature existed, with no
  console errors from a dangling SignalR client reference
- [ ] No `/hubs/board` route is reachable (confirms the hub registration was actually
  removed, not just unused)
- [ ] `node_modules`/`package-lock.json` no longer reference `@microsoft/signalr` after
  `npm install` on the reverted tree
