# Data Model — 007 Search & Filter

No new entity, table, or migration. This feature reads fields the existing schema already
carries and holds one small piece of transient, client-only view state.

## Existing entities read (unchanged shape, one additive DTO field)

| Entity | Field | Notes |
|---|---|---|
| `Card` | `Title` | Existing (004). Read path: search text matching (FR-001). |
| `Card` | `Description` | Existing (004) — already selected from the database by `GetBoardContentAsync` today (`BoardContentService.cs:157`), but not yet forwarded into `CardSummaryDto`. **Addendum** (research.md R-2): forward it as a new `Description` (nullable string) field on `CardSummaryDto`/`CardSummary`, alongside the existing `HasDescription` boolean (kept as-is — 004's card-front badge still reads only the boolean). No new query, no new endpoint. |
| `Card` | `DueAt` | Existing (004). Read path: "Next 7 days" bucket window check (research.md R-3) and search-irrelevant. |
| `Card` | `DueStatus` (computed, `CardDueStatus.Compute`) | Existing (004). Read path: "Overdue"/"No due date" buckets reuse it directly (`dueStatus === "overdue"`, `dueAt === null`) — no new computation. |
| `Card` → `CardLabels` → `Label` | `PublicId`, `Name`, `Color` | Existing (004), already returned as `CardSummaryDto.Labels`. Read path: label filter (OR within category). |
| `Card` → `CardMembers` → `User` | `PublicId`, `DisplayName`, `Initials`, `AvatarColor` | Existing (004), already returned as `CardSummaryDto.Members`. Read path: member filter (OR within category). |

## Response DTO addendum

`CardSummaryDto` (backend, `Services/BoardContentService.cs`) gains one field:

```csharp
public sealed record CardSummaryDto(
    Guid PublicId,
    string Title,
    DateTime? DueAt,
    string? DueStatus,
    bool HasDescription,
    string? Description,   // NEW — full text, research.md R-2
    int? ChecklistDone,
    int? ChecklistTotal,
    int CommentCount,
    IReadOnlyList<LabelSummaryDto> Labels,
    IReadOnlyList<MemberUserDto> Members);
```

Mirrored on the frontend as `CardSummary.description: string | null`
(`lib/api/boards-client.ts`). This is additive to 003's existing response shape — same
convention 006 already used adding `RowVersion` to `BoardContentDto`/`ListContentDto` — and
does not change `contracts/board-content-api.md`'s endpoint, method, or status codes; see
`contracts/search-filter-addendum.md` for the full before/after response shape.

## Transient client state (not persisted, not an entity)

| Field | Type | Notes |
|---|---|---|
| `text` | `string` | Live search text. Reset on board switch (FR-009). |
| `labelIds` | `string[]` (label `publicId`s) | OR within category. |
| `memberIds` | `string[]` (member `publicId`s) | OR within category. |
| `due` | `"overdue" \| "week" \| "none" \| ""` | At most one active; `""` = no due-date filter. |

Held in `BoardFilterProvider` (research.md R-4), scoped to one board's page tree, never
sent to the backend, never written to any store.
