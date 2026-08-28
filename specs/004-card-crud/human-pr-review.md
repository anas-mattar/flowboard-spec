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
