# Backend Compliance Checklist — MANDATORY

> **Binding**: This checklist is part of Definition of Done item 5
> (`docs/sdlc/definition-of-done.md`). The AI completes it for every phase touching the
> backend tier and records the result in the phase's review notes. **Any FAIL blocks the
> phase.**
>
> **Adopted**: 2026-08-27, before feature 001 — no grandfathered code exists.

## Structure (`docs/rulebooks/backend-rules.md`)

- [ ] New endpoints are minimal-API endpoint groups (`Endpoints/{Feature}Endpoints.cs`,
      `Map{Feature}Endpoints` + `MapGroup`); no `[ApiController]` controllers, CQRS,
      MediatR, or generic repositories without plan approval.
- [ ] Handlers are thin: no business rules, no direct `DbContext` access, no hand-rolled
      status-code switches.
- [ ] Contract-implementing files cite the feature's `contracts/` file in a top comment.

## API Surface

- [ ] Every input validated at the boundary; failures return
      RFC 9457 problem details (`Results.ValidationProblem`).
- [ ] Responses use DTOs — no serialized EF entities; no internal `Id` in any URL,
      payload, event, or client-visible log (invariant 8: `PublicId` only).
- [ ] `409` returned on stale `If-Match` / concurrency conflicts (invariant 6); list
      endpoints are cursor/server-paginated.

## Domain & Authorization

- [ ] Every board-scoped operation verifies the caller's role on that board per spec §6
      (invariant 5) — token validity alone is never treated as board access.
- [ ] No domain-invariant violations (`docs/domain/flowboard-invariants.md`); invariants
      expressible as schema constraints have them.
- [ ] Position/ordering math only in the one named ordering module — no inline
      re-derivations (invariant 2).
- [ ] Every state-changing card action writes its `ActivityEvent`; no UPDATE/DELETE path
      touches activity rows (invariant 1).

## Data Access & Performance (`docs/rulebooks/backend-rules.md`)

- [ ] Read queries use `AsNoTracking()` and `.Select()` DTO projection; filtering,
      sorting, and paging happen in SQL — no `.ToList()` before filters.
- [ ] No N+1: no navigation-property access in loops without explicit loading;
      `AsSplitQuery()` for complex include graphs.
- [ ] Soft-delete filtering owned by the global query filter; `IgnoreQueryFilters()`
      only in named restore/admin paths.
- [ ] All I/O async with `CancellationToken`; no `.Result`, `.Wait()`, `Thread.Sleep()`.
- [ ] SignalR events published only after `SaveChangesAsync()` succeeds, broadcasting the
      same event objects the activity feed stores.

## Security (`docs/rulebooks/backend-rules.md`)

- [ ] Auth required on protected endpoints (`.RequireAuthorization()` on the group);
      writes carry the applicable permission policy.
- [ ] EF Core parameterized queries only — no SQL built by string concatenation.
- [ ] No secrets in source or logs; no sensitive data logged; errors return safe
      ProblemDetails, never stack traces.
- [ ] External HTTP via `IHttpClientFactory` with timeout; no `new HttpClient()`.

## Testing

- [ ] Every new endpoint has a `WebApplicationFactory` integration test against the
      disposable `flowboard-db-test`; covers success, validation failure, authorization
      failure, and concurrency conflict where applicable.
- [ ] Ordering/business calculations have golden-fixture tests with hand-worked values.

## Process

- [ ] No new packages beyond those approved in the feature's `plan.md` (constitution IV).
- [ ] Only the approved phase's files changed (`git diff --stat` reviewed).
- [ ] Gate run by the user with confirmed exit code 0 (constitution XIII).
