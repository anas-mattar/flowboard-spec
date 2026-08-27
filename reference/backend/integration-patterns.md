# Integration Patterns

## Purpose

This file defines standard integration patterns for FMS.

## Pattern 1: Outbound Query API

Use for read-only provider data such as:

- Exchange rates
- Vendor status
- Customer information
- Bank account validation

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
- Do not mutate financial data directly from a query response.
- Log failures with correlation ID.

## Pattern 2: Outbound Posting API

Use for sending official data to another system:

- Payment instruction
- E-invoice submission
- ERP posting
- Tax submission

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

Use for external systems calling FMS.

Flow:

```text
Webhook Controller
  -> Validate signature/timestamp
  -> Store raw payload
  -> Enqueue processing job
  -> Return 200/202 quickly
  -> Processor validates business data
  -> Apply business action
  -> Store processing result
```

Rules:

- Do not do heavy business processing inside the webhook controller.
- Webhook processing must be idempotent.
- Store raw payload for audit.
- Validate signature before trusting payload.

## Pattern 4: Scheduled Sync

Use for periodic data import:

- Exchange rates
- Bank statements
- Vendor master data
- Customer master data

Flow:

```text
Scheduler
  -> Sync Service
  -> External Client
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

Use when provider calls are slow or unreliable.

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

## Exchange Rate Integration

Rules:

- Store rate source.
- Store retrieved timestamp.
- Store effective date.
- Do not recalculate historical posted journals.
- FX revaluation must create explicit journals.

## ERP Integration

Rules:

- Store external document reference.
- Store request/response status.
- Do not assume success from HTTP 200 alone; check provider business status.
- Reconciliation report is required for posted data.

## Payment Gateway / Bank Integration

Rules:

- Idempotency required.
- Never log full bank details unless protected.
- Payment status changes must be audited.
- Failed payment must not silently disappear.
