# Data Model — 009 Card Attachments

## Attachment (NEW entity)

Represents one file attached to one card. Bytes live outside this row (research.md R-1); this
row is metadata + a pointer.

| Field | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1) PRIMARY KEY` | Internal key (constitution V). Never exposed. |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | Opaque API identifier (invariant 8, research.md R-7). |
| `CardId` | `INT NOT NULL` (FK → `Card.Id`, `Restrict`) | Owning card. Indexed. |
| `FileName` | `NVARCHAR(255) NOT NULL` | Original filename as uploaded, for display and download (spec FR-003). Not used as the storage key (research.md R-1). |
| `SizeBytes` | `BIGINT NOT NULL` | For display (spec FR-003) and to avoid re-reading the stored file just to show a size. |
| `ContentType` | `NVARCHAR(255) NOT NULL` | As reported by the upload request; used to set `Content-Type` on download. |
| `StorageKey` | `NVARCHAR(255) NOT NULL` | Opaque key `LocalDiskAttachmentStorage` uses to locate the bytes (research.md R-1) — never derived from `FileName`. |
| `UploadedById` | `INT NOT NULL` (FK → `User.Id`, `Restrict`) | For display ("uploaded by", spec FR-003) and for the removal-permission check (spec FR-005, research.md R-5). |
| `CreatedDate` | `DATETIME2 NOT NULL` | Audit field (constitution VI). Doubles as "attached at". |
| `CreatedBy` | `NVARCHAR(100) NOT NULL` | Audit field — the uploader's `PublicId` string, matching every other mutation's `CreatedBy` convention in this codebase. |

No `UpdatedDate`/`UpdatedBy`/soft-delete fields: an attachment is never edited, only added or
hard-removed (spec.md has no "edit an attachment" story, and FR-007 requires removal to make
the file "immediately unavailable," not merely hidden). Hard delete here does not conflict
with constitution VI's "master data is never physically deleted" — an attachment is not master
data, and `Comment`/`ChecklistItem` establish the same precedent of card sub-resources with no
soft-delete fields of their own; the append-only, never-deleted record of the fact that an
attachment existed and was removed lives in `ActivityEvent` (below), consistent with how a
deleted `ChecklistItem` is still visible in card history.

**Query filter**: `HasQueryFilter(x => !x.Card.IsDeleted)`, same pattern as
`ChecklistItemConfiguration` — an attachment on an archived (soft-deleted) card is excluded
from normal queries the same way its card's other sub-resources are, and returns when the card
is restored (spec.md's "Attachments remain associated with the card through archive and
restore," FR-012).

**Relationships**: `Card` 1 → many `Attachment` (new `Card.Attachments` navigation collection,
alongside the existing `CardLabels`/`CardMembers`/`ChecklistItems`/`Comments`). `User` 1 → many
`Attachment` (uploader), no navigation collection needed on `User` (none of the other
uploader-style FKs — e.g. `Comment.AuthorId` — have one either).

## ActivityEvent (extended, no schema change)

Two new `Type` values, added to `Domain/ActivityEventType.cs` (research.md R-6):

- `attachment.added` — `Payload: { fileName: string }`.
- `attachment.removed` — `Payload: { fileName: string }`.

Matches the existing convention (`checklist.item.added`'s `{ text }`,
`checklist.item.deleted`'s `{ text }`) of carrying just enough of the removed/added thing's
identity to render a human-readable activity line after the row itself is gone.

## No change to `Card`, `RealtimeEventType`, or any other existing entity

`Card` gains only the `Attachments` navigation collection (a C# property, not a schema change).
`RealtimeEventType.cs` is untouched — attachment events broadcast as `ActivityEvent` types,
verbatim, per the existing card-scoped-broadcast path (research.md R-6, 008 ADR-35).

## Migration

One migration, `AddCardAttachments`: `CREATE TABLE Attachment` per the schema above, FK to
`Card` (`Restrict` — matches `ChecklistItem`'s FK behavior, and database-rules.md's rule that
FKs to soft-deletable master data must not cascade), FK to `User` (`Restrict`), unique index on
`PublicId`, non-unique index on `CardId`. Purely additive — no existing table or column is
touched. Fully reversible by dropping the new table (`Down()`); no rollback.md is required
(Standard delivery level — see Constitution Check in plan.md).
