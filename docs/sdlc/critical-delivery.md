# Critical Delivery Addendum

Additive requirements for high-risk features. This file is only read when a feature is
declared **Critical**; everything here applies **on top of** the full numbered-feature
workflow, never instead of it.

## Delivery levels

The kit has three delivery levels. Two already exist under other names; this file defines
only the third:

| Level | Lane | Requirements |
|---|---|---|
| **Lite** | `fix/`, `chore/`, `docs/` — the lightweight lane (`docs/sdlc/branch-strategy.md`) | User-run gate + `git diff --stat` scope check + human review |
| **Standard** | `NNN-` numbered feature | Full spec workflow + Definition of Done (`docs/sdlc/definition-of-done.md`) |
| **Critical** | `NNN-` numbered feature + this addendum | Standard, plus the additions below |

The level is chosen **per feature, at feature creation** — not per project. A project in a
regulated domain will declare most features Critical; the same project's internal admin
report can still ship Standard. Declare the level in the feature's `spec.md` header; if a
feature's risk grows mid-flight (it starts touching money movement, patient data, or
irreversible operations), stop and promote it — exactly like promoting a `fix/` branch that
grew into a feature.

## When a feature MUST be Critical

Declare Critical when the feature touches any of:

- rules in the domain-invariants pack (constitution VII) — postings, balances, consent
  trails, state machines;
- irreversible or destructive data operations (migrations that drop or rewrite data);
- authentication, authorization, or payment flows;
- anything a regulator, auditor, or contract can ask evidence for.

**Why**: these are the changes where "we can fix it in a follow-up" is false.

## Additional requirements (all MUST)

1. **Rollback plan before implementation** — `specs/_templates/rollback-template.md` is
   filled for this feature **before phase 1 begins**, not at review time.
   **Why**: a rollback plan written after the change is a description, not a plan.
2. **Domain-invariant review** — the AI review and the human review each include an explicit
   pass over the domain-invariants pack (constitution VII), item by item, recorded in the
   review document.
   **Why**: invariant violations are the one class of defect the gate cannot catch.
3. **Audit evidence retained** — the gate command + exit code, the `git diff --stat` output,
   and both completed review checklists are kept in the feature directory.
   **Why**: "we reviewed it" must be demonstrable later, not remembered.
4. **Human-executed gates only** — the agent-run gate feedback loop
   (`docs/sdlc/gate-command.md`) does not apply. Every gate run that counts toward Done is
   executed by a human.
   **Why**: for Critical work, even the fast-feedback loop stays on the human side of the
   trust boundary.
5. **Independent approval** — the human reviewer MUST NOT be the feature's owner
   (`docs/sdlc/team-workflow.md`). A solo developer substitutes a second-model adversarial
   review (`adoption/existing-system.md`, step 6) plus a cooling-off period before merge.
   **Why**: the person who drove the agent is the person least able to see its blind spots.

## What this addendum is NOT

It adds no new gates, documents, or workflow steps beyond the five items above. Do not
invent extra ceremony for Critical features — the protection comes from evidence and
independence, not volume.
