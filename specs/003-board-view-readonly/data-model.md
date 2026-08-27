# Data Model: Board View (Read-Only)

Phase 1 output. All entities follow `docs/rulebooks/database-rules.md` and
`docs/rulebooks/backend/database-standards.md`: `Id INT IDENTITY` primary keys, opaque
`PublicId` on every entity this feature's API actually returns as an individually
identified item, audit fields on business entities, soft delete where invariant 4 lists
it. One migration this phase: `AddBoardContent` (schema + `HasData` seed together, per
002's precedent).

## Board *(extended — schema already exists from 002, ADR-11)*

Adds two columns to the existing table; both are additive `ALTER TABLE` operations.

| Column | Type | Notes |
|---|---|---|
| `Color` | `NVARCHAR(20) NOT NULL DEFAULT('#64748b')` | display-only in this feature (VI-001/VI-002's sidebar swatch); no endpoint sets it — B-03/006 |
| `Starred` | `BIT NOT NULL DEFAULT(0)` | display-only; sidebar sorts starred boards first (R-3, B-04's display rule) but no endpoint toggles it — B-04/006 |

The existing 002 columns (`Id`, `PublicId`, `WorkspaceId`, `Name`, audit, soft-delete)
are unchanged. The default values backfill the one existing seeded row (`Fixture Board`)
without altering its behavior in 002's own tests.

## List *(new)*

Soft-delete entity (invariant 4: "Boards, lists and cards").

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 — each list is returned as its own identified item in `GET /v1/boards/{id}` |
| `BoardId` | `INT NOT NULL` | FK → `Board.Id`, restrict delete |
| `Name` | `NVARCHAR(200) NOT NULL` | |
| `Position` | `FLOAT NOT NULL` | invariant 2; seed-assigned fixed values this feature (R-8) — no move endpoint yet |
| `WipLimit` | `INT NULL` | display-only (R-7); `NULL` = no limit shown; set only by this feature's seed |
| `CreatedDate` / `CreatedBy` | `DATETIME2` / `NVARCHAR(100)` NOT NULL | `CreatedBy = 'MIGRATION'` for seeded rows |
| `UpdatedDate` / `UpdatedBy` | nullable | unused this feature |
| `IsDeleted` / `DeletedDate` / `DeletedBy` | soft-delete trio | unused this feature (no archive/delete endpoint yet — L-06/006) |

**Indexes**: `UNIQUE INDEX IX_List_PublicId`, `INDEX IX_List_BoardId`,
`INDEX IX_List_BoardId_Position` (ordering reads, database-rules.md's "Position within
parent").

## Card *(new)*

Soft-delete entity (invariant 4). Carries `RowVersion` now per `database-rules.md`
("`RowVersion` is REQUIRED on `Card`") even though no endpoint uses `If-Match` in this
feature — the column exists so 004's optimistic-concurrency edits don't need a schema
change to add it later.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 |
| `ListId` | `INT NOT NULL` | FK → `List.Id`, restrict delete |
| `Title` | `NVARCHAR(200) NOT NULL` | |
| `Description` | `NVARCHAR(MAX) NULL` | C-05 content; this feature only reads whether it's non-empty (VI-009's description indicator) — never renders or edits the text itself |
| `Position` | `FLOAT NOT NULL` | invariant 2; seed-assigned (R-8) |
| `DueAt` | `DATETIME2 NULL` | UTC |
| `DueComplete` | `BIT NOT NULL DEFAULT(0)` | C-08 |
| `RowVersion` | `ROWVERSION NOT NULL` | SQL Server auto-maintained; `.IsRowVersion()` mapping; unused (no writes) until 004 |
| `CreatedDate` / `CreatedBy` | NOT NULL | |
| `UpdatedDate` / `UpdatedBy` | nullable | unused this feature |
| `IsDeleted` / `DeletedDate` / `DeletedBy` | soft-delete trio | unused this feature |

**Indexes**: `UNIQUE INDEX IX_Card_PublicId`, `INDEX IX_Card_ListId`,
`INDEX IX_Card_ListId_Position`, `INDEX IX_Card_DueAt` (database-rules.md's suggested
starting index list).

## Label *(new)*

Board-scoped (invariant 7). Not a soft-delete entity — not named in invariant 4's list
(boards/lists/cards only); a label-delete/archive story doesn't exist yet in
FUNCTIONAL_SPEC, so this is deferred to whichever feature adds label management, not
decided here.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 — each label is its own identified item on a card's `labels` array |
| `BoardId` | `INT NOT NULL` | FK → `Board.Id`, restrict delete — invariant 7's enforcement point |
| `Name` | `NVARCHAR(50) NOT NULL` | e.g. "Feature", "Bug" |
| `Color` | `NVARCHAR(20) NOT NULL` | chip color, VI-009 |
| `CreatedDate` / `CreatedBy` | NOT NULL | |
| `UpdatedDate` / `UpdatedBy` | nullable | |

**Indexes**: `UNIQUE INDEX IX_Label_PublicId`, `INDEX IX_Label_BoardId`.

## CardLabel *(new, join)*

Not addressed by its own identifier (like `BoardMember`) — no `PublicId`.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK (surrogate, not API-addressed) |
| `CardId` | `INT NOT NULL` | FK → `Card.Id`, restrict delete |
| `LabelId` | `INT NOT NULL` | FK → `Label.Id`, restrict delete |
| `CreatedDate` / `CreatedBy` | NOT NULL | when the label was assigned |

**Indexes**: `UNIQUE INDEX IX_CardLabel_CardId_LabelId`.

**Invariant 7 note**: a `CardLabel` row's `Label.BoardId` MUST equal its `Card`'s
(via `List`) `BoardId`. Not expressible as a single-table `CHECK` constraint; enforced at
the application layer by whichever feature writes this table (004) — this feature only
reads seed data that is trusted to already satisfy it.

## CardMember *(new, join)*

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK (surrogate, not API-addressed) |
| `CardId` | `INT NOT NULL` | FK → `Card.Id`, restrict delete |
| `UserId` | `INT NOT NULL` | FK → `User.Id`, restrict delete |
| `CreatedDate` / `CreatedBy` | NOT NULL | C-07: assigning a non-board-member adds them to the board — not this feature's concern (no assign endpoint yet) |

**Indexes**: `UNIQUE INDEX IX_CardMember_CardId_UserId`.

## ChecklistItem *(new)*

Not exposed individually by this feature's API — `GET /v1/boards/{id}` returns only the
aggregate `checklistDone`/`checklistTotal` counts per card (VI-009), never the items
themselves (that's the card detail modal, 004/INV-007). No `PublicId` yet; 004 adds one
when it starts addressing items individually (check/uncheck/delete).

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `CardId` | `INT NOT NULL` | FK → `Card.Id`, restrict delete |
| `Text` | `NVARCHAR(500) NOT NULL` | |
| `Done` | `BIT NOT NULL DEFAULT(0)` | |
| `Position` | `FLOAT NOT NULL` | matches FUNCTIONAL_SPEC §5's schema; unused for ordering by this feature (only a count is read) |
| `CreatedDate` / `CreatedBy` | NOT NULL | |

**Indexes**: `INDEX IX_ChecklistItem_CardId`.

## Comment *(new)*

Not exposed individually — only `commentCount` per card (VI-009). No `PublicId` yet
(same reasoning as `ChecklistItem`).

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `CardId` | `INT NOT NULL` | FK → `Card.Id`, restrict delete |
| `AuthorId` | `INT NOT NULL` | FK → `User.Id`, restrict delete |
| `Body` | `NVARCHAR(MAX) NOT NULL` | not rendered by this feature |
| `CreatedDate` | `DATETIME2 NOT NULL` | |
| `CreatedBy` | `NVARCHAR(100) NOT NULL` | the author's `PublicId` (matches the wrap-up B3 convention from 002) |

**Indexes**: `INDEX IX_Comment_CardId`.

## Seed data (R-4)

Three new `Board` rows under the existing fixture workspace
(`WorkspaceConfiguration.FixtureWorkspaceId`), reproducing
`screenshots/board-canvas.png` (= `docs/product/prototype/preview-board.png`):

1. **Product Roadmap Q3** — starred, 4 lists (Backlog, Design, In Progress [`WipLimit=3`],
   Review [`WipLimit=2`]), 11 cards total across them, matching the capture's labels
   (`Feature`/`Design`/`Research`/`Bug`/`Urgent`), due dates (a mix of future/near-term/
   overdue), checklists, comments, and member assignments (reusing 002's fixture owner
   plus new seeded users for the avatars shown — `AK`, `LF`, `OH`, `PN`, `TB`).
2. **Marketing Launch** and 3. **Customer Support** — the sidebar-only detail the capture
   shows (name, color swatch, card count `4` and `2` respectively) is reproduced exactly;
   their internal lists/cards are seed-author's choice (not shown in the one available
   capture) — kept small and simple, no invented visual claim the capture doesn't make.

All seed users needed only for card-member avatars (`AK`, `TB` — `LF`/`OH`/`PN` already
plausible names for future reuse) are added the same way 002 added its fixture owner:
deterministic `HasData`, non-verifiable placeholder password hashes (wrap-up B1's
pattern — no real credential ships in this migration either).

## Response DTOs (Phase 1 — contracts/board-content-api.md defines the wire shapes)

- **`BoardSummary`**: `publicId`, `name`, `color`, `starred`, `cardCount` — sidebar rows
  and `GET /v1/boards` items.
- **`BoardContent`**: `BoardSummary`'s fields plus `lists: ListContent[]` —
  `GET /v1/boards/{id}`.
- **`ListContent`**: `publicId`, `name`, `wipLimit`, `cardCount`, `cards: CardSummary[]`.
- **`CardSummary`**: `publicId`, `title`, `dueAt`, `dueStatus` (server-computed — see
  contract), `hasDescription`, `checklistDone`/`checklistTotal` (both `null` when the
  card has no checklist items), `commentCount`, `labels: LabelSummary[]`,
  `members: MemberAvatar[]`.
- **`LabelSummary`**: `publicId`, `name`, `color`.
- **`MemberAvatar`**: same shape as `board-membership-api.md`'s member `user` object
  (`publicId`, `displayName`, `initials`, `avatarColor`) — reused, not redefined.
