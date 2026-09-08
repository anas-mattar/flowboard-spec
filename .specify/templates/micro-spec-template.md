# Micro Spec: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`
**Created**: [DATE]
**Status**: Draft <!-- Draft → Approved (owner) before the phase begins — constitution I, Micro arm -->
**Delivery Level**: Micro
**Gate Certification**: user-run <!-- prefilled default — keep, or change the value to
  ci-held (lawful on Micro — constitution X, CI-held certification; this mini-spec is the
  declaration's home, since the lane has no plan.md), or delete the whole line (absent =
  user-run). Never leave a bracketed placeholder here — it is a malformed value. -->

<!-- ONE PAGE. A Micro feature is exactly ONE phase inside hard bounds: Territory of at
  most 5 files (this spec directory excluded) and at most 400 changed lines in total
  across the phase's commits — machine-enforced failures, not warnings (constitution X,
  Micro lane; scripts/enforcement-pack.ps1). NEVER declare `**Gate Batching**` here. If the work
  outgrows any bound, promote in place to Standard: expand this file to the full
  spec-template, add plan.md + tasks.md (Territory moves there), in a commit BEFORE any
  further phase commit. Critical work MUST NOT use this lane. -->

## Intent

[What changes and why — a few sentences. Enough for a reviewer to judge the diff against
documented intent, no more.]

## Acceptance checks

<!-- Numbered, individually testable. These are what the AI review and human review verify
  the phase commit against. -->

1. [Observable outcome, e.g. "the CLI prints the new flag in --help and honors it"]
2. [Observable outcome]

## Eligibility checklist *(all boxes MUST be checkable — one unchecked box means this is not a Micro feature)*

<!-- The non-measurable bounds, affirmed here at approval and verified in human review
  (the measurable bounds — 5 territory files, 400 lines, one phase — are machine-checked). -->

- [ ] No schema change or migration
- [ ] No new packages or dependencies
- [ ] No architecture change
- [ ] No domain-invariant surface (constitution V)
- [ ] No UI with visual references (`screenshots/`)

<!-- The complete set of files the ONE phase commit may touch — at most 5; this feature's
  own specs/###-feature-name/** is implicitly in territory and does not count.
  scripts/scope-check.ps1 reads this block from the commit's parent (anti-widening).
  Keep the exact `**Territory**:` marker below — it is what the machine parses. -->

**Territory**:

- `path/to/file-one`
- `path/to/file-two`

## Rollback

Revert the single phase commit (`git revert <sha>`). [Add one line only if anything else
is needed — if more than a line is needed, this is not a Micro feature.]
