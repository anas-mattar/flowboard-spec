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
