# Human PR Review — [NNN Feature Name]

**Reviewer**: [name]
**Date**: [YYYY-MM-DD]
**AI review**: [link/path to the completed ai-code-review.md — read it first; verify its
BLOCKING/CONFIRM findings were resolved, don't re-derive them]
**Spec / plan / tasks**: [links — for a Micro feature, the mini-spec `spec.md` alone;
verify its eligibility checklist still holds against the diff (constitution X, Micro lane)]

## Business Review

- [ ] Behavior matches the business intent in `spec.md` (not just the letter of the FRs)
- [ ] Domain correctness verified for business-critical outputs (spot-check real figures/cases)
- [ ] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred

## UI Review *(delete if no UI in this feature)*

- [ ] Actual rendered UI compared against the visual references (not just the code)
- [ ] Loading / empty / error states behave sensibly

## Technical Review

- [ ] Code diff read end-to-end; no unrelated changes (`git diff --stat` matches the phase scope)
- [ ] Architectural compliance (constitution IV) — no unapproved patterns/packages
- [ ] Security implications considered (authz on new surface, secrets, logging)
- [ ] Migrations/schema changes are additive or their rollback is documented

## Gate Result

- [ ] Gate certified **by the reviewer or user** (not the AI); exit code: `EXIT: ___` —
      or ci-held (declared in the plan or Micro mini-spec, Lite/Micro/Standard only):
      run URL + green conclusion +
      commit sha: `___`
      (`docs/sdlc/gate-command.md`)

## Approval

**Decision**: [APPROVED / CHANGES REQUESTED] — merge only on APPROVED (constitution IX).

## Comments

[Anything the next person touching this area should know.]
