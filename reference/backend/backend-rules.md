# Backend Rules

## Stack

- Use .NET 10 / ASP.NET Core Web API.
- Use Entity Framework Core.
- Use SQL Server unless `plan.md` approves another database.
- Use async/await for all I/O.

## Architecture

Use the architecture already present in the project.

If the project is layered:
- Controller -> Service -> Repository -> DbContext

If the project is Clean Architecture:
- Api -> Application -> Domain
- Infrastructure -> Application -> Domain
- Domain has no external dependencies

Do not introduce CQRS, MediatR, new repository patterns, or architectural changes unless approved in `plan.md`.

## API Endpoints

FMS uses minimal-API endpoint groups, not MVC controllers. This is the project standard, approved in `specs/001-solution-scaffold/plan.md` and carried forward by every feature plan since.

Endpoint groups must:
- Live in `FMS.Api/Endpoints/` as one static `{Feature}Endpoints` class per bounded context.
- Register routes in a `Map{Feature}Endpoints` extension method using `MapGroup("/api/{feature}")`.
- Apply `.RequireAuthorization()` on the group; writes add the permission policy per endpoint (`.RequireAuthorization("perm:<key>")`).
- Use `.WithTags()` for OpenAPI grouping.
- Use static handler methods that are thin.
- Validate request shape (route constraints, query parsing, Zod-equivalent checks); return `Results.ValidationProblem` on bad input.
- Call the application service layer and return its result.
- Map `Result<T>` to HTTP via the shared `ToHttpResult()` (`ResultMapping.cs`) — do not hand-roll status-code switches.

Endpoint handlers must not:
- Contain business rules.
- Access DbContext directly.
- Return raw EF entities when DTOs exist.
- Swallow exceptions silently.

Do not introduce `[ApiController]` controllers unless a feature `plan.md` explicitly approves them.

## Standard Endpoint Order

Use this order when registering routes in an endpoint group:
1. List/Get endpoints
2. Create endpoints
3. Update endpoints
4. Delete endpoints
5. Action endpoints

## HTTP Status Codes

Use:
- `200 OK`
- `201 Created`
- `204 No Content`
- `400 Bad Request`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `409 Conflict`
- `422 Unprocessable Entity`
- `500 Internal Server Error`

## Repository and EF Core

- Use repositories if the project already uses them.
- Do not create generic repositories unless the existing project pattern requires it.
- Reads must use `AsNoTracking()`.
- Use `.Select()` projection for list/read DTOs.
- Apply filtering, sorting, and paging in the database.
- Avoid `.ToList()` before filters.
- Avoid N+1 queries.
- Use `Include()` only when required.
- Use `AsSplitQuery()` for complex include graphs.

## Multiple DbContexts

If the project has multiple DbContexts:
- Always know which context is used.
- Do not join across DbContexts in one query.
- Query separately and merge in application code.

## External Services

- Use injected `HttpClient`.
- Prefer `IHttpClientFactory`.
- Never create `new HttpClient()`.
- Log external API failures with context.
- Do not log secrets or tokens.

## Events

If using MassTransit/RabbitMQ:
- Publish events after `SaveChangesAsync()` succeeds.
- Do not publish before the database commit.

## Database

- Use migrations for schema changes.
- Review migrations before deployment.
- Always implement rollback/down migration when possible.
- Use explicit column types.
- Use `HasMaxLength` for strings.
- Use `decimal` for money.
- Never use float/double for finance amounts.

## Security

- Use `.RequireAuthorization()` for protected endpoints (`[Authorize]` if a plan-approved controller exists).
- Use permission policies (`perm:<key>`) when the project has them.
- Validate all inputs.
- Do not hardcode secrets.
- Do not log sensitive data.
- Use parameterized queries.

## Testing

- Add or update tests for new behavior.
- Test success, validation failure, authorization failure, and edge cases.
- Use integration tests for important database behavior.

## FMS Database Standards Extension

For FMS, database standards are mandatory and are defined in:

- `docs/backend/database-standards.md`
- `docs/finance/fms-finance-rules.md`

Key rules:

- Use `INT IDENTITY(1,1)` primary keys.
- Do not use GUID primary keys unless approved in `plan.md`.
- Use GUID only for `PublicId`, `CorrelationId`, `IdempotencyKey`, and integration references.
- Business entities must support soft delete.
- Business tables must include audit fields.
- Financial transaction data must not be physically deleted.
- Use reversals or status transitions for financial corrections.

Any generated EF Core entity or migration that violates these rules must be rejected.

## Amendment History

- 2026-06-12 — Replaced the `[ApiController]` controller mandate with the minimal-API endpoint-group standard. The minimal-API style was approved in `specs/001-solution-scaffold/plan.md` ("Endpoints use the minimal-API style; controllers may be introduced later if a feature plan approves") and has been the shipped, plan-cited pattern in every feature since (002–007). This amendment reconciles the rule document with approved practice; no code change.
