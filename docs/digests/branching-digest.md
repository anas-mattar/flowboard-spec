# branching pack — law digest (GENERATED)

<!-- GENERATED FILE — do not edit. Regenerate: pwsh -File scripts/build-digests.ps1
     Non-authoritative: for orientation only. The source documents prevail (constitution
     II is unchanged); read the full document before acting on its area. -->

- Feature branches are NNN-short-name mapping 1:1 to specs/NNN-short-name/ — never hand-invent a different layout. (`docs/sdlc/branch-strategy.md`)
- Claim with scripts/claim-feature.ps1: remote-aware number allocation and an immediate push — the remote is the ledger. (`docs/sdlc/branch-strategy.md`)
- Lite lane (fix/, chore/, docs/): no spec directory, but the gate, scope check, and human review before merge remain. (`docs/sdlc/branch-strategy.md`)
- Four delivery levels in ascending ceremony: Lite < Micro < Standard < Critical; chosen per feature, declared in spec.md. (`docs/sdlc/branch-strategy.md`)
- Micro: single-page mini-spec, exactly one phase, at most 5 territory files and 400 changed lines, machine-enforced. (`docs/sdlc/branch-strategy.md`)
- Behavior change is at least Micro; a Micro feature that outgrows a bound promotes in place to Standard, never stretches. (`docs/sdlc/branch-strategy.md`)
- main is protected: no direct commits, never force-push; merge only after certification and approved human review. (`docs/sdlc/branch-strategy.md`)
- Push the feature branch before merging; merge --no-ff so the merge commit survives; one commit per phase. (`docs/sdlc/branch-strategy.md`)
- Every feature has exactly one owner — "the user" means the feature's owner, never a teammate and never the agent. (`docs/sdlc/team-workflow.md`)
- A remote NNN-* branch IS the claim — check remote branches before picking, never the roadmap alone. (`docs/sdlc/team-workflow.md`)
- WIP limit: one active feature each; pipelining: one awaiting-review + one active, territory disjoint or sequenced. (`docs/sdlc/team-workflow.md`)
- Cross-review: the human reviewer of a feature must not be its owner. (`docs/sdlc/team-workflow.md`)
- Run territory-check.ps1 before each phase; overlap is sequenced by agreed merge order, never discovered at merge time. (`docs/sdlc/team-workflow.md`)
- Rebase on main before the final phase's gate, and after any teammate's merge touching your territory. (`docs/sdlc/team-workflow.md`)
- Governance changes ride alone on a docs/ branch with team-lead approval — never inside a feature branch. (`docs/sdlc/team-workflow.md`)
- A merge that turns main red is reverted immediately via the fix/ lane — no debugging on a red main. (`docs/sdlc/team-workflow.md`)
