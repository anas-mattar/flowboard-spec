# Database Rules — {{PROJECT_NAME}}

> **Binding**: this rulebook is enforced through the compliance checklist of whichever
> tier owns the migration (Definition of Done item 5, `docs/sdlc/definition-of-done.md`).
> Schema changes are the least reversible thing an agent ships — this file is always read
> together with `docs/sdlc/rollback-process.md`, never alone.

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment): same three rules as the backend
template — fill descriptively at adoption (copy to docs/rulebooks/database-rules.md,
point {{DATABASE_RULES_PATH}} at it), grow reactively, MUST / MUST NOT with a Why.
The Schema Standards below are this kit's home for primary-key and auditability
conventions (formerly constitution Principles V and VI — demoted here in the 0.3.0
amendment: schema conventions are project-specific formatting choices, not law that
"supersedes everything"; see review/out/DECISION.md finding #15). They are conventions
of this rulebook, not constitutional principles — deviations are a plan-approved judgment
call, not a constitutional violation.
-->

## Setup

- Before the FIRST migration runs, the connection string's target database MUST be
  confirmed as dedicated to this project — not silently inherited from another project's
  local-dev setup and not a shared/production database. Deliberately sharing a database
  across services is permitted only as an explicit, plan-approved decision: the rule is
  confirmation, not a ban on reuse. **Why**: a connection string silently reused from
  another project points the first `migration apply` at an existing database, mixing
  schemas the moment it runs.

## Schema Standards

- Primary keys: the default primary key MUST be {{PK_STANDARD}}. <!-- e.g. `Id INT IDENTITY(1,1)
  PRIMARY KEY` (SQL Server), `BIGSERIAL` (PostgreSQL), or your ORM's convention. -->
  Deviations are prohibited unless explicitly approved in the technical plan.
  Externally-exposed identifiers (public IDs, correlation IDs, integration references,
  idempotency keys) MAY use opaque values such as GUIDs, but these are not primary keys.
  **Why**: a uniform key strategy keeps indexes compact and joins predictable while still
  allowing opaque identifiers where external exposure genuinely requires them.
- Audit fields on every business entity: {{AUDIT_FIELDS}} <!-- e.g. "CreatedDate/CreatedBy,
  UpdatedDate/UpdatedBy" -->. **Why**: systems of record require a verifiable trail of who
  changed what and when.
- Soft delete standard: {{SOFT_DELETE_STANDARD}} <!-- e.g. "IsDeleted, DeletedDate, DeletedBy;
  physical DELETE prohibited unless plan-approved" -->. Business master data MUST use soft
  delete; physical deletion is prohibited unless explicitly approved in the technical plan.
  **Why**: master data referenced by history must never disappear from under it.
- Naming conventions: {{DB_NAMING_CONVENTIONS}} <!-- tables, columns, indexes, constraints -->

## Constraints Mirror Invariants

- Every domain invariant (`{{DOMAIN_INVARIANTS_PATH}}`) that a constraint can express MUST
  be one — CHECK, FK, UNIQUE, NOT NULL — in addition to application-level enforcement.
  **Why**: application-only enforcement is one forgotten code path away from bad data.
- Foreign keys to soft-deleted master data MUST use restrict semantics, never cascade
  delete. **Why**: history must keep resolving after the referenced row is retired.

## Migrations

- Schema changes ship ONLY as migrations via {{MIGRATION_TOOL}} — no hand-run SQL against
  shared environments. **Why**: unscripted changes cannot be replayed, diffed, or rolled back.
- At most one migration per phase, named after the feature.
- Every migration MUST be reversible, or ship a written rollback plan from
  `specs/_templates/rollback-template.md`. **Why**: rollback designed after the incident
  is guesswork.
- Destructive operations (dropping columns/tables, truncating, rewriting data) are
  prohibited unless explicitly approved in the feature's `plan.md`.
- A migration already applied beyond the author's machine MUST NOT be edited — write a
  new one. **Why**: edited history diverges environments silently.

## Data Safety

- Rolling back code or a migration MUST NOT cascade into physical deletion of domain
  data. If a rollback would touch domain data, stop and report
  (`docs/sdlc/rollback-process.md`).
- Seed data: {{SEED_DATA_RULES}} <!-- e.g. "deterministic seeds only; seeds double as golden fixtures" -->
