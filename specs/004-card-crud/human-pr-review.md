# Human PR Review — 004 Card Lifecycle CRUD

**Reviewer**: anas.m
**AI review**: `specs/004-card-crud/review-notes.md`

## Phase A — backend (Foundational + Card Mutations) (T001–T030)

**Date**: 2026-08-28
**AI review read**: Phase A section of `review-notes.md` — verdict PASS (one gap found
and fixed within the review: checklist unchecking wrote no `ActivityEvent`, now covered
by `checklist.item.unchecked`), one accepted performance tradeoff (shared tracked
card-resolver used by the read path too), no other FAIL/waivers.

### Business Review

- [x] Behavior matches the business intent in `spec.md` (US1–US8's backend half: create,
  view detail, edit title/description/due date, labels/members, checklist, comments +
  activity, copy/delete)
- [x] Domain correctness verified for business-critical outputs — invariant 7 (label
  board-scoping), invariant 5 (member auto-add-to-board side effect), invariant 1
  (append-only activity, including the fixed unchecked-event gap), invariant 6 (`ETag`/
  `If-Match` optimistic concurrency), invariant 2 (all position math via `Ordering.cs`)
- [x] No open questions from the AI review are outstanding

### Technical Review

- [x] Code diff read end-to-end; no unrelated changes (diff surface matches
  `review-notes.md`'s listing — new schema/service/endpoint/test files, plus the R-5
  `CardDueStatus` extraction from `BoardContentService`, a behavior-preserving refactor
  confirmed by 003's own `BoardsEndpointTests` still passing unmodified)
- [x] Architectural compliance (constitution IV) — no new packages; `Ordering.cs` fulfills
  001's ADR-4 reservation exactly as planned; `ActivityEvent` matches plan.md ADR-16
- [x] Security implications considered — every route resolves role via
  `BoardAccessService` before acting; Observer restricted to reads + comment; no new
  attack surface beyond what the contract defines
- [x] Migration is additive (`AddColumn` with a temporary default, backfilled via
  `UpdateData`, then a unique index; `CreateTable` for `ActivityEvent`); `Down()` is the
  standard reversal

### Gate Result

- [x] Gate run by the user: `dotnet build --warnaserror && dotnet test` in
  `flowboard-api` — **EXIT: 0** (2026-08-28, 71/71 tests)

### Approval

- [x] **Decision**: **APPROVED** (2026-08-28) — Phase A cleared for merge to
  `flowboard-api`'s `main` (cross-repository rule: backend merges before Phase B
  frontend work starts)

## Phase B — frontend (composer, card detail modal + 7 panels, client-driven canvas,
Visual Compliance Loop) (T031–T053)

**Date**: 2026-08-28
**AI review read**: Phase B section of `review-notes.md` — verdict PASS. Two real gaps
found and fixed within the review (a title-field double-save race causing a spurious
409 toast; three Visual Compliance Loop deviations — section-heading style, checklist
empty state, breadcrumb wording), one disclosed data-availability limitation (no
board-level label-listing endpoint exists in this feature's own contract), one disclosed
forms-convention split (RHF for new-record forms, plain `useState` for single-value
inline edits). No other FAIL/waivers.

### Business Review

- [x] Behavior matches the business intent in `spec.md` (US1–US8's frontend half,
  manually exercised end-to-end by the AI: add, open, rename, describe, label, assign
  member, due date set/complete, checklist add/check/uncheck, comment, copy, delete)
- [x] UI matches `screenshots/card-detail-modal.png` — the Visual Compliance Loop's
  deviation table (`review-notes.md`) is empty of unresolved rows; the primary-button
  color difference is explicitly not counted as a deviation (this app's own established
  monochrome color decision from 001–003, unchanged here)
- [x] No open questions from the AI review are outstanding

### Technical Review

- [x] Code diff read end-to-end; no unrelated changes (diff surface matches
  `review-notes.md`'s listing — new cards schema/client/router/composer/modal/panel
  files, plus the shared due-status extraction from `card-front.tsx`; 002/003's auth
  pages, sidebar, and top bar untouched)
- [x] Architectural compliance (constitution IV) — no new npm packages (a generated
  `calendar` primitive pulling in `react-day-picker`/`date-fns` was removed before
  committing, in favor of a plain `<input type="date">`); ADR-14 (client-side dialog
  state) and ADR-19 (client-driven canvas) match `plan.md`
- [x] Security implications considered — no backend token reaches the client bundle; no
  new `dangerouslySetInnerHTML`. Observer-vs-Member/Admin **UI** gating was, at the time
  of this approval, believed to exist and backed by Phase A's server-side enforcement —
  this turned out to be wrong (see the Post-merge Fix section below, added after this
  approval); the server-side enforcement itself was never in question and held throughout
- [x] Accessibility spot-checked — Radix `Dialog`/`Popover` provide focus trap/restore;
  due-date/label/member indicators pair color with text or an icon, never color alone

### Gate Result

- [x] Gate run by the user: `npm run lint && npm run build` in `flowboard-web` —
  **EXIT: 0** (2026-08-28)

### Approval

- [x] **Decision**: **APPROVED** (2026-08-28) — Phase B cleared for merge to
  `flowboard-web`'s `main`

## Post-merge fix — Observer frontend permission gating

**Date**: 2026-08-28
**AI review read**: the "Post-merge fix" section appended to `review-notes.md` after
Phase B above was already merged and pushed. Manually testing `quickstart.md`'s own
Observer edge-case row surfaced that no frontend permission gating existed at all — the
"Permission gating hides/disables..." checklist item above had been marked PASS without
being verified. The backend's own enforcement (Phase A) was never at risk; only the
frontend UI failed to hide/disable what it should have.

### Business Review

- [x] Behavior now matches spec §6 / `quickstart.md`'s Observer row: verified live
  against a real invited Observer account — composer absent on every list; card modal
  shows read-only title/description, a read-only checklist with no add form, no "Add to
  card" panel; commenting still works
- [x] No open questions outstanding

### Technical Review

- [x] Code diff read end-to-end; no unrelated changes — `canMutate` computed once in
  `board-canvas.tsx`, threaded to `list-column.tsx` and every gated panel;
  `card-detail-modal.tsx` now takes it as a prop instead of computing its own
- [x] Security implications: UX-only change: hides controls the backend was already
  rejecting; no change to any backend enforcement path

### Gate Result

- [x] Gate run by the user: `npm run lint && npm run build` in `flowboard-web` —
  **EXIT: 0** (2026-08-28)

### Approval

- [x] **Decision**: **APPROVED** (2026-08-28) — follow-up fix cleared for a second
  commit on top of the already-merged Phase B, then merge/push
