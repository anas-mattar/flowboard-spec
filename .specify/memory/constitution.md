<!--
SYNC IMPACT REPORT
==================
Version change: 2.0.0 → 2.1.0 (FlowBoard, 2026-09-08)
Bump rationale: MINOR — Principle X (Controlled Delivery) materially expanded with the
  upstream kit's CI-held certification clause (kit constitution 0.5.0, feature 008),
  re-expressed here per adoption/updating.md §2. For Lite and Standard features only,
  the approved plan MAY declare `**Gate Certification**: ci-held`, under which gate
  certification is the owner's recorded approval on the CI evidence triplet — run URL,
  green conclusion, and the exact phase-commit sha (batch-end commit for a declared
  batch) — instead of a locally-run gate. The agent's obligations are unchanged: it
  never claims success; under ci-held it reports the evidence and requests the owner's
  approval. Critical features MUST NOT declare or use it (scripts/enforcement-pack.ps1
  fails a Critical plan declaring it — the check arrived in the same flow-down). Absent
  a declaration the value is `user-run`, so every existing plan stays compliant.
  Swept in the same change: CLAUDE.md strict rule and Law bullet, gate-command.md
  (CI-held section + CI wiring), review-process.md step 1, rulebook gate items; the
  kit's verbatim mirrors (definition-of-done gate 3, critical-delivery item 4,
  plan-template Gate Certification field, flow.md) arrived via update-kit in the same
  flow-down. Human adoption: the project owner's review and approval of this flow-down
  change (updating.md §2 step 6).

Prior version history entry — 1.0.0 → 2.0.0 (FlowBoard, 2026-09-01):
Bump rationale: MAJOR — adoption of the upstream kit's delivery-core amendments (kit
  constitution 0.3.0 and 0.4.0):
  1. Former V (Data Standards) and VI (Auditability) demoted to conventions in
     `docs/rulebooks/database-rules.md`, which already carries all their content in
     richer form (PK + PublicId rule, audit/soft-delete fields, append-only activity
     events) — no law lost, only relocated. Former X (Performance Responsibility)
     deleted outright (unfalsifiable; kit feature 001 finding #15). Remaining principles
     renumbered contiguously: VII→V (Domain Invariants), VIII→VI (Security), IX→VII
     (External Integration Governance), XI→VIII (Testing), XII→IX (Human Review),
     XIII→X (Controlled Delivery).
  2. Principle X gains the kit 0.4.0 **Batched gates** clause: Lite/Standard features
     may declare up to 3 consecutive phases sharing one certifying user-run gate
     (declared in plan.md before the batch); per-phase commits, scope checks, and AI
     reviews unchanged; Critical never batches (scripts/enforcement-pack.ps1 enforces).
  Swept in the same change: principle citations across docs/ and rulebooks;
  plan/spec/tasks templates replaced with kit 0.4.0 versions; definition-of-done.md now
  applies human review once per feature at merge (gates 1–5 per phase); new kit surface
  adopted (flow.md, claim-feature.ps1, territory-check.ps1, enforcement-pack.ps1 + CI
  workflow, branch-protection.md, team-workflow pipelining clause).

Prior version history entry — 0.2.0 → 1.0.0 (RATIFIED as the FlowBoard constitution, 2026-08-27):
Bump rationale: MAJOR — ratification. All slots filled and TODOs resolved:
  II  rung 2 → docs/product/prototype/flowboard-prototype.html (project-wide UI reference)
  V   PK = Id INT IDENTITY(1,1); API-exposed entities MUST carry an opaque public identifier
  VI  audit = CreatedDate/CreatedBy/UpdatedDate/UpdatedBy; soft delete = IsDeleted/DeletedDate/DeletedBy
  VII invariants pack = docs/domain/flowboard-invariants.md (8 invariants; carries force)
  III retained — multi-repo (flowboard-api / flowboard-web)
  Ratification decisions (also in docs/roadmap.md decisions log): board-scoped labels,
  30-day minimum archive restorability, opaque public IDs. Deferred as business questions:
  observer billing (spec §11 Q3), data residency at launch (§11 Q4).

Prior version history:
  0.1.0 → 0.2.0: kit template — principle IV bootstrap clause added.
  (template / unversioned) → 0.1.0: initial extraction of the portable constitution from a
  production deployment of this framework.

Principles defined (10):
  I.    Specification First
  II.   Source of Truth Hierarchy
  III.  Repository Separation            (retained — multi-repo)
  IV.   Architecture Consistency
  V.    Domain Invariants                (docs/domain/flowboard-invariants.md)
  VI.   Security
  VII.  External Integration Governance
  VIII. Testing Requirements
  IX.   Human Review Requirement
  X.    Controlled Delivery

Retired: former V (Data Standards) and VI (Auditability) — demoted to
  docs/rulebooks/database-rules.md, 2.0.0. Former X (Performance Responsibility) —
  deleted outright, 2.0.0, no replacement.

Templates requiring updates when this file changes:
  - .specify/templates/plan-template.md (Constitution Check gate must mirror the principles 1:1)
  - CLAUDE.md (strict rules must not contradict this file)
  - scripts/enforcement-pack.ps1 (encodes constitutional constants — batch-phase cap,
    Critical cooling-off hours, the Gate Certification legal values `user-run`/`ci-held`
    and the Critical ci-held exclusion — these MUST change in lockstep with amendments
    touching them)
-->

# FlowBoard Constitution

## Core Principles

### I. Specification First

All work MUST begin with specification and planning before implementation. The required
workflow is: (1) create or update `spec.md`; (2) create or update `plan.md`; (3) create or
update `tasks.md`; (4) implement one approved phase only; (5) run the project gate; (6) review
changes; (7) commit the approved phase. Implementation MUST NOT start before requirements are
documented.

**Rationale**: Documented intent prevents rework, makes review meaningful, and ties every code
change to an approved requirement.

### II. Source of Truth Hierarchy

The following order of precedence MUST always be respected:

1. Feature visual references (screenshots / prototype captures in `specs/[feature]/screenshots/`)
2. `docs/product/prototype/flowboard-prototype.html` — the project-wide UI reference; per-feature
   captures in rung 1 are taken from it
3. `spec.md`
4. `plan.md`
5. API contracts
6. Data model
7. `tasks.md`
8. Research documents
9. Notes

If a higher rung and a lower rung conflict, implementation MUST stop and the conflict MUST be
reported. Lower-fidelity artifacts MUST NOT silently override higher-fidelity intent. When
visual references exist, new UI layouts MUST NOT be invented.

**Rationale**: A single, ordered source of truth removes ambiguity and prevents lower-fidelity
artifacts from silently overriding higher-fidelity intent.

### III. Repository Separation

FlowBoard uses separate repositories. The backend repository is `flowboard-api`. The
frontend repository is `flowboard-web`. Backend and frontend code MUST NOT be mixed in the
same repository unless explicitly approved in the technical plan.

**Rationale**: Separation keeps deployment, security boundaries, and ownership clean across
tiers.

### IV. Architecture Consistency

The existing architecture is the source of truth. New features MUST follow the existing
architecture. New architectural patterns, new frameworks, new UI libraries, and new persistence
approaches MUST NOT be introduced unless explicitly approved in the technical plan.

**Bootstrap clause**: at project creation there is no existing architecture to follow. During
the initial scaffold feature (the project's first numbered feature — see
`adoption/greenfield.md`, step 4), "the existing architecture" means the architecture selected
and approved in that feature's `plan.md`, which MUST record the decision ADR-style: options
considered, the decision, and its consequences. Once the scaffold feature is merged, that
architecture becomes the existing architecture and this principle applies in full.

**Rationale**: Consistency lowers maintenance cost and keeps the system reviewable by the whole
team. Without the bootstrap clause, "follow the existing architecture" is undefined on an empty
repository — the clause anchors the rule to an approved plan instead of leaving the agent to
improvise one.

### V. Domain Invariants

The non-negotiable rules of this project's domain are defined in
`docs/domain/flowboard-invariants.md` and carry constitutional force. Agents
and reviewers MUST treat a domain-invariant violation exactly like a violation of this file.

**Rationale**: Every serious domain has rules that must survive any refactor (immutability of
postings, consent trails, order-state machines). Naming them once, with constitutional force,
stops an agent from "creatively" violating them.

### VI. Security

Authentication is required for protected functionality. Authorization is required for protected
operations. Secrets MUST NEVER be stored in source code. Sensitive information MUST NOT be
logged. All external integrations MUST use secure authentication mechanisms.

**Rationale**: Security controls are non-negotiable architecture concerns, not cleanup tasks.

### VII. External Integration Governance

All external integrations require documented contracts. Each contract MUST define purpose,
authentication, endpoints, request schema, response schema, error schema, timeout policy, retry
policy, idempotency strategy, and audit requirements. Undocumented integrations are prohibited.

**Rationale**: Documented contracts make integrations testable, recoverable, and safe to change.

### VIII. Testing Requirements

Business-critical functionality requires automated tests. Business-critical calculations require
deterministic validation (golden fixtures where outputs must be exact). Changes affecting
business-critical logic require regression coverage.

**Rationale**: Deterministic, regression-covered tests are the only credible guarantee that
critical logic remains correct across changes — especially changes made by an AI agent.

### IX. Human Review Requirement

AI review alone is insufficient. Human review is required before merge. Human reviewers MUST
verify business requirements, domain correctness, security implications, visual-reference
compliance (where visual references exist), and architectural compliance.

**Rationale**: Business and architectural correctness require human accountability that
automated review cannot replace.

### X. Controlled Delivery

Work MUST be delivered incrementally. Only one approved phase MAY be implemented at a time.
Unrelated changes MUST NOT be included in the same feature implementation. Every completed phase
MUST pass project gates — run by the user, with the exit code confirmed by the user — before
proceeding. An AI agent MUST NOT claim success without that confirmation.

**Batched gates**: for a Lite or Standard feature, the approved plan MAY declare — before the
batch's first phase is implemented, as `**Gate Batching**: phases N-M` in `plan.md` — that a
run of at most **3 consecutive phases** shares one certifying user-run gate at the end of the
batch. Within a batch, every phase still requires its own commit, its own scope check, and its
own AI review, and the agent still runs the gate per phase for feedback; only the user-run
certification moves to batch end. Critical features MUST NOT declare batches — their per-phase
user-run gate obligation is unchanged. Absent a declaration, the per-phase user-run gate above
applies in full.

**CI-held certification**: for a Lite or Standard feature, the approved plan MAY declare —
as `**Gate Certification**: ci-held` in `plan.md`, before the first phase it governs — that
gate certification is satisfied by the owner's **recorded approval on the evidence triplet**:
the CI run of the project gate on the **exact phase commit** (for a declared batch, the
batch-end commit), cited by run URL, green conclusion, and commit sha, recorded in the
feature's phase record. The approval is per phase (or per declared batch), never blanket;
a run on any other commit certifies nothing; the agent's obligations are unchanged — it
MUST NOT claim success, and under this mode it reports the evidence and requests the
owner's approval on it. The user-run gate remains lawful always. Critical features MUST NOT
declare or use CI-held certification. Absent a declaration, the value is `user-run` — the
gate law above applies in full.

**Rationale**: Small, gated increments keep changes reviewable, reversible, and low-risk; the
user-held exit code keeps the trust boundary human. Batching trades gate frequency — never
per-phase revertibility or review — for fewer owner interruptions on low-risk work, and only
when declared in an approved plan. CI-held certification moves the owner's approval input
from "I ran it" to "I read unforgeable evidence" — the agent cannot mint a green run on a
host it does not control — without ever removing the human approval itself; the trust
boundary stays human, asynchronously.

## Governance

This constitution supersedes all other development practices. When any rule, document, or
generated artifact conflicts with this constitution, the constitution prevails. This file is the
project's ONLY constitution — do not create a second copy elsewhere in the repository; other
documents may point here.

**Amendment procedure**: Amendments MUST be proposed as a documented change to this file,
including rationale and impact on dependent templates (`plan-template.md`, `spec-template.md`,
`tasks-template.md`) and runtime guidance (`CLAUDE.md`, `docs/`). An amendment is adopted only
after human approval. Update the SYNC IMPACT REPORT header with every amendment.

**Versioning policy**: This constitution is versioned using semantic versioning.
MAJOR — backward-incompatible governance or principle removals or redefinitions.
MINOR — a new principle or section is added, or guidance is materially expanded.
PATCH — clarifications, wording, and non-semantic refinements.

**Compliance review**: All specs, plans, tasks, pull requests, and reviews MUST verify
compliance with these principles. The Constitution Check gate in `plan-template.md` MUST be
evaluated before Phase 0 research and re-evaluated after Phase 1 design. Any violation MUST be
justified in the plan's Complexity Tracking section or the work MUST stop and be reported. Use
`CLAUDE.md` and the `docs/` guidance files for runtime development guidance.

**Version**: 2.1.0 | **Ratified**: 2026-08-27 | **Last Amended**: 2026-09-08
