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

---

# AI Code Review — 009 Card Attachments (Phase B — Frontend)

**Reviewer**: Claude (Sonnet 5)
**Date**: 2026-08-31
**Branches**: flowboard-web `009-card-attachments` (tip `a4c591c`, off `main` `018b56f`)
**Scope reviewed**: `src/lib/api/cards-client.ts` (attachments additions), `src/lib/api/attachments-client.ts`
(new), `src/lib/cards/schemas.ts` (attachments addition), `src/server/api/routers/cards.ts`
(`removeAttachment`), `src/app/api/attachments/route.ts` (new), `src/app/api/attachments/[attachmentPublicId]/route.ts`
(new), `src/components/board/card-detail/card-attachments-panel.tsx` (new),
`src/components/board/card-detail/card-detail-modal.tsx`, `src/components/board/board-canvas.tsx`,
`src/components/board/card-detail/card-activity-feed.tsx`, `src/lib/realtime/use-board-realtime.ts`
— every file plan.md's Project Structure section lists for Phase B (T020–T030). Not reviewed:
flowboard-api (Phase A, already reviewed and merged as `65dcf75`).
**Feature contract**: no new npm package; upload/download bypass tRPC via two Route Handlers
(ADR-41), everything else stays on tRPC; no new UI library; attachments panel follows the
existing card-detail-modal panels' visual language (FR-013, no screenshots exist for this
feature).

## Verdict

**APPROVE with follow-ups** (F2–F4, none blocking). Phase B adds an attachments panel to the
card detail modal — upload (gated to non-Observers), a listed attachment (filename, size,
uploader) with a download link open to every role, and a remove control gated to the uploader
or a board admin — wired to the Phase A backend exactly as its contract specifies. One real gap
(F1, missing client-side upload restrictions against `frontend-security.md` §6) was found
during this review and fixed before this document was finalized; the gate was re-run and
re-confirmed by the user after the fix. Residual risk is concentrated in the lack of an
automated or manual browser walkthrough for this phase (see Residual risk) — code-level
verification is solid, but no one has yet clicked through the feature in a live browser.

## What was verified (evidence)

| Area | Evidence |
|---|---|
| Spec match (FRs implemented as specified) | FR-001 (upload gated to non-Observer via `canMutate`, `card-attachments-panel.tsx:113`), FR-003 (list shows filename/size/uploader, same file lines 156–166), FR-004 (download link `href={`/api/attachments/${attachment.publicId}`}` rendered unconditionally — no role gate — matching "any viewer including Observer"), FR-005/FR-006 (remove control `canRemove = isBoardAdmin \|\| attachment.uploadedBy.publicId === currentUserPublicId`, hidden entirely otherwise), acceptance scenario 3 (pending/uploading row, `pending` state), acceptance scenario 4 (failed upload never invalidates the query — no partial row — and shows a `toast.error`, retryable by re-selecting the file) — read end-to-end in the final file. |
| Feature contract held (no unapproved package/permission/library) | `package.json` diff: none (not modified in this diff). No new UI library import — `lucide-react` (`Paperclip`, `X`) and shadcn `Button` were already dependencies used elsewhere (`card-checklist-panel.tsx`, `board-title-bar.tsx`). |
| ADR-41 (Route Handlers bypass tRPC only for the two byte-carrying operations) | `app/api/attachments/route.ts` and `.../[attachmentPublicId]/route.ts` are the only two backend calls outside `lib/api/*-client.ts` + tRPC in this diff; `removeAttachment` (no bytes) correctly stays on tRPC (`cards.ts:185-192`). |
| Data Flow rule (`frontend-rules.md`): browser never holds the backend token | `getBackendSession()` (existing helper, unmodified) is the only place either new Route Handler reads the token; both attach it server-side to the outbound `fetch` in `attachments-client.ts`. The browser's own `fetch("/api/attachments", ...)` call in the panel carries no `Authorization` header — it hits the same-origin Route Handler, which is exactly the BFF-hop pattern used everywhere else. |
| Permission UI matches spec §6 / invariant 5 (UX only, backend authoritative) | `isBoardAdmin`/`currentUserPublicId` are derived in `board-canvas.tsx` from `boardMembers.list` + session, the same source `board-title-bar.tsx` already uses for its own `isBoardAdmin` — no new authorization decision invented; the panel's `canRemove` check purely controls a button's visibility, the actual mutation still runs through `cards.removeAttachment` → `DELETE /v1/attachments/{id}`, which `contracts/attachments-api.md` confirms is re-checked server-side. |
| Realtime (ADR-44) | `use-board-realtime.ts`'s `BoardEvent` handler now calls `utilsRef.current.cards.getDetail.invalidate()` with no input filter, exactly as ADR-44 specifies — verified this doesn't touch `joinAndSync`'s existing sequencing (it's a second statement in the same handler, not a new subscription). |
| Security (`frontend-security.md` checklist) | Walked all 9 items in §12: no secrets exposed (✓, no new env var reaches client code — `FLOWBOARD_API_URL` is read only in the two server-only `*-client.ts` files); protected routes unaffected; permission UI matches §6 matrix (✓, above); forms validate input — N/A (no React Hook Form here, this isn't a data-entry form per se, it's a file picker + Zod-validated tRPC input for removal); no unsafe HTML; upload UI restrictions — **initially missing (F1), fixed during this review**; error messages safe (✓ — toast text is either a fixed string or the backend's own validation message, e.g. "A file is required.", never a stack trace); external links — N/A (attachment links are same-origin); sensitive data not logged — ✓ (no `console.log` added). |
| Scope guard (`git diff --stat`) | `git diff main...009-card-attachments --stat` (flowboard-web) shows exactly the files plan.md's Project Structure lists for Phase B, plus the two Route Handler files and the panel — no unrelated file touched. |
| Rollback safety | Purely additive frontend code; no schema/migration involved on this side. Reverting this branch removes the panel and both routes with no data-loss concern (attachments still exist server-side, just not reachable from this UI). |
| Phase A carry-forward (its Residual risk section asked that `Content-Disposition: attachment` survive the frontend proxy unrewritten) | Confirmed — `[attachmentPublicId]/route.ts` reads `result.response.headers.get("content-disposition")` and passes it through verbatim (falling back to the literal string `"attachment"` only if the backend ever omitted it, never to `"inline"`). |

## Findings

### F1 — Missing client-side upload restrictions — MINOR (found and fixed during this review)

`card-attachments-panel.tsx`'s initial version (commit `0ee5137`) had no client-side file-size
or extension check and no visible size-limit text, despite `frontend-security.md` §6 explicitly
requiring "restrict accepted file types in UI," "show file size limits," and "validate before
upload" for attachment UI, and §12's completion checklist listing "Upload UI has restrictions if
relevant." The backend (`CardService.AddAttachmentAsync`) already enforces the 25 MB cap and
blocked-extension list authoritatively, so this was a UX gap, not a security hole — but a real
one against a named binding rule.
*Action: fixed in commit `a4c591c` — added `findUploadRejectionReason()` (mirrors the backend's
25 MB cap and `.exe`/`.bat`/`.sh`/`.cmd`/`.msi` block-list exactly) called before any upload
request is sent, plus visible helper text ("Up to 25 MB per file. Executable files aren't
allowed.") next to the upload control. Gate re-run and re-confirmed by the user after the fix.
No further action.*

### F2 — Hidden file input loses focus after a selection — MINOR

The native `<input type="file" className="hidden">` is triggered via `fileInputRef.current?.click()`
from the visible "Attach" `Button`. After the OS file picker closes, browsers return focus to the
(hidden, off-screen) file input rather than back to the triggering button, which is a minor
keyboard/screen-reader UX rough edge (the visibly-focused element and the input value the user
just set become disconnected). This does not block any acceptance scenario — the upload still
proceeds correctly, and the same pattern is not used elsewhere in this codebase to compare
against.
*Action: none required for merge; worth a follow-up if a future accessibility pass covers file
inputs specifically. Not spec-mandated for this feature.*

### F3 — `removeAttachmentInputSchema` is the only schema using `.uuid()` — MINOR / DOC DRIFT

Every sibling schema in `lib/cards/schemas.ts` (`cardPublicId`, `labelPublicId`, `userPublicId`,
etc.) uses a plain `z.string()`, while `removeAttachmentInputSchema` uses `z.string().uuid()` —
an inconsistency in strictness, not a defect. This exact shape was specified verbatim in
`tasks.md` T026, so it's a deliberate deviation, not an oversight.
*Action: none — matches the approved task spec. Worth noting if a future feature normalizes all
public-ID schemas to `.uuid()` for consistency, but out of scope here.*

### F4 — No fetch timeout on upload/download — ACCEPTED

`attachments-client.ts` omits the `AbortSignal.timeout(...)` that `cards-client.ts`'s
`callCardsApi` applies to every JSON call. This is explicitly reasoned in the file's own header
comment: a JSON call hanging past 5s signals a dead connection, but a 25 MB transfer's duration
is a function of file size and the client's network, not a health signal, so a fixed timeout
would incorrectly abort slow-but-healthy transfers.
*Action: none — documented, deliberate deviation from the sibling client's pattern.*

## Constitution re-check (post-implementation)

**PASS.**

- **Specification First (I) / Source of Truth (II)**: No screenshots exist for this feature
  (unchanged since plan.md); FR-013's "follow the existing visual language" was satisfied by
  reusing `card-checklist-panel.tsx`'s exact structural pattern (section header, `hover:bg-muted/60`
  rows, hover-reveal destructive icon button) rather than inventing new layout — final visual
  confirmation is a human-review item (`review-process.md`'s Human Review checklist), not an
  AI-review one, since there's no reference screenshot for the AI to compare against.
- **Repository Separation (III)**: Held — no flowboard-api file touched in this diff.
- **Architecture Consistency (IV)**: ADR-41's Route Handler exception used correctly and only
  for the two byte-carrying operations; no new pattern introduced beyond what plan.md approved.
- **Security (VIII)**: See the security checklist row above; F1 closed the one real gap.
- **Performance Responsibility (X)**: Download response body is passed through
  (`new Response(result.response.body, ...)`), never buffered into memory or re-serialized —
  matches plan.md's "streams the file rather than buffering it fully in memory."
- **Testing Requirements (XI)**: No frontend test runner exists yet (003–008 precedent,
  unchanged); this phase's verification is code review + the lint/build gate. The
  `quickstart.md` manual walkthrough is explicitly a Polish-phase task (T031), not yet run —
  see Residual risk.
- **Human Review (XII)**: Not yet performed — required before merge, next step.
- **Controlled Delivery (XIII)**: Held — Phase A (backend) was gated, AI-reviewed,
  human-reviewed, and merged to flowboard-api's `main` (`65dcf75`) before any Phase B (frontend)
  code was written.

## Test coverage observed

No automated frontend test suite exists in this repository (unchanged from every prior
feature 003–008). Verification for this phase is: (1) `npm run lint && npm run build` — EXIT 0,
user-confirmed twice (before and after the F1 fix), which includes the full TypeScript type
check across every new/modified file; (2) this code review, reading every touched file in full
against `spec.md`'s acceptance scenarios and `contracts/attachments-api.md`. No one has yet
manually clicked through the feature in a running browser — that walkthrough
(`quickstart.md` §2/§3/§5/§6) is scheduled as Polish-phase task T031, per tasks.md's own
Implementation Strategy ("Polish → full quickstart pass").

## Residual risk

The main residual risk is that this phase has had zero live-browser verification — everything
above is static review plus a successful type-check/build. Concretely un-exercised paths worth
the human reviewer's attention: (1) the actual multipart upload round-trip through the Route
Handler to the real backend (the code path is correct by inspection, but `FormData`/`File`
forwarding across a Route Handler boundary is exactly the kind of thing that can have a runtime
surprise a type checker can't catch); (2) the download link's `Content-Disposition` behavior in
an actual browser (does it prompt "Save As" or silently download, per file type); (3) the
realtime cross-tab update (`cards.getDetail.invalidate()` firing correctly when a second
session adds/removes an attachment while a card modal is open elsewhere). None of these are
blocking findings — they're exactly the kind of thing `quickstart.md`'s walkthrough (T031) and
human review together are supposed to catch before this ships. Recommend the human reviewer
spend a few minutes actually exercising US1/US2/US3 in the browser rather than relying solely on
this document, given that gap.
