# Review Notes — 009 Card Attachments

## Phase A — Backend (Foundational + US1/US2/US3) (T001–T019)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-31
**Branches**: `flowboard-api` `009-card-attachments` (tip `a64e621`, merged to `main` as `65dcf75`)
**Full detail**: `ai-code-review.md`'s first section, `human-pr-review.md`'s first section
(APPROVED, anas.m, 2026-08-31).

## Verdict

**APPROVE with follow-ups** (F1–F4, none blocking). See `ai-code-review.md` for the full
evidence table, findings, and domain invariant pass — this section records the compliance
checklist results the AI review's narrative doesn't spell out row-by-row.

## Backend Compliance Checklist (`docs/rulebooks/backend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | `AttachmentsEndpoints.cs` is a minimal-API endpoint group (`MapAttachmentsEndpoints` + `MapPost`/`MapGet`/`MapDelete`), no controller; handlers stay thin (validation + one `ICardService` call each); `AttachmentsEndpoints.cs`, `CardService.cs`'s attachment methods, and the frontend's Route Handlers all cite `contracts/attachments-api.md` in a top comment |
| API Surface | PASS | Upload/size/extension validation returns `Failure.Validation` (RFC 9457); every DTO (`AttachmentDetailDto`) exposes `PublicId` only, never `Id`/`CardId`/`UploadedById` (invariant 8); no `If-Match`/cursor-pagination surface applies — attachments have no optimistic-concurrency field (contracts/attachments-api.md's card-detail-payload note) and ride along on the existing card-detail read rather than their own list endpoint |
| Domain & Authorization | PASS | Every one of the three endpoints re-resolves the caller's board role via `IBoardAccessService` before acting (invariant 5), verified by the Observer/non-member test coverage; `attachment.added`/`attachment.removed` are the only two new activity-event types and are only ever inserted, never updated/deleted (invariant 1); no ordering/position concept applies (invariant 2 N/A) |
| Data Access & Performance | PASS (see F3) | Attachment listing rides the existing `AsNoTracking()`/`.Select()` projection pattern in `BuildDetailDtoAsync`; `GetAttachmentContentAsync`'s own query is tracked, not `AsNoTracking()` (ai-code-review.md F3) — flagged as MINOR because it matches a pre-existing, accepted pattern elsewhere in `CardService.cs` (`ResolveCardAsync`), not a new regression; download streams the file rather than buffering it; realtime events publish only after `SaveChangesAsync()` (unchanged pattern from 008) |
| Security | PASS | `.RequireAuthorization()` on all three endpoints; EF Core parameterized queries throughout (no raw SQL); `StorageKey` is always server-generated (`Guid.NewGuid()`), never derived from caller input — no path-traversal vector; no secret/credential logged; no external `HttpClient` involved (`IAttachmentStorage` writes to local disk, not a third-party API) |
| Testing | PASS | 16 new `[Fact]` integration tests in `AttachmentsEndpointsTests.cs` covering success, validation failure (oversized/blocked-extension), authorization failure (Observer/non-member) for all three operations, plus the removal permission matrix (uploader/admin/non-uploading-member) and the activity-event shape assertion |
| Process | PASS | No new NuGet package; diff matches `tasks.md`'s Phase 1–4 file list exactly (`git diff --stat`); gate `dotnet build --warnaserror && dotnet test` — EXIT 0, 154/154 passing, user-confirmed at each of T008/T015/T018/T019's checkpoints |

## Constitution re-check (post-implementation)

See `ai-code-review.md`'s Constitution re-check and Domain Invariant Pass sections — both
PASS, re-verified against the code as built (not just the plan-time check). Human Review
(XII): APPROVED (`human-pr-review.md`). Controlled Delivery (XIII): held — backend gated,
reviewed, and merged to `flowboard-api`'s `main` before any frontend code was written.

## Test coverage observed

154/154 passing (138 pre-existing + 16 new), 0 warnings/errors under
`dotnet build --warnaserror`. Full breakdown in `ai-code-review.md`'s "Test coverage observed"
section.

## Residual risk

None correctness-shaped. F2 (contract wording overstates upload atomicity) and F4 (test
on-disk cleanup) are documentation/test-hygiene notes carried forward, not blocking anything.

---

## Phase B — Frontend (US1/US2/US3) (T020–T030)

**Reviewer**: Claude Sonnet 5 (agent)
**Date**: 2026-08-31
**Branches**: `flowboard-web` `009-card-attachments` (tip `a4c591c`, merged to `main` as `77959ec`)
**Full detail**: `ai-code-review.md`'s second section, `human-pr-review.md`'s second section
(APPROVED, anas.m, 2026-08-31).

## Verdict

**APPROVE with follow-ups** (F2–F4, none blocking). F1 (missing client-side upload
restrictions against `frontend-security.md` §6) was found during the AI review and fixed
before that document was finalized; the gate was re-run and re-confirmed by the user after the
fix. The human reviewer then exercised the feature live in the browser (upload, download,
removal permission matrix, cross-tab realtime update) before approving — closing the AI
review's own noted residual-risk gap (no live-browser verification at the code-review stage).

## Frontend Compliance Checklist (`docs/rulebooks/frontend-compliance-checklist.md`)

| Section | Result | Notes |
|---|---|---|
| Structure | PASS | New files follow the existing layout (`components/board/card-detail/card-attachments-panel.tsx`, `lib/api/attachments-client.ts`, `app/api/attachments/`); kebab-case files, PascalCase exports; `'use client'` present only where hooks/state/handlers are used (`card-attachments-panel.tsx`) — both Route Handlers stay server-only with no `'use client'` |
| Data Flow | PASS (named exception: ADR-41) | Upload/download deliberately bypass tRPC via two Route Handlers — the one approved, named exception (`plan.md` ADR-41, matching 008's realtime precedent) for the two operations tRPC's JSON transport cannot carry; removal (`removeAttachment`) has no bytes to carry and correctly stays on tRPC, Zod-validated, invalidating `cards.getDetail`/`boards.getContent` on success; no direct backend fetch from a component — the panel's own `fetch("/api/attachments", ...)` call is same-origin, hitting the Route Handler, not the backend |
| Forms | N/A | No React Hook Form data-entry form in this feature — file selection is a native file picker, and removal is a single-click action, not a submitted form; feedback still uses Sonner `toast` for every error path (upload rejection, network failure, removal failure), matching X-01's "every state-changing action gives feedback" |
| UI States & Accessibility | PASS (see F2) | Empty ("No attachments yet"), pending (per-file uploading row), and error (toast) states all present; F2 (ai-code-review.md) notes a minor focus-return quirk on the hidden file input after a picker closes — not spec-blocking, no acceptance scenario depends on it |
| State, Styling | PASS | No new client state store — `pending` uploads are local `useState`, attachment data itself lives in `cards.getDetail`'s React Query cache exclusively; Tailwind utilities + existing tokens only (`hover:bg-muted/60`, `text-destructive`), no hardcoded hex colors; layout follows `card-checklist-panel.tsx`'s established structure (FR-013, no screenshot reference exists for this feature) |
| Security & Performance | PASS (F1 fixed) | No backend token reaches the client bundle (`FLOWBOARD_API_URL` read only in server-only `*-client.ts` files); F1's client-side size/extension pre-check and visible limit text now satisfy `frontend-security.md` §6's File Upload UI requirements; download response streamed through (`new Response(result.response.body, ...)`), never buffered |
| Process | PASS | No new npm package; diff matches `tasks.md`'s Phase B file list exactly (`git diff --stat`); gate `npm run lint && npm run build` — EXIT 0, user-confirmed at each of T025/T028/T030's checkpoints, plus once more after the F1 fix |

## Constitution re-check (post-implementation)

See `ai-code-review.md`'s Constitution re-check section — PASS, including FR-013's visual-
language check (no screenshot exists for this feature, so the human reviewer's direct
comparison against the existing card-detail-modal panels stood in for the Visual Compliance
Loop, per `tasks.md`'s own note that no such loop applies here). Human Review (XII): APPROVED.
Controlled Delivery (XIII): held — frontend began only after Phase A's gate passed and merged.

## quickstart.md walkthrough (T031)

Re-read `quickstart.md` end-to-end against the final implementation:

- §0/§1 (migration + both services' start commands): paths and commands verified against the
  actual project structure (`Flowboard.Api.csproj`, `.config/dotnet-tools.json`,
  `package.json`'s `"dev": "next dev"` script) — no drift found.
- §2–§6 (upload/list, download, rejection paths, removal permissions, activity/realtime): no
  wording drift found against the shipped UI (e.g. "the new attachments section" matches the
  panel's actual "Attachments" header; the described role-gating matches `canMutate`/
  `canRemove` exactly). The described behaviors were live-verified by the human reviewer
  during Phase B's human review (`human-pr-review.md`'s UI Review checklist), not re-run
  independently by this agent — no new gap to record, and no edit to `quickstart.md` was
  needed.

## Test coverage observed (manual, no frontend test runner exists yet)

No automated frontend test suite (unchanged, 003–008 precedent). Verification is: the
`npm run lint && npm run build` gate (includes the full TypeScript type check), this agent's
code review (`ai-code-review.md`), and the human reviewer's live browser walkthrough covering
US1 (attach/list/download, including the Observer no-upload-control case), US2 (removal
permission matrix: uploader, board admin, non-uploading member, Observer), and US3 (activity
feed entries, cross-tab realtime update of an open card modal).

## Residual risk

None correctness-shaped remaining. F2 (hidden file input focus quirk), F3 (Zod `.uuid()`
inconsistency), and F4 (no fetch timeout, deliberate) are style/hygiene/accepted-deviation
notes only. The AI review's original residual-risk item (no live-browser verification) was
closed by the human reviewer's walkthrough before approval.
