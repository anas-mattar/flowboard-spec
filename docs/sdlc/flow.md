# The Flow — the Whole Ritual on One Page

Every stage of delivering a feature, in order, on one page. **This page is a summary,
not law**: it introduces no rule and changes none. If anything here conflicts with an
owning document, the owning document prevails — and the constitution
(`.specify/memory/constitution.md`) prevails over everything.

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
└───────────────────────────────┬─────────────────────────────────────┘
┌───────────────────────────────▼─────────────────────────────────────┐
│ 3 PHASE LOOP   one approved phase at a time                         │
│                                                                     │
│      implement one phase (UI + visual refs → compliance loop)       │
│         → owner runs the GATE, confirms the exit code               │
│         → SCOPE CHECK: git diff --stat = this phase's files only    │
│         → AI REVIEW checklist                                       │
│         → commit the phase                                          │
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
| 2 | Specify | **Specification approved**: `spec.md`, then `plan.md`, then `tasks.md`, approved before implementation | `.specify/memory/constitution.md` (I), `docs/sdlc/definition-of-done.md` (gate 1) |
| 3a | Implement | Exactly one approved phase; UI with visual references runs the Visual Compliance Loop | `.specify/memory/constitution.md` (X), `docs/sdlc/review-process.md` |
| 3b | Gate | **User-run gate**: the owner runs it and confirms the exit code — agent runs are feedback only | `docs/sdlc/gate-command.md`, `docs/sdlc/definition-of-done.md` (gate 3) |
| 3c | Scope check | **Diff review**: `git diff --stat` shows only this phase's intended files; revert anything else | `docs/sdlc/review-process.md`, `docs/sdlc/definition-of-done.md` (gate 4) |
| 3d | AI review | **AI review checklist** completed from `specs/_templates/ai-code-review-template.md` | `docs/sdlc/definition-of-done.md` (gate 5) |
| 3e | Commit | One commit per phase, so a bad phase reverts cleanly | `docs/sdlc/branch-strategy.md`, `docs/sdlc/rollback-process.md` |
| 4 | Feature review | **Human review**, once per feature at merge — in a team the reviewer is never the owner | `.specify/memory/constitution.md` (IX), `docs/sdlc/definition-of-done.md` (gate 6), `specs/_templates/human-pr-review-template.md` |
| 5 | Merge | Push the branch, merge `--no-ff` into protected `main`; CI on `main` is the cross-feature referee | `docs/sdlc/branch-strategy.md`, `docs/sdlc/team-workflow.md` (rule 8) |

The five bold entries are the mandatory checkpoints of the Definition of Done: gates
1 and 3–5 apply to **every phase commit**; gate 6 (human review) applies **once per
feature**, at merge.

## Lane variations

- **Lite** (`fix/`, `chore/`, `docs/` branches): skips step 2 entirely — no spec
  directory — but keeps the gate, the scope check, and human review before merge
  (`docs/sdlc/branch-strategy.md`).
- **Critical** (declared in `spec.md`): everything above plus the addendum in
  `docs/sdlc/critical-delivery.md`; agent-run gates are not used at all.
- **Batched gates**: a Lite/Standard plan may declare up to 3 consecutive phases sharing
  one certifying user-run gate at batch end (`docs/sdlc/gate-command.md`, constitution X)
  — per-phase commits, scope checks, and AI reviews stay; Critical never batches.
- **Teams**: ownership, claims, territory, cross-review, and parallel work are governed
  by `docs/sdlc/team-workflow.md`; single-developer projects can ignore it.
- **Pipelining**: while a feature sits in step 4 (awaiting review), its owner may claim
  and start the next one under the conditions in `docs/sdlc/team-workflow.md` (rule 3) —
  one awaiting-review + one active at most, territory disjoint.
