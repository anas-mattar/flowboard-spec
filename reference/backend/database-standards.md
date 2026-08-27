# Database Standards

## Purpose

This file defines mandatory database standards for FMS backend development.

These rules apply to all database design, EF Core entities, migrations, and database reviews.

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

### Allowed GUID Usage

GUIDs are allowed only as non-primary reference fields:

```text
PublicId
CorrelationId
ExternalReferenceId
IdempotencyKey
IntegrationReference
WebhookEventId
```

Example:

```sql
Id INT IDENTITY(1,1) PRIMARY KEY,
PublicId UNIQUEIDENTIFIER NOT NULL UNIQUE
```

The `Id` remains the database primary key.
The `PublicId` may be exposed to external systems or public APIs.

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

`RowVersion` is recommended for edit-prone master data and approval workflows.

## 3. Audit Fields

Required for business tables:

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
INTEGRATION
MIGRATION
```

## 4. Soft Delete

Business entities must use soft delete.

Soft delete means:

```text
IsDeleted = true
DeletedDate = current UTC date/time
DeletedBy = current user/system
```

Do not physically delete business data unless explicitly approved.

Examples of soft-delete entities:

- Customer
- Vendor
- Account
- CostCenter
- Department
- LegalEntity
- FiscalPeriod
- Budget
- BankAccount
- TaxCode
- ExchangeRate source configuration

## 5. Finance Transaction Protection

Never physically delete financial transaction data.

Protected tables include:

- Journal
- JournalLine
- GeneralLedgerEntry
- CustomerInvoice
- VendorInvoice
- Payment
- Receipt
- Allocation
- BankReconciliation
- FXRevaluation
- ConsolidationPosting
- PeriodCloseRun
- ControlLog

Corrections must use:

- Reversal
- Void
- Cancel
- Status transition
- Adjustment posting

## 6. EF Core Mapping Standard

Example:

```csharp
public sealed class AccountConfiguration : IEntityTypeConfiguration<Account>
{
    public void Configure(EntityTypeBuilder<Account> builder)
    {
        builder.ToTable("Account");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .ValueGeneratedOnAdd();

        builder.Property(x => x.AccountCode)
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(x => x.AccountName)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(x => x.IsDeleted)
            .HasDefaultValue(false);

        builder.Property(x => x.CreatedDate)
            .HasColumnType("datetime2")
            .IsRequired();

        builder.Property(x => x.RowVersion)
            .IsRowVersion();

        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
```

## 7. Global Query Filter

Entities with soft delete should be filtered by default:

```csharp
builder.HasQueryFilter(x => !x.IsDeleted);
```

For admin/audit screens, use explicit methods that intentionally include deleted records.

Do not casually use `IgnoreQueryFilters()`.

## 8. Delete Method Standard

Repositories/services should not call physical delete for business entities.

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

## 9. Money and Decimal

Finance amounts must use `decimal`.

Recommended SQL type:

```sql
DECIMAL(23,6)
```

Do not use:

```text
float
double
SQL money
```

## 10. Foreign Keys

Use integer foreign keys:

```csharp
public int AccountId { get; set; }
public Account Account { get; set; } = null!;
```

Do not use GUID foreign keys unless approved.

## 11. Indexing

Add indexes based on actual query patterns.

Recommended index candidates:

- Foreign keys
- EntityCode
- PeriodId
- JournalDate
- Status
- SourceSystem
- SourceReference
- IsDeleted
- CreatedDate

Avoid over-indexing write-heavy tables.

## 12. Migration Review

Before accepting a migration, review:

- Primary key type
- Foreign keys
- Nullability
- Decimal precision
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
