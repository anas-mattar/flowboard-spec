# Specification Quality Checklist: Drag & Drop Ordering

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-28
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- No `[NEEDS CLARIFICATION]` markers were needed. The one genuinely ambiguous design
  question this feature raises — whether `PATCH /v1/cards/{id}` should be extended to
  accept a move, or a dedicated move endpoint added instead — is an implementation
  decision, not a business-requirements ambiguity, and is deferred to `plan.md` as an
  ADR rather than marked here.
- The prototype (`docs/product/prototype/flowboard-prototype.html`) was inspected
  directly (not just its static screenshot) to confirm two load-bearing behavioral
  details that aren't visible in a single still image: (1) a same-list reorder writes no
  activity entry, only a cross-list move does; (2) the "Move" menu only offers a
  destination list, never a position within it. Both are now reflected in the spec's
  Acceptance Scenarios and Assumptions rather than left to be guessed at during planning.
- One prototype behavior was deliberately excluded as out of scope: the sample board's
  "Done" list and its auto-complete-on-move heuristic. No functional-spec story,
  roadmap item, or invariant backs it, and the real seeded boards have no such list —
  documented in Assumptions so it isn't silently reintroduced during implementation.
- Three screenshots were captured for the Visual Inventory this feature requires,
  covering card-drag, list-drag, and the keyboard-accessible "Move" popover — every
  visual element load-bearing to this feature's three user stories.
