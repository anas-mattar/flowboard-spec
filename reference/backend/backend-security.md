# Backend Security Rules

## Purpose

This file defines mandatory backend security rules for FMS.

FMS handles financial data, audit records, integrations, and possibly sensitive customer/vendor information. Security rules must be treated as architecture requirements.

## 1. Authentication

All protected APIs must require authentication.

Use the project-approved authentication mechanism:

- JWT
- Azure AD / Entra ID
- OAuth2
- internal service authentication where applicable

Do not create custom authentication unless approved in `plan.md`.

## 2. Authorization

Authentication is not enough.

Every business action must check authorization.

Examples:

- View journal
- Post journal
- Reverse journal
- Close period
- Reopen period
- Approve payment
- Export report
- Manage COA
- Manage exchange rates
- Manage integrations

Use policy/permission-based authorization where possible.

## 3. Entity Scope Security

Every query must enforce entity scope.

A user should only access data for authorized legal entities, countries, or consolidated group scope.

Do not rely only on frontend filtering. Backend must enforce entity access.

## 4. Input Validation

Validate all request payloads before business logic.

Validation must cover:

- required fields
- string length
- enum values
- date ranges
- amount precision
- entity access
- period status
- duplicate references
- idempotency keys

Frontend validation improves UX but backend validation is authoritative.

## 5. SQL Injection Protection

Use EF Core parameterized queries or parameterized raw SQL.

Never build SQL using string concatenation with user input.

Bad:

```csharp
var sql = "SELECT * FROM Journal WHERE SourceRef = '" + sourceRef + "'";
```

Good:

```csharp
var result = await _dbContext.Journals
    .Where(x => x.SourceReference == sourceRef)
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

Secrets must come from environment variables, secret manager, CI/CD secret store, or approved vault.

## 7. Logging Security

Do not log:

- passwords
- access tokens
- refresh tokens
- API keys
- full credit card/bank data
- sensitive personal data
- full request payloads containing secrets

Use structured logging and mask sensitive fields.

## 8. Error Handling

Do not expose internal stack traces to users.

API errors should return safe messages. Log technical details internally.

Use standardized error responses such as `ProblemDetails`.

## 9. External API Security

External integrations must follow:

- `docs/backend/external-api-rules.md`
- `docs/contracts/auth-patterns.md`
- `docs/contracts/webhook-patterns.md`

Required:

- secure secret storage
- TLS
- timeout
- retry limit
- correlation ID
- safe logging
- token rotation plan

## 10. Webhook Security

Incoming webhooks must:

- validate signature
- validate timestamp if provided
- reject replay attacks where possible
- be idempotent
- store raw payload safely
- process asynchronously when needed

Never trust webhook payloads just because they reached the endpoint.

## 11. File Upload Security

If FMS supports uploads:

- validate file type
- validate file size
- scan where possible
- store outside web root
- generate safe file names
- do not execute uploaded files
- restrict download permissions
- audit upload/download actions

## 12. Rate Limiting

Consider rate limiting for login, webhook endpoints, export endpoints, posting endpoints, external callback endpoints, and heavy search endpoints.

## 13. Audit Trail

Security-sensitive actions must be audited:

- login failures where available
- permission changes
- role changes
- posting
- reversal
- period close/open
- payment approval
- export of financial data
- integration credential changes

Audit records must include user, role, timestamp, action, entity scope, reference, and result.

## 14. Least Privilege

Database accounts and service accounts should have only required permissions.

Do not use highly privileged accounts for normal application runtime.

## 15. Backend Security Review Checklist

Before completing a backend phase, check:

- [ ] Is authentication required where needed?
- [ ] Is authorization enforced backend-side?
- [ ] Is entity scope enforced?
- [ ] Are inputs validated?
- [ ] Are SQL queries parameterized?
- [ ] Are secrets excluded from source/logs?
- [ ] Are errors safe for users?
- [ ] Are external API credentials protected?
- [ ] Are webhooks signature-validated?
- [ ] Are file uploads secured if present?
- [ ] Are sensitive actions audited?
