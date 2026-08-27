# Data Model: Auth & Workspaces

Phase 1 output. All entities follow `docs/rulebooks/database-rules.md` and
`docs/rulebooks/backend/database-standards.md`: `Id INT IDENTITY` primary keys, opaque
`PublicId` on every API-addressed entity, audit fields on business entities, soft delete
where the standards doc lists it.

## User

Not in the soft-delete entity list (`database-standards.md` §4) — no account
soft-delete/erasure flow in this feature (spec.md Assumptions).

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 — the only id the API exposes |
| `Email` | `NVARCHAR(320) NOT NULL` | unique index (case-insensitive collation); FR-002 |
| `PasswordHash` | `NVARCHAR(200) NOT NULL` | BCrypt-encoded (research R-2) |
| `DisplayName` | `NVARCHAR(100) NOT NULL` | |
| `Initials` | `NVARCHAR(4) NOT NULL` | derived from `DisplayName` at signup |
| `AvatarColor` | `NVARCHAR(20) NOT NULL` | matches FUNCTIONAL_SPEC §5 `User` shape |
| `CreatedDate` | `DATETIME2 NOT NULL` | |
| `CreatedBy` | `NVARCHAR(100) NOT NULL` | `SYSTEM` for self-signup (no actor yet exists) |
| `UpdatedDate` | `DATETIME2 NULL` | |
| `UpdatedBy` | `NVARCHAR(100) NULL` | |

**Indexes**: `UNIQUE INDEX IX_User_Email` (case-insensitive), `UNIQUE INDEX
IX_User_PublicId`.

**Validation**: `Email` valid format, ≤ 320 chars; password (not persisted as its own
column — validated pre-hash) minimum 10 characters (research R-10).

## Workspace

Soft-delete entity (`database-standards.md` §4 list).

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 |
| `Name` | `NVARCHAR(200) NOT NULL` | defaulted at signup (e.g. "{DisplayName}'s Workspace") |
| `OwnerUserId` | `INT NOT NULL` | FK → `User.Id`, restrict delete; ADR-10 — the workspace admin |
| `CreatedDate` / `CreatedBy` | `DATETIME2` / `NVARCHAR(100)` NOT NULL | |
| `UpdatedDate` / `UpdatedBy` | nullable | |
| `IsDeleted` / `DeletedDate` / `DeletedBy` | soft-delete trio | not exercised by this feature (no workspace-delete flow in scope) — present per the standard, unused for now |

**Indexes**: `UNIQUE INDEX IX_Workspace_PublicId`, `INDEX IX_Workspace_OwnerUserId`.

**Invariant**: exactly one `Workspace` row per `User` created at signup (FR-006, FR-007)
— enforced by creating both rows in the same transaction as part of signup, with a
`UNIQUE INDEX IX_Workspace_OwnerUserId` preventing a second workspace ever being
attached to the same owner.

## Board

Soft-delete entity. **Minimal placeholder schema** (ADR-11) — 003/006 extend this table
with their own migrations (color, starred, etc.); this feature only adds what
`BoardMember`/`Invitation` and its own tests need.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 |
| `WorkspaceId` | `INT NOT NULL` | FK → `Workspace.Id`, restrict delete |
| `Name` | `NVARCHAR(200) NOT NULL` | |
| `CreatedDate` / `CreatedBy` | NOT NULL | |
| `UpdatedDate` / `UpdatedBy` | nullable | |
| `IsDeleted` / `DeletedDate` / `DeletedBy` | soft-delete trio | not exercised by this feature |

**Seed data**: one deterministic `HasData` row (fixed `Id`/`PublicId`/timestamps,
`CreatedBy = 'MIGRATION'`) — a fixture board this feature's own integration tests invite
members to and check authorization against. Not the prototype's three seeded boards
(that seed belongs to 003, per ADR-11). This board's `Workspace` and owning `User` are
seeded alongside it (`WorkspaceConfiguration`/`UserConfiguration`); per second-model
adversarial review B1, the seeded `User.PasswordHash` MUST be a non-verifiable
placeholder in this production migration model — never a real, working credential. The
real test-only hash is set separately by the test host, only in the disposable test
database.

**Indexes**: `UNIQUE INDEX IX_Board_PublicId`, `INDEX IX_Board_WorkspaceId`.

## BoardMember

Join entity — never addressed by the API via its own bare identifier (always via
board + user `PublicId`s), so no `PublicId` column. Not in the soft-delete list;
removal is a hard delete of the membership row.

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK (surrogate, for uniform FK-ability — not API-addressed) |
| `BoardId` | `INT NOT NULL` | FK → `Board.Id`, restrict delete (database-rules.md: FKs to soft-deleted master data never cascade — a `BoardMember` row for an archived board simply stops granting access via `BoardAccessService`, it isn't cleaned up by a cascade) |
| `UserId` | `INT NOT NULL` | FK → `User.Id`, restrict delete |
| `Role` | `NVARCHAR(20) NOT NULL` | `CHECK (Role IN ('BoardAdmin','BoardMember','Observer'))` — FUNCTIONAL_SPEC §6 roles (invariant mirrored as a constraint, database-rules.md) |
| `CreatedDate` | `DATETIME2 NOT NULL` | when this membership was granted |
| `CreatedBy` | `NVARCHAR(100) NOT NULL` | the inviter's `PublicId`, or `SYSTEM` for the workspace-owner's implicit access (which is never actually materialized as a row — see ADR-9) |

**Indexes**: `UNIQUE INDEX IX_BoardMember_BoardId_UserId` (FR-009 — no duplicate
membership rows).

**Note**: the workspace owner's `BoardAdmin`-equivalent access (FR-015) is **not** a
`BoardMember` row — it's resolved live by `BoardAccessService` (ADR-9) by comparing
`Board.WorkspaceId → Workspace.OwnerUserId` against the caller. A `BoardMember` row only
exists for members added via invitation.

## Invitation

Not in the soft-delete list — its own `Status` lifecycle is the audit record (no
physical delete on accept/revoke).

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT IDENTITY(1,1)` | PK |
| `PublicId` | `UNIQUEIDENTIFIER NOT NULL UNIQUE` | invariant 8 — addressed by `DELETE /v1/invitations/{publicId}` |
| `BoardId` | `INT NOT NULL` | FK → `Board.Id`, restrict delete |
| `Email` | `NVARCHAR(320) NOT NULL` | the invitee's email (may not have an account yet — FR-011) |
| `Role` | `NVARCHAR(20) NOT NULL` | same `CHECK` constraint as `BoardMember.Role` |
| `InvitedByUserId` | `INT NOT NULL` | FK → `User.Id`, restrict delete |
| `Status` | `NVARCHAR(20) NOT NULL` | `CHECK (Status IN ('Pending','Accepted','Revoked'))` |
| `CreatedDate` / `CreatedBy` | NOT NULL | |
| `UpdatedDate` / `UpdatedBy` | nullable | set on the Pending → Accepted/Revoked transition |

**Indexes**: `UNIQUE INDEX IX_Invitation_PublicId`; `UNIQUE INDEX
IX_Invitation_BoardId_Email_Pending` — a filtered unique index
(`WHERE Status = 'Pending'`) enforcing at most one pending invitation per
(board, email) pair. Re-inviting the same pending email updates that row's `Role`
in place (spec edge case: "most recent invite's role wins") rather than inserting a
second row.

**State transitions**: `Pending → Accepted` (the invited email signs up or is already a
registered user whose next session picks it up — a `BoardMember` row is created in the
same transaction); `Pending → Revoked` (a Board admin/Workspace admin deletes it before
acceptance). No transition out of `Accepted`/`Revoked`.

## Entity Relationship Summary

```text
User 1──1 Workspace        (Workspace.OwnerUserId → User.Id; ADR-10)
Workspace 1──* Board       (Board.WorkspaceId → Workspace.Id)
Board 1──* BoardMember     (BoardMember.BoardId → Board.Id)
User 1──* BoardMember      (BoardMember.UserId → User.Id)
Board 1──* Invitation      (Invitation.BoardId → Board.Id)
User 1──* Invitation       (Invitation.InvitedByUserId → User.Id, "invited by")
```

## Out of Scope for This Feature

- `Board.Color`, `Board.Starred` — 006 (board management).
- The prototype's three-board seed — 003 (read-only board view).
- `WorkspaceMember` (multiple admins per workspace) — not modeled; ADR-10.
- Email delivery for invitations — research R-7.
