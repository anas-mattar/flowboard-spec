# The Flow — the Whole Ritual on One Page

Every stage of delivering a feature, in order, on one page. **This page is a summary,
not law**: it introduces no rule and changes none. If anything here conflicts with an
owning document, the owning document prevails — and the constitution
(`.specify/memory/constitution.md`) prevails over everything.

<!-- digest: The flow: baseline, claim, specify, phase loop (gate, commit, scope check, AI review), human review, merge. -->
<!-- digest: flow.md is a summary, not law — the owning documents prevail, and the constitution prevails over everything. -->

## The diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│ 0 BASELINE     clean working tree · gate green on untouched code    │
└───────────────────────────────┬─────────────────────────────────────┘
┌───────────────────────────────▼─────────────────────────────────────┐
│ 1 CLAIM        branch NNN-name + specs/NNN-name/ · push immediately │
│                (the remote branch IS the claim)                     │
└───────────────────────────────┬─────────────────────────────────────┘
┌───────────────────────────────▼─────────────────────────────────────┐
│ 2 SPECIFY      spec.md → plan.md → tasks.md · approved before code  │
│                (Micro: a single-page mini-spec spec.md alone)       │
└───────────────────────────────┬─────────────────────────────────────┘
┌───────────────────────────────▼─────────────────────────────────────┐
│ 3 PHASE LOOP   one approved phase at a time                         │
│                                                                     │
│      implement one phase (UI + visual refs → compliance loop)       │
│         → owner certifies the GATE (exit code — or, declared        │
│           ci-held, evidence approval AFTER the phase commit below)  │
│         → commit the phase ('phase N' in the subject)               │
│         → SCOPE CHECK: scope-check.ps1 = declared territory only    │
│         → AI REVIEW by a fresh-context reviewer (provenance block)  │
│                                                                     │
│      ritual-checks CI re-runs the machine checks on every push      │
│                                                                     │
│      more approved phases? ── yes ──► loop                          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ no — all phases committed gate-green
┌───────────────────────────────▼─────────────────────────────────────┐
│ 4 FEATURE REVIEW   push branch · HUMAN REVIEW of the full feature   │
│                    diff, once per feature (reviewer ≠ owner)        │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ approved
┌───────────────────────────────▼─────────────────────────────────────┐
│ 5 MERGE        --no-ff into protected main · CI on main referees    │
└─────────────────────────────────────────────────────────────────────┘
```

## The steps, one line each

| # | Step | One line | Owning document |
|---|------|----------|-----------------|
| 0 | Baseline | Stop if unrelated uncommitted changes exist; run the gate on untouched code first | `CLAUDE.md` (Workflow), `docs/sdlc/gate-command.md` |
| 1 | Claim | Branch `NNN-name` maps to `specs/NNN-name/`; push immediately — the remote branch is the claim | `docs/sdlc/branch-strategy.md`, `docs/sdlc/team-workflow.md` (rules 2–3) |
| 2 | Specify | **Specification approved**: `spec.md`, then `plan.md`, then `tasks.md`, approved before implementation (Micro: the single-page mini-spec alone — see Lane variations) | `.specify/memory/constitution.md` (I), `docs/sdlc/definition-of-done.md` (gate 1) |
| 3a | Implement | Exactly one approved phase; UI with visual references runs the Visual Compliance Loop | `.specify/memory/constitution.md` (X), `docs/sdlc/review-process.md` |
| 3b | Gate | **Certifying gate**: the owner runs it and confirms the exit code — or, when the approved plan (Micro: mini-spec) declares `**Gate Certification**: ci-held` (Lite/Micro/Standard only), records approval on the CI evidence triplet; agent runs are feedback only in either mode | `docs/sdlc/gate-command.md`, `docs/sdlc/definition-of-done.md` (gate 3) |
| 3c | Commit | One commit per phase (`phase N` in the subject) after the owner's `git diff --stat` intent review, so a bad phase reverts cleanly and the scope check can attribute it; `ritual-checks` CI re-runs the machine checks on every push | `docs/sdlc/branch-strategy.md`, `docs/sdlc/rollback-process.md`, `docs/sdlc/branch-protection.md` |
| 3d | Scope check | **Machine scope check**: `scripts/scope-check.ps1` verifies the committed phase against its declared **Territory** in `tasks.md` (Micro: in `spec.md`) — PASS required; a failing commit is remediated and redone | `docs/sdlc/review-process.md`, `docs/sdlc/definition-of-done.md` (gate 4) |
| 3e | AI review | **AI review** completed from `specs/_templates/ai-code-review-template.md` by a **fresh-context agent or second model** (never self-graded), with the Reviewer Provenance block | `docs/sdlc/definition-of-done.md` (gate 5), `docs/sdlc/review-process.md` |
| 4 | Feature review | **Human review**, once per feature at merge — in a team the reviewer is never the owner | `.specify/memory/constitution.md` (IX), `docs/sdlc/definition-of-done.md` (gate 6), `specs/_templates/human-pr-review-template.md` |
| 5 | Merge | Push the branch, merge `--no-ff` into protected `main`; CI on `main` is the cross-feature referee | `docs/sdlc/branch-strategy.md`, `docs/sdlc/team-workflow.md` (rule 8) |

The five bold entries are the mandatory checkpoints of the Definition of Done: gates
1 and 3–5 apply to **every phase commit**; gate 6 (human review) applies **once per
feature**, at merge.

## Lane variations

- **Lite** (`fix/`, `chore/`, `docs/` branches): skips step 2 entirely — no spec
  directory — but keeps the gate, the scope check, and human review before merge
  (`docs/sdlc/branch-strategy.md`).
- **Micro** (declared `**Delivery Level**: Micro` in `spec.md`): step 2 is a single-page
  mini-spec (`.specify/templates/micro-spec-template.md`) — no plan.md/tasks.md — and the
  phase loop runs exactly once, inside hard machine-checked bounds (≤5 territory files,
  ≤400 lines); every verification layer stays, with the scope check reading **Territory**
  from spec.md; outgrowing a bound promotes the feature in place to Standard
  (constitution X, Micro lane; `docs/sdlc/branch-strategy.md`).
- **Critical** (declared in `spec.md`): everything above plus the addendum in
  `docs/sdlc/critical-delivery.md`; agent-run gates are not used at all.
- **Batched gates**: a Lite/Standard plan may declare up to 3 consecutive phases sharing
  one certifying user-run gate at batch end (`docs/sdlc/gate-command.md`, constitution X)
  — per-phase commits, scope checks, and AI reviews stay; Critical never batches.
- **CI-held certification**: a Lite, Micro, or Standard feature may declare
  `**Gate Certification**: ci-held` (in `plan.md` — for Micro, in the mini-spec) —
  certification becomes the owner's recorded approval on the CI evidence
  triplet (run URL + green conclusion + exact phase-commit sha) instead of a live
  user-run gate (`docs/sdlc/gate-command.md`, constitution X). The agent still never
  claims success; Critical never uses it; absent the declaration, `user-run` is the value.
- **Teams**: ownership, claims, territory, cross-review, and parallel work are governed
  by `docs/sdlc/team-workflow.md`; single-developer projects can ignore it.
- **Pipelining**: while a feature sits in step 4 (awaiting review), its owner may claim
  and start the next one under the conditions in `docs/sdlc/team-workflow.md` (rule 3) —
  one awaiting-review + one active at most, territory disjoint.
