# Critical Delivery Addendum

Additive requirements for high-risk features. This file is only read when a feature is
declared **Critical**; everything here applies **on top of** the full numbered-feature
workflow, never instead of it.

## Delivery levels

The kit has four delivery levels. The first three are defined elsewhere — Lite and
Standard under other names in `docs/sdlc/branch-strategy.md`, Micro in constitution X
(Micro lane); this file defines only the last:

| Level | Lane | Requirements |
|---|---|---|
| **Lite** | `fix/`, `chore/`, `docs/` — the lightweight lane (`docs/sdlc/branch-strategy.md`) | User-run gate + `git diff --stat` scope check + human review |
| **Micro** | `NNN-` numbered feature, single-page mini-spec, one phase inside hard bounds (constitution X, Micro lane) | Mini-spec approved + Definition of Done with the Micro arms (`docs/sdlc/definition-of-done.md`) |
| **Standard** | `NNN-` numbered feature | Full spec workflow + Definition of Done (`docs/sdlc/definition-of-done.md`) |
| **Critical** | `NNN-` numbered feature + this addendum | Standard, plus the additions below — **never** Micro, gate batching, or ci-held |

The level is chosen **per feature, at feature creation** — not per project. A project in a
regulated domain will declare most features Critical; the same project's internal admin
report can still ship Standard. Declare the level in the feature's `spec.md` header; if a
feature's risk grows mid-flight (it starts touching money movement, patient data, or
irreversible operations), stop and promote it — exactly like promoting a `fix/` branch that
grew into a feature.

<!-- digest: The level is chosen per feature at creation, declared in spec.md; risk growing mid-flight promotes — never stretch. -->

## When a feature MUST be Critical

Declare Critical when the feature touches any of:

- rules in the domain-invariants pack (constitution V) — postings, balances, consent
  trails, state machines;
- irreversible or destructive data operations (migrations that drop or rewrite data);
- authentication, authorization, or payment flows;
- anything a regulator, auditor, or contract can ask evidence for.

**Why**: these are the changes where "we can fix it in a follow-up" is false.

<!-- digest: Declare Critical for domain invariants, irreversible data operations, authn/authz/payment, or auditor-facing evidence. -->

## Additional requirements (all MUST)

1. **Rollback plan before implementation** — `specs/_templates/rollback-template.md` is
   filled for this feature **before phase 1 begins**, not at review time.
   **Why**: a rollback plan written after the change is a description, not a plan.

   <!-- digest: Critical 1: the rollback plan is filled before phase 1 begins, not at review time. -->

2. **Domain-invariant review** — the AI review and the human review each include an explicit
   pass over the domain-invariants pack (constitution V), item by item, recorded in the
   review document.
   **Why**: invariant violations are the one class of defect the gate cannot catch.

   <!-- digest: Critical 2: AI and human reviews each pass over the domain-invariants pack item by item, recorded. -->

3. **Audit evidence retained** — the gate command + exit code, the `scope-check.ps1`
   verdict and the `git diff --stat` output,
   and both completed review checklists are kept in the feature directory.
   **Why**: "we reviewed it" must be demonstrable later, not remembered.

   <!-- digest: Critical 3: audit evidence retained — gate command + exit code, scope-check verdict, diff stat, both review checklists. -->

4. **Human-executed gates only, one per phase** — the agent-run gate feedback loop
   (`docs/sdlc/gate-command.md`) does not apply, and neither does gate batching
   (constitution X, Batched gates), CI-held certification (constitution X, CI-held
   certification), nor the Micro lane (constitution X, Micro lane — a Critical feature is
   never a one-phase mini-spec feature): a Critical feature MUST NOT declare
   `**Gate Batching**` or `**Gate Certification**: ci-held` in its `plan.md`, nor
   `**Delivery Level**: Micro` at all — `scripts/enforcement-pack.ps1` fails the branch
   on any of these. Every phase's gate run that counts toward Done is executed
   by a human, locally.
   **Why**: for Critical work, even the fast-feedback loop stays on the human side of the
   trust boundary, and both gate frequency and gate *execution* are part of that boundary.

   <!-- digest: Critical 4: human-executed gates only, one per phase — never agent-run gates, batching, ci-held, or the Micro lane. -->

5. **Independent approval** — the human reviewer MUST NOT be the feature's owner
   (`docs/sdlc/team-workflow.md`). A solo developer substitutes:
   - a written **second-model adversarial review**, recorded as
     `specs/NNN-name/second-model-review.md`, structured like
     `specs/_templates/ai-code-review-template.md` but performed by a model different from
     the one that implemented the feature, explicitly instructed to probe for the
     implementer's likely blind spots (not to re-confirm its work); and
   - a minimum **24-hour cooling-off period** between that review being recorded and the
     feature being merged, during which the developer does not act further on the feature.

   **Honesty**: this substitute is a mitigation for the solo-developer case, not a claim of
   true independence — it does not provide the independence an external human reviewer would.
   **Why**: the person who drove the agent is the person least able to see its blind spots,
   and an undefined substitute ("some review, some time") is not falsifiable.

   <!-- digest: Critical 5: the human reviewer is never the owner; solo devs substitute a second-model review + 24h cooling-off. -->

## What this addendum is NOT

It adds no new gates, documents, or workflow steps beyond the five items above. Do not
invent extra ceremony for Critical features — the protection comes from evidence and
independence, not volume.

<!-- digest: Critical adds nothing beyond the five items — protection comes from evidence and independence, not volume. -->
