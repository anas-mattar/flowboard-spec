# Research: Realtime Sync & Concurrency

Each item: Decision, Rationale, Alternatives considered.

## R-1: Realtime transport — ASP.NET Core SignalR, no new backend package

**Decision**: Use `Microsoft.AspNetCore.SignalR` server APIs, which ship inside the
`Microsoft.NET.Sdk.Web` shared framework already referenced by `Flowboard.Api` — **no new
NuGet package** is required on the backend.

**Rationale**: The roadmap and `docs/rulebooks/backend-rules.md`'s existing "Realtime
(SignalR)" section already name SignalR as this project's realtime mechanism; it comes
free with the web SDK already in use (confirmed: `Flowboard.Api.csproj` has no explicit
SignalR package today and none is needed — `Microsoft.AspNetCore.App` provides it).
Constitution IV's "no new package without plan approval" is satisfied trivially since
there is no new package to approve on this side.

**Alternatives considered**: raw `WebSocket` middleware (rejected — SignalR already
provides groups, reconnection, and JSON hub protocol, all of which this feature needs;
reimplementing them is exactly the kind of new pattern `backend-rules.md`'s Layering
section warns against introducing without cause). Long-polling only, no live channel at
all (rejected — the feature exists specifically to add live propagation; NFR "realtime
latency <500ms p95" already assumes a push transport, FUNCTIONAL_SPEC.md §8).

## R-2: Realtime transport (frontend) — `@microsoft/signalr` npm package (NEW dependency, approved here)

**Decision**: Add `@microsoft/signalr` (official Microsoft client) to `flowboard-web`.
This is a **new dependency**, approved in this plan per constitution IV's dependency
policy.

**Rationale**: It is the canonical client for an ASP.NET Core SignalR hub — matching
hub protocol, automatic reconnection (`withAutomaticReconnect`), and an
`accessTokenFactory` hook that fits `frontend-rules.md`'s "SignalR client connects
directly with a short-lived scoped token" exception exactly (R-3).

**Alternatives considered**: hand-rolled `WebSocket` client (rejected — would need to
reimplement reconnection/backoff and framing that `@microsoft/signalr` already provides
and that Story 3/FR-008/FR-009 depend on). A third-party realtime SaaS (Pusher, Ably)
(rejected outright — introduces an external integration requiring a full
`docs/rulebooks/backend/backend-external-api.md`-style contract per constitution IX, adds
a paid dependency, and duplicates a transport the backend already gets for free via R-1).

## R-3: Realtime auth — short-lived, board-scoped JWT minted through the existing BFF path

**Decision**: A new backend endpoint `POST /v1/boards/{boardPublicId}/realtime-token`
(authenticated with the caller's normal 14-day backend JWT, same as every other
board-scoped route) verifies the caller's role on that board via the existing
`IBoardAccessService` (invariant 5) and issues a **new, separate JWT** with a 2-minute
lifetime, scoped to exactly that board (`boardId` claim = the board's `PublicId`) and
carrying no other board's access. The frontend reaches this endpoint through the normal
tRPC → server-only client path (`boards.getRealtimeToken` procedure →
`lib/api/realtime-client.ts`, mirroring every other `lib/api/*-client.ts`) — only the
actual hub `WebSocket`/long-poll connection itself is made directly from the browser,
via `@microsoft/signalr`'s `accessTokenFactory` calling that tRPC procedure.

**Rationale**: `frontend-rules.md` already fixes this shape ("the SignalR client connects
to the board channel directly with a short-lived scoped token... its wiring is decided in
feature 008's plan.md") and `frontend-security.md` §1 already forbids the browser holding
the real backend JWT. Minting a second, narrowly-scoped, short-lived token is the standard
way to let a browser hold *something* without holding the actual bearer credential. A
short (2-minute) lifetime bounds how stale a client's access can be after membership is
revoked (see R-7) without needing token revocation infrastructure (002's ADR-7 already
deliberately deferred refresh-token rotation / denylists — reusing that same posture here
rather than introducing one just for this feature).

**Alternatives considered**: reuse the existing 14-day backend JWT directly in the browser
for the hub connection (rejected — directly violates `frontend-security.md` §1 and ADR-2's
"browser never holds the backend token"). Cookie-based hub auth (rejected — SignalR's
JS client already has a purpose-built `accessTokenFactory` mechanism for exactly this
case; a cookie would also travel to non-hub requests, widening exposure for no benefit).

## R-4: Broadcast call sites — explicit publish call after each mutating service method's `SaveChangesAsync`, not a new interceptor

**Decision**: Introduce one shared `IBoardEventPublisher` service (backed by
`IHubContext<BoardHub>`), and call it **explicitly, inline**, immediately after the
`SaveChangesAsync()` that commits each board/list/card mutation — in `CardService`,
`ListService`, `BoardContentService`, and `BoardMembershipService`. No EF Core
`SaveChangesInterceptor` or other cross-cutting pipeline is introduced.

**Rationale**: `backend-rules.md`'s Realtime section requires only that publishing happen
"after `SaveChangesAsync()` succeeds" — it does not mandate a mechanism. The codebase's
existing pattern for a mutation's side effects is already an inline call at the point of
mutation (every service method already does `db.ActivityEvents.Add(...)` inline, right
there in the method, not through a cross-cutting dispatcher). Adding
`await realtime.PublishAsync(...)` as one more inline line per method matches that
existing shape exactly — Architecture Consistency (IV) favors the smaller, already-proven
pattern over introducing a new one (an interceptor) that nothing else in this codebase
uses.

**Alternatives considered**: an EF Core `SaveChangesInterceptor` capturing added
`ActivityEvent` rows and broadcasting them centrally (rejected — solves only the
card-activity subset of events; board/list mutations like rename, star, archive, and
reposition write no `ActivityEvent` row at all today — confirmed by reading
`ListService.cs` and `BoardContentService.UpdateBoardAsync`, neither touches
`db.ActivityEvents` — so an interceptor keyed on that table would silently miss half of
FR-001's required event types). A generic outbox/message-queue pattern (rejected as
over-engineering for a single-process app with no cross-service messaging need yet — no
existing async-messaging infrastructure in this codebase to extend, and introducing one
is a far larger architecture change than this feature calls for).

## R-5: Event shape — one envelope, two content styles, matching invariant 1 only where it applies

**Decision**: A single hub client method (`"BoardEvent"`) carries one envelope for every
broadcast:

```text
{ type, boardPublicId, occurredAt, actorPublicId, actorDisplayName, payload }
```

For the event types already enumerated in FUNCTIONAL_SPEC.md §5.2 (card-scoped —
`card.created`, `card.moved`, `label.added`, `comment.added`, etc.), `type` and `payload`
are copied verbatim from the `ActivityEvent` row just persisted — satisfying invariant 1's
"realtime and history MUST NOT diverge in shape" for exactly the subset that invariant
covers (card actions). For board/list mutations that have no `ActivityEvent` counterpart
(`board.renamed`, `board.starred`, `board.archived`, `list.created`, `list.renamed`,
`list.moved`, `list.archived`, `list.wip_limit_changed`), `type` is a new string and
`payload` carries only the minimal identifying fields the client needs (see
`data-model.md`) — invariant 1 does not apply to these because no stored history exists
for them to diverge from (confirmed: invariant 1's own text scopes itself to "every
state-changing **card** action").

**Rationale**: One message shape and one hub method keeps the frontend's handling code
uniform (research R-6 below treats every message the same way: invalidate). Reusing the
persisted `ActivityEvent`'s `type`/`payload` for the card subset is the only way to
literally guarantee "same shape" rather than two independently-maintained
representations that could drift.

**Alternatives considered**: a distinct hub method per mutation category (rejected —
multiplies client-side wiring for no behavioral difference, since R-6 treats every
message as an invalidation signal regardless of type). Broadcasting full updated entity
DTOs instead of thin event envelopes (rejected — duplicates `BoardContentDto`/
`CardDetailDto` shapes in a second place that could drift from the REST contract, and
`frontend-rules.md`'s Data Flow rule already says backend-owned derived values must be
read from the backend response, not reconstructed from an event payload).

## R-6: Client reconciliation — invalidate-and-refetch, not cache-patch-from-event

**Decision**: On receiving any `BoardEvent` for the board currently open, the frontend
calls `utils.boards.getContent.invalidate({ boardPublicId })` (the same tRPC query every
existing mutation already invalidates — `board-canvas.tsx`'s existing pattern) rather than
hand-patching the React Query cache from the event's `payload`.

**Rationale**: `frontend-rules.md`'s Data Flow rule already prohibits the frontend from
recomputing backend-owned derived values (positions after a move, WIP counts, due-date
buckets) — patching the cache from a thin event payload would require exactly that.
Invalidate-and-refetch reuses a path already proven correct for every mutation type since
004–007, adds no new merge logic that could diverge from the server's authoritative shape,
and automatically satisfies FR-013 (bursts converge to the correct final state — multiple
invalidations in quick succession collapse to whatever the query client's existing
de-duplication does, same as rapid own-mutations already behave today).

**Alternatives considered**: patch the query cache directly from each event's payload for
lower latency (rejected — reintroduces exactly the two-implementations-of-one-formula risk
`frontend-rules.md` warns about, and this feature's own invariant-1 discussion above
already shows board/list events don't carry full state, only identifying fields — a
partial payload cannot correctly patch a full board shape without re-deriving fields that
must come from the backend).

## R-7: Reconnection and access revocation — bounded by token TTL, not instant server push, except where cheap to make instant

**Decision**: Two mechanisms, matched to the story that needs them:

- **Reconnect/catch-up (Story 3, FR-008)**: rely on `@microsoft/signalr`'s built-in
  `withAutomaticReconnect()`; on the client's `onreconnected` callback, call the same
  `invalidate()` as R-6. No sequence numbers or missed-event replay are implemented — the
  spec's own Assumptions section already accepts "bring the client back to current server
  state" as sufficient, not "replay every intermediate event."
- **Access revocation mid-session (edge case, FR-007)**: the 2-minute token TTL (R-3)
  bounds staleness for the general case (a client's hub connection is re-authorized every
  time `accessTokenFactory` is called, which happens on every reconnect attempt). For the
  specific, cheap-to-detect case of a board member being removed
  (`BoardMembershipService`'s existing remove-member method) or a board being archived/
  deleted (`BoardContentService.UpdateBoardAsync` / delete path), the same
  `IBoardEventPublisher` additionally calls `Groups.RemoveFromGroupAsync` for that user's
  tracked connections on that board (a small in-memory connection tracker keyed by
  `(boardPublicId, userPublicId) → connectionIds`, populated in `BoardHub.JoinBoard` and
  cleaned up in `OnDisconnectedAsync`) — so the common revocation paths are evicted
  immediately, and every other case is bounded by the 2-minute token TTL.

**Rationale**: Instant eviction for every conceivable access-loss path (e.g., a workspace
being deleted, a cascading permission change) would require plumbing a publish call into
every place a role could theoretically change — disproportionate for a spec whose Success
Criteria (SC-001–SC-005) don't set a numeric target for this edge case, unlike the general
<500ms live-update target. Handling the two paths that already have a single, well-known
call site (`BoardMembershipService`, `BoardContentService`) instantly, and bounding
everything else by the already-short 2-minute token TTL, satisfies FR-007's "as soon as"
in the cases that matter most without a new general-purpose permission-change-notification
system.

**Alternatives considered**: no proactive eviction at all, rely purely on token TTL
(rejected — 2 minutes is a long window for the two common, easily-detected revocation
paths that already have a clear call site). A full permission-change pub/sub system
(rejected as disproportionate — see Rationale).

## R-8: Single-instance scope — no SignalR backplane

**Decision**: SignalR groups are held in-process (the default provider); no Redis/Azure
SignalR backplane is added.

**Rationale**: Nothing in FUNCTIONAL_SPEC.md §8's non-functional requirements or this
spec's Success Criteria requires multi-instance horizontal scale-out for the realtime
channel specifically, and adding a backplane is a new external dependency requiring its
own justification (constitution IX/IV) that no current requirement demands. `flowboard-api`
today runs as a single process in every environment this project has defined so far.

**Alternatives considered**: Azure SignalR Service or a Redis backplane now (rejected —
premature; would be a straightforward, additive follow-up feature if/when horizontal
scaling is actually needed, not a day-one requirement of this spec).
