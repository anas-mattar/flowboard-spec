# Tasks: Realtime Sync & Concurrency

**Input**: Design documents from `/specs/008-realtime-sync/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/realtime-api.md,
quickstart.md

**Delivery Level**: Critical (`docs/sdlc/critical-delivery.md`) — `rollback.md` is already
written; both AI and human review must include an explicit domain-invariant pass; gate
output and both review checklists are retained in this directory; every gate run that
counts toward Done is user-executed, never agent-run-and-reported (CLAUDE.md Strict
Rules); approval is independent/second-model-adversarial.

**Tests**: Included — plan.md's Testing section explicitly requires hub-level integration
tests (join/broadcast/eviction) and a "no duplicate/no missing broadcast call" test per
mutating endpoint, and this feature is Critical (domain invariants 1/5/6/8).

**Sequencing**: Per `docs/sdlc/repository-strategy.md` and plan.md's Controlled Delivery
gate, the backend phase (Setup, Foundational, and every backend task inside US1–US4) is
implemented and gated before any frontend task. Within this file that means: complete all
non-frontend tasks in Phases 1–2 first; each user-story phase's backend tasks still
precede that same phase's frontend tasks.

**Organization**: Tasks are grouped by user story (spec.md priorities) to enable
independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Maps the task to spec.md's US1/US2/US3/US4
- Every task names its exact file path(s)

## Path Conventions

Existing `flowboard-api`/`flowboard-web` layout (001's plan.md), unchanged in shape — see
plan.md's Project Structure section for the exact new/modified file list this feature
introduces.

---

## Phase 1: Setup

**Purpose**: The one net-new package this feature needs (research.md R-2, plan.md —
approved dependency).

- [x] T001 Add `@microsoft/signalr` to `flowboard-web/package.json` dependencies and run
  `npm install` (updates `package-lock.json`) — no other package changes.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The hub, publisher, connection tracker, token issuance, and the one new
tRPC path to reach it — every user story below depends on this existing first.

**⚠️ CRITICAL**: No user story task can begin until this phase is complete.

- [x] T002 [P] Add `RealtimeTokenClaims`-shaped issuance to `ITokenService`/`TokenService`
  in `flowboard-api/src/Flowboard.Api/Services/TokenService.cs`: new method
  `IssueRealtimeToken(Guid userPublicId, Guid boardPublicId)` returning an `IssuedToken`
  whose JWT carries `sub` (userPublicId), a new `boardId` claim (boardPublicId), a new
  `purpose` claim (`"realtime"`), and a 2-minute `exp` — reusing the existing
  `JsonWebTokenHandler`/signing-key plumbing already in this file (data-model.md
  `RealtimeTokenClaims`, research.md R-3).

- [x] T003 [P] Create `BoardConnectionTracker` in
  `flowboard-api/src/Flowboard.Api/Services/BoardConnectionTracker.cs` — a singleton,
  thread-safe map `(boardPublicId, userPublicId) -> HashSet<connectionId>` with
  `AddConnection`, `RemoveConnection`, and `GetConnectionIds(boardPublicId, userPublicId)`
  methods (data-model.md `BoardConnectionTracker entry`).

- [x] T004 Create `BoardHub` in `flowboard-api/src/Flowboard.Api/Hubs/BoardHub.cs`
  (depends on T003): JWT bearer auth configured to require the `purpose == "realtime"`
  claim (rejecting a normal 14-day session token at handshake); `JoinBoard(string
  boardPublicId)` validates the argument matches the connection token's `boardId` claim,
  re-resolves the caller's role via the existing `IBoardAccessService` (invariant 5 — no
  resolvable role closes the connection), then adds the connection to SignalR group
  `board:{boardPublicId}` and records it in `BoardConnectionTracker`; `LeaveBoard(string
  boardPublicId)` removes both; `OnDisconnectedAsync` removes the connection from the
  tracker for every board it had joined (contracts/realtime-api.md).

- [x] T005 Create `IBoardEventPublisher`/`BoardEventPublisher` in
  `flowboard-api/src/Flowboard.Api/Services/BoardEventPublisher.cs` (depends on T004),
  wrapping `IHubContext<BoardHub>`: `PublishAsync(Guid boardPublicId, string type,
  DateTime occurredAt, Guid actorPublicId, string actorDisplayName, object payload)` sends
  `"BoardEvent"` (the `BoardRealtimeEvent` envelope, data-model.md) to group
  `board:{boardPublicId}`; `EvictUserAsync(Guid boardPublicId, Guid userPublicId)` sends
  `"BoardEvent"` with `type: "access.revoked"` to that user's tracked connection ids only,
  then removes them from the group via `Groups.RemoveFromGroupAsync` (research.md R-7,
  ADR-38); `EvictBoardAsync(Guid boardPublicId)` does the same for every connection
  currently tracked for that board (used when the whole board becomes inaccessible, e.g.
  archive/delete).

- [x] T006 [P] Add `POST /v1/boards/{boardPublicId}/realtime-token` to
  `flowboard-api/src/Flowboard.Api/Endpoints/BoardsEndpoints.cs` (depends on T002):
  requires the normal 14-day bearer JWT, resolves the caller's role via
  `IBoardAccessService` (`404` if none — matches the existing "board's existence is not
  confirmed to a non-member" rule), calls `TokenService.IssueRealtimeToken`, returns `200
  { token, expiresAt }` (contracts/realtime-api.md).

- [x] T007 Wire SignalR into `flowboard-api/src/Flowboard.Api/Program.cs` (depends on
  T002–T006): `builder.Services.AddSignalR()`, register `BoardConnectionTracker` and
  `IBoardEventPublisher`/`BoardEventPublisher` in DI, add
  `app.MapHub<BoardHub>("/hubs/board")` alongside the existing `MapXEndpoints()` calls.
  **Amendment (found during T019 manual verification)**: the browser's direct-to-hub
  connection (ADR-33) is cross-origin (`localhost:3000` → `localhost:5111`) and the
  backend had no CORS policy at all — negotiation failed with `TypeError: Failed to
  fetch`. Added a `"Realtime"` CORS policy (`Cors:RealtimeOrigin` config, default
  `http://localhost:3000`), applied only to `MapHub<BoardHub>(...).RequireCors("Realtime")`
  — no other route gets CORS. Not anticipated by research.md/plan.md; recorded here rather
  than silently patched.

- [x] T008 [P] Create server-only `flowboard-web/src/lib/api/realtime-client.ts` mirroring
  the existing `lib/api/*-client.ts` pattern (e.g. `boards-client.ts`): attaches the
  caller's backend JWT, calls `POST /v1/boards/{boardPublicId}/realtime-token`, maps
  `401`/`404` the same way `boards-client.ts` already does, returns `{ token, expiresAt }`
  (contracts/realtime-api.md).

- [x] T009 Add `getRealtimeToken` procedure to
  `flowboard-web/src/server/api/routers/boards.ts` (depends on T008): `protectedProcedure`,
  input `{ boardPublicId: string }`, calls `realtime-client.ts`, returns `{ token,
  expiresAt }` verbatim.

**Checkpoint**: Hub, publisher, connection tracker, and token path exist end-to-end (a
client can mint a token and successfully `JoinBoard`) but no mutation broadcasts anything
yet — user story implementation can now begin.

---

## Phase 3: User Story 1 - See teammates' changes live (Priority: P1) 🎯 MVP

**Goal**: Every card/list/board mutation from 003–007 is pushed live, scoped per board, to
every other connected client with the same shape as the persisted activity event.

**Independent Test**: spec.md's US1 Independent Test — two sessions on the same board;
create/edit/move a card, rename a list, add a comment in session A; confirm each appears
in session B within the latency target with no manual refresh, and that history is
identical. Executable via quickstart.md §3.

### Tests for User Story 1

- [x] T010 [P] [US1] Integration test in
  `flowboard-api/tests/Flowboard.Api.Tests/BoardHubTests.cs`: `JoinBoard` succeeds for a
  board member and for an observer, fails (connection closed) for a non-member, and fails
  for a board-mismatched token (contracts/realtime-api.md).

- [x] T011 [P] [US1] Integration test in `BoardHubTests.cs`: after a card mutation (e.g.
  `AddCommentAsync`), a joined client receives `"BoardEvent"` whose `type`/`payload` match
  the `ActivityEvent` row just persisted for that same change (invariant 1, FR-003).

- [x] T012 [P] [US1] Integration test in `BoardHubTests.cs`: after `RemoveMemberAsync`
  evicts a joined connection, that connection is closed/removed from the group and stops
  receiving further `"BoardEvent"` messages for that board (FR-007).

### Implementation for User Story 1

- [x] T013 [P] [US1] Add one `IBoardEventPublisher.PublishAsync` call after each existing
  `SaveChangesAsync()` in `flowboard-api/src/Flowboard.Api/Services/CardService.cs`
  (`CreateCardAsync`, `UpdateCardAsync`, `AddLabelAsync`, `RemoveLabelAsync`,
  `AddMemberAsync`, `RemoveMemberAsync`, `AddChecklistItemAsync`,
  `UpdateChecklistItemAsync`, `DeleteChecklistItemAsync`, `AddCommentAsync`,
  `CopyCardAsync`, `DeleteCardAsync`, `MoveCardAsync`) — each call copies the `type`/
  `payload` of the `ActivityEvent` row that method just persisted (ADR-35, ADR-34: inline,
  never before `SaveChangesAsync` succeeds).

- [x] T014 [P] [US1] Add one `PublishAsync` call after each existing `SaveChangesAsync()`
  in `flowboard-api/src/Flowboard.Api/Services/ListService.cs` (`MoveListAsync`,
  `CreateListAsync`, `UpdateListAsync`, `ArchiveAllCardsAsync`, `DeleteListAsync`), using
  the new event types `list.created`/`list.renamed`/`list.moved`/`list.archived`/
  `list.wip_limit_changed` with only the minimal identifying payload fields
  (data-model.md, research.md R-5/R-6).

- [x] T015 [P] [US1] Add one `PublishAsync` call after each existing `SaveChangesAsync()`
  in `flowboard-api/src/Flowboard.Api/Services/BoardContentService.cs`
  (`UpdateBoardAsync`, `StarBoardAsync`, `UnstarBoardAsync`, `DeleteBoardAsync`) using
  event types `board.renamed`/`board.starred`/`board.unstarred`/`board.archived`; also add
  an `IBoardEventPublisher.EvictBoardAsync` call in the archive/delete path so every
  connected client loses access immediately (research.md R-7, FR-007). `CreateBoardAsync`
  needs no broadcast — no other client can be viewing a board that doesn't exist yet.

- [x] T016 [P] [US1] Add an `IBoardEventPublisher.EvictUserAsync` call after the existing
  `SaveChangesAsync()` in `RemoveMemberAsync` in
  `flowboard-api/src/Flowboard.Api/Services/BoardMembershipService.cs`, evicting the
  removed member's connections to that board (research.md R-7, FR-007).

- [x] T017 [P] [US1] Create `flowboard-web/src/lib/realtime/use-board-realtime.ts`: builds
  a `HubConnection` to `/hubs/board` via `@microsoft/signalr`, with
  `accessTokenFactory` calling `trpc.boards.getRealtimeToken` for the given
  `boardPublicId`; on connect, invokes `JoinBoard(boardPublicId)`; on unmount, invokes
  `LeaveBoard(boardPublicId)` and stops the connection; on any `"BoardEvent"`, calls
  `utils.boards.getContent.invalidate({ boardPublicId })` (research.md R-6, contracts/
  realtime-api.md). Reconnect/status handling is extended in US3 (T024) — this task only
  needs the base connect/join/subscribe/invalidate path.

- [x] T018 [US1] Wire `use-board-realtime` into
  `flowboard-web/src/components/board/board-canvas.tsx` (depends on T017) for the board
  currently being viewed. **Amendment**: `page.tsx` is a server component and cannot hold
  a client-side hub connection — `board-canvas.tsx` is already this board's client-driven
  data owner (ADR-19, `trpc.boards.getContent.useQuery` + `trpc.useUtils()`), so the hook
  is called there instead. Also added: an early-return fallback rendering the same
  "you don't have access to this board" markup as `page.tsx`'s existing `NOT_FOUND` branch
  when `boards.getContent`'s client query errors with `NOT_FOUND` — contracts/
  realtime-api.md requires an `access.revoked` event (just another invalidate signal) to
  end up showing this state, which needs an explicit check on the client query's `error`
  since only the initial server-rendered load had this branch before.

- [x] T019 [US1] Manual verification: quickstart.md §2 (token endpoint claims — confirmed:
  minted token's `sub`/`boardId`/`purpose`/`exp` match a live board and caller, 2-minute
  lifetime) and §3 (live propagation — confirmed via real `dotnet run` + `npm run dev`:
  three REST-driven card creations from a second (invited BoardMember) user each appeared
  in the first user's already-open browser tab with no manual reload). §7 (access
  revocation) is confirmed only at the protocol level via T012's automated test
  (`RemoveMemberAsync` evicts the connection, no further `BoardEvent` reaches it) — a live
  two-browser-session UI check was attempted but this session's browser automation shares
  one cookie jar across tabs, so a second login kept re-resolving to the first session's
  cookie; this is a tooling limitation of this verification pass, not a code change, and
  is worth a real two-device check before Done. **Bug found and fixed during this
  verification**: see T007's amendment (missing CORS).

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the
MVP.

---

## Phase 4: User Story 2 - Never silently lose a concurrent edit (Priority: P1)

**Goal**: Confirm the existing optimistic-concurrency (`RowVersion`/`If-Match`/`409`) and
last-write-wins (`ExecuteUpdateAsync`) rules from 004/005/006 are untouched by this
feature's broadcast calls, and that their outcomes are now visible live via US1's channel.

**Independent Test**: spec.md's US2 Independent Test — concurrent field-edit save
conflict rejected with current data shown; concurrent card drags converge to one
deterministic position. Executable via quickstart.md §4.

> Per spec.md's Assumptions and plan.md's Domain Invariant Pass, this feature "does not
> renegotiate" the concurrency rules themselves (invariant 6 unchanged) — the tasks below
> are regression tests and manual verification, not new production code, unless a gap is
> found.

- [x] T020 [P] [US2] Regression test in
  `flowboard-api/tests/Flowboard.Api.Tests/CardsEndpointTests.cs`: a stale `If-Match` on
  `UpdateCardAsync` still returns `409` with the current `RowVersion`/data, and the
  broadcast added in T013 fires for the winning save only, never for the rejected one
  (FR-004). **Note (post adversarial-review, see `human-pr-review.md`)**:
  `UpdateCard_StaleIfMatch_RejectedSaveNeverPersistsOrBroadcasts` proves the persistence
  half via the activity feed; a companion hub-level test,
  `BoardHubTests.UpdateCard_StaleIfMatch_RejectedSaveNeverBroadcasts`, was added to
  *empirically* observe the hub and confirm zero `"card.renamed"` broadcast for the
  rejected save (round 1 of the adversarial review found the activity-feed-only proof
  insufficient on its own).

- [x] T021 [P] [US2] Regression test in
  `flowboard-api/tests/Flowboard.Api.Tests/BoardHubTests.cs` (hub-level, per the
  parenthetical — asserting on the delivered `"BoardEvent"` needs a live hub connection,
  which `OrderingTests.cs` has no fixture for): two genuinely concurrent `MoveCardAsync`
  calls (`Task.WhenAll`) on the same card converge to exactly one final list with no
  duplication or loss, and the hub delivers exactly one `"card.moved"` broadcast per
  accepted move — never a duplicated or dropped one (FR-005, SC-003).
  `MoveCard_TwoConcurrentMoves_ConvergeToOnePosition_NoDuplicateOrLostBroadcast`
  deliberately does not assert which of the two destinations wins, or that broadcast
  arrival order matches DB commit order (SignalR delivery isn't synchronized with each
  request's independent commit-then-publish sequence, so a stronger assertion would be
  flaky) — only the two properties the requirements actually demand. **Note (post
  adversarial review)**: the broadcast assertion was tightened from per-element
  containment to an exact sorted-multiset comparison — round 1 found the original form
  would still pass if one destination's broadcast was duplicated while the other's was
  dropped.

- [x] T022 [US2] Four regression tests in `CardsEndpointTests.cs` covering every
  legitimate interleaving of a `MoveCardAsync` and a field-edit `UpdateCardAsync` on the
  same card (FR-006, FR-004): `FieldEdit_ThenMove_BothPersist_NeitherErasesTheOther`
  (field edit first, fresh precondition — both persist),
  `MoveCard_ThenFieldEditWithFreshPrecondition_BothPersist` (move first, then a field
  edit whose precondition reflects the post-move state — both persist),
  `MoveCard_ThenStaleFieldEdit_RejectedWithoutCorruptingTheMove` (move first, then a
  field edit whose precondition predates the move — correctly rejected, move intact),
  and `MoveCard_ConcurrentWithFieldEdit_NeitherCorruptsNorSilentlyErasesTheOther` (a
  genuinely concurrent `Task`-started version, accepting either legitimate outcome, as a
  complementary check that true concurrency doesn't take a different, corruption-prone
  path than either sequential case). **Note (post adversarial review, see
  `human-pr-review.md` — this task went through 4 review rounds)**: the original
  single-test version re-fetched its precondition after the move, silently eliminating
  the race it claimed to test; the fix (round 2) replaced it with the racy version alone,
  which round 2's own reviewer then flagged as unable to prove both interleavings are
  reachable; the two deterministic tests added in response (round 3) initially omitted
  the move-first-with-fresh-precondition case by mistake, caught and restored in round 4.

- [x] T023 [US2] Manual verification: quickstart.md §4 (two-window field-edit conflict and
  concurrent-drag walkthrough). Confirmed via real `dotnet run` + the already-running
  `npm run dev`, two browser tabs on the same card (RT Verify Board, seeded from the
  T019 session): window A's description save succeeded; window B's conflicting save
  (based on the same pre-edit state) was rejected with a "This card was changed by
  someone else. Showing the latest version." toast and immediately showed window A's
  saved text, never B's — FR-004 exactly as specified, not a silent overwrite. Two
  near-simultaneous drags of the same card (A → Doing, B → Done) converged both windows
  to the identical final state (card in Doing only, Done empty, no duplicate/phantom
  card) — FR-005/live sync reconciling both sessions to one outcome.

**Checkpoint**: User Stories 1 AND 2 both work independently — concurrent-edit and
concurrent-move outcomes are confirmed correct and now visible live.

---

## Phase 5: User Story 3 - Recover cleanly after a dropped connection (Priority: P2)

**Goal**: A client whose connection drops shows a visible "reconnecting" signal, and on
reconnect catches up to current server state with no duplicated or missed events.

**Independent Test**: spec.md's US3 Independent Test — simulate a drop, make changes from
another session, restore the connection, confirm full catch-up with a visible indicator
throughout. Executable via quickstart.md §5.

- [x] T024 [US3] Extend `flowboard-web/src/lib/realtime/use-board-realtime.ts` (depends on
  T017): configure `withAutomaticReconnect()`, track connection state
  (`connecting`/`connected`/`reconnecting`/`disconnected`) via `onreconnecting`/
  `onreconnected`/`onclose` handlers, call `utils.boards.getContent.invalidate(...)` and
  re-issue `JoinBoard(boardPublicId)` in `onreconnected` (research.md R-7, contracts/
  realtime-api.md), and expose the current state to callers. **Amendment**: the "no hub
  URL configured" branch's status is computed as the `useState` initializer rather than a
  synchronous `setStatus` call inside the effect — `react-hooks/set-state-in-effect`
  (Next.js 16's ESLint config) flags any direct `setState` in an effect body; this
  environment condition never changes for the component's lifetime, so an initializer is
  equivalent and lint-clean.

- [x] T025 [P] [US3] Create a small connection-status indicator component (e.g.
  `flowboard-web/src/components/layout/realtime-status-indicator.tsx`) rendering
  "live"/"reconnecting"/"offline" states using existing shadcn/ui primitives, per FR-009.

- [x] T026 [US3] Wire the connection state from `use-board-realtime` (T024) into the
  indicator (T025) via `flowboard-web/src/components/layout/top-bar.tsx` and
  `app/(app)/boards/[boardPublicId]/page.tsx`. **Amendment**: TopBar and BoardCanvas are
  page-level siblings, not parent/child (ADR-30) — the one hub connection needs to be
  shared between BoardCanvas (which no longer calls the hook itself) and TopBar's
  indicator without opening a second connection. Added
  `flowboard-web/src/components/board/board-realtime-context.tsx` (not itself a listed
  task file, but the same established shape as `sidebar-context.tsx`/
  `board-filter-context.tsx` — a small client Context Provider for exactly this
  sibling-state problem), and moved the `useBoardRealtime` call from `board-canvas.tsx`
  into that provider. `page.tsx` now wraps `<TopBar>` and `<BoardCanvas>` in
  `<BoardRealtimeProvider boardPublicId={boardPublicId}>` (nested inside the existing
  `BoardFilterProvider`).

- [x] T027 [P] [US3] Integration test in `BoardHubTests.cs`: a client that disconnects and
  reconnects successfully re-joins its board's group and receives subsequent
  `"BoardEvent"` messages, with no event delivered twice (FR-008, SC-004).
  `Reconnect_RejoinsGroupAndReceivesSubsequentEvents_NoDuplicateDelivery` stops and
  restarts the same `HubConnection`, re-invokes `JoinBoard`, and counts `"card.created"`
  broadcasts (that event's payload is empty — `CardService.cs`'s `NewEvent(..., new {})`
  — so the test counts occurrences rather than matching a payload field): one before the
  drop, one made *while* disconnected (must never be delivered — no server-side replay
  buffer exists), one after reconnect — asserting the final count is exactly 2. Done ahead
  of T024–T026 per `docs/sdlc/repository-strategy.md`'s cross-repository rule (backend
  before frontend within a story); full backend gate slice (`dotnet build --warnaserror &&
  dotnet test`, 126/126) run by the assistant as a dev-verification checkpoint, not the
  Done gate.

- [x] T028 [US3] Manual verification: quickstart.md §5 (offline/online toggle, indicator
  behavior, catch-up with no manual reload). Confirmed via a real `dotnet run` (backend)
  against the already-running `npm run dev` (frontend, left over from a prior session's
  manual verification — reused rather than starting a second instance on a different
  port), one browser session on a freshly seeded board: indicator showed "● Live"
  (emerald dot) on load; killing the backend process produced "Reconnecting…" (amber,
  pulsing) within seconds while the board itself stayed fully rendered/usable (lists and
  cards, no error boundary, no blocked interaction); SignalR's default 4-attempt backoff
  (0/2/10/30s) exhausted before the backend came back up in this pass, producing "Offline"
  — the correct `onclose` fallback (FR-012/US4 territory), not a bug. A card created via
  the API immediately after the backend returned did not appear until the page was
  reloaded (expected — the automatic-reconnect window had already closed); reloading
  showed "● Live" again and the card was already present with no data loss, confirming
  FR-008's core guarantee (a fresh connection converges to current state). **Tooling
  limitation, not a code issue** (same class as T019's note): reliably timing a *second*
  backend restart inside the ~2–10s retry window to observe the automatic
  reconnect-without-reload path from the browser was not achievable through this
  session's tool round-trip latency. That exact mechanism (stop → restart → re-`JoinBoard`
  → resume delivery, no duplicate/replayed event) is what T027's automated hub test
  proves directly; the frontend's `onreconnected` handler (T024) implements the identical
  contract (re-invoke `JoinBoard`, invalidate `getContent`) that test validates at the hub
  level. A real two-network-blip check (e.g. toggling Wi-Fi) is worth doing before Done,
  as T019 similarly flagged for its own two-browser-session case.

**Checkpoint**: User Stories 1, 2, and 3 all work independently — dropped connections
recover cleanly and visibly.

---

## Phase 6: User Story 4 - Board stays usable if live updates aren't available (Priority: P3)

**Goal**: A client that can never establish the live channel still gets a fully usable
board via the existing 003–007 behavior, with a manual refresh reflecting others' changes.

**Independent Test**: spec.md's US4 Independent Test — block the live channel, confirm
the board still loads and every existing feature still works, and manual refresh reflects
current data. Executable via quickstart.md §6.

- [ ] T029 [US4] Harden `flowboard-web/src/lib/realtime/use-board-realtime.ts` (depends on
  T024) so a hub connection failure (initial connect or `onclose` after exhausted
  reconnect attempts) is caught and surfaced only as the indicator's "unavailable" state —
  it must never throw, block rendering, or prevent the board page's existing data-fetching
  from working (FR-012).

- [ ] T030 [US4] Manual verification: quickstart.md §6 (hub connection blocked; board still
  loads and every 003–007 feature — create/edit/move cards, board/list management,
  search/filter — still works; a manual refresh still reflects another window's changes).

**Checkpoint**: All four user stories are independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Critical Delivery addendum close-out (`docs/sdlc/critical-delivery.md`) and
final validation across all stories.

- [ ] T031 [P] Run the full quickstart.md walkthrough end-to-end (§1–§7) in one pass;
  retain the results in this directory as the audit evidence Critical Delivery item 3
  requires.

- [ ] T032 Re-read `specs/008-realtime-sync/rollback.md` against what was actually built in
  Phases 2–6 and correct any step that has drifted from the implementation (Critical
  Delivery item 1).

- [ ] T033 Run the gate slice — `dotnet build --warnaserror && dotnet test` in
  `flowboard-api/`, `npm run lint && npm run build` in `flowboard-web/`
  (`docs/sdlc/gate-command.md`). Per CLAUDE.md's Strict Rules, this must be user-executed;
  do not mark this phase Done until the user confirms the exit code.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup. Backend tasks T002–T007 must all complete
  and be gated (repository-strategy.md) before frontend tasks T008–T009. **Blocks every
  user story.**
- **User Story 1 (Phase 3)**: Depends on Foundational only.
- **User Story 2 (Phase 4)**: Depends on Foundational only (US1's broadcast calls, T013,
  make T020/T021's broadcast assertions meaningful, but US2's own conflict/move behavior
  predates this feature — no hard code dependency on Phase 3 tasks beyond that).
- **User Story 3 (Phase 5)**: Depends on Foundational and on T017 (Phase 3) — it extends
  the same hook file.
- **User Story 4 (Phase 6)**: Depends on Foundational and on T024 (Phase 5) — it extends
  the same hook's connection-failure path.
- **Polish (Phase 7)**: Depends on all four user stories being complete.

### Within Each User Story

- Backend tasks precede frontend tasks (repository-strategy.md's cross-repository rule).
- Tests are written before/alongside their corresponding implementation task and must
  fail first where the behavior is new (US1); US2's tests instead confirm no regression in
  already-shipped behavior.
- Story complete (checkpoint) before moving to the next priority.

### Parallel Opportunities

- Foundational: T002 and T003 in parallel; T006 in parallel with T004/T005 (different
  files); T008 in parallel with any backend task once T002–T007 are gated.
- US1: T010, T011, T012 in parallel (same test file, but additive/non-conflicting test
  methods — coordinate on file if worked by different people). T013, T014, T015, T016 in
  parallel (four different service files). T017 in parallel with the backend tasks above.
- US2: T020 and T021 in parallel (different concerns, though possibly the same file —
  check for conflicts if run by different people).
- US3: T025 in parallel with T024; T027 in parallel with T024–T026 (different files).
- US4: single-threaded (both tasks touch/depend on the same hook file in sequence).

---

## Parallel Example: User Story 1

```bash
# Backend broadcast wiring — four independent files:
Task: "Add PublishAsync calls to CardService.cs mutating methods"
Task: "Add PublishAsync calls to ListService.cs mutating methods"
Task: "Add PublishAsync + EvictBoardAsync calls to BoardContentService.cs"
Task: "Add EvictUserAsync call to BoardMembershipService.cs RemoveMemberAsync"

# Hub tests — same file, coordinate if split across people:
Task: "BoardHubTests.cs — JoinBoard success/failure"
Task: "BoardHubTests.cs — BoardEvent shape matches ActivityEvent"
Task: "BoardHubTests.cs — eviction closes connection"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational — **CRITICAL**, blocks all stories; backend gated before
   frontend within this phase too.
3. Complete Phase 3: User Story 1.
4. **STOP and VALIDATE**: run quickstart.md §2/§3/§7 independently (T019).
5. Stop here and get user/gate approval before continuing — CLAUDE.md's "implement one
   phase only" rule applies per user story in this Critical-delivery feature just as it
   does per feature elsewhere.

### Incremental Delivery

1. Setup + Foundational → hub/publisher/token path ready, nothing broadcasts yet.
2. Add US1 → live propagation works → validate independently (MVP).
3. Add US2 → concurrency outcomes confirmed correct and now visible live → validate.
4. Add US3 → reconnect/catch-up works → validate.
5. Add US4 → graceful degradation confirmed → validate.
6. Polish → full quickstart pass, rollback.md re-check, user-executed gate.

### Solo/Small-Team Strategy

Given this repository's actual size (one active branch, sequential feature delivery per
`docs/sdlc/branch-strategy.md`), stories are most realistically implemented in priority
order (US1 → US2 → US3 → US4) rather than staffed in parallel — the parallel-opportunity
notes above exist for the case where more than one person picks up this branch.

---

## Notes

- [P] tasks = different files, no dependency on an incomplete task.
- [Story] label maps each task to spec.md's US1–US4 for traceability.
- This is a Critical-delivery feature (`docs/sdlc/critical-delivery.md`): do not skip
  T031–T033, and do not claim any phase Done without a user-confirmed gate exit code.
- Per CLAUDE.md's Strict Rules: implement one phase (one user story) at a time and stop
  for user approval before continuing to the next.
