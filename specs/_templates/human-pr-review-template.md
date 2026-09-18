# Human PR Review — [NNN Feature Name]

**Reviewer**: [name]
**Date**: [YYYY-MM-DD]
**AI review**: [link/path to the completed ai-code-review.md — read it first; verify its
BLOCKING/CONFIRM findings were resolved, don't re-derive them]
**Spec / plan / tasks**: [links — for a Micro feature, the mini-spec `spec.md` alone;
verify its eligibility checklist still holds against the diff (constitution X, Micro lane)]

<!-- The Review Provenance block below is REQUIRED for a Critical feature in a project whose
  kit-adoption.json declares two or more developers ("team mode"): scripts/enforcement-pack.ps1
  fails the branch when the section is missing, either name is unfilled or left as a
  [placeholder], the two names match, or the attestation is absent. The file must also be
  COMMITTED — evidence in a working tree is not evidence.

  In a solo project the block is optional: there, item 5's independence is substituted by
  second-model-review.md plus the cooling-off period, and the check asks for that instead
  (docs/sdlc/critical-delivery.md item 5).

  What it proves is bounded, and worth stating plainly: two names written by the same team, in
  one file. It converts a silent omission into a written claim someone can falsify. It does not,
  and cannot, verify that the review happened.

  This comment sits OUTSIDE the section on purpose. A comment inside it that loses its closing
  marker would hide the whole block from a renderer — and, before the check learned to read
  comments the way a renderer does, would have hidden it from the check while still passing. -->

## Review Provenance

- **Reviewer**: [name — the person who reviewed; MUST NOT be the owner]
- **Owner**: [name — the person who owns and implemented the feature]
- **Attestation**: This reviewer is not the owner of the feature under review.

## Business Review

- [ ] Behavior matches the business intent in `spec.md` (not just the letter of the FRs)
- [ ] Domain correctness verified for business-critical outputs (spot-check real figures/cases)
- [ ] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred

## UI Review *(delete if no UI in this feature)*

- [ ] Actual rendered UI compared against the visual references (not just the code)
- [ ] Loading / empty / error states behave sensibly

## Technical Review

- [ ] Code diff read end-to-end; no unrelated changes (`git diff --stat` matches the phase scope)
- [ ] Every amendment to the feature's own approved documents carries its record, and the
      named approver really did approve it — a machine can only check the record exists and
      matches its commit; whether consent was real, and whether the implementing agent
      approved its own amendment, is yours to judge (constitution I)
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
