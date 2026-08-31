# Tasks: Card Attachments

**Input**: Design documents from `/specs/009-card-attachments/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/attachments-api.md, quickstart.md

**Delivery Level**: **Standard** (`docs/sdlc/critical-delivery.md`) — additive, reversible
migration; no new authentication mechanism; reuses 002's `IBoardAccessService` and 008's
`IBoardEventPublisher` unchanged. Full Definition of Done applies; no Critical addendum.

**Tests**: Backend integration tests are included throughout — `docs/rulebooks/backend-rules.md`
requires one per endpoint unconditionally, and the permission matrix (role × ownership ×
rejection path) is this feature's actual business logic (constitution XI). No frontend test
runner exists yet (003–008 precedent) — frontend verification is `quickstart.md`'s manual
walkthrough (no Visual Compliance Loop — spec.md has no Visual Inventory section; no
screenshots exist for this feature, per FR-013).

**Organization**: Tasks are grouped primarily by delivery phase (constitution XIII,
cross-repository rule: backend gates and merges before frontend starts), with `[Story]`
labels for traceability back to spec.md's user stories (US1 attach and view, US2 remove,
US3 activity and realtime). See "Delivery Mapping" below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US3); Foundational/Polish tasks
  carry no story label
- Paths are relative to the named nested repo (`flowboard-api/` or `flowboard-web/`)

---

## Phase 1: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user-story work (Phase 2+) may begin until this phase is complete. No new
package this feature (plan.md Technical Context) — nothing to add in a separate Setup phase.

- [x] T001 [P] Create `Attachment` entity (`Id`, `PublicId`, `CardId`, `FileName`, `SizeBytes`, `ContentType`, `StorageKey`, `UploadedById`, `CreatedDate`, `CreatedBy`) in flowboard-api/src/Flowboard.Api/Domain/Entities/Attachment.cs (data-model.md Attachment)
- [x] T002 [P] Add `AttachmentAdded = "attachment.added"` and `AttachmentRemoved = "attachment.removed"` constants in flowboard-api/src/Flowboard.Api/Domain/ActivityEventType.cs (data-model.md ActivityEvent extension, research.md R-6)
- [x] T003 [P] Create `IAttachmentStorage` interface (`SaveAsync(Stream content, CancellationToken) -> storageKey`, `OpenReadAsync(string storageKey, CancellationToken) -> Stream`, `DeleteAsync(string storageKey, CancellationToken)`) in flowboard-api/src/Flowboard.Api/Services/IAttachmentStorage.cs (research.md R-1)
- [x] T004 Create `LocalDiskAttachmentStorage` implementing `IAttachmentStorage` — writes under a configured root directory keyed by a generated opaque filename (`Guid.NewGuid()`-based), never the caller-supplied filename — in flowboard-api/src/Flowboard.Api/Services/LocalDiskAttachmentStorage.cs (depends on T003; research.md R-1)
- [x] T005 Create `AttachmentConfiguration` (`PublicId` unique index, FK `CardId` → `Card` `Restrict` + index, FK `UploadedById` → `User` `Restrict`, `FileName`/`ContentType`/`StorageKey` max lengths, `HasQueryFilter(x => !x.Card.IsDeleted)`) in flowboard-api/src/Flowboard.Api/Data/Configurations/AttachmentConfiguration.cs (depends on T001; data-model.md)
- [x] T006 Register `DbSet<Attachment>` in flowboard-api/src/Flowboard.Api/Data/FlowboardDbContext.cs and add the `Attachments` navigation collection to flowboard-api/src/Flowboard.Api/Domain/Entities/Card.cs (depends on T001, T005)
- [x] T007 Generate the `AddCardAttachments` migration (`dotnet ef migrations add`, repo-local tool) — purely additive `Attachment` table, no existing table/column touched — in flowboard-api/src/Flowboard.Api/Migrations/ (depends on T005, T006)
- [x] T008 Register `IAttachmentStorage` → `LocalDiskAttachmentStorage` in DI (singleton, matching `TokenService`'s stateless-singleton shape) in flowboard-api/src/Flowboard.Api/Program.cs. No `appsettings.Development.json` entry added — `LocalDiskAttachmentStorage` itself defaults the root path to `ContentRootPath/App_Data/attachments` when `Attachments:StorageRootPath` is absent, matching `Program.cs`'s existing `Cors:RealtimeOrigin` precedent (config key optional, code carries the dev default) rather than requiring every environment file to set one explicitly (depends on T004)

**Checkpoint**: Foundation ready — schema, migration, and storage abstraction exist. Backend
endpoint work (Phase 2) can now begin.

**Gate**: `dotnet build --warnaserror && dotnet test` in flowboard-api — EXIT 0, 138 passed, no
regressions. User-confirmed. Committed as flowboard-api `9c7e149` on branch `009-card-attachments`
(created off `main`, per `repository-strategy.md`'s cross-repository rule).

---

## Phase 2: Backend — Attach and view files (Priority: P1) 🎯 MVP — delivery Phase A, part 1

**Goal**: Every attach/list/download route in `contracts/attachments-api.md` (US1).

**Independent Test**: `AttachmentsEndpointsTests.cs`'s upload/download coverage (T014/T015) —
each capability callable directly against the running API before any frontend exists, matching
004/008's precedent of gating the backend as a unit ahead of the consuming tier.

- [ ] T009 [US1] `CardService.AddAttachmentAsync(cardPublicId, callerPublicId, fileName, contentType, sizeBytes, content, ct)` — `CanMutate` check (reuses the existing private helper), size (25 MB) and blocked-extension (`.exe`/`.bat`/`.sh`/`.cmd`/`.msi`) validation as `Failure.Validation` before any write, `IAttachmentStorage.SaveAsync`, inserts `Attachment` row, writes an `attachment.added` `ActivityEvent` via the existing `NewEvent`/`PublishActivityEventAsync` helpers — in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/attachments-api.md; research.md R-4, R-6)
- [ ] T010 [US1] `CardService.GetAttachmentContentAsync(attachmentPublicId, callerPublicId, ct)` — any resolvable board role (including `Observer`) may read; returns the stream, `ContentType`, and `FileName`, or `NotFound` — in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/attachments-api.md)
- [ ] T011 [US1] Extend `CardDetailDto` with `IReadOnlyList<AttachmentDetailDto> Attachments` and `BuildDetailDtoAsync` with an `AsNoTracking()`/`.Select()` projection ordered by `CreatedDate`, matching the existing labels/members/checklist projections' shape — in flowboard-api/src/Flowboard.Api/Services/CardService.cs (depends on T009; data-model.md, contracts/attachments-api.md's card-detail-payload section)
- [ ] T012 [US1] `POST /v1/cards/{cardPublicId}/attachments` — `[FromForm] IFormFile file`, `RequireAuthorization()`, a per-endpoint request body size limit above the 25 MB product cap as an abuse backstop (research.md R-4) — in flowboard-api/src/Flowboard.Api/Endpoints/AttachmentsEndpoints.cs (new file; depends on T009); register `MapAttachmentsEndpoints()` in Program.cs
- [ ] T013 [US1] `GET /v1/attachments/{attachmentPublicId}/content` — streams the file with `Content-Type` and `Content-Disposition: attachment; filename="..."` — in flowboard-api/src/Flowboard.Api/Endpoints/AttachmentsEndpoints.cs (depends on T010)
- [ ] T014 [P] [US1] Integration test: upload succeeds for board admin/member and appears in a follow-up `GET /v1/cards/{cardPublicId}`; fails `403` for `Observer`; fails `404` for a non-member; fails `400` for a blocked extension and for a file over 25 MB — in flowboard-api/tests/Flowboard.Api.Tests/AttachmentsEndpointsTests.cs (new file)
- [ ] T015 [P] [US1] Integration test: download succeeds for every role including `Observer`, with the correct `Content-Type`/filename; fails `404` for a non-member — in flowboard-api/tests/Flowboard.Api.Tests/AttachmentsEndpointsTests.cs

**Checkpoint**: US1 backend verifiable independently via T014/T015.

---

## Phase 3: Backend — Remove an attachment (Priority: P2) — delivery Phase A, part 2

**Goal**: Removal with the uploader-or-board-admin permission model (US2).

**Independent Test**: `AttachmentsEndpointsTests.cs`'s removal-permission coverage (T018).

- [ ] T016 [US2] `CardService.CanRemoveAttachment(BoardRole role, bool isUploader)` (`role == BoardRole.BoardAdmin || isUploader`) and `RemoveAttachmentAsync(attachmentPublicId, callerPublicId, ct)` — deletes the `Attachment` row, calls `IAttachmentStorage.DeleteAsync` after the row is committed, writes an `attachment.removed` `ActivityEvent` (`{ fileName }`) — in flowboard-api/src/Flowboard.Api/Services/CardService.cs (cite contracts/attachments-api.md; research.md R-5)
- [ ] T017 [US2] `DELETE /v1/attachments/{attachmentPublicId}` — `204` on success, `403` when the caller is neither the uploader nor a board admin — in flowboard-api/src/Flowboard.Api/Endpoints/AttachmentsEndpoints.cs (depends on T016)
- [ ] T018 [P] [US2] Integration test: removal succeeds for the uploader and for a board admin removing someone else's attachment; fails `403` for a non-uploading board member and for `Observer`; a follow-up download of a removed attachment returns `404` — in flowboard-api/tests/Flowboard.Api.Tests/AttachmentsEndpointsTests.cs

**Checkpoint**: US2 backend verifiable independently via T018.

---

## Phase 4: Backend — Activity and realtime (Priority: P3) — delivery Phase A, part 3

**Goal**: Confirm the activity/realtime behavior US3 requires — no new production code, since
T009/T016 already write and broadcast the events inline (research.md R-6, matching 004's US5
precedent where a story's backend work was pure test coverage over an existing endpoint).

**Independent Test**: `AttachmentsEndpointsTests.cs`'s activity-feed coverage (T019).

- [ ] T019 [P] [US3] Integration test: attaching and then removing a file each produce exactly one correctly-typed, correctly-shaped `ActivityEvent` (`attachment.added` / `attachment.removed`, `{ fileName }` payload), retrievable via `GET /v1/cards/{cardPublicId}/activity` — in flowboard-api/tests/Flowboard.Api.Tests/AttachmentsEndpointsTests.cs (reuses T012/T017, no new production code)

**Checkpoint — Phase A gate**: STOP. User runs `dotnet build --warnaserror && dotnet test` in
flowboard-api and confirms EXIT 0. AI review AND human review. Commit Phase A. Per
`docs/sdlc/repository-strategy.md`'s cross-repository rule, the backend gates and merges to
`main` **before** Phase B (frontend) begins.

---

## Phase 5: Frontend — Attach and view files (Priority: P1) — delivery Phase B, part 1

**Goal**: A working attachments panel in the card detail modal (US1).

**Independent Test**: `quickstart.md` §2/§3.

- [ ] T020 [US1] Extend `CardDetail`/add `AttachmentDetail` types with the `attachments` field (mirrors contracts/attachments-api.md's card-detail-payload section) in flowboard-web/src/lib/api/cards-client.ts
- [ ] T021 [US1] Create the server-only attachments client — `uploadAttachment(cardPublicId, formData, backendToken)` (forwards multipart), `downloadAttachment(attachmentPublicId, backendToken)` (returns the raw `Response` for streaming, not a parsed JSON result, since the body is a file) — in flowboard-web/src/lib/api/attachments-client.ts (new file; cite contracts/attachments-api.md; research.md R-2)
- [ ] T022 [US1] Create `app/api/attachments/route.ts` (`POST` — `getBackendSession()`, forward the incoming `FormData` to `uploadAttachment`, map its result to a JSON response with the same status code) in flowboard-web/src/app/api/attachments/route.ts (new file; depends on T021; research.md R-2)
- [ ] T023 [US1] Create `app/api/attachments/[attachmentPublicId]/route.ts` (`GET` — `getBackendSession()`, stream `downloadAttachment`'s response body straight through with its `Content-Type`/`Content-Disposition` headers) in flowboard-web/src/app/api/attachments/[attachmentPublicId]/route.ts (new file; depends on T021; research.md R-2)
- [ ] T024 [US1] Create `CardAttachmentsPanel` — lists attachments (filename, human-readable size, uploader display name), an upload control (native `<input type="file">`, POSTs a `FormData` to `/api/attachments`, gated by `canMutate`, with a pending/uploading state per FR-item — spec.md acceptance scenario 3), each attachment name links to `/api/attachments/{publicId}` for open/download — in flowboard-web/src/components/board/card-detail/card-attachments-panel.tsx (new file; depends on T020, T022, T023)
- [ ] T025 [US1] Mount `CardAttachmentsPanel` in the modal's left column, alongside the existing labels/description/checklist/activity panels — in flowboard-web/src/components/board/card-detail/card-detail-modal.tsx (depends on T024)

**Checkpoint**: US1 verifiable end-to-end through the browser (`quickstart.md` §2/§3/§4).

---

## Phase 6: Frontend — Remove an attachment (Priority: P2) — delivery Phase B, part 2

**Goal**: Uploader-or-admin removal, surfaced correctly per viewer (US2).

**Independent Test**: `quickstart.md` §5.

- [ ] T026 [US2] Add `removeAttachmentInputSchema` (`{ attachmentPublicId: z.string().uuid() }`) in flowboard-web/src/lib/cards/schemas.ts
- [ ] T027 [US2] Extend `cards-client.ts` with `removeAttachment(attachmentPublicId, backendToken)` and the `cards` tRPC router with a `removeAttachment` `protectedProcedure` (`403`/`404` mapped the same way every other card mutation already is) in flowboard-web/src/lib/api/cards-client.ts, flowboard-web/src/server/api/routers/cards.ts (depends on T026)
- [ ] T028 [US2] Compute `isBoardAdmin` and `currentUserPublicId` alongside the existing `canMutate` derivation and thread both down through `CardDetailModal` to `CardAttachmentsPanel`; render a remove control per attachment only when `isBoardAdmin || attachment.uploadedBy.publicId === currentUserPublicId`, calling `removeAttachment` on click — in flowboard-web/src/components/board/board-canvas.tsx, flowboard-web/src/components/board/card-detail/card-detail-modal.tsx, flowboard-web/src/components/board/card-detail/card-attachments-panel.tsx (depends on T027)

**Checkpoint**: US2 verifiable end-to-end, including the three-way permission check
(uploader / admin / neither) in the browser.

---

## Phase 7: Frontend — Activity and realtime (Priority: P3) — delivery Phase B, part 3

**Goal**: Attachment events readable in the activity feed and visible live (US3).

**Independent Test**: `quickstart.md` §6.

- [ ] T029 [US3] Add `attachment.added` → `` `attached "${payload.fileName}"` `` and `attachment.removed` → `` `removed "${payload.fileName}"` `` cases to `describe()` (its `default` case currently renders a blank description for any unmapped type) in flowboard-web/src/components/board/card-detail/card-activity-feed.tsx
- [ ] T030 [US3] Extend `use-board-realtime.ts`'s `connection.on("BoardEvent", ...)` handler to also call `utils.cards.getDetail.invalidate()` (no input filter — refetches whichever card modal is currently open, a no-op when none is) alongside its existing `boards.getContent.invalidate(...)`, closing the pre-existing gap where an open card detail modal never live-updated — in flowboard-web/src/lib/realtime/use-board-realtime.ts (research.md R-8, plan.md ADR-44)

**Checkpoint**: US3 verifiable end-to-end — activity feed shows both event types, and a second
open window sees an attachment add/remove without a manual reload.

**Checkpoint — Phase B gate**: STOP. User runs `npm run lint && npm run build` in
flowboard-web and confirms EXIT 0. AI review AND human review (no Visual Compliance Loop —
spec.md has no screenshots; FR-013's "follow the existing visual language" is checked as part
of ordinary human review instead). Commit Phase B.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T031 [P] Walk `quickstart.md` end-to-end (all sections) and fix any doc drift in specs/009-card-attachments/quickstart.md
- [ ] T032 Write phase review notes (backend + frontend compliance checklist results, gate evidence, the domain-invariant pass) in specs/009-card-attachments/review-notes.md; write specs/009-card-attachments/human-pr-review.md; on merge, set roadmap row 009 → shipped in docs/roadmap.md

---

## Delivery Mapping (constitution XIII, cross-repository rule)

| Delivery phase | Tasks | Gate (user-run, exit 0 confirmed) |
|---|---|---|
| Foundational | T001–T008 | none (no endpoint surface yet); covered by `dotnet test` once Phase A's tests exist |
| Phase A — backend (attach/view, remove, activity+realtime reuse) | T009–T019 | `dotnet build --warnaserror && dotnet test` in flowboard-api |
| Phase B — frontend (attachments panel, remove control, activity+realtime wiring) | T020–T030 | `npm run lint && npm run build` in flowboard-web |
| Wrap-up | T031–T032 | both gates re-run at merge time |

## Dependencies & Execution Order

- Foundational (T001–T008) has no dependency on anything outside this feature and blocks
  every later task. Within it: T001, T002, T003 can proceed in parallel; T004 depends on T003;
  T005 depends on T001; T006 depends on T001 and T005; T007 (the migration) depends on T005 and
  T006; T008 depends on T004.
- Phase A (T009–T019) depends on Foundational completing. Within it: T009 (add) → T011 (detail
  projection, needs `Attachment` rows to exist as a concept) → T012 (endpoint); T010 (read) →
  T013 (endpoint) can proceed in parallel with T009/T011/T012 once Foundational is done; T014/
  T015 depend on T012/T013 respectively; T016 → T017 → T018 depend on T009/T012 already
  existing (removal needs something to remove); T019 depends on both T012 and T017 (it exercises
  both endpoints).
- Phase B (T020–T030) depends on the Phase A gate passing and merging first
  (repository-strategy.md's cross-repository rule). T020 (type extension) precedes T021
  (client) precedes T022/T023 (Route Handlers, parallel once T021 exists) precedes T024 (panel)
  precedes T025 (mount). T026 → T027 → T028 (removal UI) depends on T024/T025 existing (there
  must be a rendered attachment to attach a remove control to). T029/T030 (US3) are independent
  of each other and of T026–T028, and can proceed as soon as T025 has landed (there is
  something in the activity feed / an open modal to observe).
- Polish (T031–T032) is last, after both phase gates pass.

## Parallel Opportunities

- Within Foundational: T001, T002, T003 together (independent files); T004 and T005 can
  proceed in parallel once T001/T003 land, before converging on T006.
- Within Phase A: T010/T013 (download path) in parallel with T009/T011/T012 (upload/listing
  path) — no shared file conflict beyond both landing in `CardService.cs`/`AttachmentsEndpoints.cs`,
  which is why the file-level tasks (T009/T012, T010/T013) aren't marked `[P]` against each
  other, but the three integration tests (T014, T015, T019 once its dependencies exist) are.
- Within Phase B: T022 and T023 (the two Route Handlers) together once T021 exists — two
  independent files, same client underneath. T029 and T030 (US3) together — different files,
  no dependency on each other.

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Foundational.
2. Complete Phase 2: Backend US1 (attach, list, download).
3. **STOP and VALIDATE**: `dotnet test` passes; T014/T015 cover the full permission matrix for
   upload/download.
4. Get user/gate approval before continuing (Phase A isn't done until US2/US3's backend tasks
   also land and the Phase A gate is run — see Delivery Mapping — but US1 alone is already a
   demonstrable, independently-testable increment per spec.md).

### Incremental Delivery

1. Foundational → schema/storage abstraction ready, nothing callable yet.
2. Add US1 (backend, then frontend) → attach/view/download works end-to-end → validate via
   `quickstart.md` §2/§3 (MVP).
3. Add US2 (backend, then frontend) → removal with correct permissions → validate via
   `quickstart.md` §5.
4. Add US3 (backend test only, then frontend) → activity feed + live update → validate via
   `quickstart.md` §6.
5. Polish → full quickstart pass, both phase gates re-confirmed, wrap-up docs.

### Solo/Small-Team Strategy

Given this repository's actual size (one active branch, sequential feature delivery per
`docs/sdlc/branch-strategy.md`), stories are most realistically implemented in priority order
(US1 → US2 → US3) within each repository phase, matching every prior feature's precedent —
the parallel-opportunity notes above exist for the case where more than one person picks up
this branch.

## Notes

- `[P]` tasks = different files, no dependency on an incomplete task.
- `[Story]` label maps each task to spec.md's US1–US3 for traceability.
- Per CLAUDE.md's Strict Rules: implement one phase (one delivery phase, per the mapping above)
  at a time and stop for user approval before continuing to the next.
