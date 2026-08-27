# Backend Security Rules

## Purpose

This file defines mandatory backend security rules for FlowBoard.

FlowBoard is a multi-tenant SaaS holding customer boards, cards, comments, and member
data. Security rules must be treated as architecture requirements.

## 1. Authentication

All protected APIs must require authentication.

Use the project-approved authentication mechanism (decided in feature 002's `plan.md`):

- JWT bearer tokens (spec §7)
- SSO (SAML/OIDC) on the Enterprise tier (spec §8)

Do not create custom authentication unless approved in `plan.md`.

## 2. Authorization

Authentication is not enough.

Every business action must check authorization against the capability matrix in
`docs/product/FUNCTIONAL_SPEC.md` §6.

Examples:

- View board
- Create / edit / move cards
- Comment
- Create / rename / delete lists
- Manage labels
- Invite / remove board members
- Rename / archive / delete board
- Manage workspace members & billing

Use policy/permission-based authorization where possible.

## 3. Board Membership Scope

Every query must enforce board membership scope (domain invariant 5).

A user may only access boards they are a member of (or workspace-admin over). A valid
token is not board access.

Do not rely only on frontend filtering. Backend must enforce board scope on every
board-scoped endpoint.

## 4. Input Validation

Validate all request payloads before business logic.

Validation must cover:

- required fields
- string length
- enum values
- date ranges
- position values
- board/workspace membership
- `If-Match` preconditions (spec §7.1)
- duplicate references
- idempotency keys where applicable

Frontend validation improves UX but backend validation is authoritative.

## 5. SQL Injection Protection

Use EF Core parameterized queries or parameterized raw SQL.

Never build SQL using string concatenation with user input.

Bad:

```csharp
var sql = "SELECT * FROM Card WHERE Title LIKE '%" + search + "%'";
```

Good:

```csharp
var results = await _dbContext.Cards
    .Where(x => x.Title.Contains(search))
    .ToListAsync(cancellationToken);
```

If raw SQL is required, review carefully and parameterize.

## 6. Secrets Management

Do not commit secrets.

Forbidden in source code:

- passwords
- API keys
- client secrets
- database passwords
- private keys
- tokens
- connection strings with credentials

Secrets must come from .NET user-secrets (dev), environment variables, CI/CD secret
store, or approved vault.

## 7. Logging Security

Do not log:

- passwords
- access tokens
- refresh tokens
- API keys
- sensitive personal data
- full request payloads containing secrets

Use structured logging and mask sensitive fields. Internal `Id` values must not appear
in client-visible logs (domain invariant 8).

## 8. Error Handling

Do not expose internal stack traces to users.

API errors should return safe messages. Log technical details internally.

Use standardized error responses (`ProblemDetails`, RFC 9457).

## 9. External API Security

External integrations (none in v1.0; email/billing/SSO arrive later) must follow
`docs/rulebooks/backend/external-api-rules.md`.

Required:

- secure secret storage
- TLS
- timeout
- retry limit
- correlation ID
- safe logging
- token rotation plan

## 10. Webhook Security

If FlowBoard ever accepts incoming webhooks (e.g. billing provider callbacks):

- validate signature
- validate timestamp if provided
- reject replay attacks where possible
- be idempotent
- store raw payload safely
- process asynchronously when needed

Never trust webhook payloads just because they reached the endpoint.

## 11. File Upload Security

Attachments are out of scope for v1.0 (spec §9). When v1.1 adds them:

- validate file type
- validate file size
- scan where possible
- store outside web root
- generate safe file names
- do not execute uploaded files
- restrict download permissions
- audit upload/download actions

## 12. Rate Limiting

Consider rate limiting for login, search endpoints (spec §7 `/search`), export
endpoints, invitation endpoints, and any future external callback endpoints. Spec §8
requires rate limiting per token.

## 13. Audit Trail

Security-sensitive actions must be audited:

- login failures where available
- permission/role changes
- board member invite/remove
- board archive/delete
- workspace membership and billing changes
- data-export and erasure requests (spec §8, GDPR)

Card-level history is the append-only `ActivityEvent` stream (domain invariant 1).
Audit records must include user, role, timestamp, action, board/workspace scope,
reference, and result.

## 14. Least Privilege

Database accounts and service accounts should have only required permissions.

Do not use highly privileged accounts for normal application runtime.

## 15. Backend Security Review Checklist

Before completing a backend phase, check:

- [ ] Is authentication required where needed?
- [ ] Is authorization enforced backend-side per the §6 matrix?
- [ ] Is board membership scope enforced?
- [ ] Are inputs validated?
- [ ] Are SQL queries parameterized?
- [ ] Are secrets excluded from source/logs?
- [ ] Are errors safe for users?
- [ ] Are internal Ids kept out of URLs, payloads, and client-visible logs?
- [ ] Are external API credentials protected (when integrations exist)?
- [ ] Are webhooks signature-validated (when they exist)?
- [ ] Are sensitive actions audited?
