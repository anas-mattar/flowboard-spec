# Definition of Done

The single, authoritative checklist a phase MUST satisfy before it is considered
complete. It is the operational form of constitution **XIII. Controlled Delivery**
and **XII. Human Review Requirement**.

> A phase is **Done** only when **every** item below is true. If any item is false,
> the phase is **not** Done — stop and resolve it before proceeding.

## Gates (all required, in order)

1. **Specification approved** — `spec.md`, `plan.md`, and `tasks.md` for the feature
   exist and are approved before implementation begins (constitution I).
2. **Single-phase scope respected** — only the one approved phase was implemented; no
   unrelated changes are bundled in (constitution XIII).
3. **Gate passed with user-confirmed exit code** — the user (not AI) ran the gate
   (`docs/sdlc/gate-command.md`) and confirmed the exit code. AI MUST NOT claim
   success without that confirmation (constitution XIII). The AI MAY run the gate
   during implementation for fast feedback, but an agent-run gate never satisfies
   this item — and is not used at all for Critical features
   (`docs/sdlc/critical-delivery.md`).
4. **Diff reviewed / scope guard** — `git diff --stat` was reviewed and shows only the
   files this phase intended to change; unrelated changes were reverted
   (`docs/sdlc/review-process.md`).
5. **AI review complete** — the AI review checklist
   (`specs/_templates/ai-code-review-template.md`) was completed: spec/visual-reference
   match, stack rulebooks, security, tests, migrations, unrelated changes,
   rollback safety. For phases touching a tier with a compliance checklist
   (`docs/rulebooks/`), this includes passing that checklist — any FAIL blocks the phase.
6. **Human review approved** — a human reviewer verified business requirements,
   domain correctness, security implications, visual-reference compliance, and
   architectural compliance, and approved the change. **Human review is required
   before merge** (constitution XII; `specs/_templates/human-pr-review-template.md`).

Only after items 1–6 are all true may the phase be **committed and merged**. Merge
occurs only after the human approval in item 6.

## Conflict rule

If any artifact conflicts with another, or with the constitution, **stop and report**
rather than silently choosing one. The constitution
(`.specify/memory/constitution.md`) prevails.

## Equivalence to the constitution

This Definition of Done is equivalent to constitution **XIII** (incremental delivery,
one approved phase at a time, no unrelated changes, every phase passes the gate) plus
**XII** (mandatory human review before merge). Applying this checklist to a phase
yields the same pass/fail outcome as applying those principles directly. If this
document and the constitution ever diverge, the constitution prevails and this
document MUST be corrected.
