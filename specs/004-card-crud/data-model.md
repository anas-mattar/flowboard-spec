# Data Model: Card Lifecycle CRUD

Phase 1 output. Extends 003's schema. One migration this phase: `AddCardActivity`
(one new table, one new column — every other table this feature writes to already
exists). All entities follow `docs/rulebooks/database-rules.md` and
`docs/rulebooks/backend/database-standards.md`.

## Card *(unchanged schema, extended from 003 — first feature to write to it)*

No column changes. `Title`, `Description`, `DueAt`, `DueComplete`, `Position`,
`RowVersion`, the audit trio, and the soft-delete trio (all from 003's data-model.md)
are exercised by real writes for the first time: `PATCH` (title/description/due-date
fields, `RowVersion`-gated per ADR-17), `DELETE` (soft-delete trio), `Position` (set via
`Ordering.cs`, ADR-18, on create and on copy).

## ChecklistItem *(extended — gains `PublicId`)*

003 created this table but never exposed items individually ("no `PublicId` yet; 004
adds one when it starts addressing items individually" — 003's own data-model.md). This
feature does exactly that: items are now ticked and deleted by their own identifier.

| Column | Type | Notes |
|---|---|---|
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | **new this feature** — invariant 8; `PATCH`/`DELETE /v1/checklist-items/{id}` address by this |

Every other column (`Id`, `CardId`, `Text`, `Done`, `Position`, audit fields) is
unchanged from 003.

**Indexes**: add `UNIQUE INDEX IX_ChecklistItem_PublicId` alongside 003's existing
`IX_ChecklistItem_CardId`.

## CardLabel / CardMember / Comment *(unchanged schema, extended from 003)*

003 modeled these fully but never wrote to them (seed data only). This feature adds the
first write paths:

- **CardLabel**: `POST/DELETE .../labels` insert/delete rows. Invariant 7 is enforced
  in application code here for the first time — `Label.BoardId` (via the label being
  assigned) MUST equal the card's own board (through `Card → List → Board`), checked
  before insert; 003 only ever trusted seed data to already satisfy this.
- **CardMember**: `POST/DELETE .../members` insert/delete rows. `POST` additionally
  inserts a `BoardMember` row (role `BoardMember`) when the assigned user isn't already
  one — the one sanctioned membership side effect (invariant 5, C-07).
- **Comment**: `POST .../comments` inserts one row (`Body`, `AuthorId`, `CreatedDate`).
  Never updated or deleted by this feature (no edit/delete-comment story exists yet).
  Its `PublicId`-less shape from 003 is unchanged — still not individually addressed by
  a URL; the activity feed (below) is what the frontend actually reads.

## ActivityEvent *(new)*

Append-only (invariant 1) — no `Updated*` columns, no soft-delete trio, because there is
no update or delete path for a row in this table, ever.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK — not individually addressed by any route; the feed is fetched as a list scoped to a card, same reasoning as `Comment`/`ChecklistItem` in 003 |
| `CardId` | `INT NOT NULL` | FK → `Card.Id`, restrict delete (invariant 4 — history must keep resolving after a card is soft-deleted) |
| `ActorId` | `INT NOT NULL` | FK → `User.Id`, restrict delete |
| `Type` | `NVARCHAR(40) NOT NULL` | one of: `card.created`, `card.renamed`, `card.described`, `label.added`, `label.removed`, `member.assigned`, `member.unassigned`, `due.set`, `due.cleared`, `due.completed`, `checklist.item.added`, `checklist.item.checked`, `checklist.item.deleted`, `comment.added` (FUNCTIONAL_SPEC §5.2, plus `checklist.item.deleted` which this feature's C-09 needs and §5.2 didn't originally enumerate) |
| `Payload` | `NVARCHAR(MAX) NOT NULL` | small JSON blob, shape fixed per `Type` (research.md R-6); e.g. `comment.added` → `{"body":"..."}`, `card.renamed` → `{"title":"..."}` |
| `CreatedDate` | `DATETIME2 NOT NULL` | |
| `CreatedBy` | `NVARCHAR(100) NOT NULL` | the actor's `PublicId` (matches `Comment.CreatedBy`'s existing convention from 003) |

**Indexes**: `INDEX IX_ActivityEvent_CardId_CreatedDate` (feed reads: one card, newest
first, cursor-paginated per ADR-12's reused shape).

**Database-rules.md note**: no UPDATE/DELETE code path exists for this table; a
database-level guard (trigger or permission) is a reasonable hardening step but not
required to satisfy invariant 1 in this feature — application code never attempts one.

## Response DTOs (Phase 1 — `contracts/card-crud-api.md` defines the wire shapes)

- **`CardDetail`**: `publicId`, `title`, `description`, `dueAt`, `dueComplete`,
  `dueStatus` (via the shared `CardDueStatus` helper, research.md R-5), `listPublicId`,
  `listName`, `boardPublicId`, `boardName`, `labels: LabelSummary[]` (reused from 003),
  `members: MemberAvatar[]` (reused from 003), `checklistItems: ChecklistItemDetail[]`.
- **`ChecklistItemDetail`**: `publicId`, `text`, `done`.
- **`ActivityEntry`**: `type`, `payload` (opaque JSON, typed per `type` on the frontend
  — research.md R-6), `actorDisplayName`, `actorInitials`, `actorAvatarColor`,
  `createdAt`.
- **`CardSummary`** *(003, unchanged shape — still what board hydration returns)*: this
  feature's mutations change which cards exist and what they contain, but never change
  the shape 003 already defined.
