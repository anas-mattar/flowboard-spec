# Backend Examples

## Minimal-API Endpoint Group

One static class per bounded context in the API project's endpoint folder. The group
requires authentication; each write declares its permission policy. Handlers are thin:
validate shape, call the application service, map `Result<T>` to HTTP via the shared
`ToHttpResult()`.

```csharp
public static class CardEndpoints
{
    private const string EditPolicy = "perm:board.edit_cards";

    public static IEndpointRouteBuilder MapCardEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/v1/cards")
            .WithTags("Cards")
            .RequireAuthorization();

        group.MapGet("/{publicId:guid}", GetDetailAsync);
        group.MapPatch("/{publicId:guid}", UpdateAsync).RequireAuthorization(EditPolicy);
        group.MapDelete("/{publicId:guid}", ArchiveAsync).RequireAuthorization(EditPolicy);

        return endpoints;
    }

    private static async Task<IResult> GetDetailAsync(
        Guid publicId, ICardReadService reads, CancellationToken cancellationToken)
    {
        var dto = await reads.GetDetailAsync(publicId, cancellationToken);

        if (dto is null)
            return Results.NotFound(new { message = "Card not found" });

        return Results.Ok(dto);
    }

    private static async Task<IResult> UpdateAsync(
        Guid publicId,
        UpdateCardRequest request,
        HttpContext http,
        ICardWriteService writes,
        CancellationToken cancellationToken)
    {
        // If-Match precondition per spec §7.1 — stale version returns 409.
        var etag = http.Request.Headers.IfMatch.ToString();
        var result = await writes.UpdateAsync(publicId, request, etag, cancellationToken);
        return result.ToHttpResult();
    }

    private static async Task<IResult> ArchiveAsync(
        Guid publicId, ICardWriteService writes, CancellationToken cancellationToken)
    {
        var result = await writes.ArchiveAsync(publicId, cancellationToken);
        return result.ToHttpResult();
    }
}
```

Register the group in the composition root:

```csharp
app.MapCardEndpoints();
```

`ToHttpResult()` lives beside the endpoint groups (one shared `ResultMapping.cs`) and
maps uniformly: Success → 200, ValidationFailed → 400 ProblemDetails, NotFound → 404,
Forbidden → 403, Conflict → 409, Unavailable → 503.

## EF Core Read Query

```csharp
public async Task<CardDetailDto?> GetDtoByPublicIdAsync(Guid publicId)
{
    return await _context.Cards
        .AsNoTracking()
        .Where(x => x.PublicId == publicId)
        .Select(x => new CardDetailDto
        {
            PublicId = x.PublicId,
            Title = x.Title,
            Description = x.Description,
            DueAt = x.DueAt,
            CreatedDate = x.CreatedDate
        })
        .FirstOrDefaultAsync();
}
```

## Paginated List

```csharp
public async Task<PagedResult<ActivityEventDto>> ListActivityAsync(
    Guid cardPublicId, ActivityListParameters parameters)
{
    var query = _context.ActivityEvents
        .AsNoTracking()
        .Where(x => x.Card.PublicId == cardPublicId);

    var total = await query.CountAsync();

    var items = await query
        .OrderByDescending(x => x.CreatedDate)
        .Skip(parameters.Skip)
        .Take(parameters.Take)
        .Select(x => new ActivityEventDto
        {
            Type = x.Type,
            Payload = x.Payload,
            CreatedDate = x.CreatedDate
        })
        .ToListAsync();

    return new PagedResult<ActivityEventDto>(items, total);
}
```

## Concurrency-Safe Update (spec §7.1)

```csharp
public async Task<Result<CardDetailDto>> UpdateAsync(
    Guid publicId, UpdateCardRequest request, string etag, CancellationToken cancellationToken)
{
    var card = await _context.Cards
        .FirstOrDefaultAsync(x => x.PublicId == publicId, cancellationToken);

    if (card is null)
        return Result<CardDetailDto>.NotFound();

    if (!EtagMatches(card.RowVersion, etag))
        return Result<CardDetailDto>.Conflict("Card was modified by someone else.");

    // apply changes, write ActivityEvent, save — broadcast AFTER commit
    ...
}
```
