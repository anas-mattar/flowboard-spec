# Backend Examples

## Minimal-API Endpoint Group

One static class per bounded context in `FMS.Api/Endpoints/`. The group requires authentication; each write declares its permission policy. Handlers are thin: validate shape, call the application service, map `Result<T>` to HTTP via the shared `ToHttpResult()`.

```csharp
public static class PurchaseOrderEndpoints
{
    private const string AddPolicy = "perm:purchasing.add_po";

    public static IEndpointRouteBuilder MapFmsPurchaseOrderEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/purchase-orders")
            .WithTags("PurchaseOrders")
            .RequireAuthorization();

        group.MapGet("/", GetListAsync);
        group.MapGet("/{id:int}", GetDetailAsync);
        group.MapPost("/", CreateAsync).RequireAuthorization(AddPolicy);

        return endpoints;
    }

    private static async Task<IResult> GetDetailAsync(
        int id, IPurchaseOrderReadService reads, CancellationToken cancellationToken)
    {
        var dto = await reads.GetDetailAsync(id, cancellationToken);

        if (dto is null)
            return Results.NotFound(new { message = "Purchase Order not found" });

        return Results.Ok(dto);
    }

    private static async Task<IResult> CreateAsync(
        CreatePurchaseOrderRequest request,
        IPurchaseOrderWriteService writes,
        CancellationToken cancellationToken)
    {
        var result = await writes.CreateAsync(request, cancellationToken);
        return result.ToHttpResult();
    }
}
```

Register the group in the composition root:

```csharp
app.MapFmsPurchaseOrderEndpoints();
```

`ToHttpResult()` lives in `FMS.Api/Endpoints/ResultMapping.cs` and maps uniformly: Success → 200, ValidationFailed → 400 ProblemDetails, NotFound → 404, Forbidden → 403, Conflict → 409, Unavailable → 503.

## EF Core Read Query

```csharp
public async Task<PurchaseOrderDto?> GetDtoByIdAsync(int id)
{
    return await _context.PurchaseOrders
        .AsNoTracking()
        .Where(x => x.Id == id)
        .Select(x => new PurchaseOrderDto
        {
            Id = x.Id,
            Code = x.Code,
            Status = x.Status,
            CreatedDate = x.CreatedDate
        })
        .FirstOrDefaultAsync();
}
```

## Paginated List

```csharp
public async Task<PagedResult<PurchaseOrderListItemDto>> ListAsync(
    ListParameters<PurchaseOrderParameters, PurchaseOrderFilters> parameters)
{
    var query = _context.PurchaseOrders.AsNoTracking();

    if (!string.IsNullOrWhiteSpace(parameters.Filters.Status))
        query = query.Where(x => x.Status == parameters.Filters.Status);

    var total = await query.CountAsync();

    var items = await query
        .OrderByDescending(x => x.CreatedDate)
        .Skip(parameters.Skip)
        .Take(parameters.Take)
        .Select(x => new PurchaseOrderListItemDto
        {
            Id = x.Id,
            Code = x.Code,
            Status = x.Status
        })
        .ToListAsync();

    return new PagedResult<PurchaseOrderListItemDto>(items, total);
}
```

## External Service Pattern

```csharp
public sealed class WmsService : IWmsService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<WmsService> _logger;

    public WmsService(HttpClient httpClient, ILogger<WmsService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<WmsResponse?> PushAsync(WmsRequest request)
    {
        try
        {
            var response = await _httpClient.PostAsJsonAsync("api/orders", request);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<WmsResponse>();
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "WMS push failed for {Reference}", request.Reference);
            throw;
        }
    }
}
```
