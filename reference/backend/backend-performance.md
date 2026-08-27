# Backend Performance Rules

## Purpose

This file defines mandatory backend performance rules for FMS.

FMS is a finance system. Slow queries, uncontrolled external calls, and inefficient report generation can directly affect month-end closing, posting reliability, and user trust.

## 1. General Principles

- Measure before optimizing.
- Do not guess performance fixes.
- Keep queries bounded.
- Prefer database-side filtering, sorting, and aggregation.
- Avoid loading large object graphs.
- Keep transaction scopes short.
- Do not block request threads.
- Move slow work to background jobs when needed.

## 2. EF Core Query Rules

### Read-Only Queries

Use `AsNoTracking()` for read-only queries.

```csharp
var journals = await _dbContext.Journals
    .AsNoTracking()
    .Where(x => x.EntityCode == entityCode)
    .ToListAsync(cancellationToken);
```

### Projection

Use `.Select()` to fetch only required fields.

Do not load full entities for list screens or reports.

Good:

```csharp
var items = await _dbContext.Journals
    .AsNoTracking()
    .Where(x => x.PeriodId == periodId)
    .Select(x => new JournalListItemDto
    {
        Id = x.Id,
        JournalDate = x.JournalDate,
        Source = x.Source,
        Status = x.Status
    })
    .ToListAsync(cancellationToken);
```

Bad:

```csharp
var items = await _dbContext.Journals.ToListAsync();
```

### Server-Side Paging

All list endpoints must use server-side paging.

```csharp
var total = await query.CountAsync(cancellationToken);

var items = await query
    .Skip((page - 1) * pageSize)
    .Take(pageSize)
    .ToListAsync(cancellationToken);
```

Never load all records and paginate in memory.

### Filtering and Sorting

Filtering and sorting must happen in SQL where possible.

Do not do this:

```csharp
var all = await query.ToListAsync();
var filtered = all.Where(x => x.Status == status).ToList();
```

### Includes

Use `Include()` only when required.

For multiple includes, consider `AsSplitQuery()`.

```csharp
var journal = await _dbContext.Journals
    .Include(x => x.Lines)
    .AsSplitQuery()
    .AsNoTracking()
    .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);
```

### N+1 Prevention

Do not access navigation properties in loops unless data was explicitly loaded.

Bad:

```csharp
foreach (var journal in journals)
{
    var lines = journal.Lines;
}
```

Good:

```csharp
var journals = await _dbContext.Journals
    .Include(x => x.Lines)
    .AsNoTracking()
    .ToListAsync(cancellationToken);
```

## 3. Index Review

Any new query used by list pages, reports, posting validation, reconciliation, external API lookups, or period closing must include index review.

Common index candidates:

- EntityCode
- PeriodId
- JournalDate
- Status
- SourceSystem
- SourceReference
- AccountId
- CustomerId
- VendorId
- IsDeleted
- CreatedDate

Do not over-index write-heavy tables.

## 4. Report Performance

Financial reports must read from posted ledger data efficiently.

For heavy reports:

- Use projection.
- Use grouped SQL queries.
- Avoid per-row calculations in C# when SQL can aggregate.
- Consider materialized summary tables only when approved in `plan.md`.
- Never compromise correctness for speed.

## 5. Transaction Performance

Keep transactions short.

Do not perform slow external API calls inside a database transaction.

Bad:

```text
Begin transaction
  Save local data
  Call external API
  Save response
Commit
```

Better:

```text
Save pending record
Commit
Call external API
Save result/status
```

For financial posting that must be atomic, keep only database work inside the transaction.

## 6. External API Performance

External calls must have:

- timeout
- retry limit
- correlation ID
- logging
- controlled failure path

Do not block user requests for long-running provider calls when async processing is acceptable.

Use background jobs/queues for bulk posting, slow provider submissions, document processing, large imports, and reconciliation syncs.

## 7. Caching

Use caching only when justified.

Good candidates:

- static reference data
- exchange rate provider metadata
- country/entity lists
- permission lookups with short TTL

Do not cache:

- posted journal results without invalidation strategy
- sensitive user data
- frequently changing balances without clear rules

Every cache must define key, TTL, invalidation rule, and data sensitivity.

## 8. Bulk Operations

Bulk imports and posting should:

- validate before writing
- process in batches
- log batch status
- avoid one SaveChanges per row
- avoid huge transactions
- provide progress/status when user-facing

## 9. Async Rules

- Use async/await for I/O.
- Pass `CancellationToken`.
- Do not use `.Result`.
- Do not use `.Wait()`.
- Do not use `Thread.Sleep()`.

## 10. Performance Review Checklist

Before completing a backend phase, check:

- [ ] Are list endpoints paginated?
- [ ] Are read queries `AsNoTracking()`?
- [ ] Are DTO projections used?
- [ ] Are filters applied before `ToListAsync()`?
- [ ] Are N+1 queries avoided?
- [ ] Are indexes considered?
- [ ] Are transactions short?
- [ ] Are external API calls timed out?
- [ ] Is caching justified and documented?
- [ ] Are heavy operations moved to background jobs when needed?
