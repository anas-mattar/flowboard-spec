# Integration Patterns

## Purpose

This file defines standard integration patterns for FlowBoard. No integration exists in
v1.0; each pattern activates when its feature is specced (contract first —
constitution IX).

## Pattern 1: Outbound Query API

Use for read-only provider data such as:

- Billing/subscription status
- SSO directory lookups

Flow:

```text
Application Service
  -> External Client
  -> Provider API
  -> Map Response
  -> Return DTO
```

Rules:

- Cache only if approved.
- Do not mutate domain data directly from a query response.
- Log failures with correlation ID.

## Pattern 2: Outbound Posting API

Use for sending official data to another system:

- Invitation / notification emails
- Billing mutations (seat changes, plan changes)
- Data-export delivery (spec §8, GDPR)

Flow:

```text
Application Service
  -> Create local pending record
  -> Create idempotency key
  -> External Client
  -> Provider API
  -> Store response
  -> Update status
```

Rules:

- Must use idempotency key where possible.
- Must store request and response summary.
- Must not mark success until provider confirms success.
- Must handle duplicate submission safely.

## Pattern 3: Incoming Webhook

Use for external systems calling FlowBoard (e.g. billing provider events).

Flow:

```text
Webhook Endpoint
  -> Validate signature/timestamp
  -> Store raw payload
  -> Enqueue processing job
  -> Return 200/202 quickly
  -> Processor validates business data
  -> Apply business action
  -> Store processing result
```

Rules:

- Do not do heavy business processing inside the webhook endpoint.
- Webhook processing must be idempotent.
- Store raw payload for audit.
- Validate signature before trusting payload.

## Pattern 4: Scheduled Sync

Use for periodic data import/maintenance:

- SCIM directory sync (Enterprise)
- Retention sweeps (30-day archive window — invariant 4: sweeps only mark
  purge-eligible; physical purge needs its own approved feature)

Flow:

```text
Scheduler
  -> Sync Service
  -> External Client / database
  -> Compare with existing data
  -> Insert/update using audit fields
  -> Store sync summary
```

Rules:

- Sync must be repeatable.
- Sync must not duplicate records.
- Sync must record last successful run.
- Sync failures must be visible.

## Pattern 5: Queue-Based Integration

Use when provider calls are slow or unreliable (notification fan-out, export
generation).

Flow:

```text
API Request
  -> Validate
  -> Store pending record
  -> Publish queue message
  -> Worker sends external request
  -> Worker updates status
```

Rules:

- Queue messages must include correlation ID.
- Worker must be idempotent.
- Retry policy must be controlled.
- Poison messages must be visible.
