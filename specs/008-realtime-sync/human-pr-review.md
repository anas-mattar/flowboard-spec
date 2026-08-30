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
