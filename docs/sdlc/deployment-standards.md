# Deployment Standards

> **Status: PLACEHOLDER — expand as deployment decisions are made.**
> This document is deliberately incomplete. It exists so that deployment decisions, once
> made, have an enforceable home — and so that *until* they are made, no one can claim a
> deployment practice is "governed". Expansion of this document must itself go through the
> spec → plan → tasks workflow.

## Scope (to be expanded)

- CI/CD gate enforcement (the user-run gate's automated twin)
- Environment promotion (dev → staging → production)
- Secrets handling (never in source — constitution VIII; define the injection mechanism)
- Migration/rollback alignment (`docs/sdlc/rollback-process.md`)
- Repository separation at deploy time (`docs/sdlc/repository-strategy.md`)

## Recorded decisions

*(Append decisions here as they are made, each with a date and the feature/spec that
introduced it. Nothing is recorded yet.)*

## Break-glass procedure (template)

When production requires an emergency change that bypasses the normal gates, ALL of the
following must hold — record each instance:

1. Conditions (all-of): {{BREAK_GLASS_CONDITIONS}} <!-- e.g. production outage + no
   gate-passing fix available within the SLA -->
2. Named approver: {{BREAK_GLASS_APPROVER}} <!-- a person/role, not a team -->
3. Revert window: the bypassing change is re-driven through the full workflow (spec, gate,
   reviews) within {{REVERT_WINDOW}} or reverted.
4. Any privileged role/permission granted for the emergency is time-boxed and audited.

## Until expanded

No deployment automation is governed by this kit yet. Deployments are manual and each one
must be recorded under "Recorded decisions" above until this document is expanded.
