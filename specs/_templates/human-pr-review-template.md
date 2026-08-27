# Human PR Review — [NNN Feature Name]

**Reviewer**: [name]
**Date**: [YYYY-MM-DD]
**AI review**: [link/path to the completed ai-code-review.md — read it first; verify its
BLOCKING/CONFIRM findings were resolved, don't re-derive them]

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

- [ ] Gate run **by the reviewer or user** (not the AI); exit code: `EXIT: ___`

## Approval

**Decision**: [APPROVED / CHANGES REQUESTED] — merge only on APPROVED (constitution XII).

## Comments

[Anything the next person touching this area should know.]
