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

---

# AI Code Review — 008 Realtime Sync & Concurrency (US2)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — Critical Delivery
addendum item 5 requires this be treated as informational only; an independent human
reviewer, or a second-model adversarial review if solo, is still required before merge)
**Date**: 2026-08-30
**Branches**:
- `flowboard-api` `008-realtime-sync` (tip `1122466`)
- `flowboard` (governance/specs repo) `008-realtime-sync` (tip `5bcb888`)
**Scope reviewed**: `tests/Flowboard.Api.Tests/CardsEndpointTests.cs` and
`tests/Flowboard.Api.Tests/BoardHubTests.cs` (the only files this phase's diff touches —
see `git diff --stat` in the Evidence Appendix); the underlying production code these
tests exercise and did not change (`CardService.UpdateCardAsync`/`MoveCardAsync`,
`CardConfiguration.cs`'s `RowVersion` mapping); `specs/008-realtime-sync/tasks.md`
Phase 4; `docs/domain/flowboard-invariants.md` invariants 1, 5, 6, 8 (the ones this phase
touches or could touch).
**Feature contract**: No migration, no new table/column, no new package — Phase 4's own
scope statement in `tasks.md` is "regression tests, not new production code, unless a gap
is found"; no gap was found, so the diff is test-only (confirmed below).

**Covers**: `tasks.md` Phase 4 (T020–T023 — User Story 2 only). US1 was reviewed
separately above; US3/US4/Polish remain out of scope for this review.

## Verdict

**APPROVE.** This phase adds three regression tests and performs one manual two-window
walkthrough; it changes no production code, which is the correct outcome per plan.md's
own framing ("this feature does not renegotiate concurrency rules"). All three tests
pass individually and as part of the full 121/121 suite, each test's assertions match
what it claims to prove (traced against the actual `CardService` code paths, not just
run), and the manual walkthrough reproduced both US2 acceptance scenarios live with
screenshot evidence. One MINOR test-robustness note (F1) carried over from this
codebase's existing hub-test convention, not introduced by this phase; no BLOCKING or
CONFIRM findings.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-004, FR-005, FR-006, SC-002, SC-003 for US2's scope) | FR-004 (no silent overwrite) verified by `UpdateCard_StaleIfMatch_RejectedSaveNeverPersistsOrBroadcasts`: traced `CardService.cs` lines 235–248 — the `catch (DbUpdateConcurrencyException)` returns *before* the `foreach`/`PublishActivityEventAsync` loop, so a rejected save cannot reach either persistence or broadcast; the test proves this via the activity feed (exactly one `CardRenamed` entry, the winner's) rather than asserting a hub non-event, and separately confirms the loser is shown current data and can retry. FR-005/SC-003 (concurrent moves converge, no dup/loss) verified by `MoveCard_TwoConcurrentMoves_ConvergeToOnePosition_NoDuplicateOrLostBroadcast` using genuine `Task.WhenAll` concurrency (not sequential calls dressed up as concurrent) — traced `CardService.MoveCardAsync` lines 839–846: `ExecuteUpdateAsync` has no `WHERE RowVersion=...` clause, confirming last-write-wins is real, not incidental. FR-006 (move + field edit, neither erases the other) verified by `MoveCard_ThenFieldEdit_BothPersist_NeitherErasesTheOther`, which also documents *why* it re-fetches the field edit's `If-Match` after the move rather than racing a stale one against it (see Finding discussion below — this is a deliberate, correct scope choice, not a gap). |
| Visual-reference match | N/A — no UI change in this phase. |
| Feature contract held | Confirmed: `git diff --stat` (Evidence Appendix) shows exactly 2 files, both test files, 143 insertions, 0 deletions — no production file touched, no migration, no package change. |
| Constitution / domain invariants | See dedicated section below. |
| Security (authn/authz, secrets, sensitive logging) | No new endpoint, no new auth path. Tests reuse the existing fixture-owner/invited-client authorization helpers already used throughout `CardsEndpointTests.cs`/`BoardHubTests.cs` — no new credential or token-handling code introduced. |
| Scope guard (`git diff --stat`) | Matches `tasks.md`'s Phase 4 file list exactly (`CardsEndpointTests.cs`, `BoardHubTests.cs`) — see Evidence Appendix. |
| Rollback safety | No schema/migration exists in this phase to roll back; reverting it only removes three test methods, touching zero production code and zero data. |

## Findings

### F1 — Fixed `Task.Delay(1s)` buffer before asserting broadcast count — MINOR

`MoveCard_TwoConcurrentMoves_ConvergeToOnePosition_NoDuplicateOrLostBroadcast` waits a
flat 1 second after both moves complete, then asserts `movedEvents.Count == 2`, rather
than waiting on a completion signal for exactly 2 events the way
`BoardEvent_AfterCommentAdded_MatchesPersistedActivityEvent` and
`RemoveMember_EvictsConnectedConnection_NoFurtherBoardEvents` wait on a
`TaskCompletionSource` for one specific event. Under unusual system load (as actually
observed once during this feature's own US1 manual-verification pass, per the first
review's Evidence Appendix note on a slower `dotnet test` run), a fixed delay is
theoretically flakier than an event-counted wait. This matches an existing pattern
already in this test file for the *other* eviction assertion in the same test
(`RemoveMember_EvictsConnectedConnection_NoFurtherBoardEvents` also uses a flat
`Task.Delay(1s)` for its negative-count check, since there's no positive signal to wait
on for "no more events arrive") — so this isn't a new convention, and the test passed
cleanly across three separate full-suite runs during this phase (see Evidence Appendix).
*Action: none required to merge; if this test is ever seen to flake in CI, tighten it to
a short polling loop with a longer ceiling rather than a single fixed sleep.*

### Carried forward from the US1 review (not re-decided here)

F1 (`ListService.SortByDueDateAsync` never broadcasts), F2 (partial "one broadcast per
mutating endpoint" test coverage — this phase adds coverage for `UpdateCardAsync` and
`MoveCardAsync`, narrowing but not closing that gap), and F4 (no environment-specific
`Cors:RealtimeOrigin` override) are all still open and untouched by this phase's diff —
none are re-assessed here since Phase 4 changes no production code they'd interact with.

## Constitution re-check (post-implementation)

- **I Specification First**: Held — spec/plan/tasks already existed; this phase only
  implemented Phase 4 exactly as `tasks.md` describes it (regression tests, no new prod
  code, since no gap was found).
- **VII Domain Invariants**: See dedicated pass below — this phase exists specifically to
  confirm invariant 6.
- **XI Testing Requirements**: Held for this phase's own scope — plan.md's Testing
  section calls for regression coverage of the existing concurrency rules under the new
  broadcast calls; T020–T022 deliver exactly that.
- **XII Human Review**: Pending — this document is the AI half; human review (or
  second-model adversarial + cooling-off if solo) is still required before merge.
- All other principles: unaffected by a test-only diff; see the US1 review above for
  their full-feature assessment, unchanged by this phase.

## Domain Invariant Pass (Critical Delivery addendum item 2)

| # | Invariant | Verdict | Evidence |
|---|---|---|---|
| 1 | Activity Is Append-Only | **PASS** | `UpdateCard_StaleIfMatch_RejectedSaveNeverPersistsOrBroadcasts` confirms the rejected save adds zero `ActivityEvent` rows (exactly one `CardRenamed` entry exists, the winner's) — the rejected write never reaches `db.ActivityEvents.AddRange`'s persisted counterpart, matching append-only-and-never-diverged-from-history for the loser. |
| 5 | Permissions Server-Side | **N/A** | Not exercised by this phase's tests — no new endpoint or auth path added; unchanged from the US1 review. |
| 6 | Optimistic Concurrency — No Silent Overwrites | **PASS** | This is the invariant this phase exists to confirm. `UpdateCard_StaleIfMatch_RejectedSaveNeverPersistsOrBroadcasts` proves the reject-and-refetch field-edit path is unbroken by US1's broadcast calls. `MoveCard_TwoConcurrentMoves_ConvergeToOnePosition_NoDuplicateOrLostBroadcast` proves genuinely concurrent last-write-wins moves still converge to exactly one position with no duplicated/missing card. `MoveCard_ThenFieldEdit_BothPersist_NeitherErasesTheOther` proves the two concurrency mechanisms (whole-row `RowVersion` precondition vs. precondition-free `ExecuteUpdateAsync`) don't clobber each other's disjoint columns. All three confirm existing (004/005) behavior is unchanged by this feature, per plan.md's explicit claim. |
| 8 | Opaque Public Identifiers | **PASS** | Every new test asserts and constructs URLs using `PublicId` values exclusively (`card.PublicId`, `board.PublicId`, `destinationAPublicId`, etc.), consistent with every existing test in both files — no internal `Id` surfaced anywhere in the new code. |

**Rollback interaction**: no invariant-relevant data is created or mutated by this phase's
diff (test code only); there is nothing to roll back beyond the three test methods
themselves.

## Test coverage observed

- **`Flowboard.Api.Tests`** (`dotnet test`, full suite, re-run during this review):
  **121/121 passing**, 0 failed, 0 skipped (up from 118 in the US1 review — 3 new tests,
  0 regressions). New in this phase:
  `UpdateCard_StaleIfMatch_RejectedSaveNeverPersistsOrBroadcasts` and
  `MoveCard_ThenFieldEdit_BothPersist_NeitherErasesTheOther` (`CardsEndpointTests.cs`),
  `MoveCard_TwoConcurrentMoves_ConvergeToOnePosition_NoDuplicateOrLostBroadcast`
  (`BoardHubTests.cs`).
- **Frontend**: no change this phase; not re-verified (no frontend file touched).
- **Manual verification** (quickstart.md §4, T023): performed live against real
  `dotnet run` + `npm run dev` processes, two browser tabs on the same card. Both US2
  acceptance scenarios reproduced and screenshotted: window B's stale save rejected with
  a "This card was changed by someone else. Showing the latest version." toast, showing
  window A's saved text rather than overwriting it; two near-simultaneous drags to
  different lists converged both windows to the identical final state (card in exactly
  one list, the other left empty — no duplicate/phantom card).

## Residual risk

Negligible for this phase in isolation — test-only diff, all findings MINOR or carried
forward from a prior phase's still-open items. Residual risk for the feature overall
still concentrates where the US1 review placed it (F1/F2/F4 there), unchanged by this
phase. Safe to merge Phase 4 once a human (or second-model adversarial, if solo)
reviewer signs off, independent of those carried-forward items' disposition.

---

## Evidence Appendix (Critical Delivery addendum item 3 — audit evidence retained)

### Backend gate (re-run during this review)

```text
$ dotnet build --warnaserror
Build succeeded.
    0 Warning(s)
    0 Error(s)

$ dotnet test
Passed!  - Failed: 0, Passed: 121, Skipped: 0, Total: 121, Duration: 1 m 3 s
```

(User separately ran the gate and confirmed exit 0 before requesting this review and the
commit.)

### `git diff --stat` (Phase 4 commit, `flowboard-api`)

```text
tests/Flowboard.Api.Tests/BoardHubTests.cs      | 61 ++++++++++++++++++
tests/Flowboard.Api.Tests/CardsEndpointTests.cs | 82 +++++++++++++++++++++++++
2 files changed, 143 insertions(+)
```

### Manual verification (quickstart.md §4, T023)

- Two browser tabs opened the same card's detail modal (RT Verify Board, the board
  seeded during the US1 manual-verification pass).
- Window A saved a description edit first — succeeded, toast "Description saved."
- Window B, still showing the pre-edit (empty) description, saved a different edit based
  on the same stale precondition — rejected with toast "This card was changed by someone
  else. Showing the latest version," and the field immediately displayed window A's
  saved text, not window B's attempted overwrite.
- Both windows then dragged the same card to different destination lists (Doing vs.
  Done) within the same few seconds. After settling, both windows converged to an
  identical final state: the card in "Doing" only, "Done" empty, no duplicate or phantom
  card in either list.

---

# AI Code Review — 008 Realtime Sync & Concurrency (US3)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — Critical Delivery
addendum item 5 requires this be treated as informational only; an independent human
reviewer, or a second-model adversarial review if solo, is still required before merge)
**Date**: 2026-08-31
**Branches**:
- `flowboard-api` `008-realtime-sync` (tip `41d5830`)
- `flowboard-web` `008-realtime-sync` (tip `2503c86`)
- `flowboard` (governance/specs repo) `008-realtime-sync` (tip `c967c62`)
**Scope reviewed**: `flowboard-web/src/lib/realtime/use-board-realtime.ts`,
`flowboard-web/src/components/board/board-realtime-context.tsx` (new),
`flowboard-web/src/components/layout/realtime-status-indicator.tsx` (new),
`flowboard-web/src/components/layout/top-bar.tsx`,
`flowboard-web/src/app/(app)/boards/[boardPublicId]/page.tsx`,
`flowboard-web/src/components/board/board-canvas.tsx`,
`flowboard-api/tests/Flowboard.Api.Tests/BoardHubTests.cs` (new test), and
`flowboard-api/src/Flowboard.Api/Hubs/BoardHub.cs` (unchanged this phase, read to trace
what `JoinBoard` does on failure — `Context.Abort()`, no explicit rejection message);
`specs/008-realtime-sync/tasks.md` Phase 5; `contracts/realtime-api.md`'s Connection
lifecycle section; `docs/domain/flowboard-invariants.md` (all 8 items).
**Feature contract**: No migration, no new table/column, no new package, no new endpoint
— this phase is client-side reconnect/status UI plus one backend hub test confirming the
existing `JoinBoard`/group-membership contract holds across a reconnect.

**Covers**: `tasks.md` Phase 5 (T024–T028 — User Story 3 only). US1/US2 were reviewed
separately above; US4/Polish remain out of scope for this review.

## Verdict

**APPROVE with follow-ups.** The reconnect/status-indicator mechanism works correctly for
the common case — verified by a new hub-level integration test (stop/restart/rejoin, no
duplicate or replayed delivery), the full existing suite (126/126, no regressions), and a
live manual run against real `dotnet run` + `npm run dev` where the indicator was observed
transitioning Live → Reconnecting → Offline and a post-outage reload correctly caught up
with no data loss. One real gap (F1) was found by tracing the failure path of a reconnect
that races an access revocation: the client neither surfaces the failure cleanly (an
unhandled promise rejection) nor re-syncs board content along that specific path. It is
narrow (disconnected + access revoked while disconnected + then reconnect) and
self-correcting within a few hundred milliseconds (the indicator does end up showing
"Offline"), not a security gap or silent data corruption — a CONFIRM, not BLOCKING.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-008, FR-009, SC-004 for US3's scope) | FR-009 (visible signal when the connection is down) verified live in-browser: killing the backend process produced "● Reconnecting…" (amber, pulsing) within seconds, and "● Offline" (grey) once SignalR's default reconnect policy (0/2/10/30s) was exhausted — screenshots taken during this phase's manual pass. FR-008 (no missed change left unreflected after reconnect) is proven at the protocol level by the new hub test `Reconnect_RejoinsGroupAndReceivesSubsequentEvents_NoDuplicateDelivery` (traced: stops/restarts the same `HubConnection`, re-invokes `JoinBoard`, and asserts the final `card.created` count is exactly 2 — the pre-drop and post-reconnect cards, never the while-offline one, never a duplicate) and reproduced live via reload-based catch-up (a card created via the API immediately after the backend returned was absent until reload, then present with no loss — consistent with FR-008's "converges to current state," though see F1 for the one path where convergence doesn't happen automatically). SC-004 (reconnect within 60s converges with zero duplicated/missing events) — the hub test's assertion window (10s) is well inside SC-004's 60s bound; not separately re-tested at the 60s boundary. |
| Visual-reference match | N/A — plan.md's Constitution Check already noted this feature adds no new rendered layout beyond the small status indicator, which has no prototype reference to compare against; confirmed by direct observation instead (Evidence Appendix). |
| Feature contract held | Confirmed: `git diff --stat` (Evidence Appendix) shows no migration, no `package.json` change, no new endpoint — every file is either an existing file this phase extends or a small new client component/context. |
| Constitution / domain invariants | See dedicated section below. |
| Security (authn/authz, secrets, sensitive logging) | No new auth surface. Reconnect re-invokes the existing `JoinBoard`, which re-runs `IBoardAccessService.ResolveAsync` (`BoardHub.cs:28`, unchanged this phase) — access is re-checked on every join, not cached from the original connection. No secret added; no new logging. |
| Scope guard (`git diff --stat`) | Matches `tasks.md`'s Phase 5 file list, plus the one documented amendment (`board-realtime-context.tsx`, not itself a listed task file but the same established sibling-state-sharing shape as `sidebar-context.tsx`/`board-filter-context.tsx`, noted inline in `tasks.md`'s T026 entry). |
| Rollback safety | No schema/migration exists in this phase. Reverting removes the reconnect handlers, the status context/indicator, and the one hub test — touches zero `Board`/`List`/`Card`/`ActivityEvent` rows. |

## Findings

### F1 — A `JoinBoard` failure on reconnect (e.g., access revoked while disconnected) is an unhandled rejection and never re-syncs board content — CONFIRM

`use-board-realtime.ts`'s `onreconnected` handler (line 64) does:

```ts
connection.onreconnected(() => {
  setStatus("connected");
  void connection.invoke("JoinBoard", boardPublicId);
  void utilsRef.current.boards.getContent.invalidate({ boardPublicId });
});
```

`BoardHub.JoinBoard` (`BoardHub.cs:28-33`) calls `Context.Abort()` — not an exception
returned to the caller — when the caller's role no longer resolves. Tracing the existing
`JoinBoard_TokenBoardMismatch_ClosesConnection`/`JoinBoard_AfterAccessRevoked_
ReResolvesRoleAndCloses` hub tests (both wrap their `InvokeAsync("JoinBoard", ...)` in a
`try/catch`, with a comment noting the abort "can surface as a connection error here")
confirms `connection.invoke(...)` genuinely rejects when the server aborts mid-call — this
is exercised behavior, not a hypothetical. In the initial connect path (`connection.start()
.then(() => connection.invoke("JoinBoard", ...))`, line 72-79), that rejection is caught by
the chain's trailing `.catch()`. In `onreconnected`, the same call is `void`-fired with no
`.catch()` — a genuine inconsistency between the two call sites for the exact same
invocation.

Concretely, this matters for one edge case named in spec.md itself ("A member is removed
from a board... while they are actively viewing it"): if the member is *disconnected* at
the moment they're removed, the targeted `access.revoked` `BoardEvent`
(`BoardEventPublisher.EvictUserAsync`) has no connection to reach — nothing is tracked for
them at that moment. When they later reconnect, `JoinBoard` fails immediately and the
connection is aborted, but `getContent` is never invalidated along this specific path (the
unconditional `invalidate` two lines below only runs because `onreconnected` fired at all,
not conditioned on `JoinBoard` having actually succeeded) — so the stale, no-longer-
accessible board content is not immediately replaced with the "no access" state T018
established for the tracked-eviction case. The status indicator is not permanently wrong
(`onclose` fires shortly after the abort and flips it to "Offline"), but the board content
itself stays stale until a manual refresh, and the browser console logs an unhandled
promise rejection in the meantime.
*Action: CONFIRM whether to fix now or defer. A narrow fix exists — chain a `.catch()` onto
the `onreconnected` invoke that also calls `getContent.invalidate(...)`, treating a failed
rejoin the same as a received `access.revoked` event — but this is a judgment call for the
feature owner on timing (US3 vs. a fast-follow), not mine to make unilaterally. Not
BLOCKING: the scenario requires being disconnected at the exact moment access is revoked,
self-corrects to "Offline" within one reconnect cycle, and leaks no data to an unauthorized
viewer (the hub still refuses the rejoin).*

## Constitution re-check (post-implementation)

- **I Specification First**: Held — T024–T028 implemented exactly as `tasks.md` describes.
- **III Repository Separation**: Held — the hub test stayed in `flowboard-api`; the
  reconnect hook/context/indicator stayed in `flowboard-web`.
- **IV Architecture Consistency**: Held — `board-realtime-context.tsx` reuses the
  already-established sibling-state Context Provider shape (`sidebar-context.tsx`,
  `board-filter-context.tsx`) rather than introducing a new state-sharing mechanism; no new
  UI library, no new package.
- **V Data Standards**: N/A — no new entity.
- **VI Auditability**: N/A — no new business entity.
- **VII Domain Invariants**: See dedicated pass below.
- **VIII Security**: Held — see Security row above; F1 does not grant unauthorized access,
  it only delays the *client-side signal* that access is gone.
- **IX External Integration Governance**: N/A.
- **X Performance Responsibility**: Held — no new query added to any hot path; reconnect
  handling is event-driven, not polling.
- **XI Testing Requirements**: Held for the hub/server contract (T027, automated). The
  frontend reconnect UI itself has no automated test — unchanged limitation from every
  prior phase in this repo (no frontend test runner exists yet, 003 precedent) — covered
  instead by manual verification (T028), which is where F1's specific failure path was
  *not* exercised (the manual pass tested the happy-path drop/restore, not a
  drop-then-access-revoked-then-reconnect sequence).
- **XII Human Review**: Pending — this document is the AI half; human review (or
  second-model adversarial + cooling-off if solo, per Critical Delivery item 5) is still
  required before merge.
- **XIII Controlled Delivery**: Held — T027 (backend) was implemented, tested, and gated
  before T024–T026 (frontend), per `docs/sdlc/repository-strategy.md`'s cross-repository
  rule.

## Domain Invariant Pass (Critical Delivery addendum item 2)

| # | Invariant | Verdict | Evidence |
|---|---|---|---|
| 1 | Activity Is Append-Only | **N/A** | This phase writes no `ActivityEvent` row and adds no new broadcast call site — it only changes how the client reacts to the connection lifecycle. |
| 2 | Ordering Integrity | **N/A** | No position-computation logic touched. |
| 3 | WIP Limits Are Advisory | **N/A** | Not touched. |
| 4 | Soft Delete Only, 30-Day Restorability | **N/A** | No new deletion path. |
| 5 | Permissions Server-Side | **PASS (with F1 caveat)** | `JoinBoard`'s existing `IBoardAccessService.ResolveAsync` re-check (`BoardHub.cs:28`, unchanged) runs on *every* join, including a post-reconnect rejoin — confirmed by this phase's own hub test, which only receives events again after re-invoking `JoinBoard`. The server-side enforcement itself is correct and unaffected by this phase; F1 is a client-side signal-surfacing gap, not a permissions gap — no unauthorized access is ever granted. |
| 6 | Optimistic Concurrency — No Silent Overwrites | **N/A** | Untouched by this phase; US2 already confirmed this invariant holds under the live channel. |
| 7 | Labels Are Board-Scoped | **N/A** | Not touched. |
| 8 | Opaque Public Identifiers | **PASS** | The new hub test uses `board.PublicId` exclusively (never an internal `Id`); the reconnect hook and context continue to key everything by the `boardPublicId` prop already threaded through since T017/T018 — no new identifier surface introduced. |

**Rollback interaction**: no invariant-relevant data is created or mutated by this phase's
diff; reverting it touches zero rows in any table.

## Test coverage observed

- **`Flowboard.Api.Tests`** (`dotnet test`, full suite, re-run during this review):
  **126/126 passing**, 0 failed, 0 skipped (up from 121 after the US2 review — 5 new tests
  from the frontend-parallel batch plus 1 new in this phase). New in this phase:
  `Reconnect_RejoinsGroupAndReceivesSubsequentEvents_NoDuplicateDelivery`. Scope note: this
  test simulates a drop via a manual `StopAsync()`/`StartAsync()` on the same
  `HubConnection` (the .NET SignalR test client has no `withAutomaticReconnect()`
  equivalent) — it validates the *server-side* contract ("a new connection must
  `JoinBoard` again to receive events, and nothing is replayed for the gap") rather than
  the frontend's automatic-reconnect timing/backoff policy itself, which has no automated
  coverage (see XI above).
- **Frontend**: no test runner exists yet (003 precedent, unchanged) — `npm run lint` and
  `npm run build` both pass cleanly; correctness otherwise established by the manual
  in-browser verification (T028), which did not happen to exercise F1's specific failure
  path.
- **Manual verification** (quickstart.md §5, T028): real `dotnet run` + `npm run dev`,
  one browser session. Indicator showed "● Live" on load; killing the backend produced
  "● Reconnecting…" while the board stayed fully usable; the indicator settled to
  "● Offline" once automatic reconnect exhausted its attempts; a reload after the backend
  returned showed "● Live" again with a card created during the outage already present, no
  data loss. The tighter "reconnect succeeds automatically, no reload" path and F1's
  specific race were not reproduced live — documented as tooling/time limitations in
  `tasks.md`'s T028 note, not silently skipped.

## Residual risk

Risk concentrates entirely in F1 — narrow, self-correcting, not a security or data-loss
issue, but a real gap against FR-008's "no missed change left unreflected" for one specific
race. Everything else in this phase (the common reconnect path, the status indicator, the
sibling-state sharing, the hub-side re-authorization contract) is verified working and
introduces no new invariant, security, or architectural risk. Safe to merge once a human
(or second-model adversarial, if solo) reviewer signs off; recommend deciding F1's
disposition (fix now vs. tracked follow-up) explicitly rather than silently, consistent with
how F1/F2/F4 were handled in the US1 review.

### F1 — Disposition: FIXED (post-review, same cycle)

The feature owner elected to fix rather than defer. `use-board-realtime.ts`'s
`onreconnected` handler now chains a `.catch()` onto the `JoinBoard` re-invoke, matching
the initial-connect path's existing error handling:

```ts
connection.onreconnected(() => {
  setStatus("connected");
  connection
    .invoke("JoinBoard", boardPublicId)
    .catch(() => {
      setStatus("disconnected");
    });
  void utilsRef.current.boards.getContent.invalidate({ boardPublicId });
});
```

A failed rejoin (the `Context.Abort()` case traced above) now flips the indicator to
"Offline" immediately instead of leaving an unhandled promise rejection and a
"connected"-labeled indicator over stale content — closing the client-side signal gap.
Note the unconditional `getContent.invalidate` two lines below is unchanged and still
correct: it is not conditioned on `JoinBoard` succeeding because a *successful* reconnect
still needs the cache refresh to catch up on any events missed while offline (FR-008); a
*failed* rejoin invalidates a query the client can no longer read anyway (harmless no-op
via existing 403 handling, not a new failure mode). Re-verified: `npm run lint` clean
(no new warnings, including no new `react-hooks/set-state-in-effect` violation from the
added `setStatus` call inside the `.catch()`, which is inside a connection-lifecycle
callback, not inside the `useEffect` body itself — the same shape already accepted for
`onreconnecting`/`onclose`).

---

## Evidence Appendix (Critical Delivery addendum item 3 — audit evidence retained)

### Backend gate (re-run during this review)

```text
$ dotnet build --warnaserror
Build succeeded.
    0 Warning(s)
    0 Error(s)

$ dotnet test
Passed!  - Failed: 0, Passed: 126, Skipped: 0, Total: 126, Duration: 2 m 44 s
```

(User separately ran the gate — both `flowboard-api`'s and `flowboard-web`'s — and
confirmed exit 0 for both before requesting this review; recorded in `tasks.md`'s Phase 5
Gate line and this branch's `c967c62` commit.)

### Frontend gate

```text
$ npm run lint
> eslint
(no output — clean)

$ npm run build
✓ Compiled successfully in 2.7s
  Running TypeScript ...
  Finished TypeScript in 5.1s ...
✓ Generating static pages using 10 workers (6/6)
```

### `git diff --stat` (Phase 5 commits)

```text
flowboard-api (41d5830):
 tests/Flowboard.Api.Tests/BoardHubTests.cs | 77 ++++++++++++++++++++++++++++++
 1 file changed, 77 insertions(+)

flowboard-web (2503c86):
 src/app/(app)/boards/[boardPublicId]/page.tsx      | 21 ++++++++----
 src/components/board/board-canvas.tsx              |  3 --
 src/components/board/board-realtime-context.tsx    | 31 +++++++++++++++++
 src/components/layout/realtime-status-indicator.tsx| 27 +++++++++++++++
 src/components/layout/top-bar.tsx                  |  7 +++-
 src/lib/realtime/use-board-realtime.ts             | 39 +++++++++++++++++++---
 6 files changed, 112 insertions(+), 16 deletions(-)

flowboard (governance repo, c452bb6 + c967c62):
 specs/008-realtime-sync/tasks.md | 74 ++++++++++++++++++++++++++++++++++------
 1 file changed, 63 insertions(+), 11 deletions(-)
```

### Manual verification (quickstart.md §5, T028)

- Fresh user/board seeded via API; logged into the real Next.js dev server, board opened —
  indicator showed "● Live" (emerald dot).
- Backend process killed: indicator transitioned to "● Reconnecting…" (amber, pulsing)
  within seconds; board remained fully rendered and interactive throughout (lists/cards
  visible, no error boundary).
- SignalR's default 4-attempt backoff (0/2/10/30s) exhausted before the backend returned in
  this pass; indicator correctly settled to "● Offline" (the `onclose` fallback,
  US4-territory but confirms the hook doesn't get stuck in an intermediate state).
- A card created via the API immediately after the backend returned did not appear until
  the page was reloaded (expected — the automatic-reconnect window had already closed by
  then); reloading showed "● Live" again with the card already present, no data loss.

# AI Code Review — 008 Realtime Sync & Concurrency (US4)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — Critical Delivery
addendum item 5 requires this be treated as informational only; an independent human
reviewer, or a second-model adversarial review if solo, is still required before merge)
**Date**: 2026-08-31
**Branches**:
- `flowboard-api` `008-realtime-sync` (tip `41d5830`, unchanged this phase)
- `flowboard-web` `008-realtime-sync` (tip `52b7338`)
- `flowboard` (governance/specs repo) `008-realtime-sync` (tip `dbf318d` at review start)
**Scope reviewed**: `flowboard-web/src/lib/realtime/use-board-realtime.ts` (only file
touched this phase); `specs/008-realtime-sync/tasks.md` Phase 6; `contracts/realtime-api.md`'s
Connection lifecycle section; `docs/domain/flowboard-invariants.md` (all 8 items, to confirm
none apply to a client-side-only change).
**Feature contract**: No migration, no new table/column, no new package, no new endpoint,
no backend change at all — this phase is one defensive try/catch in an existing client hook.

**Covers**: `tasks.md` Phase 6 (T029–T030 — User Story 4 only). US1/US2/US3 were reviewed
separately above; Polish remains out of scope for this review.

## Verdict

**APPROVE.** This is the smallest possible change that closes the one remaining gap FR-012
names: a synchronous throw out of `use-board-realtime.ts`'s effect (from
`HubConnectionBuilder.build()`, which validates `NEXT_PUBLIC_FLOWBOARD_HUB_URL` synchronously
and has no schema validation anywhere upstream) would propagate through
`BoardRealtimeProvider`, which has no error boundary, and take down the whole board page —
directly contradicting FR-012's "board MUST remain fully usable." Every other hardening
target named in T029's own description (a failed `connection.start()`, `onclose` after
exhausted reconnect attempts) was already caught as of T024/T028's `.catch()` handlers; T029
correctly scoped itself to the one gap those didn't cover rather than re-doing already-solved
work.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-012 for US4's scope) | Verified live in two ways. (1) Hub pointed at an unreachable port (backend up, only the hub unreachable — the actual US4 scenario, not a full outage): board loaded, indicator settled to "● Offline", create/search/filter all worked via the unaffected REST/tRPC path, and a card created directly via `POST /v1/lists/{id}/cards` (simulating another window) appeared after a manual reload with no live channel involved — both spec.md Acceptance Scenarios for US4 hold. (2) Hub URL set to a value chosen to probe the new synchronous-throw guard (`not a valid url`): this did *not* actually reach the new try/catch — browsers resolve almost any non-empty string as a valid relative URL against the document's base, so `HubConnectionBuilder.build()` didn't throw even here, and the run instead exercised the pre-existing async-failure path (negotiate got Next.js's own HTML fallback page back, treated as a connection failure). No realistic way was found to force a live synchronous throw from a browser tab; see Findings for what this means for confidence in the fix. |
| Visual-reference match | N/A — no new rendered UI; the indicator's "Offline" presentation already existed as of US3. |
| Feature contract held | Confirmed: `git diff --stat` (Evidence Appendix) shows one file changed, no migration, no `package.json` change, no new endpoint. |
| Constitution / domain invariants | No domain invariant applies — this touches connection setup only, no `Board`/`List`/`Card`/`ActivityEvent` read or write path. |
| Security (authn/authz, secrets, sensitive logging) | No change to any auth surface; the catch block logs nothing (no `console.error`/`console.log` added) and carries no secret. |
| Scope guard (`git diff --stat`) | Matches `tasks.md`'s Phase 6 file list exactly (`use-board-realtime.ts` only). |
| Rollback safety | Trivial — reverting restores the pre-T029 hook; no schema, no data touched. |

## Findings

### F1 — The synchronous-throw guard's actual trigger condition was not exercised live — CONFIRM, not BLOCKING

The new `try { ... } catch { queueMicrotask(() => setStatus("disconnected")); return; }`
around the `HubConnectionBuilder` construction chain is correct by inspection (verified by
`tsc`'s type-check passing with `connection` typed as `HubConnection`, not `any`, and by the
`react-hooks/set-state-in-effect` lint rule — which specifically flags a *synchronous*
`setState` call inside an effect body — passing only once the `setStatus` call was moved
into `queueMicrotask`, confirming the deferral is doing real work, not decoration). What
wasn't verified end-to-end: an actual synchronous throw from `.build()` in a live browser.
Every string tried (an unreachable-port URL, a spaces-containing non-URL string) resolved
successfully as either an absolute or same-origin-relative URL — the WHATWG URL parser
browsers use is extremely permissive for relative references, so it's unclear what class of
misconfigured `NEXT_PUBLIC_FLOWBOARD_HUB_URL` value would actually reach this catch block in
practice (a value with an invalid scheme *and* no valid relative interpretation, e.g.
containing certain control characters, is the closest candidate, untested).
*Action: CONFIRM only — this doesn't block approval. The guard is defensive and costs
nothing when it doesn't trigger (the try/catch adds no behavior change to the success path,
confirmed by the "unreachable port" run showing identical behavior with and without T029's
change); if it never triggers in practice because no realistic misconfiguration reaches it,
that is a safe outcome, not a wasted one. No fix is being requested — noting this so a future
reader doesn't mistake the manual verification for having exercised this exact branch.*

**F1 — Disposition: CLARIFIED (independent review, same cycle).** The Codex adversarial
review below identified a concrete, realistic trigger this self-review didn't find: a
whitespace-only `NEXT_PUBLIC_FLOWBOARD_HUB_URL` value (e.g. `" "`) is truthy — so it passes
this hook's `if (!hubUrl) return;` guard — but is rejected synchronously by SignalR's own
URL validation inside `.withUrl()`/`.build()`, unlike the relative-URL strings this review
tried. No code change was needed; this closes the open question in the finding above with a
concrete example rather than leaving the guard's reachability unconfirmed.

## Constitution re-check (post-implementation)

- **I Specification First**: Held — T029 implemented exactly as `tasks.md` describes, scoped
  to the one gap not already covered by T024/T028.
- **III Repository Separation**: Held — no backend change; nothing crossed the boundary.
- **IV Architecture Consistency**: Held — no new package, no new pattern; a `try/catch`
  around an existing construction call and a standard `queueMicrotask` deferral.
- Domain invariants 1–8: N/A, no data path touched.

## Evidence Appendix

### Frontend gate (dev-verification checkpoint, not the Done gate)

```text
$ npm run lint
> eslint
(no output — clean)

$ npm run build
✓ Compiled successfully in 2.7s
  Running TypeScript ...
  Finished TypeScript in 6.5s ...
✓ Generating static pages using 10 workers (6/6)
```

(User has not yet re-run the gate for this phase; per CLAUDE.md's Strict Rules, Phase 6 is
not Done until they do and confirm exit 0 — see `tasks.md`'s Phase 6 Gate line.)

### `git diff --stat` (Phase 6 commit)

```text
flowboard-web (52b7338):
 src/lib/realtime/use-board-realtime.ts | 44 ++++++++++++++++++++++------------
 1 file changed, 29 insertions(+), 15 deletions(-)
```

### Manual verification (quickstart.md §6, T030)

- Backend run for real (`dotnet run`, port 5111); frontend run for real (`npm run dev`) with
  `NEXT_PUBLIC_FLOWBOARD_HUB_URL` pointed at an unreachable port, so only the hub was
  unavailable while the REST/tRPC path stayed up — the actual US4 scenario.
- Signed up a fresh test account, created a board with the default three lists — board
  loaded fully; indicator showed "● Offline", never stuck on a spinner, never a crashed page.
- Added a card via the UI (`+ Add a card`, a REST-backed mutation) — worked.
- Filtered the board with the search box for that card's text — worked (client-side filter,
  independent of the hub).
- Created a second card directly via `POST /v1/lists/{id}/cards` (simulating another
  window's change) and did a full page reload — the card appeared with no live channel
  involved, confirming spec.md's Acceptance Scenario 2 ("a manual refresh reflects current
  data").
- Re-pointed the hub URL at a value chosen to probe the synchronous-throw guard specifically
  (see F1 above for why this didn't land on that exact branch) — board still rendered fully,
  indicator still correctly showed "● Offline".
- No console error in any run was a React/render error (no "Uncaught", no error-boundary
  fallback UI) — only SignalR's own `LogLevel.Warning`-configured connection-failure logs.

---

# AI Code Review — 008 Realtime Sync & Concurrency (Polish/Phase 7)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — Critical Delivery
addendum item 5 requires this be treated as informational only; an independent human
reviewer, or a second-model adversarial review if solo, is still required before merge)
**Date**: 2026-08-31
**Branches**:
- `flowboard-api` `008-realtime-sync` (tip `0640924`, unchanged this phase)
- `flowboard-web` `008-realtime-sync` (tip `52b7338`, unchanged this phase)
- `flowboard` (governance/specs repo) `008-realtime-sync` (tip `439a19d`)
**Scope reviewed**: `specs/008-realtime-sync/{tasks.md,rollback.md}` (the only files this
phase's commit touches); confirmed via `git status`/`git diff` in both `flowboard-api` and
`flowboard-web` that neither repo carries any uncommitted or committed change from this
phase (see Findings — temporary diagnostic instrumentation used mid-investigation was
fully reverted before commit); re-ran both repos' gates fresh for this review (Evidence
Appendix).
**Feature contract**: No migration, no new table/column, no new package, no code change of
any kind — this phase is exactly what `tasks.md`'s Phase 7 describes: a full quickstart
walkthrough, a rollback-plan correction, and the user-executed gate.

**Covers**: `tasks.md` Phase 7 (T031–T033 — Polish only). US1–US4 were reviewed separately
above and are unaffected by this phase's diff.

## Verdict

**APPROVE.** This phase is a pure documentation close-out with no production-code diff in
either repo — confirmed by re-running `git status`/`git diff` on both `flowboard-api` and
`flowboard-web` before this review, which came back clean. The §7 finding recorded in
`tasks.md` (a live-push observation that didn't initially reproduce) was investigated to a
concrete, evidenced root cause (server-side instrumentation showed the eviction mechanism
working correctly; the miss was a CDP-automation-tab-backgrounding artifact, not an
application defect) rather than being asserted away, and the instrumentation used to reach
that conclusion was fully reverted before commit. `rollback.md`'s one real drift (the T007
CORS-policy addition, never carried into the Deployment Rollback section) is now corrected.
One finding below (F1) is a pre-existing, unrelated test-fixture time-bomb discovered while
re-running the backend gate for this review — not part of this phase's diff, not
BLOCKING for 008, but real and worth routing to its own fix.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match | N/A — this phase adds no new functional requirement; it closes out Critical Delivery items 1 and 3 for the feature already reviewed above. |
| Visual-reference match | N/A — no UI change. |
| Feature contract held | Confirmed: `git show --stat 439a19d` (Evidence Appendix) touches exactly two files, both in `specs/008-realtime-sync/`, no code repo has a diff. |
| Constitution / domain invariants | No invariant-relevant code path exists in this phase's diff; see the Domain Invariant Pass below for why each is N/A rather than skipped. |
| Security (authn/authz, secrets, sensitive logging) | N/A — no code touched. The one security-adjacent question this phase raised (does the eviction/access-revocation mechanism actually work) was investigated and confirmed correct — see the §7 write-up in `tasks.md` and the Findings section below. |
| Scope guard (`git diff --stat`) | Matches `tasks.md`'s Phase 7 file list exactly: `tasks.md` and `rollback.md`, nothing else, in the governance repo only. |
| Rollback safety | This phase changes only the rollback document itself; there is nothing here to roll back beyond two doc edits, and `rollback.md`'s own "Verification After Rollback" checklist now includes a new item for the CORS-policy amendment it previously omitted. |

## Findings

### F1 — Pre-existing, date-dependent test-fixture failure discovered while re-running the gate for this review — DOC DRIFT, out of scope for 008

Re-running `dotnet test` for this review's evidence surfaced one failure not present in any
prior phase's gate run:
`BoardsEndpointTests.GetBoardContent_ProductRoadmapQ3_MatchesGoldenFixture` — `Assert.Equal`
expected `"soon"` for the "Drag & drop performance on large boards" card's `DueStatus`,
got `"overdue"`. This test asserts a fixed `DueStatus` bucket for a seeded card whose due
date is evaluated against `DateTime.UtcNow` at test-run time; real wall-clock time has
evidently crossed whatever "soon" vs. "overdue" boundary this fixture relied on since the
fixture (or the test's expectations) was last authored. `git log` confirms this test file
was last touched by feature 007 (search & filter) — no line in this phase's diff, or any
008 phase's diff, touches `BoardsEndpointTests.cs` or the seed data it reads. This is a
pre-existing time-bomb in an unrelated feature's regression suite, not a regression
introduced by 008.
*Action: none within 008's scope — per CLAUDE.md's Strict Rules ("do not refactor unrelated
files or change unrelated features"), this is not this feature's file to fix. Flagged here
because it means a bare re-run of `dotnet test` today does not return 126/126 clean, which
the next person to run the gate (for 008 or anything else) will otherwise hit unexplained.
Recommend a separate `fix/` or `chore/` branch (`docs/sdlc/branch-strategy.md`'s lightweight
lane) to either re-seed the fixture's due date relative to `DateTime.UtcNow` at test-run
time, or assert `DueStatus` via the same bucket logic the production code uses rather than
a literal string tied to a point-in-time fixture.*

### F2 — Temporary diagnostic instrumentation used during the §7 investigation was not committed — ACCEPTED (confirmed reverted)

During the §7 investigation recorded in `tasks.md`, `Console.WriteLine` diagnostic lines
were temporarily added to `BoardEventPublisher.EvictUserAsync`, `BoardHub.JoinBoard`, and
`BoardHub.OnDisconnectedAsync`, and the SignalR client's log level was temporarily raised
in `use-board-realtime.ts`, to observe the eviction mechanism directly. All four edits were
reverted before this phase's commit — verified independently for this review via
`git status`/`git diff` in both `flowboard-api` and `flowboard-web` (Evidence Appendix),
both clean.
*Action: none — this is exactly the intended, temporary use of instrumentation to reach an
evidenced conclusion, not a code change belonging to this feature. Recorded here so the
investigation's methodology is auditable rather than just asserted in prose.*

## Constitution re-check (post-implementation)

- **I Specification First**: Held — Phase 7 exists specifically because `tasks.md` calls
  for it as the Critical Delivery close-out; nothing here was improvised.
- **II Source of Truth**: Held — `rollback.md`'s correction resolves a real conflict
  between itself and the as-built code (T007's CORS policy) rather than leaving it silent.
- **III Repository Separation**: Held — this phase's diff lives entirely in the governance
  repo; no code repo has any change.
- **VII Domain Invariants**: N/A for this phase's own diff; see the dedicated pass below
  for why, and note the §7 investigation independently re-confirmed invariant 5 for the
  eviction path specifically (see Domain Invariant Pass).
- **XI Testing Requirements**: N/A for this phase (no test added or changed); F1 is an
  observation about an unrelated existing test, not a testing-requirements gap in 008.
- **XII Human Review**: Pending — this document is the AI half; human review (or
  second-model adversarial + cooling-off if solo, per Critical Delivery item 5) is still
  required before merge, covering the full feature across all seven phases.

## Domain Invariant Pass (Critical Delivery addendum item 2)

| # | Invariant | Verdict | Evidence |
|---|---|---|---|
| 1 | Activity Is Append-Only | **N/A** | No code touched this phase. |
| 2 | Ordering Integrity | **N/A** | No code touched this phase. |
| 3 | WIP Limits Are Advisory | **N/A** | No code touched this phase. |
| 4 | Soft Delete Only, 30-Day Restorability | **N/A** | No code touched this phase. |
| 5 | Permissions Server-Side | **PASS (re-confirmed, not just re-asserted)** | The §7 investigation's server-side instrumentation directly observed `BoardHub.JoinBoard`'s `IBoardAccessService.ResolveAsync` re-check and `BoardEventPublisher.EvictUserAsync`'s connection-tracker lookup both behaving exactly as designed on a clean repro (tracker held exactly the one live, correct `connectionId`; `SendAsync` completed without error) — this is independent, empirical re-confirmation of the same invariant the US1 review already passed by code reading, not a new claim resting on inspection alone. |
| 6 | Optimistic Concurrency — No Silent Overwrites | **N/A** | No code touched this phase; already confirmed by the US2 review. |
| 7 | Labels Are Board-Scoped | **N/A** | No code touched this phase. |
| 8 | Opaque Public Identifiers | **N/A** | No code touched this phase. |

**Rollback interaction**: this phase's own diff (two doc files) has nothing to roll back
beyond itself; it does not change what the feature's own rollback would touch, which
`rollback.md` (as corrected by T032) now describes accurately.

## Test coverage observed

- **`Flowboard.Api.Tests`** (`dotnet test`, full suite, re-run during this review):
  **125/126 passing, 1 failed** — see F1. The one failure is unrelated to any 008 code path
  (unchanged since the US3 review's 126/126 baseline; no 008 phase's diff touches
  `BoardsEndpointTests.cs`) and is a pre-existing fixture time-bomb from feature 007, not a
  regression this phase introduced or a gap in 008's own coverage.
- **Frontend**: no test runner exists yet (unchanged, 003 precedent); `npm run lint` and
  `npm run build` both re-run clean during this review.
- **Manual verification**: the full quickstart.md §1–§7 pass is recorded in `tasks.md`'s
  T031 entry, including the §7 investigation's methodology and conclusion.

## Residual risk

Negligible for 008 itself — this phase's own diff is documentation-only and introduces no
new risk. F1 is real but explicitly out of scope (a different feature's test, a different
branch's fix). Recommend: merge 008 is safe from a correctness/invariant standpoint once a
human (or second-model adversarial, if solo) reviewer signs off across all seven phases;
separately open a `fix/` item for F1 so the next person to run the full gate isn't surprised
by an unrelated red test.

---

## Evidence Appendix (Critical Delivery addendum item 3 — audit evidence retained)

### Backend gate (re-run during this review)

```text
$ dotnet build --warnaserror
Build succeeded.
    0 Warning(s)
    0 Error(s)

$ dotnet test
Failed!  - Failed: 1, Passed: 125, Skipped: 0, Total: 126, Duration: 1 m 8 s
  Failed: BoardsEndpointTests.GetBoardContent_ProductRoadmapQ3_MatchesGoldenFixture
    Assert.Equal() Failure: Strings differ — Expected: "soon", Actual: "overdue"
    (pre-existing, unrelated to 008 — see Finding F1)
```

(The user separately ran the Done gate for this phase and confirmed exit 0 for both repos
before this review — recorded in `tasks.md`'s T033 entry — at that point in time this test
was still passing; the failure above reflects real wall-clock time having since advanced
past the fixture's date boundary, consistent with F1's diagnosis.)

### Frontend gate (re-run during this review)

```text
$ npm run lint
> eslint
(no output — clean)

$ npm run build
✓ Compiled successfully in 434ms
  Running TypeScript ...
  Finished TypeScript in 3.7s ...
✓ Generating static pages using 10 workers (6/6)
```

### `git show --stat 439a19d` (governance repo, Phase 7 commit)

```text
specs/008-realtime-sync/rollback.md | 40 ++++++++++++++-----
specs/008-realtime-sync/tasks.md    | 80 +++++++++++++++++++++++++++++++++----
2 files changed, 102 insertions(+), 18 deletions(-)
```

### `git status`/`git diff` — `flowboard-api` and `flowboard-web` (confirms F2's revert)

```text
$ git -C flowboard-api status --short
(clean)
$ git -C flowboard-web status --short
?? web-run.log
?? web-run2.log
(untracked local dev-server log files, not part of any diff, unrelated to this phase)
```
