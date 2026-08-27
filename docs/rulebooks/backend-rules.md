# Backend Rules — FlowBoard

> **Binding**: this rulebook is enforced through the backend tier's compliance checklist
> (Definition of Done item 5, `docs/sdlc/definition-of-done.md`): the checklist asserts,
> this rulebook explains. Domain invariants (`{{DOMAIN_INVARIANTS_PATH}}`) carry
> constitutional force and always outrank this file.

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment):

1. At adoption, fill the {{SLOT}}s and keep only the baseline rules that are TRUE for your
   codebase. On an existing system, write rules descriptively, not aspirationally — an
   aspirational rule makes the agent "improve" code it should not touch
   (`adoption/existing-system.md`, step 2). Copy to docs/rulebooks/backend-rules.md and
   point CLAUDE.md's {{BACKEND_RULES_PATH}} slot at it.
2. Grow it reactively (`adoption/greenfield.md`, step 6): a class of mistake caught twice
   in review becomes a rule here, a binary item in the tier checklist, and — where
   possible — a lint/analyzer rule. Once the machine enforces it, the prose shrinks.
3. Every rule is MUST / MUST NOT with a one-line Why. No advice ("prefer X") — advice is
   what agents drop first under pressure.
-->

## Layering & Placement

- Code layout: {{BACKEND_LAYOUT}} <!-- e.g. "Domain/ entities; Data/ DbContext + Migrations/; Endpoints/ static endpoint classes" -->
- New code MUST follow the existing layout. A new top-level folder, layer, or project
  requires approval in the feature's `plan.md`.
  **Why**: architecture changes ride in on "just one helper folder" — this is where drift starts.

## API Surface

- Every external input MUST be validated at the API boundary; validation failures MUST
  return {{ERROR_SHAPE}}. <!-- e.g. "RFC 9457 validation problem details" -->
  **Why**: the boundary is the one place a bad value is rejected once for all callers.
- Responses MUST use dedicated DTOs; domain entities MUST NOT be serialized directly.
  **Why**: entity leaks turn every schema refactor into a breaking API change.
- Code implementing a feature contract MUST cite the contract file (the feature's
  `contracts/` directory) in a comment at the top of the file.
  **Why**: the citation makes rung-checking possible during review.

## Domain Logic

- Domain invariants (`{{DOMAIN_INVARIANTS_PATH}}`) MUST be enforced in code AND asserted
  by the database schema where a constraint can express them — never in one place only.
- Money, dates, and numbers MUST be parsed and formatted culture-invariantly at every
  boundary. **Why**: a locale-dependent parse is data corruption that no test on the
  author's machine catches.
- Shared business calculations (rounding, conversion, totals) MUST live in one named
  module — {{CALCULATION_MODULE}} — covered by golden-fixture tests. Re-deriving them
  inline is prohibited. **Why**: two implementations of one formula always diverge.

## Data Access

- Read-only queries MUST NOT track entities. ({{NO_TRACKING_IDIOM}})
- Soft-delete filtering MUST be explicit in every query unless a global query filter owns
  it — and which of the two the project uses is fixed here: {{SOFT_DELETE_QUERY_RULE}}.

## Testing

- {{BACKEND_TEST_STANDARDS}} <!-- e.g. "xUnit; every endpoint has an API test; every business calculation has a golden-fixture test with hand-worked expected values" -->
- The gate (`docs/sdlc/gate-command.md`) is run by the user; a phase is not done before
  the user confirms exit code 0.

## Security

- Secrets MUST NOT be committed; configuration and secrets come from {{SECRETS_SOURCE}}.
- {{BACKEND_SECURITY_RULES}} <!-- authn/authz standards, input size limits, etc. -->
