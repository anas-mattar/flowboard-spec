# AI Code Review — 009 Card Attachments (Foundational + Backend US1/US2/US3)

**Reviewer**: Claude Sonnet 5 (self-review of own implementation — an independent human
reviewer is still required before merge, per constitution XII / `docs/sdlc/review-process.md`)
**Date**: 2026-08-31
**Branches**:
- `flowboard-api` `009-card-attachments` (tip `a64e621`)
**Scope reviewed**: Every file in the four Phase A commits (`9c7e149`, `90f93c4`, `d48a380`,
`a64e621` — `git diff bfe1a7c..a64e621 --stat`); `docs/domain/flowboard-invariants.md` (all 8
items); `docs/rulebooks/backend-rules.md`; `specs/009-card-attachments/{spec,plan,research,
data-model,contracts/attachments-api.md}`.
**Feature contract**: One additive migration (`Attachment` table only, `Restrict` FKs, no
existing table/column touched); no new package; local-disk `IAttachmentStorage` as an interim,
swappable abstraction (ADR-40); two narrow, named deviations already approved in plan.md
(multipart request body, `.DisableAntiforgery()` — the latter discovered during
implementation, not anticipated in the plan, see F1).

**Covers**: `tasks.md` Phases 1–4 (T001–T019 — Foundational, US1 attach/view, US2 remove, US3
activity confirmation). Frontend (Phase B, T020–T030) and Polish (T031–T032) are out of scope
for this review.

## Verdict

**APPROVE with follow-ups.** The full attach/list/download/remove flow works correctly and is
covered end-to-end by 16 new integration tests (all passing) plus the full existing suite
(154/154, no regressions). Every domain invariant this feature touches (1, 4, 5, 8) is
enforced in code and verified by a test. Residual risk is coverage-shaped and doc-precision-
shaped, not correctness-shaped: one finding (F2) is a doc-vs-code precision gap in a failure
mode that is user-invisible, and two (F3, F4) are minor test-hygiene notes for a later phase.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FR-001–FR-013 for backend-reachable scope) | Read every FR in spec.md against the implementation. FR-001/002/008/009 (upload, validation, permission) — `AddAttachmentAsync` (`CardService.cs`), covered by `Upload_BoardAdmin_Succeeds_AndAppearsInCardDetail`, `Upload_BoardMember_Succeeds`, `Upload_Observer_Returns403`, `Upload_NonMember_Returns404`, `Upload_BlockedExtension_Returns400`, `Upload_OverSizeLimit_Returns400`. FR-003 (metadata visible on the card) — `CardDetailDto.Attachments`, covered by the same upload test's follow-up `GET`. FR-004 (download, any role) — `GetAttachmentContentAsync`, covered by `Download_EveryRole_Succeeds_WithCorrectContentTypeAndFilename` (asserts `Content-Type`, `Content-Disposition` filename, and byte-for-byte body), `Download_NonMember_Returns404`, `Download_UnknownAttachment_Returns404`. FR-005/006/007 (uploader-or-admin removal, immediate unavailability) — `CanRemoveAttachment`/`RemoveAttachmentAsync`, covered by `Remove_ByUploader_Succeeds_WritesActivity_AndDownloadThen404`, `Remove_ByBoardAdmin_RemovingSomeoneElsesAttachment_Succeeds`, `Remove_ByNonUploadingBoardMember_Returns403`, `Remove_ByObserver_Returns403`, `Remove_NonMember_Returns404`, `Remove_UnknownAttachment_Returns404`. FR-011 (activity log) — `AttachAndRemove_EachWriteExactlyOneCorrectlyShapedActivityEvent` asserts exactly one `attachment.added` and one `attachment.removed` entry, each with the correct `{ fileName }` payload. FR-012 (attachments survive archive/restore) is enforced by construction (`HasQueryFilter(x => !x.Card.IsDeleted)`, matching `ChecklistItemConfiguration`'s own filter) but has no dedicated test in this phase — reasonable, since 004/006 never added a dedicated archive/restore test for `ChecklistItem` either; the pattern is trusted by precedent, not re-verified per feature. |
| Visual-reference match | N/A — no screenshots exist for this feature (FR-013, spec.md); this is a backend-only review, nothing rendered yet. |
| Feature contract held | Confirmed via `git diff --stat`: exactly one new table (`Attachment`), no existing table/column altered, no new NuGet package (`Flowboard.Api.csproj` untouched), `IAttachmentStorage` is this project's own code, not a third-party dependency. |
| Constitution / domain invariants | See dedicated section below. |
| Security (authn/authz, secrets, sensitive logging) | All three endpoints carry `RequireAuthorization()`. Every service method re-resolves the caller's board role via `IBoardAccessService.ResolveAsync` (never trusts a client-supplied role) — verified by reading `AddAttachmentAsync`, `GetAttachmentContentAsync`, `RemoveAttachmentAsync` and by the Observer/non-member test coverage above. `StorageKey` is always server-generated (`Guid.NewGuid().ToString("N")`, `LocalDiskAttachmentStorage.SaveAsync`) and never derived from the caller-supplied `FileName` — no path-traversal vector on save, read, or delete. Download sets `Content-Disposition: attachment` (via `Results.File`'s `fileDownloadName` parameter, confirmed by `Download_EveryRole_...`'s header assertion), which forces a browser download rather than inline rendering — the standard mitigation against a malicious upload's `Content-Type` (attacker-controlled, echoed verbatim per data-model.md) being rendered in-origin; no secret or credential is logged or newly introduced. |
| Scope guard (`git diff --stat`) | Every changed file matches `tasks.md`'s Phase 1–4 file list (`Attachment.cs`, `ActivityEventType.cs`, `IAttachmentStorage.cs`, `LocalDiskAttachmentStorage.cs`, `AttachmentConfiguration.cs`, `FlowboardDbContext.cs`, `Card.cs`, the migration pair, `Program.cs`, `CardService.cs`, `AttachmentsEndpoints.cs`, `AttachmentsEndpointsTests.cs`) plus the `.gitignore` addition for the local storage dev-default root — a reasonable, narrowly-scoped addition, not a drive-by change. |
| Rollback safety | Purely additive migration (`CREATE TABLE Attachment` only); `Down()` drops the new table and nothing else (verified by reading `20260831074455_AddCardAttachments.cs`). No `rollback.md` required at Standard delivery level (data-model.md, plan.md Constitution Check) — reverting this phase's code and migration touches no `Board`/`List`/`Card`/`ActivityEvent` row. |

## Findings

### F1 — Upload endpoint required `.DisableAntiforgery()`, undocumented in plan.md — DOC DRIFT

`[FromForm] IFormFile` binding in .NET 10 minimal APIs automatically attaches antiforgery
metadata to the endpoint, which throws at request time (`InvalidOperationException`) if no
antiforgery middleware is registered — discovered via a failing test during implementation,
not anticipated by plan.md/research.md/contracts/attachments-api.md. The fix
(`.DisableAntiforgery()` on the upload route, with an inline comment) is correct: this API is
bearer-token-only with no cookies, so the CSRF threat model antiforgery tokens defend against
does not apply, and no antiforgery services are registered anywhere in the project (verified by
reading `Program.cs`). No security regression — an attacker still cannot attach a bearer token
to a forged cross-origin request.
*Action: none required for merge. Optional: add one line to research.md (a new R-9, or an
addendum to R-3) recording this discovery for future readers, matching how R-8 documented the
realtime-gap discovery in this same feature. Low priority — the code comment already carries
the reasoning.*

### F2 — contracts/attachments-api.md overstates upload's atomicity — MINOR / DOC DRIFT

The contract states upload's side effects are "all three, or none if any step fails before
`SaveChangesAsync()` commits." In `AddAttachmentAsync`, `IAttachmentStorage.SaveAsync` runs
*before* `db.SaveChangesAsync()`, so if the database insert fails for any reason after the file
write succeeds (a transient DB error — no realistic in-app cause exists today, since neither a
uniqueness conflict nor a concurrency token applies to a new `Attachment` row), the file is
orphaned on disk with no corresponding row. This is the same trade-off every "write blob, then
write metadata" pattern makes and is user-invisible (no dangling reference is ever returned to
a client), but the contract's literal "or none" wording is stronger than what a non-transactional
disk write + SQL insert can actually guarantee.
*Action: none required for merge — the failure mode is benign and matches an industry-standard
pattern. Recommend softening the contract's wording at the next natural edit of that file (e.g.
Polish phase docs pass, T031) rather than as a standalone change now.*

### F3 — `GetAttachmentContentAsync`'s query is tracked, not `AsNoTracking()` — MINOR

Per `backend-rules.md`, read-only queries must not track entities. This method never mutates
the loaded `Attachment`, so `.AsNoTracking()` would be more correct. Noted for completeness;
however, `GetCardDetailAsync`'s own `ResolveCardAsync` helper has the identical property
(tracked, used by both pure-read and read-then-mutate callers) and has never been flagged in a
prior feature's review — this finding is consistent with a pre-existing, accepted pattern in
`CardService.cs`, not a new regression this feature introduced.
*Action: none required for merge. Optional cleanup, bundle-able with any future pass that
addresses the same shape elsewhere in this file.*

### F4 — Test suite has no cleanup for on-disk attachment bytes — MINOR

`AttachmentsEndpointsTests.cs`'s `DisposeAsync` removes the `Attachment` database rows it
created but never calls `IAttachmentStorage.DeleteAsync` (or otherwise removes) the
corresponding files under `LocalDiskAttachmentStorage`'s root — every test run leaves a small
number of orphaned files in `App_Data/attachments` (gitignored, so this never reaches source
control, but it is unbounded growth on a dev machine or CI runner across repeated runs).
*Action: none required for merge — not a correctness issue. Recommend a follow-up (Polish
phase or a later test-infra pass) that either points `LocalDiskAttachmentStorage`'s test
configuration at a temp directory cleaned up by the test fixture, or has `DisposeAsync` delete
the files it created.*

## Constitution re-check (post-implementation)

All checks in plan.md's Constitution Check (re-read above) still hold against the code as
built:

- **Domain Invariants (VII)** — see Domain Invariant Pass below.
- **Security (VIII)** — held; see evidence table above. Upload bounded by size cap + extension
  deny-list (verified by test); full malware scanning remains an accepted, documented
  out-of-scope item (spec.md Assumptions), not a silent gap.
- **Data Standards (V)** / **Opaque Public Identifiers (VIII, invariant 8)** — `Attachment.Id`
  is `INT IDENTITY(1,1)`, never serialized; every DTO and endpoint route addresses attachments
  by `PublicId` only (confirmed by reading `AttachmentDetailDto`, `AttachmentsEndpoints.cs`,
  and the migration's column list).
- **Architecture Consistency (IV)** — the three approved new patterns (multipart body,
  `IAttachmentStorage` local-disk abstraction, no new layering) are exactly as scoped in
  plan.md; F1's antiforgery fix is a corollary of the first, not a fourth new pattern.
- No principle regressed; no unapproved table, package, or permission model was introduced
  (`CanRemoveAttachment` is the one new authorization predicate, explicitly approved as ADR-42).

### Domain Invariant Pass (re-verified against the built code)

- **Invariant 1 (Activity Is Append-Only)**: Confirmed — `AddAttachmentAsync`/
  `RemoveAttachmentAsync` only ever call `db.ActivityEvents.Add(...)`; no code path updates or
  deletes an `ActivityEvent` row. `AttachAndRemove_EachWriteExactlyOneCorrectlyShapedActivityEvent`
  proves both events coexist and are independently retrievable after the attachment itself is
  gone.
- **Invariant 4 (Soft Delete / Restorability)**: `AttachmentConfiguration.HasQueryFilter(x =>
  !x.Card.IsDeleted)` matches `ChecklistItemConfiguration`'s identical filter shape exactly —
  an attachment on an archived card is excluded, not deleted, and returns when the card is
  restored. No dedicated archive/restore test this phase (see evidence table above) —
  consistent with precedent, not a gap unique to this feature.
- **Invariant 5 (Permissions Server-Side)**: Confirmed by construction and by test — every one
  of the three new endpoints re-resolves the caller's role via `IBoardAccessService` before
  acting; Observer/non-member paths are explicitly tested for all three operations.
- **Invariant 8 (Opaque Public Identifiers)**: Confirmed — see Constitution re-check above.

## Test coverage observed

`AttachmentsEndpointsTests.cs` — 16 `[Fact]` tests, all passing:

- **Upload (6)**: admin success + card-detail/activity assertions; member success; Observer
  403; non-member 404; blocked extension 400; file over 25 MB 400.
- **Download (3)**: every role (admin/member/Observer) succeeds with correct `Content-Type`,
  `Content-Disposition` filename, and exact byte content; non-member 404; unknown attachment
  404.
- **Remove (6)**: uploader removes own attachment (activity written, card detail updated,
  follow-up download 404); board admin removes someone else's attachment; non-uploading board
  member 403; Observer 403; non-member 404; unknown attachment 404.
- **Activity (1)**: attach-then-remove produces exactly one `attachment.added` and one
  `attachment.removed` entry, each with the correct `{ fileName }` payload.

Full suite: **154/154 passed**, 0 warnings/errors under `dotnet build --warnaserror`. No
regression in any of the 138 pre-existing tests.

## Residual risk

Concentrated in F2 (a documentation-precision gap over a benign, user-invisible failure mode)
and F3/F4 (minor code-hygiene notes, neither blocking). No finding touches a domain invariant,
a security control, or a data-integrity guarantee. The one item worth carrying forward into
Phase B's own review: when the frontend (T022/T023) proxies the download response, confirm the
`Content-Disposition: attachment` header set here is preserved end-to-end and never rewritten
to `inline` — that is what keeps F1's benign-by-construction upload surface benign once a real
browser is in the loop.
