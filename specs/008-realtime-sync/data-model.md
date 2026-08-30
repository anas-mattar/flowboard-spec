# Data Model: Realtime Sync & Concurrency

Phase 1 output. **No migration.** This feature adds no persisted table or column — every
concurrency mechanism it relies on (`Card.RowVersion`, `List.RowVersion`,
`Board.RowVersion`, the `ExecuteUpdateAsync`-based last-write-wins card move) already
exists from 004/005/006. What follows are the new **transient, protocol-level shapes**:
one JWT claim set, one broadcast envelope, and one in-memory connection map — none of
them rows in `flowboard-db`.

## RealtimeTokenClaims *(new — not persisted, minted per request)*

Issued by `POST /v1/boards/{boardPublicId}/realtime-token` (contracts/realtime-api.md),
consumed by `BoardHub`'s connection auth. Reuses `ITokenService`'s existing JWT issuance
(002's ADR-7) with a distinct, short lifetime and purpose claim so it can never be
mistaken for — or substituted by — the 14-day backend session JWT.

| Claim | Type | Notes |
|---|---|---|
| `sub` | `Guid` (User.`PublicId`) | Same claim name as the existing backend JWT (ADR-7), so `ClaimsPrincipalExtensions.GetUserPublicId()` keeps working unchanged for the hub. |
| `boardId` | `Guid` (Board.`PublicId`) | **New claim.** The one board this token authorizes; never any other board's `PublicId`. Opaque public identifier only — never the internal `Board.Id` (invariant 8). |
| `purpose` | `string` (`"realtime"`) | **New claim.** Lets `BoardHub`'s auth reject a normal 14-day session JWT presented by mistake — that token has no `purpose`/`boardId` claim at all. |
| `exp` | Unix timestamp | **New lifetime.** 2 minutes from issuance (research.md R-3/R-7) — short enough to bound access-revocation staleness without a revocation list. |

Role is deliberately **not** a claim (same posture as the existing backend JWT, ADR-7):
`BoardHub.JoinBoard` re-resolves the caller's role via `IBoardAccessService` at join time
rather than trusting a role baked into a token that could be up to 2 minutes stale
(invariant 5 — "a valid token is not board access").

## BoardRealtimeEvent *(new — the broadcast envelope, never persisted)*

Sent by `IBoardEventPublisher` to SignalR group `board:{boardPublicId}`, received by every
client's single `"BoardEvent"` hub handler (research.md R-5).

| Field | Type | Notes |
|---|---|---|
| `type` | `string` | For card-scoped events: the exact `ActivityEventType` string already persisted to the `ActivityEvent` row for this change (`card.created`, `card.moved`, `label.added`, `comment.added`, etc. — FUNCTIONAL_SPEC.md §5.2). For board/list mutations with no `ActivityEvent` counterpart: one of `board.renamed`, `board.starred`, `board.unstarred`, `board.archived`, `list.created`, `list.renamed`, `list.moved`, `list.archived`, `list.wip_limit_changed`. |
| `boardPublicId` | `Guid` | Routing/scoping only (FR-002) — every client already knows which board it opened; this lets the client ignore an event that somehow arrives for a different board. |
| `occurredAt` | `DateTime` (UTC) | For card-scoped events: the persisted `ActivityEvent.CreatedAt`. For board/list events: the mutation's `UpdatedDate`. |
| `actorPublicId` / `actorDisplayName` | `Guid` / `string` | Who made the change — same actor-resolution already used for `ActivityEntryDto` (`CardService.NewEvent`). Lets the client, if it chooses, suppress or de-emphasize an echo of the viewer's own action (optimistic UI already applied it). |
| `payload` | JSON object | For card-scoped events: the exact `ActivityEvent.Payload` already persisted (invariant 1 — "same event objects"). For board/list events: only the minimal identifying fields a consumer needs — e.g. `list.wip_limit_changed` carries `{ listPublicId }`, not the new limit value itself (research.md R-6 — the client always re-fetches rather than trusting a payload value as authoritative). |

This is a wire shape (JSON over the SignalR hub protocol), not a C# entity — it has no
table, no `PublicId` of its own, and is never queried after delivery.

## BoardConnectionTracker entry *(new — in-memory only, not persisted, not distributed)*

Held by a singleton service backing `IBoardEventPublisher`'s eviction path
(research.md R-7). Populated in `BoardHub.JoinBoard`, removed in `OnDisconnectedAsync`.

| Key | Value | Notes |
|---|---|---|
| `(boardPublicId, userPublicId)` | `set<connectionId>` | One user can have multiple live connections to the same board (two tabs, two devices) — Edge Cases in spec.md. Cleared entirely on process restart; rebuilt as clients reconnect (research.md R-8 — single-instance, no distributed state). |

## Existing entities this feature reads but does not alter

- **`Card`, `List`, `Board`** (`RowVersion`, `Position`, soft-delete trio) — concurrency
  behavior unchanged from 004/005/006; this feature only makes the *outcome* of an
  existing `409`/last-write-wins visible live, per Story 2. See research.md's discussion
  of `CardService.MoveCardAsync`'s existing ADR-21 (`ExecuteUpdateAsync` bypasses the
  RowVersion check — ExecuteUpdateAsync will still legally bump the SQL Server
  `rowversion` value itself, which is exactly why a stale field-edit `If-Match` correctly
  409s even after a concurrent move it never knew about).
- **`ActivityEvent`** — read (not written) by this feature's card-event broadcast path;
  no schema change, no new event type added to `ActivityEventType` (invariant 1 already
  enumerates the full set this feature reuses).
