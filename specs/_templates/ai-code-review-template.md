# AI Code Review — [NNN Feature Name]

**Reviewer**: [agent + model]
**Date**: [YYYY-MM-DD]
**Branches**: [repo `branch` (tip `sha`) — one entry per affected repository]
**Scope reviewed**: [files/areas actually read — be explicit; "everything" is not a scope]
**Feature contract**: [the headline constraints from plan.md, e.g. "read-only; no new
table / migration / permission / package"]

## Verdict

[**APPROVE** / **APPROVE with follow-ups** / **REQUEST CHANGES** / **BLOCKED**] — one
paragraph: what the change does, why the verdict, and where the residual risk sits.

## What was verified (evidence)

> Every claim needs evidence — a file/symbol read, a test observed, a query run. A row
> without evidence is an assumption, not a verification.

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | |
| Visual-reference match (where references exist): Visual Compliance Loop deviation table attached, empty or user-approved (`docs/sdlc/review-process.md`) | |
| Feature contract held (no unapproved table/migration/permission/package) | |
| Constitution / domain invariants | |
| Security (authn/authz, secrets, sensitive logging) | |
| Scope guard (`git diff --stat` — only intended files) | |
| Rollback safety (phase reverts cleanly; schema additive?) | |

## Findings

> One `### F<n> — <title> — <status>` block per finding. Statuses:
> **BLOCKING** (must fix before merge) · **CONFIRM** (needs owner/domain-expert decision) ·
> **ACCEPTED** (deliberate deviation, documented) · **DOC DRIFT** (code correct, docs stale) ·
> **MINOR** (note for reviewer awareness). Every finding ends with an *Action:* line —
> "*Action: none*" is a valid action; a missing one is not.

### F1 — [title] — [STATUS]

[What was found, where (file/symbol), why it matters, and the evidence.]
*Action: [who does what, or "none" + why].*

## Constitution re-check (post-implementation)

[PASS/FAIL — re-evaluate the plan's Constitution Check against the code as built. List
principles satisfied / N/A / engaged-late, and any nuance vs. the plan-time check.]

## Test coverage observed

[Per test project/suite: what exists, what it asserts, counts. Name the critical
assertions (e.g. golden fixtures, tie-outs), not just totals.]

## Residual risk

[Where the risk concentrates, which findings carry it, and what must happen before or
after merge (e.g. "merge after live tie-out + domain sign-off").]
