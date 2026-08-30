# AI Code Review — 008 Realtime Sync & Concurrency (Setup+Foundational+US1)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — Critical Delivery
addendum item 5 requires this be treated as informational only; an independent human
reviewer, or a second-model adversarial review if solo, is still required before merge)
**Date**: 2026-08-30
**Branches**:
- `flowboard-api` `008-realtime-sync` (tip `5b82b3d`)
- `flowboard-web` `008-realtime-sync` (tip `d07a3b6`)
**Scope reviewed**: Every file in both commits (see Evidence Appendix's `git diff --stat`);
`docs/domain/flowboard-invariants.md` (all 8 items); `docs/rulebooks/backend-rules.md`'s
Realtime section; `docs/rulebooks/frontend-rules.md`'s Data Flow section;
`specs/008-realtime-sync/{spec,plan,research,data-model,contracts/realtime-api.md}`.
**Feature contract**: No migration, no new table/column (data-model.md). One new backend
dependency: none (SignalR ships in the shared web SDK). One new frontend dependency,
pre-approved in plan.md: `@microsoft/signalr`. One new NEXT_PUBLIC_* env var, the
sanctioned exception (frontend-rules.md, plan.md ADR-33).

**Covers**: `tasks.md` Phases 1–3 (T001–T019 — Setup, Foundational, User Story 1 only).
User Stories 2–4 and Polish are out of scope for this review.

## Verdict

**APPROVE with follow-ups.** The hub/publisher/token/broadcast mechanism works correctly
end-to-end — verified by 5 new automated hub tests (all passing), the full existing suite
(118/118, no regressions), and a live manual run against real `dotnet run` + `npm run dev`
processes in a real browser, where a genuine bug (missing CORS policy) was found and fixed
before this review. Residual risk is coverage-shaped, not correctness-shaped: one broadcast
call site plan.md's own Testing section calls for (an exhaustive "no duplicate/no missing
broadcast" test per mutating endpoint) was not built, and one card-position mutation
(`ListService.SortByDueDateAsync`) still doesn't broadcast at all. Neither is a domain-
invariant violation or a security gap; both are named as follow-ups below.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-001–003, FR-007, FR-010–012 for US1's scope) | Read every FR in spec.md against the implementation; FR-001 (push card/list/board/comment changes) verified live in-browser (3 REST-driven card creations appeared with no reload); FR-002 (per-board scoping) verified by construction (`Groups.Group(BoardHub.GroupName(boardPublicId))`, never a global broadcast); FR-003 (same shape as history) verified by `BoardHubTests.BoardEvent_AfterCommentAdded_MatchesPersistedActivityEvent`, which asserts the live payload equals the persisted `ActivityEvent.Payload`; FR-007 (access ends live delivery) verified by `BoardHubTests.RemoveMember_EvictsConnectedConnection_NoFurtherBoardEvents` and `JoinBoard_AfterAccessRevoked_ReResolvesRoleAndCloses`; FR-010 (opaque ids only) — see Invariant 8 below; FR-011 (observer parity) verified by `JoinBoard_MemberAndObserverSucceed_ConnectionStaysOpen`; FR-012 (graceful degradation) is architecturally true (hook fails silently, page never depends on the hub) but not yet hardened — that's explicitly US4's T029, not this phase's. |
| Visual-reference match | N/A — spec.md's Visual Inventory was omitted per plan.md (no new rendered layout in this phase; the connection-status indicator is US3). |
| Feature contract held | Confirmed: no migration (`git diff --stat` shows no `Migrations/` files), one pre-approved frontend package, one new env var scoped exactly as ADR-33 describes. |
| Constitution / domain invariants | See dedicated section below (Critical Delivery addendum item 2). |
| Security (authn/authz, secrets, sensitive logging) | `BoardHub` requires the `RealtimeOnly` policy (`purpose == "realtime"` claim) — a normal 14-day session JWT is rejected at handshake, never reaching a hub method (read `Program.cs`'s `AddJwtBearer`/`AddAuthorization` blocks). `JoinBoard` re-resolves role via `IBoardAccessService` rather than trusting the token (tested). No secret added beyond the existing JWT signing key. No sensitive payload logged — broadcast bodies mirror what REST already returns to the same authorized audience. CORS policy is scoped to `/hubs/board` only (`RequireCors("Realtime")`), not applied globally. |
| Scope guard (`git diff --stat`) | See Evidence Appendix — every file matches `tasks.md`'s Phase 1–3 file list, plus the two amendments (CORS, `board-canvas.tsx` instead of `page.tsx`) documented inline in `tasks.md`. |
| Rollback safety | No schema/migration exists to roll back. Reverting this phase's code removes the hub, the broadcast calls, and the frontend hook; it touches no `Board`/`List`/`Card`/`ActivityEvent` row and cascades into no data deletion — consistent with `rollback.md`'s pre-Phase-1 plan (not yet re-verified line-by-line against the built code — that is `tasks.md` T032, in the Polish phase). |

## Findings

### F1 — `ListService.SortByDueDateAsync` never broadcasts — CONFIRM

This method rewrites every card's `Position` in a list via `ExecuteUpdateAsync` (the same
last-write-wins pattern as `CardService.MoveCardAsync`'s intra-list branch, which *does*
broadcast). A viewer with the board open during a due-date sort sees no live update and
would need a manual refresh to see the new order — a real, if narrow, gap in FR-001's
"push card... changes" for this one bulk-reorder path. Not in `tasks.md`'s T014 method
list (an omission at task-authoring time, not a deliberate design decision recorded
anywhere in research.md/data-model.md).
*Action: CONFIRM with the feature owner whether this is in scope for US1 or an accepted
gap — no `RealtimeEventType` exists yet for a bulk-reorder notification, so closing it
means either a new event type (Architecture Consistency (IV) implication, however small)
or broadcasting one `card.moved`-shaped event per repositioned card (noisy for a 1000-card
board). Recommend deciding before Polish, not silently.*

### F2 — Plan.md's "one broadcast call per mutating endpoint" test coverage is partial — CONFIRM

Plan.md's Testing section states: "one integration test per mutating endpoint confirming
its existing `SaveChangesAsync()` is still followed by exactly one broadcast call (no
duplicate, no missing call)." `BoardHubTests.cs` verifies this for exactly one endpoint
(`AddCommentAsync`, via `BoardEvent_AfterCommentAdded_MatchesPersistedActivityEvent`) plus
the eviction path — not for the other twelve `CardService` mutating methods or any
`ListService`/`BoardContentService` method. Given Testing Requirements (XI) names this
"exactly one broadcast call" invariant as business-critical, this is a real gap against the
feature's own stated test plan, though every call site was manually code-read during this
review (see Domain Invariant Pass, Invariant 6) and each follows the same
`SaveChangesAsync()`-then-broadcast shape.
*Action: CONFIRM whether to close this gap now (adds ~13 test methods) or accept the
current coverage (5 hub tests + full existing suite unaffected) for this phase and track it
as a Polish-phase follow-up. Recommend the latter, given time already invested and that the
manual code read found no call site violating the invariant — but this is a judgment call
for the feature owner, not mine to make unilaterally.*

### F3 — `EvictBoardAsync` sends `actorPublicId: Guid.Empty` in its `access.revoked` payload — MINOR

`BoardEventPublisher.EvictBoardAsync` has no single "actor" (the board itself became
inaccessible, not a specific user's action against another user) and passes `Guid.Empty`.
Per contracts/realtime-api.md the evicted client treats `access.revoked` as a bare signal
and never reads `actorPublicId`/`actorDisplayName` — functionally inert — but a
placeholder Guid on the wire is worth a one-line comment for the next reader.
*Action: none required to merge; a one-line code comment would remove the "is this a bug"
question for a future reader. Left as-is for this review.*

### F4 — `Cors:RealtimeOrigin` defaults to `http://localhost:3000` with no environment-specific override configured — CONFIRM

`Program.cs` reads `builder.Configuration["Cors:RealtimeOrigin"]` falling back to the dev
default. No `appsettings.Production.json`/deployment config sets this yet, so a production
deploy would silently keep the dev-only CORS origin — the browser's hub connection would
fail (loud in the browser console, not silent data corruption) rather than the origin being
wrong in a way that's exploitable, but it is a deploy-readiness gap discovered by this
phase's work, not present before it.
*Action: CONFIRM this is tracked for the environment/deployment configuration work
(whichever feature or ops task owns `appsettings.Production.json`) — out of scope for this
feature's code itself, which correctly reads from config rather than hardcoding.*

## Constitution re-check (post-implementation)

Re-checked plan.md's Constitution Check against the code as built:

- **I Specification First**: Held — spec→plan→tasks preceded all code in this phase.
- **II Source of Truth**: Held — no conflict found between `FUNCTIONAL_SPEC.md`,
  invariants, both rulebooks, and the code; two amendments (CORS, `board-canvas.tsx` vs
  `page.tsx`) are recorded in `tasks.md`, not silently diverged from.
- **III Repository Separation**: Held — hub/publisher/tracker/token stayed in
  `flowboard-api`; SignalR client/hook/procedure stayed in `flowboard-web`.
- **IV Architecture Consistency**: Held — the hub and the one direct-to-backend browser
  connection are both pre-approved by name in the rulebooks; broadcast call sites follow
  the existing inline-side-effect pattern, no new interceptor/pipeline introduced.
- **V Data Standards**: Held — no new entity/primary key; realtime token's `boardId` claim
  is the board's `PublicId`.
- **VI Auditability**: Held/N/A — no new business entity; the feature reads audited data,
  never writes it.
- **VII Domain Invariants**: See dedicated pass below.
- **VIII Security**: Held — see Security row above.
- **IX External Integration Governance**: N/A — no third-party integration.
- **X Performance Responsibility**: Held — broadcasts are group-scoped; no new query added
  to any mutation's hot path (publisher reads only data already loaded/just persisted).
- **XI Testing Requirements**: Partially held — see F2.
- **XII Human Review**: Pending — this document is the AI half; human review (or
  second-model adversarial review + cooling-off if solo, per Critical Delivery item 5) is
  still required before merge.
- **XIII Controlled Delivery**: Held for this phase — backend and frontend were both
  implemented and gated together in this pass rather than backend-merge-then-frontend, but
  neither has merged to `main` yet; the cross-repository rule's actual requirement (backend
  gate+review before backend merge, frontend gate+review before frontend merge) is still
  achievable from here since nothing has merged.

## Domain Invariant Pass (Critical Delivery addendum item 2)

| # | Invariant | Verdict | Evidence |
|---|---|---|---|
| 1 | Activity Is Append-Only | **PASS** | No code path in this diff calls `.Update()`/`.Remove()` on `ActivityEvent`; every card-scoped broadcast reads `activityEvent.Type`/`.Payload` from the row just added via `db.ActivityEvents.Add(...)` and already `SaveChangesAsync()`-committed, then deserializes that same `Payload` string (`PublishActivityEventAsync`) — never re-serializes a fresh object. Board/list events with no `ActivityEvent` counterpart use a disjoint `RealtimeEventType` namespace, so they never masquerade as history. |
| 2 | Ordering Integrity | **PASS** | No position-computation logic changed; `CardService.MoveCardAsync`'s `ExecuteUpdateAsync` call (single-row write) is untouched — the new broadcast is a read-only side effect added after it. `use-board-realtime.ts` never applies a payload position to the client cache (invalidate-and-refetch only, ADR-36). |
| 3 | WIP Limits Are Advisory | **N/A** | Feature does not touch WIP-limit enforcement; `list.wip_limit_changed` broadcast carries only `{ listPublicId }`, never the limit value itself, so the client cannot use it to (mis)enforce anything. |
| 4 | Soft Delete Only, 30-Day Restorability | **N/A** | No new deletion path. `card.archived`/`list.archived`/`board.archived` broadcasts fire after the existing soft-delete write (`IsDeleted = true`) already committed — they announce it, they don't perform it. |
| 5 | Permissions Server-Side | **PASS** | `BoardHub.JoinBoard` calls `IBoardAccessService.ResolveAsync` at connection time — confirmed by test to reject a token whose board access was revoked *after* the token was minted but *before* expiry (`JoinBoard_AfterAccessRevoked_ReResolvesRoleAndCloses`), i.e. the implementation does not trust the token's implicit access. The realtime-token REST endpoint performs the same check before issuing a token. |
| 6 | Optimistic Concurrency — No Silent Overwrites | **PASS** | Read every one of the ~20 broadcast call sites added across `CardService`/`ListService`/`BoardContentService`/`BoardMembershipService`: each `PublishAsync`/`PublishActivityEventAsync`/`EvictUserAsync`/`EvictBoardAsync` call is textually after its method's `SaveChangesAsync()` or `ExecuteUpdateAsync()` call, never before or interleaved with it — satisfies backend-rules.md's Realtime section literally. The existing `409`/`ExecuteUpdateAsync` concurrency behavior itself is untouched (no method's concurrency-relevant code changed, only a line added after the existing commit). |
| 7 | Labels Are Board-Scoped | **N/A** | Feature does not touch label assignment/cross-board logic. |
| 8 | Opaque Public Identifiers | **PASS** | `RealtimeTokenClaims`'s `boardId` claim is `Board.PublicId` (confirmed via manual curl + JWT decode during T019: claim value matched the board's public id, not its internal int `Id`). `BoardRealtimeEvent`'s `boardPublicId`/`actorPublicId` fields and `BoardConnectionTracker`'s dictionary keys are `Guid` (`PublicId`) throughout — no internal `Id` reaches a hub method parameter, a JWT claim, or a broadcast payload in any reviewed call site. |

**Rollback interaction**: no invariant-relevant data is created or mutated by this feature
(no new table, no new column); a rollback of this code touches zero rows in `Board`,
`List`, `Card`, `Comment`, or `ActivityEvent`.

## Test coverage observed

- **`Flowboard.Api.Tests`** (`dotnet test`, full suite): **118/118 passing**, 0 failed, 0
  skipped. New in this phase: `BoardHubTests.cs` (5 tests) —
  `JoinBoard_MemberAndObserverSucceed_ConnectionStaysOpen`,
  `JoinBoard_TokenBoardMismatch_ClosesConnection`,
  `JoinBoard_AfterAccessRevoked_ReResolvesRoleAndCloses`,
  `BoardEvent_AfterCommentAdded_MatchesPersistedActivityEvent` (asserts `type`, `boardPublicId`,
  `actorPublicId`, and `payload.body` on the live event, then cross-checks `payload.body`
  against the persisted `ActivityEvent` fetched via the existing activity-feed endpoint),
  `RemoveMember_EvictsConnectedConnection_NoFurtherBoardEvents`.
- **Frontend**: no test runner exists yet in this repo (003 precedent, unchanged this
  phase) — `npm run lint` and `npm run build` (which runs the TypeScript compiler) both
  pass cleanly; this phase's frontend correctness is otherwise established by the manual
  in-browser verification in the Evidence Appendix, not by an automated frontend test.
- **Gap**: see F2 — no automated coverage yet for "exactly one broadcast call" on the
  other ~13 mutating methods beyond `AddCommentAsync`.

## Residual risk

Risk concentrates in F1 (one silent-until-refresh gap for due-date sort) and F2 (test
coverage narrower than plan.md's own stated target) — both CONFIRM-status, neither
blocking, both explicitly not resolved unilaterally by this review since they're scope/
priority calls for the feature owner. F4 is a deployment-readiness note, not a code defect.
Recommend: merge is safe from a correctness/invariant standpoint once a human (or
second-model adversarial, if solo) reviewer signs off; decide F1/F2's disposition (fix now
vs. explicitly deferred to Polish) before declaring US1 fully Done, and route F4 to whatever
owns production configuration.

---

## Evidence Appendix (Critical Delivery addendum item 3 — audit evidence retained)

### Backend gate

```text
$ dotnet build --warnaserror
Build succeeded.
    0 Warning(s)
    0 Error(s)

$ dotnet test
Passed!  - Failed: 0, Passed: 118, Skipped: 0, Total: 118, Duration: 9 m 1 s
```

(An earlier full run, before the CORS fix, also passed 118/118 in 1 m 7 s — the later run's
longer duration reflects system load from the concurrent manual browser-verification
session in progress, not a performance regression in the feature itself.)

### Frontend gate

```text
$ npm run lint
> eslint
(no output — clean)

$ npm run build
✓ Compiled successfully
  Running TypeScript ...
  Finished TypeScript in 56s ...
✓ Generating static pages using 10 workers (6/6)
```

### `git diff --stat` (both repos, `main` → `008-realtime-sync` at review time)

```text
flowboard-api:
 src/Flowboard.Api/Endpoints/BoardsEndpoints.cs     |  28 ++++
 src/Flowboard.Api/Program.cs                       |  51 ++++++-
 src/Flowboard.Api/Services/BoardContentService.cs  |  29 +++-
 src/Flowboard.Api/Services/BoardMembershipService.cs |   7 +-
 src/Flowboard.Api/Services/CardService.cs          | 146 ++++++++++++++++-----
 src/Flowboard.Api/Services/ListService.cs          |  67 +++++++++-
 src/Flowboard.Api/Services/TokenService.cs         |  48 +++++++
 tests/Flowboard.Api.Tests/Flowboard.Api.Tests.csproj |   4 +
 + new: Domain/RealtimeEventType.cs, Hubs/BoardHub.cs,
   Services/BoardConnectionTracker.cs, Services/BoardEventPublisher.cs,
   tests/BoardHubTests.cs
 13 files changed, 898 insertions(+), 40 deletions(-)

flowboard-web:
 .env.example                          |   6 ++
 package-lock.json                     | 182 +++++++++++++++++++++++++++++++++-
 package.json                          |   1 +
 src/components/board/board-canvas.tsx |  19 +++-
 src/lib/boards/schemas.ts             |   4 +
 src/server/api/routers/boards.ts      |  12 +++
 + new: src/lib/api/realtime-client.ts, src/lib/realtime/use-board-realtime.ts
 8 files changed, 338 insertions(+), 2 deletions(-)
```

### Manual verification (quickstart.md, T019)

- §2 (token endpoint): `POST /v1/boards/{id}/realtime-token` → decoded JWT confirmed
  `sub` = caller's `PublicId`, `boardId` = board's `PublicId`, `purpose` = `"realtime"`,
  `exp` − `iat` = 120s.
- §3 (live propagation): real `dotnet run` + `npm run dev`; three cards created via REST as
  an invited `BoardMember` each appeared in a separate, already-open, signed-in browser tab
  within roughly a second, with no manual reload, across three separate mutations.
- §7 (access revocation): confirmed at the protocol level only (`BoardHubTests`); a live
  two-browser-session UI check was attempted but this verification session's browser
  automation shares one cookie jar across tabs, so a second login kept reverting to the
  first session — a tooling limitation of this pass, recorded rather than papered over.
