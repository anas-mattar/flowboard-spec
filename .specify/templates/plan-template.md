# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`
**Gate Batching**: none <!-- REQUIRED value: `none`, or `phases N-M` to declare that up to 3
  consecutive phases share one certifying user-run gate at batch end (constitution X,
  Batched gates). Lite/Standard only — a Critical feature declaring a batch fails
  scripts/enforcement-pack.ps1. Declare BEFORE the batch's first phase is implemented;
  never retroactively. -->

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]  
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]  
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]  
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Confirm each item or record a justified exception in Complexity Tracking. Source: `.specify/memory/constitution.md`.

<!-- Keep this list mirroring the constitution's principles 1:1. When the constitution is
     amended, regenerate these items (this is required by the constitution's SYNC IMPACT
     REPORT / amendment procedure). -->

- [ ] **Specification First (I)**: spec.md, plan.md, and tasks.md exist and are approved before implementation.
- [ ] **Source of Truth (II)**: No conflict between artifacts, per the ordered source-of-truth ladder in constitution II. Conflicts stop work.
- [ ] **Repository Separation (III)**: Backend (`{{BACKEND_REPO}}`) and frontend (`{{FRONTEND_REPO}}`) code are not mixed unless approved here. *(Delete if the project is single-repo.)*
- [ ] **Architecture Consistency (IV)**: No new patterns, frameworks, UI libraries, or persistence approaches unless approved in this plan.
- [ ] **Domain Invariants (V)**: The plan violates no rule in `{{DOMAIN_INVARIANTS_PATH}}`.
- [ ] **Security (VI)**: Auth required for protected functionality/operations; no secrets in source; no sensitive data in logs.
- [ ] **External Integration Governance (VII)**: Every external integration has a complete documented contract.
- [ ] **Testing Requirements (VIII)**: Business-critical logic has automated/deterministic/regression coverage.
- [ ] **Human Review (IX)**: Plan accounts for required human review before merge.
- [ ] **Controlled Delivery (X)**: One approved phase at a time; no unrelated changes; each phase passes the user-run gate — or, for a Lite/Standard feature with `**Gate Batching**: phases N-M` declared above (max 3 consecutive phases, before the batch starts), one certifying user-run gate at batch end while every phase keeps its own commit, scope check, AI review, and agent-run feedback gate. Critical features MUST NOT batch.

  **Phase sizing rule**: A phase MUST be independently revertible (no other phase's
  correctness depends on this phase being present) and MUST correspond to one meaningfully
  independent, testable slice of the feature — not "whatever fits before the deadline." A
  phase breakdown that bundles unrelated concerns (e.g., a schema change and an unrelated UI
  change) into one phase FAILS this gate and MUST be split before the plan is approved.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
