<!--
Embeds specs/_templates/human-pr-review-template.md's checklist so the review layer is
visible on every PR instead of relying on memory (specs/002-enforcement-pack, FR-009).
Keep this in sync by hand if that template changes — no templating engine exists in this kit
(see specs/002-enforcement-pack/research.md §7).
-->

## Summary

[What does this PR do, in one or two sentences?]

**Feature/branch**: `[NNN-name | fix/name | chore/name | docs/name]`
**Spec / plan / tasks**: [link, if this is a numbered `NNN-` feature]
**AI review**: [link to the completed ai-code-review.md — read it first]

## Business Review

- [ ] Behavior matches the business intent in `spec.md` (not just the letter of the FRs)
- [ ] Domain correctness verified for business-critical outputs (spot-check real figures/cases)
- [ ] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred

## UI Review *(delete if no UI in this PR)*

- [ ] Actual rendered UI compared against the visual references (not just the code)
- [ ] Loading / empty / error states behave sensibly

## Technical Review

- [ ] Code diff read end-to-end; no unrelated changes (`git diff --stat` matches the phase scope)
- [ ] Architectural compliance (constitution IV) — no unapproved patterns/packages
- [ ] Security implications considered (authz on new surface, secrets, logging)
- [ ] Migrations/schema changes are additive or their rollback is documented

## Gate Result

- [ ] Gate run **by the reviewer or user** (not the AI)

**Gate exit code**: `EXIT: ___`

## Approval

**Decision**: [APPROVED / CHANGES REQUESTED] — merge only on APPROVED (constitution IX).

## Comments

[Anything the next person touching this area should know.]
