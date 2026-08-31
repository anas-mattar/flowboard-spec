# Research — 009 Card Attachments

No `[NEEDS CLARIFICATION]` markers remained in spec.md, so this phase resolves
implementation-level unknowns the spec deliberately left to `plan.md` (per its own
Assumptions section), not spec ambiguities.

## R-1: What "object storage" means at this stage of the project

**Decision**: Introduce an `IAttachmentStorage` abstraction (`Services/IAttachmentStorage.cs`)
with one implementation for now, `LocalDiskAttachmentStorage`, that writes each attachment's
bytes to a configured root directory outside `wwwroot`, keyed by a generated opaque filename
(never the caller-supplied original filename, to avoid path traversal/collision). The
`Attachment` database row stores the original filename, size, and content type as metadata
only — never the bytes (FR-002).

**Rationale**: Every other tier of this project (SQL Server via `(localdb)`, no cloud
account, no deployment target chosen yet — confirmed by `appsettings.json` carrying no cloud
config and `Flowboard.Api.csproj` referencing no cloud SDK) has been local-dev-only through
008. Introducing a real cloud object-store dependency (e.g. an Azure Blob Storage SDK
package) now would require plan-level approval for infrastructure that doesn't exist yet and
that no other feature has needed — a bigger decision than this thin v1.1 slice warrants.
`FUNCTIONAL_SPEC.md`'s own release-plan row ("File attachments to object storage") names the
architectural *category* (bytes live outside the relational database), not a vendor. The
interface boundary makes the eventual swap to a real cloud object store a change contained
entirely to one new class, with no change to the `Attachment` entity, the API contract, or
any calling code — satisfying the spirit of "object storage" now and the letter of it later.

**Alternatives considered**:
- Store file bytes in a SQL Server `VARBINARY(MAX)` column — rejected: spec's FR-002
  explicitly requires bytes not live in the database, and database-rules.md's read-path
  rules (no unnecessary data transfer) argue against loading large blobs through EF Core's
  change tracker on every card read.
- Add a real cloud object-store SDK now (Azure Blob Storage, being the natural fit next to
  SQL Server/ASP.NET Core/SignalR) — rejected for this slice: no Azure (or any cloud)
  account/config exists anywhere in the project yet; adding one is an infrastructure
  decision that deserves its own justification, not a rider on a UI feature. Nothing in this
  plan forecloses it — `IAttachmentStorage` is exactly the seam a future `AzureBlobAttachmentStorage`
  would implement.

## R-2: How attachment bytes cross the tRPC-only frontend boundary

**Decision**: Upload and download are the two operations that touch raw file bytes; both go
through dedicated Next.js Route Handlers (`app/api/attachments/route.ts` for upload,
`app/api/attachments/[attachmentPublicId]/route.ts` for download) rather than a tRPC
procedure. Both handlers call `getBackendSession()` (`lib/auth/session.ts`, the same accessor
the tRPC catch-all route already uses) to obtain the caller's backend token, then forward the
request to the backend using a new server-only client, `lib/api/attachments-client.ts`, built
in the same shape as `cards-client.ts`. Every other attachment operation (listing — folded
into the existing `cards.getDetail` payload — and removal) is an ordinary tRPC procedure,
exactly like every other card sub-resource.

**Rationale**: `frontend-rules.md`'s Data Flow rule ("ALL backend calls MUST go through tRPC
procedures... UI components MUST NOT call the backend directly") exists so there is one place
that owns base URL, auth, timeouts, and error mapping, and so the browser never holds the
backend token. A Route Handler that reads the session server-side and calls the backend with
that token preserves every one of those properties — the browser still only ever talks to
this project's own Next.js server, never to `flowboard-api` directly (unlike the realtime
token, which the browser DOES hold and use directly against the hub — 008's one sanctioned
BFF exception). What a Route Handler doesn't preserve is the *literal* tRPC transport, and
that's the actual constraint being worked around: tRPC's transport is JSON-RPC-shaped, and
neither multipart file upload nor a binary file download response fits it without a lossy
workaround (see the rejected base64 alternative below). This is a well-established pattern in
Next.js + tRPC applications generally, not a novel idea invented for this feature.

**Alternatives considered**:
- Base64-encode the file inside a normal tRPC JSON mutation input — rejected: a 25 MB file
  (this plan's FR-008 cap, from spec.md's Assumptions) becomes ~33 MB of JSON text, which
  both Next.js' request handling and the backend's JSON body parsing would need raised limits
  for, with no benefit over sending the bytes directly; pure overhead for no gain.
- Have the browser upload/download directly against `flowboard-api` (a second BFF exception
  alongside realtime, using a short-lived scoped token the way 008 does) — rejected: adds a
  second authentication mechanism and a second CORS surface for a feature that doesn't need
  one; the existing single-hop BFF proxy already satisfies every requirement in spec.md
  (FR-001, FR-004) without a new trust boundary. Revisit only if upload/download volume ever
  makes proxying through the Next.js server itself a bottleneck — no such requirement exists
  today (spec.md Success Criteria has no throughput target beyond SC-001's per-file latency).

## R-3: Backend upload endpoint shape

**Decision**: `POST /v1/cards/{cardPublicId}/attachments`, `Content-Type: multipart/form-data`,
one `IFormFile` field named `file`. `IFormFile`/`IFormFileCollection` binding ships in the
`Microsoft.NET.Sdk.Web` shared framework already targeted by `Flowboard.Api.csproj` (same
"no new package" situation as SignalR in 008/research.md R-1) — minimal APIs bind it via
`[FromForm] IFormFile file` on the handler, following the same thin-handler-calls-service
shape as every other endpoint in `CardsEndpoints.cs`.

**Rationale**: This is the first non-JSON request body in this API surface, but ASP.NET
Core's minimal APIs support it natively with no additional package — matching
`backend-rules.md`'s existing endpoint style (validate shape → call service → map result)
with the only difference being what "validate shape" checks (content type, size, filename)
before handing a stream to the service.

**Alternatives considered**: A raw `HttpContext`-reading handler bypassing typed binding —
rejected, no reason to abandon the existing typed-binding convention just because the type is
`IFormFile` instead of a JSON record.

## R-4: Enforcing the 25 MB cap and the blocked-extension list (spec.md Assumptions)

**Decision**: Enforce both at the API boundary, before any byte reaches `IAttachmentStorage`:
size via ASP.NET Core's per-endpoint request body size limit (`IHttpMaxRequestBodySizeFeature`,
no new package) returning a clean `413`-mapped validation failure through the existing
`Failure`/`ResultMapping` pattern; extension via a fixed deny-list constant
(`.exe`, `.bat`, `.sh`, `.cmd`, `.msi`, matching spec.md's Assumptions verbatim) checked
case-insensitively against the uploaded filename before the file is written anywhere. On the
frontend, the Route Handler performs the same two checks up front (from the `File`'s
`.size`/`.name` before the multipart body is even forwarded) purely as a fast, friendly
rejection — the backend check is the authoritative one (frontend-rules.md: "Frontend
permission/validation gating is UX only; the backend remains authoritative").

**Rationale**: Matches this codebase's existing validate-at-the-boundary convention (e.g.
`AddChecklistItemAsync`'s inline text-length check) rather than introducing a new
cross-cutting validation pipeline.

**Alternatives considered**: Content-sniffing/magic-byte validation or antivirus scanning —
explicitly out of scope per spec.md's Assumptions ("Files are not scanned for malware content
in this slice"); revisit only if `IAttachmentStorage`'s eventual cloud-backed implementation
offers scanning as a platform feature, which would be that implementation's concern, not this
plan's.

## R-5: Removal permission (uploader-or-admin) — a new authorization shape

**Decision**: A new check, `CanRemoveAttachment(BoardRole role, bool isUploader) => role ==
BoardRole.BoardAdmin || isUploader`, alongside (not replacing) the existing `CanMutate`
private helper in `CardService`. Upload uses the existing `CanMutate` (workspace admin/board
admin/board member — spec.md FR-001); removal uses this new, narrower check (spec.md FR-005).

**Rationale**: `BoardRole` (`Domain/Entities/BoardRole.cs`) already resolves workspace admins
to `BoardAdmin` for board-scoped operations (confirmed: `CanMutate` checks only `BoardAdmin`/
`BoardMember`, with no separate workspace-role branch anywhere in `CardService`), so "board
admin or workspace admin" from spec.md FR-005 is already just "`BoardRole.BoardAdmin`" at this
layer — no new role concept is introduced, only a new combination of the existing role check
with an ownership check.

**Alternatives considered**: Making every board member able to remove any attachment (i.e.
reusing `CanMutate` unchanged for removal too) — rejected, contradicts spec.md FR-006/US2
acceptance scenario 3 directly.

## R-8: Closing a real gap — the open card detail modal does not currently live-update

**Finding**: Inspecting `lib/realtime/use-board-realtime.ts` (008) shows its `BoardEvent`
handler invalidates only `boards.getContent` — never `cards.getDetail`. This is correct and
sufficient for everything 008 shipped (the board canvas), but it means a card detail modal
left open today does NOT live-update on another user's edit to that same card (checklist,
comments, labels — this gap already existed before this feature; it was simply never
exercised by a spec.md acceptance scenario until now). Spec.md's US3 acceptance scenario 3 and
FR-011 require the attachment list specifically to update live in an open card view, which
does not hold today without a change.

**Decision**: Extend `use-board-realtime.ts`'s existing `connection.on("BoardEvent", ...)`
handler to also call `utils.cards.getDetail.invalidate()` (no input filter — invalidates every
active `getDetail` query, i.e. whichever single card modal happens to be open on that board;
tRPC/React Query only refetches queries that are actually mounted, so this is a no-op when no
card modal is open). One line added to one existing file; no new hook, no new connection, no
change to `BoardRealtimeProvider`'s one-connection-per-board-page shape (research.md context:
`board-realtime-context.tsx`'s ADR already rejected a second hub connection just for a status
indicator — the same reasoning argues against a second connection here).

**Rationale**: Matches ADR-36's existing philosophy exactly (every `BoardEvent` is an
invalidate-and-refetch signal, never a payload-applied-to-cache signal) — this is applying
that same philosophy to a second query type, not inventing a new one. Scoped narrowly: this
plan does not attempt to fix every other card-detail field's live-update gap as a side effect,
it only makes the one behavior spec.md's US3 actually requires true.

**Alternatives considered**: A second, card-scoped hub subscription opened by the modal itself
— rejected, adds a second connection per 008's own established reasoning against exactly that
shape. Leaving the gap and scoping FR-011/US3's acceptance scenario 3 down to "canvas-only" —
rejected, spec.md is explicit that the attachment list itself (which only renders inside the
modal, never on the card front) must update live; scoping it down would silently fail to
deliver what was specified rather than making a small, justified fix.

## R-6: Activity and realtime plumbing — reuse, not new infrastructure

**Decision**: Add two constants to `Domain/ActivityEventType.cs` (`AttachmentAdded =
"attachment.added"`, `AttachmentRemoved = "attachment.removed"`); no change to
`Domain/RealtimeEventType.cs`. Both new service methods call the existing private
`NewEvent(...)` and `PublishActivityEventAsync(...)` helpers already used by every other
card-scoped mutation.

**Rationale**: `RealtimeEventType.cs`'s own header comment states card-scoped broadcasts reuse
`ActivityEventType` verbatim from the just-persisted `ActivityEvent` row (008's ADR-35,
invariant 1) — attachments are card-scoped, so this feature needs zero new realtime
infrastructure. This is the mechanism spec.md's US3/FR-010/FR-011 describe, already built and
merged; this feature is a pure consumer of it, exactly as 008 anticipated ("every mutating
service method gains one inline broadcast call").

## R-7: `Attachment` needs a `PublicId`

**Decision**: `Attachment` gets `PublicId GUID NOT NULL UNIQUE`, like `ChecklistItem`, unlike
`Comment`.

**Rationale**: `Comment.cs`'s own header comment explains it has no `PublicId` because it is
"not exposed individually by this feature's API." Attachments are the opposite: FR-004/FR-005
require addressing one specific attachment for download and removal, exactly the reason
`ChecklistItem` (individually toggled/deleted) carries a `PublicId` while `Comment`
(append-only, never addressed individually) does not. Constitution V/invariant 8 require the
API to address it by `PublicId`, never the internal `Id`.
