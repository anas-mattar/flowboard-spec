# Integration Rules — {{PROJECT_NAME}}

> **Binding**: contract-before-implementation is constitution IX; this rulebook only
> operationalizes it. It covers every call that crosses a repository or leaves the system
> (own API consumed by own frontend included).

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment): same three rules as the backend
template — fill descriptively at adoption (copy to docs/rulebooks/integration-rules.md,
point {{INTEGRATION_RULES_PATH}} at it), grow reactively, MUST / MUST NOT with a Why.
-->

## Contract First

- Every cross-repository or external call MUST have a written contract in the feature's
  `contracts/` directory BEFORE either side is implemented; both sides cite the contract
  file in a comment. **Why**: two teams (or two agents) coding against an imagined
  interface produce two interfaces.
- The contract outranks `tasks.md` and implementation notes (Source of Truth rung 4). If
  implementation and contract conflict: stop and report — never silently patch either.

## Change Discipline

- Additive changes (new optional fields, new endpoints) are the default evolution path.
  Breaking a published contract requires a spec update and `plan.md` approval, plus a
  coordinated cross-repository rollout per `docs/sdlc/repository-strategy.md`.
- Cross-repository order: backend implements and gates first; the frontend may proceed in
  parallel ONLY by mocking against the agreed contract, never against guesses.

## Wire Format

- {{WIRE_FORMAT_RULES}} <!-- e.g. "camelCase JSON; list responses wrapped in a named object; dates ISO 8601 (yyyy-MM-dd); money as decimal number plus ISO 4217 currency code" -->
- Errors MUST use the contract's declared error shape ({{ERROR_SHAPE}}) — consumers MUST
  distinguish "call failed" from "empty result".
  **Why**: a failure decoded as an empty list is silent data loss.

## Runtime Discipline

- Every outbound call MUST have an explicit timeout: {{TIMEOUT_STANDARD}}.
- Retry/backoff policy: {{RETRY_RULES}} <!-- e.g. "no automatic retries for MVP; reads may add jittered retry when plan-approved" -->
- A failed integration MUST surface as the consumer's error/unavailable state — never as
  fabricated or cached-stale data presented as fresh.

## Configuration & Secrets

- Base URLs, keys, and credentials come from configuration ({{CONFIG_SOURCE}}), never
  hard-coded. Secrets MUST NOT reach client-side code.
