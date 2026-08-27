# Database Standards

## Purpose

This file defines mandatory database standards for FlowBoard backend development.

These rules apply to all database design, EF Core entities, migrations, and database
reviews. They restate and detail constitution principles V–VI; the constitution wins on
any conflict.

## 1. Primary Key Standard

Default primary key:

```sql
Id INT IDENTITY(1,1) PRIMARY KEY
```

Do not use GUID/UUID as the database primary key unless explicitly approved in `plan.md`.

### Why INT IDENTITY

Use `INT IDENTITY` because it gives:

- Smaller clustered indexes
- Better SQL Server join performance
- Less index fragmentation
- Easier support and troubleshooting
- Cleaner foreign keys
- Easier manual database inspection

### Public Identifiers (MANDATORY for API-exposed entities)

Every API-exposed entity carries an opaque public identifier (constitution V, domain
invariant 8):

```sql
Id INT IDENTITY(1,1) PRIMARY KEY,
PublicId UNIQUEIDENTIFIER NOT NULL UNIQUE
```

The `Id` remains the database primary key and never leaves the service. The `PublicId`
is the only identifier exposed by the API, WebSocket events, or logs.

Other allowed GUID usages (non-primary reference fields):

```text
CorrelationId
ExternalReferenceId
IdempotencyKey
IntegrationReference
WebhookEventId
```

## 2. Base Entity Standard

All business entities should inherit or follow this structure:

```csharp
public abstract class BaseEntity
{
    public int Id { get; set; }

    public DateTime CreatedDate { get; set; }
    public string CreatedBy { get; set; } = string.Empty;

    public DateTime? UpdatedDate { get; set; }
    public string? UpdatedBy { get; set; }

    public bool IsDeleted { get; set; }
    public DateTime? DeletedDate { get; set; }
    public string? DeletedBy { get; set; }

    public byte[]? RowVersion { get; set; }
}
```

`RowVersion` is REQUIRED on `Card` and any entity with `If-Match` edits — it implements
the optimistic concurrency of spec §7.1 (domain invariant 6).

## 3. Audit Fields

Required for business tables (constitution VI):

```text
CreatedDate DATETIME2 NOT NULL
CreatedBy NVARCHAR(100) NOT NULL
UpdatedDate DATETIME2 NULL
UpdatedBy NVARCHAR(100) NULL
IsDeleted BIT NOT NULL DEFAULT(0)
DeletedDate DATETIME2 NULL
DeletedBy NVARCHAR(100) NULL
```

For system-generated entries, use a clear system user value:

```text
SYSTEM
MIGRATION
```

## 4. Soft Delete

Business entities must use soft delete (domain invariant 4: restorable ≥ 30 days).

Soft delete means:

```text
IsDeleted = true
DeletedDate = current UTC date/time
DeletedBy = current user/system
```

Do not physically delete business data unless explicitly approved.

Soft-delete / archive entities:

- Workspace
- Board
- List
- Card
- Label

## 5. Append-Only Data Protection

Never physically delete or update append-only history (domain invariant 1).

Protected tables:

- ActivityEvent (append-only: no UPDATE, no DELETE — the audit trail)
- Comment (soft-delete only; referenced by activity)

Corrections happen through new events or status transitions, never by editing history.

## 6. EF Core Mapping Standard

Example:

```csharp
public sealed class BoardConfiguration : IEntityTypeConfiguration<Board>
{
    public void Configure(EntityTypeBuilder<Board> builder)
    {
        builder.ToTable("Board");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PublicId)
            .IsRequired();
        builder.HasIndex(x => x.PublicId)
            .IsUnique();

        builder.Property(x => x.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(x => x.IsDeleted)
            .HasDefaultValue(false);

        builder.Property(x => x.CreatedDate)
            .HasColumnType("datetime2")
            .IsRequired();

        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
```

## 7. Global Query Filter

Entities with soft delete should be filtered by default:

```csharp
builder.HasQueryFilter(x => !x.IsDeleted);
```

For restore flows (B-06, C-13) and admin/audit screens, use explicit methods that
intentionally include deleted records.

Do not casually use `IgnoreQueryFilters()`.

## 8. Delete Method Standard

Repositories/services must not call physical delete for business entities.

Preferred:

```csharp
public async Task SoftDeleteAsync(int id, string deletedBy, CancellationToken cancellationToken)
{
    var entity = await _dbContext.Set<TEntity>()
        .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    if (entity is null)
        return;

    entity.IsDeleted = true;
    entity.DeletedDate = DateTime.UtcNow;
    entity.DeletedBy = deletedBy;

    await _dbContext.SaveChangesAsync(cancellationToken);
}
```

## 9. Numeric Types

Use `decimal` for any money-like or precision-sensitive value; never float/double —
EXCEPT `Position`, whose sparse-rank type (float vs lexicographic string) is fixed once
in 001's `plan.md` (domain invariant 2) and applied uniformly after that.

## 10. Foreign Keys

Use integer foreign keys pointing at internal `Id`:

```csharp
public int BoardId { get; set; }
public Board Board { get; set; } = null!;
```

Do not use GUID foreign keys unless approved. FKs to soft-deleted master data use
restrict semantics, never cascade delete.

## 11. Indexing

Add indexes based on actual query patterns.

Recommended index candidates:

- Foreign keys
- `PublicId` (unique)
- `Position` within parent scope
- `DueAt`
- `Archived` / `IsDeleted`
- `CreatedDate`

Avoid over-indexing write-heavy tables (`Card`, `ActivityEvent`).

## 12. Migration Review

Before accepting a migration, review:

- Primary key type
- `PublicId` presence + unique index on API-exposed entities
- Foreign keys
- Nullability
- Decimal/position precision
- Soft-delete fields
- Audit fields
- Indexes
- Destructive operations
- Rollback safety

## 13. Destructive Changes

Do not drop tables or columns without explicit approval.

If a destructive migration is required:

1. Document why.
2. Document backup plan.
3. Document rollback plan.
4. Get approval before implementation.
