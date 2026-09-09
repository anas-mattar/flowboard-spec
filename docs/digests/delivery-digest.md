# delivery pack — law digest (GENERATED)

<!-- GENERATED FILE — do not edit. Regenerate: pwsh -File scripts/build-digests.ps1
     Non-authoritative: for orientation only. The source documents prevail (constitution
     II is unchanged); read the full document before acting on its area. -->

- Gates 1-5 must hold at every phase commit; gate 6 (human review) applies once per feature, at merge. (`docs/sdlc/definition-of-done.md`)
- Gate 1: spec.md, plan.md, tasks.md approved before implementation begins; Micro: the approved mini-spec alone. (`docs/sdlc/definition-of-done.md`)
- Gate 2: only the one approved phase, nothing unrelated; Micro: at most 400 changed lines across the phase's commits. (`docs/sdlc/definition-of-done.md`)
- Gate 3: the user runs the gate and confirms the exit code — the AI never claims success on its own runs. (`docs/sdlc/definition-of-done.md`)
- Batched gates (Lite/Standard, plan-declared, max 3 consecutive phases): one certifying user-run gate at batch end. (`docs/sdlc/definition-of-done.md`)
- ci-held (Lite/Micro/Standard, declared in plan or mini-spec): owner approval recorded on run URL + green + exact sha. (`docs/sdlc/definition-of-done.md`)
- Gate 4: scope-check PASS — every changed file inside the declared Territory; amendments precede the phase commit. (`docs/sdlc/definition-of-done.md`)
- Gate 5: AI review by a fresh-context agent or second model with the Reviewer Provenance block — never self-graded. (`docs/sdlc/definition-of-done.md`)
- Gate 6: a human reviews the full feature diff and approves before merge — once per feature. (`docs/sdlc/definition-of-done.md`)
- If artifacts conflict, stop and report — the constitution prevails; never silently choose. (`docs/sdlc/definition-of-done.md`)
- The flow: baseline, claim, specify, phase loop (gate, commit, scope check, AI review), human review, merge. (`docs/sdlc/flow.md`)
- flow.md is a summary, not law — the owning documents prevail, and the constitution prevails over everything. (`docs/sdlc/flow.md`)
