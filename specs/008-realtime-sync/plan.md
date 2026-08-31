# Implementation Plan: Realtime Sync & Concurrency

**Branch**: `008-realtime-sync` | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-realtime-sync/spec.md`

## Summary

Add a per-board SignalR channel (`/hubs/board`, group `board:{boardPublicId}`) that
broadcasts every card/list/board mutation from 003–007 to every other connected client
viewing that board, and make the concurrency rules already implemented since 004/005/006
(RowVersion-backed `If-Match`/`409` field-edit conflicts; `ExecuteUpdateAsync`
last-write-wins card moves) visible live rather than only on next reload. The browser
connects to the hub directly using a new, short-lived (2-minute), board-scoped JWT minted
through the normal tRPC BFF path — the one sanctioned exception to the BFF-only data flow
rule (`frontend-rules.md`). Every mutating service method gains one inline broadcast call
after its existing `SaveChangesAsync()`; the frontend treats every incoming event as an
invalidation signal and re-fetches `boards.getContent` (already every mutation's own
reconciliation path since 004) rather than patching the cache from event payloads.

## Technical Context

**Language/Version**: C# / .NET 10 (backend, unchanged); TypeScript / Next.js 16 App
Router (frontend, unchanged)

**Primary Dependencies**:
- Backend: **no new NuGet package** — `Microsoft.AspNetCore.SignalR` ships inside the
  `Microsoft.NET.Sdk.Web` shared framework `Flowboard.Api` already targets
  (research.md R-1).
- Frontend: **`@microsoft/signalr`** (NEW dependency, approved here — research.md R-2).
  No other new package; realtime UI (connection-status indicator) reuses existing
  shadcn/ui primitives and Sonner (already used for X-01 toasts).

**Storage**: SQL Server — **no migration** (data-model.md). This feature adds no table
or column; it reads `Card`/`List`/`Board`'s existing `RowVersion` columns (004/006) and
`ActivityEvent` rows (004) without altering either.

**Testing**: `dotnet test` — hub-level integration tests via `WebApplicationFactory`'s
SignalR test-client support (`Microsoft.AspNetCore.SignalR.Client`, test-only, already
implied by the shared framework — not a new production dependency) covering: join
succeeds for a board member/observer, join fails for a non-member, `BoardEvent` is
received after a card mutation with the same `type`/`payload` as the persisted
`ActivityEvent`, eviction closes the connection after member removal. Plus one
integration test per mutating endpoint confirming its existing `SaveChangesAsync()` is
still followed by exactly one broadcast call (no duplicate, no missing call). Frontend:
no test runner exists yet (003 precedent) — verified via `quickstart.md`'s manual
two-window walkthrough.

**Target Platform**: Web (existing Next.js/ASP.NET Core stack, unchanged); realtime
transport negotiates WebSocket with SignalR's automatic fallback (server-sent events /
long-polling) for restrictive networks, satisfying Story 4/FR-012 without extra code —
this fallback behavior is built into SignalR, not something this feature implements.

**Project Type**: Web application (existing `flowboard-api` + `flowboard-web`, unchanged)

**Performance Goals**: A change is visible on another connected client in <500ms p95
(SC-001, FUNCTIONAL_SPEC.md §8's existing NFR) — a push over an already-open connection,
not a poll; group-scoped broadcast (`Clients.Group(...)`) so no client receives, and no
server work is spent serializing, events for boards it isn't viewing (FR-002).

**Constraints**: No SignalR backplane / multi-instance fan-out (research.md R-8 — out of
scope, no current requirement demands it). Realtime token lifetime fixed at 2 minutes
(research.md R-3/R-7) — not configurable per environment beyond that default, to keep the
access-revocation staleness bound predictable. Broadcasting MUST happen only after
`SaveChangesAsync()` succeeds, never before (backend-rules.md's existing Realtime
section) — a failed transaction must never appear to have happened on another client's
screen.

**Scale/Scope**: No migration. Backend: one new `Hubs/BoardHub.cs`, one new
`Services/BoardEventPublisher.cs` (+`IBoardEventPublisher`), one new
`Services/BoardConnectionTracker.cs`, one new endpoint (`POST
/v1/boards/{id}/realtime-token`) on the existing `BoardsEndpoints.cs`, one new method on
`ITokenService`/`TokenService`, and one additional inline broadcast call added to each of
`CardService.cs`, `ListService.cs`, `BoardContentService.cs`,
`BoardMembershipService.cs`'s existing mutating methods (no method signature changes).
Frontend: one new `lib/api/realtime-client.ts`, one new `boards.getRealtimeToken`
tRPC procedure, one new realtime-connection hook (e.g. `lib/realtime/use-board-realtime.ts`)
consumed by the board page, and one small connection-status indicator component in the
top bar.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist all-PASS, no
  `NEEDS CLARIFICATION` markers); this plan.md follows before any code; tasks.md follows
  this plan before implementation.
- [x] **Source of Truth (II)**: No screenshots exist for this feature (spec.md's Visual
  Inventory section was omitted per the template's own instruction — this feature adds no
  new rendered layout, only a small connection-status indicator with no prototype
  reference). No conflict found between `FUNCTIONAL_SPEC.md` §7/§7.1/§8,
  `docs/domain/flowboard-invariants.md` invariants 1/5/6/8, `docs/rulebooks/backend-rules.md`'s
  Realtime section, and `docs/rulebooks/frontend-rules.md`'s Data Flow section — all four
  agree on the same shape (per-board SignalR channel, same event objects as history,
  direct-to-hub browser connection as the one BFF exception). See Architecture Decision
  Records below for how each is satisfied.
- [x] **Repository Separation (III)**: `flowboard-api` (hub, publisher, connection
  tracker, token endpoint) and `flowboard-web` (SignalR client, connection hook, status
  indicator) stay separate; no mixing.
- [x] **Architecture Consistency (IV)**: New patterns introduced and approved here: (1) a
  SignalR hub — the project's first, explicitly anticipated by
  `docs/rulebooks/backend-rules.md`'s pre-existing "Realtime (SignalR)" section and
  `docs/rulebooks/frontend-rules.md`'s "feature 008's plan.md" pointer; (2) the browser's
  one direct-to-backend connection, explicitly sanctioned in advance by the same frontend
  rulebook section as the sole exception to the tRPC-only Data Flow rule. No other new
  framework, UI library, or persistence approach. Broadcast call sites follow the
  existing inline-side-effect pattern (research.md R-4) rather than introducing a new
  interceptor/pipeline pattern.
- [x] **Data Standards (V)**: No new entity, no new primary key. The realtime token's
  `boardId` claim carries the board's opaque `PublicId`, never the internal `Id`
  (data-model.md, invariant 8).
- [x] **Auditability (VI)**: No new business entity. This feature neither adds nor
  requires audit/soft-delete fields — it broadcasts and reads existing audited data,
  never writes it.
- [x] **Domain Invariants (VII)**: See Domain Invariant Pass below — this is exactly why
  the feature is declared Critical (spec.md Delivery Level).
- [x] **Security (VIII)**: The hub requires authentication (a valid `purpose: "realtime"`
  token — contracts/realtime-api.md); `JoinBoard` re-authorizes via `IBoardAccessService`
  rather than trusting the token's staleness-bounded implicit access (invariant 5). No
  secret is added beyond reusing the existing JWT signing key (`JwtOptions`, already an
  environment/user-secrets value per 002). No sensitive data is logged — broadcast
  payloads mirror what the REST API already returns to the same authorized audience.
- [ ] **External Integration Governance (IX)**: N/A — no external (third-party/SaaS)
  integration is added; the hub is this project's own backend talking to this project's
  own frontend (research.md R-2 explicitly rejected a third-party realtime SaaS for this
  reason).
- [x] **Performance Responsibility (X)**: See Technical Context — broadcasts are
  group-scoped (no fan-out to uninvolved clients), no new database query is added to any
  existing mutation's hot path (the publisher reads only data already loaded/just
  persisted by that same method, e.g. the `ActivityEvent` just added to the change
  tracker), and client-side reconciliation reuses the existing `getContent` query
  (research.md R-6) rather than adding a second data-fetching path.
- [x] **Testing Requirements (XI)**: See Technical Context's Testing entry — hub join/
  broadcast/eviction behavior and the "exactly one broadcast call per mutation" invariant
  are business-critical (they ARE this feature) and get automated integration coverage.
- [x] **Human Review (XII)**: Same phased AI-then-human review as 001–007, with the
  Critical addendum's additional explicit domain-invariant pass in both reviews (item 2).
- [x] **Controlled Delivery (XIII)**: Backend phase (hub, publisher, connection tracker,
  token endpoint, per-service broadcast calls) implemented and gated before frontend, per
  `docs/sdlc/repository-strategy.md`'s cross-repository rule — same sequencing as
  004/005/006/007.

**Delivery Level**: **Critical** (`docs/sdlc/critical-delivery.md`) — declared in
spec.md's header. Triggers: this feature touches domain invariants 1, 5, 6, and 8
directly, and introduces a new authentication mechanism (the short-lived realtime token).
The addendum's five additional requirements apply on top of everything above:
`rollback.md` is already written (this plan, before Phase 1 — item 1); both AI and human
review will include an explicit invariant-by-invariant pass (item 2); gate output, `git
diff --stat`, and both review checklists are retained in this directory (item 3); every
gate run that counts toward Done is human-executed, not agent-run-and-reported (item 4);
approval is independent of this feature's author or a second-model adversarial review
plus a cooling-off period if solo (item 5).

### Domain Invariant Pass

- **Invariant 1 (Activity Is Append-Only)**: This feature never writes, edits, or deletes
  an `ActivityEvent` row — it only reads one, after it is already committed, to copy its
  `type`/`payload` into a broadcast envelope (research.md R-5, data-model.md). "Realtime
  and history MUST NOT diverge in shape" is satisfied by literal reuse, not
  reimplementation, of the persisted value.
- **Invariant 2 (Ordering Integrity)**: Untouched — this feature broadcasts the *result*
  of a move (research.md R-6: the client re-fetches rather than trusting a payload
  position), it never computes or writes a position itself.
- **Invariant 5 (Permissions Server-Side)**: `JoinBoard` re-resolves the caller's role via
  `IBoardAccessService` at connection time (contracts/realtime-api.md) rather than
  trusting the realtime token's absence of a role claim as implicit access — matching
  invariant 5's "a valid token is not board access" for the hub exactly as it already
  applies to every REST endpoint.
- **Invariant 6 (Optimistic Concurrency)**: This feature changes no concurrency behavior
  — `CardService.MoveCardAsync`'s existing ADR-21 (`ExecuteUpdateAsync`, no precondition,
  last-write-wins) and the existing `RowVersion`/`If-Match`/`409` field-edit path are
  unchanged. This feature only makes their existing outcomes visible live (Story 2).
- **Invariant 8 (Opaque Public Identifiers)**: The realtime token's `boardId` claim, the
  `BoardRealtimeEvent` envelope's `boardPublicId`/`actorPublicId`, and the connection
  tracker's keys all use `PublicId` values exclusively (data-model.md) — no internal
  `Id` is ever placed on a JWT claim, a hub method parameter, or a broadcast payload.

## Project Structure

### Documentation (this feature)

```text
specs/008-realtime-sync/
├── plan.md                      # This file
├── research.md                  # Phase 0 output
├── data-model.md                # Phase 1 output
├── quickstart.md                # Phase 1 output
├── contracts/
│   └── realtime-api.md          # Phase 1 output
├── checklists/
│   └── requirements.md          # spec quality gate (already PASS)
├── rollback.md                  # Critical Delivery Addendum item 1 — written now, pre-Phase-1
└── tasks.md                     # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
flowboard-api/src/Flowboard.Api/
├── Hubs/
│   └── BoardHub.cs                       # NEW — JoinBoard/LeaveBoard, group membership
├── Services/
│   ├── BoardEventPublisher.cs            # NEW — IBoardEventPublisher, wraps IHubContext<BoardHub>
│   ├── BoardConnectionTracker.cs         # NEW — singleton, (boardPublicId,userPublicId) -> connectionIds
│   ├── TokenService.cs                   # MODIFIED — + IssueRealtimeToken(userPublicId, boardPublicId)
│   ├── CardService.cs                    # MODIFIED — + one PublishAsync call per mutating method
│   ├── ListService.cs                    # MODIFIED — + one PublishAsync call per mutating method
│   ├── BoardContentService.cs            # MODIFIED — + one PublishAsync call per mutating method
│   └── BoardMembershipService.cs         # MODIFIED — + PublishAsync + eviction call on member removal
├── Endpoints/
│   └── BoardsEndpoints.cs                # MODIFIED — + POST /{boardPublicId}/realtime-token
└── Program.cs                            # MODIFIED — + AddSignalR(), MapHub<BoardHub>, new DI registrations

flowboard-api/tests/Flowboard.Api.Tests/
└── BoardHubTests.cs                      # NEW — join/leave/broadcast/eviction integration tests

flowboard-web/src/
├── lib/
│   ├── api/
│   │   └── realtime-client.ts            # NEW — server-only client for realtime-api.md
│   └── realtime/
│       └── use-board-realtime.ts         # NEW — SignalR connection hook (connect, join, invalidate on event/reconnect)
├── server/api/routers/
│   └── boards.ts                         # MODIFIED — + getRealtimeToken procedure
├── components/layout/
│   └── top-bar.tsx                       # MODIFIED — + connection-status indicator
└── app/(app)/boards/[boardPublicId]/
    └── page.tsx                          # MODIFIED — wires use-board-realtime for this board
```

**Structure Decision**: Existing `flowboard-api`/`flowboard-web` layout (001's plan.md),
unchanged in shape. Backend gains one new top-level folder, `Hubs/`, alongside the
existing `Endpoints/`/`Services/`/`Domain/`/`Data/` split — the smallest addition that
fits SignalR's own convention (a `Hub` is not an `Endpoints` handler or an application
`Service`, it is its own thing with its own base class and lifecycle) without inventing a
deeper reorganization. Frontend gains one new `lib/realtime/` folder alongside the
existing `lib/api/`/`lib/trpc/`/`lib/auth/` split, matching that directory's existing
per-concern convention (`frontend-rules.md`'s Structure section).

## Architecture Decision Records

**ADR-32 — Realtime transport is ASP.NET Core SignalR with no backend package addition
and one new frontend package (`@microsoft/signalr`)**: research.md R-1/R-2. Confirmed by
inspecting `Flowboard.Api.csproj` (no SignalR package present, none needed — it ships in
the shared web framework) and `flowboard-web/package.json` (no realtime client present
today). This is the first realtime code in either repository, exactly as
`frontend-rules.md` anticipated ("until 008, no realtime code ships at all").

**ADR-33 — Browser holds a second, short-lived, board-scoped JWT for the hub connection
only; the 14-day backend session JWT never reaches the browser (unchanged)**:
research.md R-3, data-model.md's `RealtimeTokenClaims`. Minted via a new endpoint
(`POST /v1/boards/{id}/realtime-token`, contracts/realtime-api.md) reached through the
normal tRPC BFF path; only the resulting token — not the original bearer credential — is
used directly against the hub. This is `frontend-rules.md`'s one named exception,
implemented as narrowly as that rule allows.

**ADR-34 — Broadcast is an explicit inline call after each mutating service method's
`SaveChangesAsync()`, not a cross-cutting EF Core interceptor**: research.md R-4. Chosen
specifically because board/list mutations (`ListService`, `BoardContentService`) write no
`ActivityEvent` row today — an interceptor keyed on that table would miss them entirely.
Matches this codebase's existing inline-side-effect style (`db.ActivityEvents.Add(...)`
already appears inline in every mutating method).

**ADR-35 — One broadcast envelope and one hub client method (`"BoardEvent"`) for every
mutation type; card-scoped events copy the persisted `ActivityEvent`'s `type`/`payload`
verbatim, board/list events carry only minimal identifying fields**: research.md R-5,
data-model.md. Satisfies invariant 1 for exactly the subset it covers (card actions)
without inventing a parallel "history" for board/list mutations that don't have one.

**ADR-36 — Client treats every `BoardEvent` as an invalidate-and-refetch signal against
the existing `boards.getContent` query; no event payload is applied to the cache
directly**: research.md R-6. Reuses the reconciliation path every mutation (004–007) has
already used since `board-canvas.tsx`'s ADR-19; avoids a second, independently-maintained
representation of board state that could diverge from the REST contract.

**ADR-37 — Reconnect/catch-up relies on `@microsoft/signalr`'s built-in automatic
reconnect plus a refetch on `onreconnected`; no missed-event replay or sequence-number
system is built**: research.md R-7 (first half). Matches spec.md's own Assumptions
section, which explicitly does not require replaying every intermediate missed event.

**ADR-38 — Access revocation is instant for the two call sites that already exist
(`BoardMembershipService` member removal, `BoardContentService` board archive/delete) via
an in-memory connection tracker + `Groups.RemoveFromGroupAsync`; every other conceivable
access-loss path is bounded by the realtime token's 2-minute lifetime, not covered by a
general-purpose eviction system**: research.md R-7 (second half). No new
permission-change-notification infrastructure is introduced.

**ADR-39 — No SignalR backplane; groups are held in-process, single-instance**:
research.md R-8. No current requirement (FUNCTIONAL_SPEC.md §8, this spec's Success
Criteria) demands multi-instance realtime fan-out; adding one now would be an
unjustified new external dependency (constitution IV/IX).

## Complexity Tracking

No unjustified Constitution Check violations. Architecture Consistency (IV)'s "new
pattern" flag above (a SignalR hub, and the browser's one direct-backend connection) is
not a violation requiring justification here — both are explicitly pre-approved by
`docs/rulebooks/backend-rules.md`'s existing "Realtime (SignalR)" section and
`docs/rulebooks/frontend-rules.md`'s existing "feature 008's plan.md" pointer, i.e. the
constitution's own dependent rulebooks already anticipated and named this exact plan as
where the decision would be made. This table is intentionally empty.
