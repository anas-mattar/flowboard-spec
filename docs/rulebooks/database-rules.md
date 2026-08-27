# Database Rules — FlowBoard

> **Binding**: this rulebook is enforced through the compliance checklist of whichever
> tier owns the migration (Definition of Done item 5, `docs/sdlc/definition-of-done.md`).
> Schema changes are the least reversible thing an agent ships — this file is always read
> together with `docs/sdlc/rollback-process.md`, never alone.

## Schema Standards

- Primary keys: `Id INT IDENTITY(1,1) PRIMARY KEY` (constitution V). GUID primary keys are
  prohibited unless approved in `plan.md`.
- Every API-exposed entity additionally carries
  `PublicId UNIQUEIDENTIFIER NOT NULL UNIQUE` — the only identifier the API ever exposes
  (invariant 8). Foreign keys are integer (`AccountId`-style), pointing at internal `Id`.
- Audit fields on every business table (constitution VI): `CreatedDate DATETIME2 NOT NULL`,
  `CreatedBy NVARCHAR(100) NOT NULL`, `UpdatedDate/UpdatedBy` nullable. Soft-delete
  entities add `IsDeleted BIT NOT NULL DEFAULT(0)`, `DeletedDate`, `DeletedBy`.
  System-generated rows stamp `SYSTEM` / `MIGRATION` as the actor.
- Entities inherit one abstract `BaseEntity`: `Id`, audit fields, soft-delete fields, and
  nullable `RowVersion` (`byte[]`). `RowVersion` is REQUIRED on `Card` (and any entity
  with `If-Match` edits) — it implements invariant 6's optimistic concurrency;
  `.IsRowVersion()` in the mapping.
- Naming: singular table names (`Board`, `List`, `Card`); PascalCase columns; explicit
  column types; `HasMaxLength` on every string; timestamps `datetime2` in UTC; `decimal`
  for any money-like value (never float/double).
- `Card.Position` / `List.Position`: the sparse-rank type (float vs lexicographic string)
  is fixed once in 001's `plan.md` per invariant 2 and never varied per feature.

## Constraints Mirror Invariants

- Every domain invariant (`docs/domain/flowboard-invariants.md`) that a constraint can
  express MUST be one — CHECK, FK, UNIQUE, NOT NULL — in addition to application-level
  enforcement. **Why**: application-only enforcement is one forgotten code path away from
  bad data. Known mappings: `Label.BoardId NOT NULL` + composite FK path keeping
  `CardLabel` within one board (invariant 7); `PublicId` UNIQUE (invariant 8);
  activity-event tables get INSERT-only treatment — no UPDATE/DELETE paths in code, and
  a trigger or permission guard where the platform allows (invariant 1).
- Foreign keys to soft-deleted master data MUST use restrict semantics, never cascade
  delete. **Why**: history must keep resolving after the referenced row is retired
  (invariant 4).

## Migrations

- Schema changes ship ONLY as EF Core migrations via the repo-local `dotnet-ef` tool
  (`dotnet tool restore`; generated from `flowboard-api` with the API project as startup
  project) — no hand-run SQL against shared environments.
  **Why**: unscripted changes cannot be replayed, diffed, or rolled back.
- At most one migration per phase, named after the feature.
- Every migration MUST be reversible, or ship a written rollback plan from
  `specs/_templates/rollback-template.md`. A destructive `Down()` needs a fresh decision
  per feature — approval never carries over. **Why**: rollback designed after the incident
  is guesswork.
- Destructive operations (dropping columns/tables, truncating, rewriting data) are
  prohibited unless explicitly approved in the feature's `plan.md`, with documented
  backup + rollback plan.
- A migration already applied beyond the author's machine MUST NOT be edited — write a
  new one. **Why**: edited history diverges environments silently.
- Migration review checklist: PK type, FKs, nullability, precision, soft-delete + audit
  fields, indexes, destructive ops, rollback safety.

## Data Safety

- Rolling back code or a migration MUST NOT cascade into physical deletion of boards,
  lists, cards, comments, or activity events, and MUST NOT edit activity history
  (invariants 1 and 4). If a rollback would touch domain data, stop and report
  (`docs/sdlc/rollback-process.md`).
- Seed data: deterministic `HasData` seeds only — stable ids, stable timestamps (no
  `DateTime.Now` in seeds). The seed mirrors the prototype's three boards
  (`docs/product/prototype/`), so seeded data doubles as the Visual Compliance Loop
  fixture and as golden fixtures for read tests.
- Indexes are added from actual query patterns (start: FKs, `PublicId`, `IsDeleted`,
  `Position` within parent, `DueAt`); write-heavy tables are not over-indexed.
