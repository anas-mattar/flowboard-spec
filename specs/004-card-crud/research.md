# Research: Card Lifecycle CRUD

Phase 0 output. All Technical Context unknowns resolved below; no `NEEDS
CLARIFICATION` markers remain. The larger architecture calls (modal pattern,
description rendering, activity-feed shape, concurrency mechanism, ordering module,
client-driven canvas) are recorded as ADR-14 through ADR-19 in `plan.md`; this document
covers the remaining operational decisions those ADRs depend on.

## R-1: Endpoint surface — one group, ~14 routes, no `move`

**Decision**: `CardsEndpoints` exposes exactly what spec.md's FRs need and nothing from
FUNCTIONAL_SPEC §7 that belongs to a later feature:

| Method | Path | FR |
|---|---|---|
| POST | `/v1/lists/{listPublicId}/cards` | FR-001 |
| GET | `/v1/cards/{cardPublicId}` | FR-002 |
| PATCH | `/v1/cards/{cardPublicId}` | FR-003, FR-004, FR-007 |
| POST | `/v1/cards/{cardPublicId}/labels` | FR-005 |
| DELETE | `/v1/cards/{cardPublicId}/labels/{labelPublicId}` | FR-005 |
| POST | `/v1/cards/{cardPublicId}/members` | FR-006 |
| DELETE | `/v1/cards/{cardPublicId}/members/{userPublicId}` | FR-006 |
| POST | `/v1/cards/{cardPublicId}/checklist-items` | FR-008 |
| PATCH | `/v1/checklist-items/{checklistItemPublicId}` | FR-008 |
| DELETE | `/v1/checklist-items/{checklistItemPublicId}` | FR-008 |
| POST | `/v1/cards/{cardPublicId}/comments` | FR-009, FR-010 |
| GET | `/v1/cards/{cardPublicId}/activity` | FR-002, FR-010 |
| POST | `/v1/cards/{cardPublicId}/copy` | FR-011 |
| DELETE | `/v1/cards/{cardPublicId}` | FR-012 |

**Rationale**: FUNCTIONAL_SPEC §7's own `PATCH /v1/cards/{id}` is documented as "update
fields **and** move" — this feature's `PATCH` accepts only the fields spec.md scopes to
it (title, description, due date/complete); `list_id`+`position` are intentionally
rejected (`400`) until 005 decides whether to extend this same route or add a dedicated
move endpoint. Discrete label/member/checklist-item routes (rather than one
"replace the whole set" `PUT`) match spec.md's framing of each as an individual
toggle, and let each one carry only the validation it needs (invariant 7 for labels,
the auto-add-to-board side effect for members).

**Alternatives considered**: a single generic `PATCH /v1/cards/{id}` accepting a
partial-update body for labels/members/checklist arrays too — rejected: array-diffing
on the server to infer "was this added or removed" is more code and more failure modes
than a discrete add/remove route per relationship, for no real client simplification
(the UI already reacts to one toggle at a time).

## R-2: Permission matrix — reuse 002's role resolution, apply spec §6 as a fixed table

**Decision**: Every `CardsEndpoints` route resolves the caller's role for the card's
board via 002's existing `BoardAccessService` (traversing `Card → List → Board`, the
same join direction `BoardContentService` already uses for `GET /v1/boards/{id}`), then
checks a fixed table: `BoardAdmin`/`BoardMember` may perform every route above;
`Observer` may perform only `POST .../comments` and every `GET`; anyone with no
resolvable role gets `404` (matching 003's existing "don't confirm existence to a
non-member" behavior).

**Rationale**: Spec §6 already draws this exact line ("Comment: ✓ for every role
including Observer; create/edit/move cards: ✓ only for admin/member"); invariant 5
requires it enforced server-side regardless of what the UI hides. No new role concept
is introduced (spec.md's own Assumptions already commit to this).

## R-3: Copy semantics — precise algorithm

**Decision**: `POST /v1/cards/{id}/copy` performs, in one transaction: (1) create a new
`Card` row — `Title = original.Title + " (copy)"`, `Description` copied verbatim,
`DueAt`/`DueComplete` copied verbatim, `ListId` = original's list, `Position` =
`Ordering.InsertBetween(original.Position, nextSiblingPositionOrNull)` (ADR-18); (2)
copy every `CardLabel` row (same `LabelId`s); (3) copy every `CardMember` row (same
`UserId`s); (4) copy every `ChecklistItem` — same `Text`, `Done` reset to `false`, fresh
`PublicId`s, same relative `Position` order; (5) write exactly one `ActivityEvent`
(`card.created`) on the new card — no `Comment` rows, no other events, are copied.

**Rationale**: matches spec.md's Assumptions ("checklist items carry over with their
text but reset to unchecked... labels, members, description, and due date carry over
unchanged") and C-12's "activity resets" acceptance criterion literally — the new
card's activity feed contains only its own creation.

**Alternatives considered**: preserving checklist checked-state on copy (Trello's own
optional behavior) — rejected as unnecessary choice-surface for a first version; spec.md
already documents the simpler default and flags it as revisitable, not fixed forever.

## R-4: Checklist/label/comment aggregates — computed on read, never a stored counter

**Decision**: `checklistDone`/`checklistTotal` (already returned by 003's
`GET /v1/boards/{id}`) and `commentCount` continue to be computed by aggregate query
(`Count()`/`Count(x => x.Done)`) at read time, in both `BoardContentService` (card
summaries) and the new `CardService` (single-card detail) — never cached on the `Card`
row itself. Adding, ticking, or deleting a checklist item, or posting a comment, needs
no separate "update the counter" step because there is no counter to update.

**Rationale**: `backend-rules.md`'s N+1/derived-value guidance plus plain correctness —
a stored counter is one missed code path away from drifting from the rows it's supposed
to summarize; an aggregate query never can.

## R-5: `dueStatus` bucketing — extracted into one shared helper, not duplicated

**Decision**: The `dueStatus` computation 003 built inline in `BoardContentService` is
extracted into a small static helper (`Flowboard.Api/Domain/CardDueStatus.cs`,
`Compute(DateTime? dueAt, bool dueComplete, DateTime now)` → `"complete" |
"overdue" | "soon" | "future" | null`), called from both `BoardContentService` (card
summaries, unchanged behavior) and the new `CardService` (single-card detail, and
recomputed after every `PATCH`/checklist/etc. that could change it).

**Rationale**: `backend-rules.md`: "two implementations of one formula always diverge."
003 had only one caller so inlining was fine; 004 adds a second caller, which is exactly
the point ADR-4-style shared-module guidance exists for.

**Alternatives considered**: leave it duplicated in `CardService` — rejected, this is
precisely the drift risk the rulebook calls out, and the fix (extract once) costs one
small file.

## R-6: Activity feed rendering — backend returns structured events, frontend owns display text

**Decision**: `GET /v1/cards/{id}/activity` returns each event as
`{ type, payload, actorDisplayName, actorInitials, actorAvatarColor, createdAt }` — the
frontend maps `type` to one of a fixed set of message templates (e.g. `card.renamed` →
`renamed this card to "{payload.title}"`; `comment.added` → renders `payload.body` as
the comment itself, not a templated line) and formats `createdAt` as a relative
timestamp in the viewer's own locale/timezone (spec §8 i18n requirement — the backend
would have to guess the viewer's locale to pre-render text, which it can't).

**Rationale**: relative-time formatting ("2 days ago") and locale are inherently a
display concern; keeping `type`+`payload` as the wire contract (rather than a
pre-rendered string) means adding a new event type later is additive on both sides,
never a breaking string-format change.

## R-7: New card defaults

**Decision**: `POST /v1/lists/{id}/cards` creates a card with only `Title` (required,
from the composer) and `Position = Ordering.Append(lastCardPositionInList)` (or a fixed
start value if the list is empty) — no due date, no description, no labels, no members,
no checklist items. One `ActivityEvent` (`card.created`) is written.

**Rationale**: matches the prototype's own composer (title only) and C-01's acceptance
criteria; every other field is added afterward from the detail modal (Stories 3–7).
