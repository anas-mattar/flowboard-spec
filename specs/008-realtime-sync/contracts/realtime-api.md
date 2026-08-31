# Contract: Realtime Token & Board Hub

Cite this file in a top comment in `BoardHub.cs`, `BoardEventPublisher.cs`, the new
`realtime-token` handler in `BoardsEndpoints.cs`, and the frontend's
`lib/api/realtime-client.ts` / `lib/realtime/board-connection.ts`.

## `POST /v1/boards/{boardPublicId}/realtime-token` — mint a scoped realtime token

FR-003, FR-010, User Stories 1–3. Requires `Authorization: Bearer <backend session JWT>`
— the normal 14-day token, same as every other board-scoped route. Authorization: caller
must resolve to any role on the board (`BoardAdmin`, `BoardMember`, or `Observer` —
Story 1's acceptance scenario 4 requires observers to receive live updates too); no
resolvable role → `404` (matching the existing "board's existence is not confirmed to a
non-member" rule, 002 FR-013).

**Request body**: none.

**Response `200 OK`**:

```json
{ "token": "<jwt>", "expiresAt": "2026-08-30T12:02:00Z" }
```

- `token` — a JWT per `data-model.md`'s `RealtimeTokenClaims` (`sub`, `boardId`,
  `purpose: "realtime"`, 2-minute `exp`). Never the caller's backend session JWT.
- `expiresAt` — echoes the token's `exp` claim as an ISO-8601 timestamp so the client
  knows when to expect its own reconnect via `accessTokenFactory` to be re-invoked.

**Failure responses**:

- `401` — unauthenticated (no/invalid backend session JWT).
- `404` — board does not exist, or caller has no role on it.

**Side effects**: none (no write, no `ActivityEvent`).

## Hub: `/hubs/board`

Connection auth: `accessTokenFactory` supplies the token from the endpoint above as an
`access_token` query-string value (the standard SignalR JS client mechanism for browser
`WebSocket`/SSE transports, which cannot carry an `Authorization` header). The hub's JWT
bearer validation requires `purpose == "realtime"` — a normal 14-day session JWT is
rejected at the transport handshake, never reaching a hub method.

### Client → Hub

**`JoinBoard(boardPublicId: string)`**

- Validates `boardPublicId` matches the connection token's `boardId` claim — mismatch
  closes the connection (a token is only ever good for the one board it was minted for).
- Re-resolves the caller's current role via `IBoardAccessService` (invariant 5 — a valid
  token is not board access by itself); no resolvable role closes the connection with the
  same "not found" posture as the REST API (no distinction surfaced between "board
  deleted" and "you were removed").
- On success: adds the connection to SignalR group `board:{boardPublicId}` and records
  `(boardPublicId, callerPublicId) → connectionId` in the connection tracker
  (data-model.md).

**`LeaveBoard(boardPublicId: string)`**

- Removes the connection from the group. Called when the frontend navigates away from a
  board (FR-002 — a client must not keep receiving updates for a board it left).

### Hub → Client

**`BoardEvent(event: BoardRealtimeEvent)`**

- Sent to group `board:{boardPublicId}` for every card/list/board mutation (FR-001).
  Envelope shape: `data-model.md`'s `BoardRealtimeEvent`.
- Also sent — to the specific evicted connection only, not the group — with
  `type: "access.revoked"` when `IBoardEventPublisher`'s eviction path fires
  (research.md R-7); the client treats this exactly like a failed refetch (FR-007) and
  shows the existing "you don't have access to this board" state
  (`app/(app)/boards/[boardPublicId]/page.tsx`'s existing `NOT_FOUND` branch).

### Connection lifecycle (client-observable, drives Story 3/FR-009)

- `onreconnecting` — live updates are paused; client shows the visible "reconnecting"
  indicator (FR-009).
- `onreconnected` — client re-joins its board's group (`JoinBoard`) and invalidates
  `boards.getContent` (research.md R-6) to catch up.
- `onclose` (reconnection exhausted) — client falls back to the no-live-connection state
  (Story 4/FR-012): board remains fully usable via existing 003–007 behavior; the
  indicator communicates "live updates unavailable," not an error blocking the page.

## `boards.getRealtimeToken` (tRPC procedure)

`server/api/routers/boards.ts` — `protectedProcedure`, input `{ boardPublicId: string }`,
calls the server-only `lib/api/realtime-client.ts` (new, mirrors every existing
`lib/api/*-client.ts`: attaches the caller's backend JWT, maps `404`/`401` the same way
`boards-client.ts` already does). Returns `{ token, expiresAt }` verbatim. This procedure
is the one and only thing the browser calls through the BFF for realtime — the resulting
`token` is then used directly against the hub, per `frontend-rules.md`'s sanctioned
exception.
