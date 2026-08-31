# Human PR Review — 008 Realtime Sync & Concurrency (US2)

**Reviewer**: Second-model adversarial review (OpenAI Codex, `gpt-5.x`-class, via the
`codex` CLI) — solo-developer substitute for independent human review, per
`docs/sdlc/critical-delivery.md` item 5 ("A solo developer substitutes a second-model
adversarial review... plus a cooling-off period before merge"). Genuinely independent of
the model that wrote the code and the AI self-review (Claude Sonnet 5): a different
vendor, different weights, prompted explicitly to refute and find gaps rather than
confirm.
**Date**: 2026-08-30
**AI review**: `specs/008-realtime-sync/ai-code-review.md`, second section ("AI Code
Review — 008 Realtime Sync & Concurrency (US2)") — read first by the adversarial
reviewer each round; its APPROVE verdict on production-code safety was not disputed, but
its self-review missed the test-rigor gaps found below (expected, since the same model
wrote both the tests and that review).
**Scope reviewed**: `tests/Flowboard.Api.Tests/CardsEndpointTests.cs` and
`tests/Flowboard.Api.Tests/BoardHubTests.cs` — the complete Phase 4 diff, `git diff
5b82b3d..HEAD` in `flowboard-api`, re-read from scratch in every round rather than trusting
the round-over-round description of what changed.

## Process note

This review ran four rounds against the same base (`5b82b3d`, the tip of Phase 3/US1),
each round re-reading the *entire* current diff rather than only the delta — this is
what caught round 3's regression (a fix applied during round 2 accidentally deleted a
still-needed case; re-reading the whole diff, not just "did the named fix land," is what
surfaced it). Summary:

| Round | Verdict | Finding(s) |
|---|---|---|
| 1 | CHANGES REQUESTED | (a) FR-006 test refetched its precondition after the move, eliminating the race it claimed to prove; (b) concurrent-move broadcast assertion allowed a duplicate-one/dropped-the-other bug to pass (per-element containment, not exact multiset); (c) rejected-save test never empirically observed a hub broadcast, only the activity feed. |
| 2 | CHANGES REQUESTED | Fixed (b) and (c); replaced the FR-006 test with a genuinely concurrent (`Task`-started-before-either-`await`) version — but that version alone doesn't prove *both* legitimate race outcomes are reachable, since TestServer scheduling could make one deterministic every run. |
| 3 | CHANGES REQUESTED | The two deterministic tests added in response to round 2 covered field-edit-first (both persist) and move-first-with-*stale*-precondition (edit rejected) — but the move-first-with-*fresh*-precondition case (both persist) was missing entirely, having been deleted by mistake during the round-2 rewrite rather than kept alongside the new race test. |
| 4 | **APPROVED** | Missing case restored as its own test. All four T022-area tests, plus the T020/T021 fixes from earlier rounds, re-verified intact and correct in the final diff. No further finding. |

Every round's fix was verified by this developer running `dotnet build --warnaserror &&
dotnet test` locally before the next round (125/125 passing at final commit
`6590d6e`) — the human-executed-gate requirement (critical-delivery.md item 4) — not by
either model claiming success.

## Business Review

- [x] Behavior matches the business intent in `spec.md`'s US2 section — the final four
  T022-area tests plus T020/T021 collectively cover every US2 acceptance scenario: #1
  (stale field-edit rejected, current data shown), #2 (concurrent moves converge to one
  position, no dup/loss), #3 (move + field edit — both an FR-006 preservation case per
  ordering, and the FR-004 rejection case when the edit's precondition predates the
  move).
- [x] Domain correctness verified — invariant 6 (optimistic concurrency) traced against
  the actual `CardService.cs` code paths in every round, not just against test names.
- [x] No open CONFIRM findings from the AI review pertain to this phase's diff (the AI
  review's own carried-forward items — F1 due-date-sort broadcast gap, F2 partial
  broadcast coverage, F4 CORS env config — are US1-scope and explicitly out of scope for
  this phase's test-only diff).

## Technical Review

- [x] Code diff read end-to-end, four times (once per round) — no unrelated changes;
  `git diff --stat` at final commit: `tests/Flowboard.Api.Tests/BoardHubTests.cs` and
  `tests/Flowboard.Api.Tests/CardsEndpointTests.cs` only, no production file touched, no
  migration, no package change.
- [x] Architectural compliance — test-only diff, no new pattern/package introduced.
- [x] Security implications — none; no new endpoint, no new auth path, reuses existing
  test fixture/auth helpers.
- [x] Migrations/schema — N/A, none in this diff.

## Gate Result

- [x] Gate run **by the developer** (not either model): `dotnet build --warnaserror &&
  dotnet test` — **EXIT: 0**, 125/125 passing, at commit `6590d6e`.

## Approval

**Decision**: **APPROVED** — merge is clear from a review-process standpoint (constitution
XII). Per critical-delivery.md item 5, a cooling-off period is expected before merge on
top of this approval.

## Comments

- The three-round back-and-forth is the point, not a failure mode: round 1's findings
  were real (weak assertions that would pass a broken implementation), and round 3
  caught this developer's own regression (deleting a needed test case while fixing
  round 2's finding) — exactly the kind of blind spot item 5 exists to catch, since the
  same model that writes the fix is the one least likely to notice it introduced a new
  gap while closing the last one.
- T022/FR-006 now has four tests by design, not redundancy: field-edit-first (both
  persist), move-first-fresh-precondition (both persist), move-first-stale-precondition
  (edit rejected, FR-004), and a genuinely concurrent `Task`-based version (accepts either
  legitimate outcome, guards against a corruption-prone path unique to true concurrency).
  A future reader should not collapse these back into one "concurrency" test — each
  proves a distinct interleaving.
- `ai-code-review.md`'s F1/F2/F4 (US1-scope) remain open and are not this document's
  concern; they should be resolved or explicitly deferred before the feature as a whole
  (not just Phase 4) is declared Done.

---

# Human PR Review — 008 Realtime Sync & Concurrency (US3)

**Reviewer**: Second-model adversarial review (OpenAI Codex, `gpt-5.x`-class, via `codex
exec -s read-only`) — solo-developer substitute for independent human review, per
`docs/sdlc/critical-delivery.md` item 5. Genuinely independent of the model that wrote the
code and the AI self-review (Claude Sonnet 5): a different vendor, different weights,
prompted explicitly to refute and find gaps rather than confirm, each round given only the
scope/context needed and told to re-read the entire current diff from scratch rather than
trust a round-over-round description of what changed.
**Date**: 2026-08-31
**AI review**: `specs/008-realtime-sync/ai-code-review.md`, third section ("AI Code Review
— 008 Realtime Sync & Concurrency (US3)") — read first by the adversarial reviewer each
round. Its APPROVE-with-follow-ups verdict, and the Finding F1 fix it already documents
(`onreconnected`'s `JoinBoard` re-invoke gained a `.catch()`), predate this loop; this loop
found two further gaps the self-review missed (expected — the same model wrote both the
code and that review).
**Scope reviewed**: two repositories, reviewed separately (constitution III — Repository
Separation):
- `flowboard-api`: `tests/Flowboard.Api.Tests/BoardHubTests.cs`, the complete Phase 5
  backend diff, `git diff 6590d6e..HEAD`.
- `flowboard-web`: `src/lib/realtime/use-board-realtime.ts`,
  `src/components/board/board-realtime-context.tsx`,
  `src/components/layout/realtime-status-indicator.tsx`, `top-bar.tsx`, `page.tsx`,
  `board-canvas.tsx` — the complete Phase 5 frontend diff, `git diff d07a3b6..HEAD`.

## Process note

Backend and frontend were reviewed as two independent tracks, each re-reading its entire
current diff every round rather than only the delta:

| Round | Repo | Verdict | Finding(s) |
|---|---|---|---|
| 1 | `flowboard-api` | CHANGES REQUESTED | (a) The reconnect test's `card.created`-count-only assertion could pass with a duplicated pre-drop event masking a missed post-reconnect one — the same class of weakness the US2 review caught; (b) the test's own comment claimed SignalR assigns a new connection id across the stop/restart cycle but never checked it. |
| 1 | `flowboard-web` | CHANGES REQUESTED | (1) `onreconnected`'s catch-up fetch fired before `JoinBoard`'s group-membership was actually restored, leaving a window where a mutation lands in neither the fetched snapshot nor a delivered event and stays stale indefinitely — a second gap in the same area as the self-review's F1, worse than F1 alone since it affects the *success* path, not just the failure path; (2) the initial connection had the identical gap; (3) the status indicator mapped ordinary page-load "connecting" to the same "Offline" presentation as a real outage, misleading a user watching it during normal load. |
| 2 | `flowboard-api` | CHANGES REQUESTED (process only) | The round-1 fix existed only as an uncommitted working-tree change; `git diff 6590d6e..HEAD` still showed the original test. Separately confirmed the uncommitted rewrite itself was technically sound (identified payload, exact sequence, real `ConnectionId` comparison, no new lock/race issue) — this was a delivery-state finding, not a code finding. |
| 2 | `flowboard-web` | CHANGES REQUESTED | Same uncommitted-delivery caveat, plus one real finding: a stale in-flight `joinAndSync` attempt (started before a drop) could resolve *after* a newer reconnect cycle had already moved status to "reconnecting", overwriting it with its own outdated "connected" — reintroducing exactly the misleading-indicator failure mode the round-1 fix was meant to close. Everything else (guarded `JoinBoard`-then-invalidate ordering, the F1 catch path, the `stopped` cleanup guard, the indicator's now-distinct wording, the type import) verified correct. |
| 3 | `flowboard-api` | **APPROVED** | Round-1 fixes now committed (`0640924`) and independently re-verified against the actual `git diff`, not just the earlier working-tree inspection. |
| 3 | `flowboard-web` | **APPROVED** | Round-1 and round-2 fixes now committed (`ff116c3`, `a13c72d`) and independently re-verified: the `attempt` generation counter is present, checked on both the success and failure branches, wired into the initial-connect path (not only `onreconnected`), and `onreconnecting`/`onclose` both invalidate older attempts. No further finding on the full diff. |

Every round's fix was verified by this developer running the full gate locally before the
next round (`dotnet build --warnaserror && dotnet test`: 126/126 both after round 1's fix
and again after round 2's; `npm run lint && npm run build`: clean both times) — dev
verification, not the counted Done gate (`critical-delivery.md` item 4; see Gate Result
below for the actual counted run).

## Business Review

- [x] Behavior matches the business intent in `spec.md`'s US3 section — the final backend
  test plus the frontend reconnect/status/indicator diff collectively cover both US3
  acceptance scenarios (visible signal while disconnected; automatic catch-up with no
  missed change once reconnected) to a materially stronger standard than the code that
  entered this review, since round 1 found the "no missed change" guarantee had two real
  holes (backend test rigor, frontend catch-up ordering) beyond the one the self-review had
  already caught and fixed (F1).
- [x] Domain correctness verified — invariant 5 (permissions server-side) re-traced against
  `BoardHub.JoinBoard`'s actual `Context.Abort()` behavior in every backend round; no
  invariant regression introduced by any of the frontend fixes (no new data path, no new
  broadcast).
- [x] No open CONFIRM/BLOCKING findings from either the AI review or this loop pertain to
  the current diff — the AI review's F1 and this loop's three additional findings are all
  fixed and re-verified APPROVED.

## Technical Review

- [x] Code diff read end-to-end, three rounds, both repositories independently — no
  unrelated changes; final `git diff --stat`: `flowboard-api` — `BoardHubTests.cs` only, no
  production file touched, no migration, no package change; `flowboard-web` — the six files
  listed under Scope reviewed, no migration, no package change.
- [x] Architectural compliance — reuses the established sibling-state Context Provider
  shape (`sidebar-context.tsx`/`board-filter-context.tsx`) and the existing
  invalidate-and-refetch cache contract (ADR-36); no new library, no new pattern.
- [x] Security implications — none beyond what the AI review already covered; the
  generation-guard fix and catch-up reordering are purely client-side state-sequencing
  changes, touching no auth or authorization path.
- [x] Migrations/schema — N/A, none in this diff.

## Gate Result

- [x] Gate run **by the developer** (not either model) after Phase 5's original T024-T028
  commits: `dotnet build --warnaserror && dotnet test` and `npm run lint && npm run build`
  — **EXIT: 0** (recorded in `tasks.md`'s Phase 5 Gate line, before this review loop).
- [x] **Re-confirmed by the developer**: this review loop added four further commits after
  that gate run — `0640924` (backend), and `f0dc03c`, `ff116c3`, `a13c72d` (frontend).
  `dotnet build --warnaserror && dotnet test` and `npm run lint && npm run build` re-run by
  the developer covering the full current diff — **EXIT: 0**.

## Approval

**Decision**: **APPROVED.** Review-process standpoint (constitution XII) is satisfied — all
findings raised across three rounds, in both repositories, are fixed and independently
re-verified, and the gate has been re-confirmed covering every commit in this loop. Per
critical-delivery.md item 5, a cooling-off period is expected before merge on top of this
approval, in addition to the pending gate re-run.

## Comments

- Round 2 across both repos landed the same process lesson at once: reviewing an
  uncommitted working-tree change and then citing `git diff <base>..HEAD` in the same
  breath is inconsistent — the diff a reviewer is asked to certify must be the diff that is
  actually committed. Every fix in this loop was committed before the next round began,
  from round 2 onward.
- The frontend's round-2 finding (a stale `joinAndSync` attempt clobbering a newer status)
  is the same *shape* of lesson US2's round 3 taught: fixing one race can introduce a new
  one in the same function, and only a full re-read from scratch — not a "did the described
  fix land" check — catches it reliably.
- `ai-code-review.md`'s carried-forward US1-scope items (F1 due-date-sort broadcast gap, F2
  partial broadcast coverage, F4 CORS env config) remain open and are not this document's
  concern; they should be resolved or explicitly deferred before the feature as a whole is
  declared Done.

# Human PR Review — 008 Realtime Sync & Concurrency (US4)

**Reviewer**: Second-model adversarial review (OpenAI Codex, `gpt-5.x`-class, via `codex
exec -s read-only`) — solo-developer substitute for independent human review, per
`docs/sdlc/critical-delivery.md` item 5.
**Date**: 2026-08-31
**AI review**: `specs/008-realtime-sync/ai-code-review.md`, fourth section ("AI Code Review
— 008 Realtime Sync & Concurrency (US4)") — read first by the adversarial reviewer. Its
APPROVE verdict carried one CONFIRM-only note (F1): the self-review couldn't find a
realistic input that reaches the new synchronous-throw guard from a browser. This loop
closed that note with a concrete example (see Process note).
**Scope reviewed**: `flowboard-web` only — `flowboard-api` has zero diff this phase (noted
in the AI review header, tip unchanged at `41d5830`), so no backend round was run.
- `flowboard-web`: `src/lib/realtime/use-board-realtime.ts`, the complete Phase 6 diff,
  `git diff a13c72d..HEAD` (one commit, `52b7338`).

## Process note

One round, one repository — this phase's diff is a single ~44-line change to one file:

| Round | Repo | Verdict | Finding(s) |
|---|---|---|---|
| 1 | `flowboard-web` | **APPROVED** | No findings requiring a fix. Independently verified: the entire `HubConnectionBuilder` construction chain (`.withUrl()`, `.withAutomaticReconnect()`, `.configureLogging()`, `.build()`) sits inside the `try`; `connection: HubConnection` is definitely assigned on every path that uses it; the catch returns before handler registration, `start()`, or cleanup, so no `LeaveBoard`/`stop()` is ever attempted on a connection that was never created; the success path's behavior and timing are unchanged; `queueMicrotask` genuinely moves the `setStatus` call into a callback from `react-hooks/set-state-in-effect`'s perspective, and an intervening unmount before the microtask runs is inert, not a bug. Beyond confirming the fix, this round supplied the concrete trigger the self-review's F1 note was missing: a whitespace-only `NEXT_PUBLIC_FLOWBOARD_HUB_URL` (e.g. `" "`) is truthy — passing this hook's own `if (!hubUrl) return;` guard — but is rejected synchronously by SignalR's own URL validation, unlike the relative-URL strings the self-review had tried. |

Gate run by this developer before requesting the review (dev-verification, not the counted
Done gate): `npm run lint` (clean) and `npx tsc --noEmit` (equivalent read-only run passed,
exit 0 — the literal `tsc --noEmit` command failed only on a read-only-filesystem artifact
unrelated to the code, `tsconfig.tsbuildinfo` write permission, in the review sandbox).

## Business Review

- [x] Behavior matches the business intent in `spec.md`'s US4 section — verified live
  against a real backend+frontend with the hub pointed at an unreachable port (the actual
  "live channel cannot be established" scenario): the board loaded and stayed fully usable
  (create, search/filter all worked via REST/tRPC), and a card created directly via the API
  appeared after a manual reload with no live channel involved — both acceptance scenarios
  hold.
- [x] Domain correctness — N/A, no data path touched (confirmed in both reviews).
- [x] No open CONFIRM/BLOCKING findings pertain to the current diff — the AI review's F1 was
  a request for clarification, not a fix, and this loop supplied that clarification.

## Technical Review

- [x] Code diff read end-to-end — one file, one commit, no unrelated changes; final `git
  diff --stat`: `flowboard-web` — `src/lib/realtime/use-board-realtime.ts` only (29
  insertions, 15 deletions), no migration, no package change; `flowboard-api` unchanged.
- [x] Architectural compliance — no new library, no new pattern; a `try/catch` around an
  existing construction call and a standard `queueMicrotask` deferral to satisfy an existing
  lint rule.
- [x] Security implications — none; no auth/authorization path touched, nothing logged.
- [x] Migrations/schema — N/A, none in this diff.

## Gate Result

- [x] Gate run **by the developer**: `dotnet build --warnaserror && dotnet test` (backend,
  unaffected by this frontend-only change but still part of the gate slice) and `npm run
  lint && npm run build` (frontend), covering the Phase 6 commit (`52b7338`) — **EXIT: 0**.

## Approval

**Decision**: **APPROVED.** Review-process standpoint (constitution XII) is satisfied — the
one round's finding was a clarifying question, not a defect, and it has been answered, and
the gate has been confirmed covering this phase's commit. Per critical-delivery.md item 5, a
cooling-off period is expected before merge on top of this approval.

## Comments

- This phase's small, single-file diff didn't need the multi-round pattern US2/US3 required
  — one thorough round with no findings-that-need-fixing is a legitimate outcome, not a
  shortcut; the review still re-read the whole diff from scratch, ran the type-check and
  lint itself, and pushed back on the one unresolved uncertainty in the self-review rather
  than rubber-stamping "APPROVE."

---

# Human PR Review — 008 Realtime Sync & Concurrency (Polish/Phase 7)

**Reviewer**: Second-model adversarial review (OpenAI Codex, `gpt-5.x`-class, read-only) —
solo-developer substitute for independent human review, per
`docs/sdlc/critical-delivery.md` item 5.
**Date**: 2026-08-31
**AI review**: `specs/008-realtime-sync/ai-code-review.md`, final section ("AI Code Review
— 008 Realtime Sync & Concurrency (Polish/Phase 7)") — read first as the self-review under
audit. Its APPROVE verdict is disputed on two grounds: the FR-007 tooling-artifact
diagnosis is plausible but not sufficiently demonstrated to exclude a delivery race, and
the corrected rollback document still contains factually incorrect frontend statements.
**Scope reviewed**:
- `flowboard`: Phase 7 commits `439a19d` (`tasks.md`, `rollback.md`) and `53324f9`
  (`ai-code-review.md`).
- `flowboard-api`: `src/Flowboard.Api/Program.cs`, `Services/BoardEventPublisher.cs`,
  `Services/BoardConnectionTracker.cs`, `Hubs/BoardHub.cs`,
  `Services/BoardMembershipService.cs`, and
  `tests/Flowboard.Api.Tests/{BoardHubTests.cs,BoardsEndpointTests.cs}`; relevant history
  through tip `0640924`.
- `flowboard-web`: `src/lib/realtime/use-board-realtime.ts`,
  `src/components/layout/realtime-status-indicator.tsx`,
  `src/components/board/board-realtime-context.tsx`, and the Phase 5/6 diffs affecting
  `page.tsx`, `top-bar.tsx`, and `board-canvas.tsx`; tip `52b7338`.

## Process note

One adversarial round reviewed the documentation diff and independently traced every
material claim into current source and repository history:

| Round | Repo | Verdict | Finding(s) |
|---|---|---|---|
| 1 | `flowboard` + cross-repo verification | **CHANGES REQUESTED** | (1) The FR-007 browser-throttling account is consistent with the code but not proven as the exclusive root cause: the uncommitted instrumentation cannot be inspected, `SendAsync` completion does not prove browser receipt, and a real disconnect/eviction race remains plausible. (2) `rollback.md` still incorrectly says no existing frontend component's rendering logic changed, despite `top-bar.tsx` adding the status indicator and `board-canvas.tsx` adding a new no-access render branch. (3) The reported golden-fixture failure is genuinely outside 008 history, although this sandbox could not independently reproduce its test output. |

No files were edited. `git status --short` remained clean in `flowboard-api`;
`flowboard-web` retained only its pre-existing untracked `web-run.log` and `web-run2.log`.

## Business Review

- [ ] FR-007 cannot yet be treated as fully confirmed from the retained evidence. The
  stable-connection integration test does prove the intended happy path:
  `BoardHubTests.cs:383-422` starts a real connection, joins the board, removes the
  member, waits up to ten seconds for `access.revoked`, then verifies that a subsequent
  `card.created` event is not received.
- [x] Server-side authorization remains correctly enforced independently of live UI state:
  `BoardHub.cs:18-36` validates the token's board scope, re-resolves current access,
  aborts unauthorized joins, and tracks only a successfully joined connection;
  `BoardMembershipService.cs:214-244` commits membership removal before invoking eviction.
- [ ] The self-review overstates the §7 conclusion. `tasks.md:493-518` records three
  failed browser observations, while the claimed diagnostic output was never committed and
  therefore could not be independently inspected. The current code supports the proposed
  explanation, but it also permits this plausible race:
  - `BoardEventPublisher.cs:43-52` snapshots tracked connection IDs.
  - `BoardEventPublisher.cs:67-77` calls `SendAsync` and only afterward removes group
    membership.
  - `BoardHub.cs:55-58` can concurrently remove a timed-out connection from the tracker.
  - `BoardConnectionTracker.cs:47-54` deliberately returns a copied snapshot, so a
    connection can disappear after lookup while the publisher still sends to its stale ID.

  In that ordering, `SendAsync` may complete without proving that a client received or
  processed the event, followed immediately by disconnect cleanup. That is consistent with
  the reported logs but does not distinguish "Chrome throttling caused the miss" from the
  more general real delivery-boundary race.
- [ ] Before FR-007 is called fully confirmed, retain a reproducible verification that
  observes the client handler, server connection lifecycle, and eviction ordering
  together. At minimum: repeat in a foreground, non-CDP-controlled browser; deliberately
  reproduce background throttling; and add or run an integration test that forces
  disconnect immediately before/during eviction and verifies the required
  reconnect/invalidate recovery. The current stable-connection test does not exercise that
  boundary.

## Technical Review

- [x] Phase scope is documentation-only. `git show --stat 439a19d` reports only
  `rollback.md` and `tasks.md` (102 insertions, 18 deletions); `git show --stat 53324f9`
  reports only `ai-code-review.md` (202 insertions). Backend and frontend tips contain no
  Phase 7 commit.
- [x] The CORS correction is accurate: `Program.cs:34-48` registers SignalR and the
  `"Realtime"` policy using `Cors:RealtimeOrigin` with the documented
  `http://localhost:3000` default; `Program.cs:160` applies it specifically to
  `/hubs/board`. This matches `rollback.md:32-36,72-81,92-94`.
- [x] The three specifically named frontend files exist and their roles are substantially
  described correctly:
  - `use-board-realtime.ts:81-110` invalidates board content on events and after
    join/rejoin.
  - `realtime-status-indicator.tsx:11-27` renders connection state.
  - `board-realtime-context.tsx:12-30` owns and shares the single hook status.
- [ ] `rollback.md` is nevertheless not fully accurate. Its statements at lines 47-52 that
  neither existing component's rendering logic changed and that the hook "only ever"
  invalidates content conflict with the actual Phase 5 diff:
  - `top-bar.tsx` added `<RealtimeStatusIndicator />`, changing rendered output.
  - `board-canvas.tsx` added `boardError` handling and a new "You don't have access…"
    render branch.
  - `page.tsx` changed its component tree to wrap `TopBar` and `BoardCanvas` in
    `BoardRealtimeProvider`.

  Consequently T032's claim at `tasks.md:520-532` that rollback drift was corrected
  against what was actually built is incomplete.
- [x] The tracker itself is lock-protected: all dictionary/set mutation and reads in
  `BoardConnectionTracker.cs:12-100` occur under `_lock`, and reads return arrays. No
  ordinary collection-corruption race was found.
- [ ] Lock safety does not provide delivery atomicity across tracker lookup, SignalR send,
  disconnect cleanup, and group removal. Those actions occur in separate critical domains
  with no shared ordering guarantee (`BoardEventPublisher.cs:43-77`; `BoardHub.cs:55-58`).
  This is the residual race the self-review did not adequately rule out.
- [x] F1 is unrelated to 008. `git log --all -- tests/Flowboard.Api.Tests/BoardsEndpointTests.cs`
  shows only `e39d718` (003), `246bd72` (006), and `511e738` (007); no 008 commit touched
  the file. The failing assertion is at `BoardsEndpointTests.cs:243-273`, including
  literal `"soon"` at line 271. Production computes `"overdue"` when `dueAt < now` and
  otherwise `"soon"` only within two days (`CardDueStatus.cs:8-25`), while the migration
  seeded dates relative to migration application time
  (`20260827165840_AddBoardContent.cs:324-333`). The date-dependent failure mechanism is
  therefore credible and outside 008.
- [x] No migration or package change exists in the Phase 7 diff.

## Gate Result

- [ ] Backend gate could not be independently executed in this read-only sandbox. `dotnet
  build flowboard-api/Flowboard.slnx --warnaserror` and `dotnet test
  flowboard-api/Flowboard.slnx` both terminated before compilation with
  `System.UnauthorizedAccessException` creating
  `C:\Users\anas.m\AppData\Local\Temp\MSBuildTemp...`; both recorded exit code
  `-532462766`. Therefore the self-review's claimed 125/126 result was not independently
  reproduced.
- [x] Frontend lint independently passed: `npm --prefix flowboard-web run lint` —
  **EXIT: 0**, no lint findings.
- [ ] Frontend build could not complete in the read-only sandbox: `npm --prefix
  flowboard-web run build` reached Next.js startup, then failed opening
  `flowboard-web\.next\trace` with `EPERM`; **EXIT: 1**. This is a filesystem restriction,
  not evidence of a source failure, but it does not independently confirm the self-review's
  clean build.
- [x] The recorded user gate remains `tasks.md:534-542`, which states both repository
  gates exited 0. This review does not replace or invalidate that human-executed gate, but
  its outputs could not be fully independently reproduced here.

## Approval

**Decision**: **CHANGES REQUESTED.** The documentation-only phase does not introduce a
production-code regression, and F1 is correctly classified as unrelated to 008. Approval
is withheld because T032 did not actually make `rollback.md` accurate, and the
highest-stakes §7 conclusion is presented as a proven tooling artifact when the retained
evidence supports only "plausible and consistent with the code." The missing
instrumentation and untested disconnect/eviction boundary are material given three failed
live observations.

## Comments

- Correct `rollback.md:47-52` to acknowledge the actual `top-bar.tsx`, `board-canvas.tsx`,
  and `page.tsx` rendering/tree changes. A rollback plan should describe what must
  disappear, not merely list the newly added modules.
- Revise the §7 evidence language unless a reproducible focused verification is retained.
  "Tracker contained the expected ID; `SendAsync` completed; disconnect followed with
  client-timeout" does not establish browser receipt and does not by itself prove timer
  throttling caused the miss.
- The most useful additional FR-007 check is not another ordinary happy-path run. Force
  the connection into the timeout/disconnect boundary while removal executes, then verify
  either immediate `access.revoked` handling or deterministic reconnect/invalidate
  convergence to the no-access state.
- Route the date-dependent golden-fixture issue separately. Repository history
  conclusively excludes it from every 008 commit, but the project-wide gate will remain
  time-sensitive until that fixture is repaired.

## Follow-up — rounds 2–4 (2026-08-31)

Three further rounds of remediation and re-review followed this one, each addressed to
`flowboard-api` and `flowboard` commits (full detail in
`specs/008-realtime-sync/tasks.md`'s Phase 7 "Round N remediation" notes under T031/T032;
summarized here for the audit trail):

- **Round 2 re-review**: CHANGES REQUESTED. The round-1 hub-level race test
  (`BoardHubTests.RemoveMember_ConcurrentDisconnectAtEvictionBoundary...`) didn't reliably
  force the disputed tracker-snapshot/disconnect interleaving (no synchronization barrier
  over TestServer's in-memory transport) and was redundant with pre-existing coverage
  (its reconnect assertion passes regardless of whether `access.revoked` delivery works).
  `rollback.md`'s round-1 fix also had a fresh error, misattributing the realtime
  `invalidate(...)` call to `board-canvas.tsx`.
- **Round 3 re-review**: CHANGES REQUESTED. The round-2 remediation added
  `BoardEventPublisherTests.cs` (a unit test faking `IHubContext<BoardHub>` to force the
  interleaving deterministically) — a real improvement, but its final assertions would
  still pass even if the race-simulation callback were deleted outright, since
  `EvictUserAsync` unconditionally clears the tracker afterward either way. `rollback.md`'s
  round-2 fix also introduced a *new* inaccuracy while fixing the last one: it claimed
  `board-canvas.tsx` calls `useBoardRealtime` via the context provider, which T026's
  refactor (`flowboard-web` commit `2503c86`) had already removed.
- **Round 4 re-review**: **APPROVE.** Round-3's fixes — an explicit `raceCallbackRan`
  assertion plus a check that the tracker still held the connection at the moment the
  callback ran (proving the interleaving landed genuinely mid-flight, not merely that the
  end state was consistent with it), and a `rollback.md` rewrite correctly stating
  `board-canvas.tsx` has no connection to the realtime hook/context at all — were verified
  accurate against the actual current source and against commit `2503c86` directly.
  Verdict: "the underlying FR-007 concern is now honestly and adequately addressed... no
  remaining evidence gap warrants blocking approval," explicitly endorsing the documented
  scope boundary (this test proves `BoardEventPublisher`'s own code behaves correctly
  under the disputed race; whether the real SignalR transport delivers bytes to a socket
  that's simultaneously closing is a framework guarantee, correctly left out of scope
  rather than claimed away). No new issues found in either round-3 commit.

**Decision (superseding the CHANGES REQUESTED above): APPROVE**, as of round 4
(2026-08-31), covering `flowboard-api` commits `4471479`, `319b046`, `b1bcccd`,
`12875b8`, `a3c31c6` and `flowboard` commits `cfe0535`, `34f94a2`, `d3afc6f`. The
independent build/test re-run remained blocked by the reviewer's own sandbox permissions
in every round (an environment limitation, not a finding) — the user-confirmed gate run
recorded under T033 is the evidence of record per Critical Delivery item 4.
