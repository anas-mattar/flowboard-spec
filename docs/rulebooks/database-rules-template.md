# Database Rules — {{PROJECT_NAME}}

> **Binding**: this rulebook is enforced through the compliance checklist of whichever
> tier owns the migration (Definition of Done item 5, `docs/sdlc/definition-of-done.md`).
> Schema changes are the least reversible thing an agent ships — this file is always read
> together with `docs/sdlc/rollback-process.md`, never alone.

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment): same three rules as the backend
template — fill descriptively at adoption (copy to docs/rulebooks/database-rules.md,
point {{DATABASE_RULES_PATH}} at it), grow reactively, MUST / MUST NOT with a Why.
The schema standards below usually restate constitution slots — keep them in sync or
point at the constitution instead of restating.
-->

## Schema Standards

- Primary keys: {{PK_STANDARD}} <!-- from the constitution — e.g. "int identity" / "GUID v7" -->
- Audit fields on every table: {{AUDIT_FIELDS}} <!-- e.g. "CreatedDate/CreatedBy, UpdatedDate/UpdatedBy" -->
- Soft delete standard: {{SOFT_DELETE_STANDARD}} <!-- e.g. "IsDeleted, DeletedDate, DeletedBy; physical DELETE prohibited unless plan-approved" -->
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
