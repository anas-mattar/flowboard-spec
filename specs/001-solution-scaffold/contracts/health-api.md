# Contract: Health API

**Consumer**: `flowboard-web` BFF (`server/api/routers/health.ts` via
`lib/api/health-client.ts`)
**Provider**: `flowboard-api` (`Endpoints/HealthEndpoints.cs`)
**Status**: v1, established by feature 001

## GET /v1/health

Public liveness signal. No authentication (spec Assumption; constitution VIII applies
to protected functionality only). No parameters.

### Response — 200 OK, `application/json`

```json
{
  "status": "ok",
  "service": "flowboard-api",
  "version": "0.1.0",
  "timestampUtc": "2026-08-27T09:30:00.0000000Z"
}
```

| Field | Type | Rules |
|---|---|---|
| `status` | string | Literal `"ok"` when the service can serve requests. Any other value, shape, or status code is treated as unhealthy by consumers. |
| `service` | string | Literal `"flowboard-api"` — identifies the responder. |
| `version` | string | Informational assembly/product version. Consumers MUST NOT branch on it. |
| `timestampUtc` | string | ISO 8601 UTC server time. Informational. |

### Error semantics

The endpoint has no failure payload of its own: if the service is up it returns 200
with `status: "ok"`. Consumers MUST treat all of the following as the **unavailable**
state (spec FR-004): network failure, timeout, any non-200 status, non-JSON body, or a
JSON body whose `status` is not `"ok"`.

### Non-goals (v1)

- No dependency checks (database, queues) — none exist yet; when they do, extending
  this contract is a feature-plan decision.
- No readiness/liveness split.

## BFF procedure contract

`trpc.health.status` (query, no input) returns:

```ts
type HealthStatus = {
  status: 'ok';
  service: string;
  version: string;
  timestampUtc: string;
};
```

The procedure validates the upstream JSON with a Zod schema mirroring the table above;
validation failure surfaces to the client as a query error (→ unavailable state).
Timeout: 5 seconds (SC-001 bound).
