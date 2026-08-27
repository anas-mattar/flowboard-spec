# Backend Performance Rules

## Purpose

This file defines mandatory backend performance rules for FlowBoard.

FlowBoard's core interaction is a live board: hydration must complete in < 1.5 s for a
board with 20 lists / 1,000 cards, and realtime changes must propagate in < 500 ms p95
(spec §8). Slow queries and uncontrolled work inside request paths directly break those
budgets.

## 1. General Principles

- Measure before optimizing.
- Do not guess performance fixes.
- Keep queries bounded.
- Prefer database-side filtering, sorting, and aggregation.
- Avoid loading large object graphs.
- Keep transaction scopes short.
- Do not block request threads.
- Move slow work to background jobs when needed (e.g. position re-balancing —
  domain invariant 2).

## 2. EF Core Query Rules

### Read-Only Queries

Use `AsNoTracking()` for read-only queries.

```csharp
var cards = await _dbContext.Cards
    .AsNoTracking()
    .Where(x => x.ListId == listId)
    .ToListAsync(cancellationToken);
```

### Projection

Use `.Select()` to fetch only required fields.

Do not load full entities for list screens or the board hydration call.

Good:

```csharp
var items = await _dbContext.Cards
    .AsNoTracking()
    .Where(x => x.List.BoardId == boardId)
    .Select(x => new CardSummaryDto
    {
        PublicId = x.PublicId,
        Title = x.Title,
        Position = x.Position,
        DueAt = x.DueAt
    })
    .ToListAsync(cancellationToken);
```

Bad:

```csharp
var items = await _dbContext.Cards.ToListAsync();
```

### Server-Side Paging

All list endpoints must page server-side (spec §7: cursor-paginated).

Never load all records and paginate in memory.

### Filtering and Sorting

Filtering and sorting must happen in SQL where possible — including board search
(`/v1/boards/{id}/search`, spec §7).

Do not do this:

```csharp
var all = await query.ToListAsync();
var filtered = all.Where(x => x.Archived == false).ToList();
```

### Includes

Use `Include()` only when required.

For multiple includes, consider `AsSplitQuery()` — the board hydration call
(board → lists → cards → labels/members/badge counts) is the primary candidate.

```csharp
var board = await _dbContext.Boards
    .Include(x => x.Lists)
    .ThenInclude(x => x.Cards)
    .AsSplitQuery()
    .AsNoTracking()
    .FirstOrDefaultAsync(x => x.PublicId == publicId, cancellationToken);
```

### N+1 Prevention

Do not access navigation properties in loops unless data was explicitly loaded.

Bad:

```csharp
foreach (var list in lists)
{
    var cards = list.Cards;
}
```

Good:

```csharp
var lists = await _dbContext.Lists
    .Include(x => x.Cards)
    .AsNoTracking()
    .ToListAsync(cancellationToken);
```

## 3. Index Review

Any new query used by board hydration, list rendering, search, filtering, the activity
feed, or membership checks must include index review.

Common index candidates:

- Foreign keys (`BoardId`, `ListId`, `CardId`, `UserId`)
- `PublicId`
- `Position` (within its parent scope)
- `DueAt`
- `Archived` / `IsDeleted`
- `CreatedDate`

Do not over-index write-heavy tables (`Card`, `ActivityEvent`).

## 4. Board Hydration Performance

`GET /v1/boards/{id}` returns the board with lists and cards in a single hydration call
(spec §7) inside the 1.5 s budget:

- Use projection — card fronts need summaries plus badge counts, not full entities.
- Compute badge counts (checklist done/total, comment count) with grouped SQL, never
  per-card round trips.
- Never compromise correctness for speed.

## 5. Transaction Performance

Keep transactions short.

Do not perform slow external calls or SignalR broadcasts inside a database transaction —
broadcast after `SaveChangesAsync()` succeeds (backend rulebook, Realtime).

Bad:

```text
Begin transaction
  Save move
  Broadcast to board channel
Commit
```

Better:

```text
Save move
Commit
Broadcast to board channel
```

## 6. Background Work

Use background jobs/queues for position re-balancing (invariant 2), bulk archival,
data-export requests (spec §8), and any future notification fan-out. Do not block user
requests for work the response does not need.

## 7. Caching

Use caching only when justified.

Good candidates:

- static reference data (label color palette)
- permission lookups with short TTL

Do not cache:

- board/list/card state without a realtime-invalidation strategy (open clients
  converge via the WebSocket channel — a stale server cache breaks that)
- sensitive user data

Every cache must define key, TTL, invalidation rule, and data sensitivity.

## 8. Bulk Operations

Bulk actions (archive all cards in a list — L-06, future imports) should:

- validate before writing
- process in batches
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
- [ ] Are transactions short, with broadcasts after commit?
- [ ] Is caching justified and documented?
- [ ] Are heavy operations moved to background jobs when needed?
