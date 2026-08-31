# Implementation Plan: Card Attachments

**Branch**: `009-card-attachments` | **Date**: 2026-08-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-card-attachments/spec.md`

## Summary

Add file attachments to cards: a new `Attachment` entity (metadata only — bytes never touch
SQL Server) behind a new `IAttachmentStorage` abstraction backed by local disk for now
(research.md R-1); a multipart upload endpoint and a streaming download endpoint on the
backend (research.md R-3); two dedicated Next.js Route Handlers on the frontend for the two
operations that carry raw bytes, since tRPC's JSON transport can't (research.md R-2), while
listing (folded into the existing card detail payload) and removal stay ordinary tRPC
procedures; and a new attachments panel in the card detail modal following the existing
labels/members/checklist panels' visual pattern (no prototype reference exists — spec.md
FR-013). Activity logging and realtime propagation need no new infrastructure — attachment
add/remove events reuse the existing card-scoped `ActivityEvent`/`PublishActivityEventAsync`
path exactly as checklist/comment events already do (research.md R-6, 008's ADR-35).

## Technical Context

**Language/Version**: C# / .NET 10 (backend, unchanged); TypeScript / Next.js 16 App Router
(frontend, unchanged)

**Primary Dependencies**:
- Backend: **no new NuGet package** — `IFormFile`/multipart binding and
  `IHttpMaxRequestBodySizeFeature` ship inside the `Microsoft.NET.Sdk.Web` shared framework
  `Flowboard.Api` already targets (research.md R-3/R-4).
- Frontend: **no new npm package** — upload/download use the platform `fetch`/`FormData`/
  `Response` APIs already available in Next.js Route Handlers (research.md R-2). UI reuses
  existing shadcn/ui primitives and Sonner (toasts), matching every other card-detail panel.

**Storage**: SQL Server — **one additive migration**, `AddCardAttachments` (data-model.md):
new `Attachment` table (metadata only), no change to any existing table/column. File bytes
live on local disk via the new `IAttachmentStorage`/`LocalDiskAttachmentStorage` abstraction
(research.md R-1) — NOT a new persistence *technology* in the constitution IV sense so much as
a new persistence *location* for non-relational data, approved here per that same principle
("new persistence approaches MUST NOT be introduced unless explicitly approved in the
technical plan" — see Constitution Check, Architecture Consistency below).

**Testing**: `dotnet test` — integration tests via `WebApplicationFactory` against the
disposable `flowboard-db-test` database (existing pattern) covering: upload succeeds for
board admin/member, fails (`403`) for Observer, fails (`404`) for a non-member, fails (`400`)
for a blocked extension, fails (`413`) for an oversized file; download succeeds for every role
including Observer, fails (`404`) after removal; removal succeeds for the uploader and for a
board admin, fails (`403`) for a non-uploading board member and for Observer; one test
confirming the activity feed gets exactly one `attachment.added`/`attachment.removed` entry
per action with the correct payload shape. Frontend: no test runner exists yet (003/008
precedent) — verified via `quickstart.md`'s manual walkthrough.

**Target Platform**: Web (existing Next.js/ASP.NET Core stack, unchanged). Uploads/downloads
are proxied through the existing single-hop BFF (browser → Next.js Route Handler →
`flowboard-api`), not a second direct-to-backend exception (research.md R-2).

**Project Type**: Web application (existing `flowboard-api` + `flowboard-web`, unchanged)

**Performance Goals**: Attach-and-see-listed in <10s for a file at the 25 MB cap on standard
broadband (SC-001); removal invisible to all viewers within 2s (SC-002); live propagation to a
second viewer within the existing <500ms p95 bound for the metadata event itself (SC-004,
FUNCTIONAL_SPEC.md §8) — the bound applies to the small `ActivityEvent` broadcast, not to a
second viewer's file transfer time were they to also download it.

**Constraints**: Upload capped at 25 MB per file (spec.md Assumptions); blocked extensions
`.exe`/`.bat`/`.sh`/`.cmd`/`.msi` (spec.md Assumptions); no malware/content scanning in this
slice (spec.md Assumptions, research.md R-4); no thumbnail/preview generation (spec.md
Assumptions) — every attachment renders as a generic file row; no hard cap on attachment count
per card (spec.md Assumptions) — the list scrolls within the modal.

**Scale/Scope**: Backend: one new entity (`Attachment`) + configuration + migration, one new
`Services/IAttachmentStorage.cs` + `LocalDiskAttachmentStorage.cs`, three new/extended
`CardService` methods (`AddAttachmentAsync`, `GetAttachmentContentAsync`,
`RemoveAttachmentAsync`), one new `Endpoints/AttachmentsEndpoints.cs`, two new
`ActivityEventType` constants, one extended `CardDetailDto`. Frontend: one new
`components/board/card-detail/card-attachments-panel.tsx`, one new
`lib/api/attachments-client.ts`, two new Route Handlers (`app/api/attachments/route.ts`,
`app/api/attachments/[attachmentPublicId]/route.ts`), one new tRPC procedure
(`cards.removeAttachment`) plus its Zod schema, `CardDetail`'s type extended with
`attachments`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Specification First (I)**: spec.md written and validated (checklist all-PASS, no
  `NEEDS CLARIFICATION` markers); this plan.md follows before any code; tasks.md follows
  this plan before implementation.
- [x] **Source of Truth (II)**: No screenshots exist for this feature (spec.md's Visual
  Inventory section was omitted per the template's own instruction). No conflict found
  between `FUNCTIONAL_SPEC.md` §5/§6/§10, `docs/domain/flowboard-invariants.md`, and the
  rulebooks — all agree on the same shape (metadata in SQL Server, bytes elsewhere, existing
  permission matrix, existing activity/realtime path). FR-013 requires the new UI to follow
  the existing card-detail-modal panels' visual language exactly because no visual reference
  exists for a new one, satisfying "never invent a new UI layout when visual references
  exist" by extension (the surrounding modal IS the reference).
- [x] **Repository Separation (III)**: `flowboard-api` (entity, storage abstraction,
  endpoints, service methods) and `flowboard-web` (panel, client, Route Handlers, tRPC
  procedure) stay separate; no mixing.
- [x] **Architecture Consistency (IV)**: New patterns introduced and approved here: (1) the
  first non-JSON (`multipart/form-data`) request body in the backend API surface —
  research.md R-3, using ASP.NET Core's built-in `IFormFile` binding, no new package,
  handler shape otherwise unchanged; (2) a new persistence *location* for file bytes
  (`IAttachmentStorage`, local-disk-backed for now) — research.md R-1, explicitly scoped as
  an interim, swappable implementation rather than a new external dependency; (3) two Next.js
  Route Handlers as the sanctioned path for the two byte-carrying operations, alongside
  (not replacing) tRPC for everything else — research.md R-2, justified against
  frontend-rules.md's Data Flow rule by name. No new UI library, no new state-management
  approach, no new backend layering pattern (endpoint → service, same as every prior
  feature).
- [x] **Data Standards (V)**: `Attachment.Id` is `INT IDENTITY(1,1)`; `Attachment.PublicId` is
  the only identifier the API exposes for it (invariant 8, research.md R-7, data-model.md).
- [x] **Auditability (VI)**: `Attachment` carries `CreatedDate`/`CreatedBy` (constitution VI).
  No `UpdatedDate`/`UpdatedBy` or soft-delete fields — justified in data-model.md (an
  attachment is never edited, and removal must make it disappear per FR-007, matching the
  existing `ChecklistItem`/`Comment` precedent of card sub-resources with no soft-delete
  fields of their own; the append-only record that it existed and was removed lives in
  `ActivityEvent`, satisfying constitution VI's audit intent through the same mechanism the
  rest of the domain already uses).
- [x] **Domain Invariants (VII)**: See Domain Invariant Pass below.
- [x] **Security (VIII)**: Upload/download/removal all `RequireAuthorization()` (existing
  pattern); every operation re-resolves the caller's board role server-side (invariant 5,
  research.md R-5) rather than trusting anything client-supplied. No secret is added. No
  sensitive data is logged — filenames/sizes are the same class of data the activity feed and
  card detail already expose to the same authorized audience. Upload is bounded (size cap,
  extension deny-list, research.md R-4) as a basic hardening measure; full malware scanning
  is explicitly out of scope (spec.md Assumptions) — an accepted, documented residual risk
  for this slice, not a silent gap.
- [ ] **External Integration Governance (IX)**: N/A — no external (third-party/SaaS)
  integration is added; local-disk storage is this project's own backend writing to its own
  filesystem, not a third-party API call.
- [x] **Performance Responsibility (X)**: Attachment listing rides along on the existing
  `GetCardDetailAsync` query (one more `AsNoTracking()`/`.Select()` projection, same pattern
  as labels/members/checklist items) — no new round trip to load a card's attachments.
  Download streams the file rather than buffering it fully in memory. No N+1: the attachments
  projection is a single query keyed on `CardId`, same shape as the three sibling
  projections beside it.
- [x] **Testing Requirements (XI)**: See Technical Context's Testing entry — permission
  matrix (upload/download/removal × role × ownership) and the size/extension rejection paths
  are business-critical (they ARE most of this feature's actual logic) and get automated
  integration coverage.
- [x] **Human Review (XII)**: Same phased AI-then-human review as 001–008.
- [x] **Controlled Delivery (XIII)**: Backend phase (entity, storage, endpoints, service
  methods) implemented and gated before frontend, per `docs/sdlc/repository-strategy.md`'s
  cross-repository rule — same sequencing as every prior feature. Within backend, and per
  spec.md's own story priorities, implementation proceeds US1 → US2 → US3, each gated before
  the next (`docs/sdlc/definition-of-done.md`).

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`). Not Critical: this
feature touches invariants 1 (append-only activity), 5 (server-side permissions), and 8
(opaque public IDs) in the same way 004/005/006/007 already did without being declared
Critical — it introduces no new authentication mechanism (unlike 008, which minted a new kind
of token), no irreversible/destructive migration (purely additive, trivially reversible by
dropping the new table), and touches no payment or regulated-data flow. No `rollback.md` is
required; the migration's reversibility is recorded directly in data-model.md.

### Domain Invariant Pass

- **Invariant 1 (Activity Is Append-Only)**: This feature only ever inserts `ActivityEvent`
  rows (`attachment.added`, `attachment.removed`) — never updates or deletes one. Removing an
  attachment does not touch the `attachment.added` event already recorded for it; history of
  a since-removed attachment remains intact, exactly like a deleted `ChecklistItem`'s history.
- **Invariant 2 (Ordering Integrity)**: Untouched — attachments carry no position/ordering
  concept.
- **Invariant 4 (Archive Restorability)**: Attachments remain associated with a card through
  archive/restore via the `HasQueryFilter(x => !x.Card.IsDeleted)` pattern (data-model.md) —
  the row is neither deleted nor hidden independently of its card's own soft-delete state.
- **Invariant 5 (Permissions Server-Side)**: Every one of the three new endpoints re-resolves
  the caller's board role via the existing `ResolveCardAsync`/`IBoardAccessService` path before
  acting (research.md R-3/R-5, contracts/attachments-api.md) — no operation trusts a
  client-asserted role or a bearer token's mere validity as access.
- **Invariant 8 (Opaque Public Identifiers)**: `Attachment.PublicId` is the only identifier
  ever placed in a URL, request body, or broadcast payload for it (data-model.md,
  research.md R-7); `Attachment.Id`/`CardId`/`UploadedById` never leave the service layer.

## Project Structure

### Documentation (this feature)

```text
specs/009-card-attachments/
├── plan.md                          # This file
├── research.md                      # Phase 0 output
├── data-model.md                    # Phase 1 output
├── quickstart.md                    # Phase 1 output
├── contracts/
│   └── attachments-api.md           # Phase 1 output
├── checklists/
│   └── requirements.md              # spec quality gate (already PASS)
└── tasks.md                         # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
flowboard-api/src/Flowboard.Api/
├── Domain/
│   ├── Entities/
│   │   └── Attachment.cs                 # NEW
│   └── ActivityEventType.cs              # MODIFIED — + AttachmentAdded, AttachmentRemoved
├── Data/
│   ├── Configurations/
│   │   └── AttachmentConfiguration.cs    # NEW
│   └── FlowboardDbContext.cs             # MODIFIED — + DbSet<Attachment>
├── Migrations/
│   └── <timestamp>_AddCardAttachments.cs # NEW
├── Services/
│   ├── IAttachmentStorage.cs             # NEW — interface
│   ├── LocalDiskAttachmentStorage.cs     # NEW — implementation (research.md R-1)
│   └── CardService.cs                    # MODIFIED — + AddAttachmentAsync,
│                                          #   GetAttachmentContentAsync, RemoveAttachmentAsync,
│                                          #   CardDetailDto.Attachments, CanRemoveAttachment
├── Endpoints/
│   └── AttachmentsEndpoints.cs           # NEW — upload/download/remove (contracts/attachments-api.md)
└── Program.cs                            # MODIFIED — + IAttachmentStorage DI registration,
                                           #   MapAttachmentsEndpoints, attachment storage root path config

flowboard-api/tests/Flowboard.Api.Tests/
└── AttachmentsEndpointsTests.cs          # NEW — permission matrix + rejection-path integration tests

flowboard-web/src/
├── components/board/card-detail/
│   ├── card-attachments-panel.tsx        # NEW
│   └── card-detail-modal.tsx             # MODIFIED — mounts the new panel
├── lib/
│   ├── api/
│   │   └── attachments-client.ts         # NEW — server-only client for contracts/attachments-api.md
│   └── cards/
│       └── schemas.ts                    # MODIFIED — + removeAttachmentInputSchema
├── server/api/routers/
│   └── cards.ts                          # MODIFIED — + removeAttachment procedure
└── app/api/attachments/
    ├── route.ts                          # NEW — POST upload (research.md R-2)
    └── [attachmentPublicId]/
        └── route.ts                      # NEW — GET download (research.md R-2)
```

**Structure Decision**: Existing `flowboard-api`/`flowboard-web` layout (001's plan.md),
unchanged in shape. Backend gains no new top-level folder — `Attachment` slots into the
existing `Domain/Entities`/`Data/Configurations`/`Services`/`Endpoints` split exactly like
every prior card sub-resource. Frontend gains one new leaf under the existing
`app/api/` folder (alongside `app/api/auth/` and `app/api/trpc/`, both already Route
Handlers, not tRPC-router-shaped) — no new top-level frontend folder either.

## Architecture Decision Records

**ADR-40 — File bytes live on local disk behind a new `IAttachmentStorage` interface, not in
SQL Server and not in a real cloud object store yet**: research.md R-1. The interface is the
seam a future cloud-backed implementation (Azure Blob Storage, the natural next choice beside
this project's other Microsoft-stack pieces) would fill without touching the `Attachment`
entity, the API contract, or any calling code — deferred because no cloud account/config
exists anywhere in this project through 008, and adding one is an infrastructure decision this
feature doesn't need to force.

**ADR-41 — Upload and download are Next.js Route Handlers, not tRPC procedures; every other
attachment operation stays on tRPC**: research.md R-2. The one deliberate, named exception to
frontend-rules.md's "ALL backend calls MUST go through tRPC procedures," justified the same
way 008's realtime exception was: by preserving the rule's actual purpose (one server-side
place owning base URL/auth/timeouts/error-mapping, browser never holding the backend token)
even though the literal transport differs, because tRPC's JSON-RPC shape cannot carry
multipart uploads or binary download responses without a lossy base64 workaround this plan
explicitly rejects.

**ADR-42 — Removal permission is "uploader OR board admin," a new check distinct from the
existing `CanMutate`**: research.md R-5. `CanMutate` (board admin/board member) still governs
upload; a new, narrower `CanRemoveAttachment` governs removal, per spec.md FR-005/FR-006.

**ADR-43 — Attachment add/remove reuse the existing `ActivityEvent`/realtime broadcast path
verbatim; no new event-type category or broadcast mechanism**: research.md R-6, 008's ADR-35.

## Complexity Tracking

No unjustified Constitution Check violations. Architecture Consistency (IV)'s three flagged
new patterns (multipart endpoint, local-disk storage abstraction, two Route Handlers bypassing
tRPC) are each explicitly approved above with a named rationale and a named alternative
rejected, per constitution IV's own requirement ("MUST NOT be introduced unless explicitly
approved in the technical plan") — this table is intentionally empty because the approval
lives inline in the Constitution Check and ADRs above, matching 008's plan.md precedent for
how a Standard/Critical feature documents an approved exception rather than treating approval
as a separate bureaucratic step.
