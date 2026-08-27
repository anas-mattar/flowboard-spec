# External API Rules

## Purpose

FlowBoard v1.0 has no external integrations; they arrive later (email/notification
delivery, billing/subscription provider for the paid tiers, SSO/SCIM on Enterprise,
export/document services). When the first one is specced, its contract comes before
implementation (constitution IX) and this file governs the implementation pattern.

## 1. Integration Layer

External APIs must never be called directly from:

- API endpoints (minimal-API handlers)
- Domain entities
- EF Core configurations
- Migrations
- React UI components

External APIs must be called through dedicated client/service classes.

Recommended structure:

```text
Services/
  External/
    Interfaces/
      IEmailClient.cs
      IBillingClient.cs
    Clients/
      EmailClient.cs
      BillingClient.cs
```

## 2. HttpClient Rule

Use `IHttpClientFactory`.

Allowed:

```csharp
services.AddHttpClient<IEmailClient, EmailClient>();
```

Forbidden:

```csharp
new HttpClient()
```

## 3. Configuration Rule

Base URLs and credentials must come from configuration or secret storage.

Do not hardcode:

```text
https://api.vendor.com
api-key-value
client-secret
```

Recommended configuration shape:

```json
{
  "ExternalApis": {
    "Email": {
      "BaseUrl": "",
      "TimeoutSeconds": 30,
      "RetryCount": 3
    }
  }
}
```

## 4. Authentication

Supported authentication methods:

- API Key
- OAuth2 Client Credentials
- JWT Bearer
- Mutual TLS if required by provider

Secrets must not be committed to source control.

## 5. Timeout

Every external call must have a timeout.

Recommended defaults:

```text
Read/query API: 30 seconds
Posting/billing API: 60 seconds
Webhook response: under 5 seconds before queueing
```

## 6. Retry

Use retry only for transient failures.

Retry candidates:

- HTTP 408
- HTTP 429
- HTTP 500
- HTTP 502
- HTTP 503
- HTTP 504
- Network timeout

Do not blindly retry:

- HTTP 400
- HTTP 401
- HTTP 403
- HTTP 404
- Validation errors
- Duplicate business requests without idempotency

## 7. Idempotency

Posting APIs (billing mutations, invitation emails) must support idempotency when
possible.

Use:

```text
IdempotencyKey
CorrelationId
SourceSystem
SourceReference
```

Store the idempotency key before sending the request.

## 8. Correlation ID

Every external request must include or log a correlation ID.

Use the same correlation ID across:

- API request
- Logs
- Integration audit table
- Queue message
- Error notifications

## 9. Logging and Audit

For important integrations, store:

- Source system
- Target system
- Endpoint
- Request reference
- CorrelationId
- Request timestamp
- Response timestamp
- Status
- Error code
- Error message
- Retry count

Do not store secrets, passwords, tokens, or sensitive personal data unless explicitly
required and protected.

## 10. Integration Audit Table

Recommended table:

```text
IntegrationRequestLog
- Id INT IDENTITY(1,1)
- CorrelationId NVARCHAR(100)
- SourceSystem NVARCHAR(100)
- TargetSystem NVARCHAR(100)
- Endpoint NVARCHAR(300)
- Method NVARCHAR(20)
- RequestReference NVARCHAR(100)
- RequestPayload NVARCHAR(MAX) NULL
- ResponsePayload NVARCHAR(MAX) NULL
- Status NVARCHAR(50)
- HttpStatusCode INT NULL
- ErrorMessage NVARCHAR(MAX) NULL
- RetryCount INT NOT NULL
- CreatedDate DATETIME2 NOT NULL
- CreatedBy NVARCHAR(100) NOT NULL
```

Mask or exclude sensitive payload fields.

## 11. Error Handling

External client methods should return typed results or throw controlled exceptions.

Do not leak raw provider errors to end users.

Map provider errors into internal error categories:

- AuthenticationFailed
- AuthorizationFailed
- ValidationFailed
- RateLimited
- Timeout
- ProviderUnavailable
- DuplicateRequest
- UnknownError

## 12. Endpoint Rule

API endpoints call application services. Never call external HTTP clients from an
endpoint handler.

Bad:

```csharp
private static async Task<IResult> InviteAsync(HttpClient httpClient)
{
    var response = await httpClient.PostAsync(...);
}
```

Good:

```csharp
private static async Task<IResult> InviteAsync(
    InviteMemberRequest request,
    IMembershipService membership,
    CancellationToken cancellationToken)
{
    var result = await membership.InviteAsync(request, cancellationToken);
    return result.ToHttpResult();
}
```

## 13. Testing

Integration code needs:

- Unit tests for request mapping
- Unit tests for error mapping
- Integration tests with mocked provider
- Contract tests when possible
- Retry/idempotency tests for posting APIs
