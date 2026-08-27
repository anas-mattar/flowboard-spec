# Backend Rules — FlowBoard

> **Binding**: this rulebook is enforced through the backend tier's compliance checklist
> (`docs/rulebooks/backend-compliance-checklist.md`, Definition of Done item 5): the
> checklist asserts, this rulebook explains. Domain invariants
> (`docs/domain/flowboard-invariants.md`) carry constitutional force and always outrank
> this file. Detailed shop guidance: `reference/backend/` (read its README
> first — FMS domain content there does not apply).

## Layering & Placement

- Code layout: minimal-API endpoint groups over a service layer —
  `Flowboard.Api/Endpoints/{Feature}Endpoints.cs` (one static class per bounded context,
  routes registered in a `Map{Feature}Endpoints` extension using `MapGroup(...)`), calling
  application services; EF Core entities + `Migrations/` in the data layer. The exact
  project split is recorded ADR-style in **specs/001-solution-scaffold/plan.md**
  (constitution IV bootstrap clause) — once merged, that layout is law.
- New code MUST follow the existing layout. A new top-level folder, layer, or project
  requires approval in the feature's `plan.md`.
  **Why**: architecture changes ride in on "just one helper folder" — this is where drift starts.
- MVC `[ApiController]` controllers, CQRS, MediatR, and generic repositories MUST NOT be
  introduced unless a feature `plan.md` explicitly approves them.
  **Why**: the shop's FMS deployment proved endpoint groups sufficient through 007 features.

## API Surface

- Every external input MUST be validated at the API boundary; validation failures MUST
  return RFC 9457 problem details (`Results.ValidationProblem`).
  **Why**: the boundary is the one place a bad value is rejected once for all callers.
- Handlers MUST be thin: validate shape → call the application service → map its result to
  HTTP via one shared mapping — no hand-rolled status-code switches, no business rules, no
  direct `DbContext` access in handlers.
- Responses MUST use dedicated DTOs; domain entities MUST NOT be serialized directly.
  **Why**: entity leaks turn every schema refactor into a breaking API change — and would
  leak internal `Id`s, violating invariant 8.
- API URLs and payloads address entities by `PublicId` ONLY (invariant 8); internal `Id`
  never leaves the service. Status codes: 200/201/204/400/401/403/404/409/422/500 — 409 is
  reserved for optimistic-concurrency conflicts (invariant 6).
- Code implementing a feature contract MUST cite the contract file (the feature's
  `contracts/` directory) in a comment at the top of the file.
  **Why**: the citation makes rung-checking possible during review.

## Domain Logic

- Domain invariants (`docs/domain/flowboard-invariants.md`) MUST be enforced in code AND
  asserted by the database schema where a constraint can express them — never in one place only.
- Authorization is board-membership-scoped: every board-scoped operation MUST verify the
  caller's role on THAT board per spec §6 (invariant 5). A valid token is not board access.
  **Why**: multi-tenant isolation enforced anywhere but the API boundary is a breach.
- Dates and numbers MUST be parsed and formatted culture-invariantly at every boundary;
  timestamps are UTC (`datetime2`). **Why**: a locale-dependent parse is data corruption
  no test on the author's machine catches.
- Position/ranking math (midpoint insertion, gap re-balancing — invariant 2) MUST live in
  one named module — `Flowboard.Domain` ordering module, name fixed in 001's plan —
  covered by golden-fixture tests. Re-deriving it inline is prohibited.
  **Why**: two implementations of one formula always diverge.

## Data Access

- Read-only queries MUST NOT track entities (`AsNoTracking()`), MUST project with
  `.Select()` into DTOs for lists, and MUST filter/sort/page in SQL — never `.ToList()`
  then filter. List endpoints MUST be paginated server-side (spec §7: cursor-paginated).
- N+1 is prohibited: no navigation-property access in loops without explicit loading;
  `Include()` only when required; `AsSplitQuery()` for complex include graphs.
- Soft-delete filtering is owned by a global query filter (`HasQueryFilter(x => !x.IsDeleted)`)
  on every soft-delete entity; `IgnoreQueryFilters()` only in named restore/admin paths,
  never casually.
- Async everywhere for I/O with `CancellationToken`; `.Result`, `.Wait()`, and
  `Thread.Sleep()` are prohibited.

## Realtime (SignalR)

- Board events broadcast the SAME event objects the activity feed stores (invariant 1);
  realtime and history MUST NOT diverge in shape.
- Events MUST be published only after `SaveChangesAsync()` succeeds — never before the
  commit. **Why**: a broadcast of an uncommitted change desynchronizes every open client.

## Testing

- xUnit. Every endpoint has an integration test via `WebApplicationFactory` against a
  disposable `flowboard-db-test` database; ordering math and other business calculations
  have golden-fixture tests with hand-worked expected values. Tests cover success,
  validation failure, authorization failure (wrong/no board membership), and concurrency
  conflict where the endpoint supports `If-Match`.
- The gate (`docs/sdlc/gate-command.md`) is run by the user; a phase is not done before
  the user confirms exit code 0.

## Security

- Secrets MUST NOT be committed; configuration and secrets come from .NET user-secrets
  (dev) / environment variables or the deployment secret store (never `appsettings.json`
  with credentials).
- Full security pack: `reference/backend/backend-security.md` (its §15
  checklist is folded into this tier's compliance checklist). Non-negotiables: EF Core
  parameterized queries only; no secrets/tokens/sensitive data in logs; safe error
  responses (ProblemDetails, no stack traces); `HttpClient` via `IHttpClientFactory`;
  rate limiting considered for login/search/export endpoints.
