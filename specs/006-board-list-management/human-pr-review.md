# Human PR Review — 006 Board & List Management

**Reviewer**: [fill in]
**Date**: [fill in]
**AI review**: `specs/006-board-list-management/review-notes.md` — Phase A verdict
APPROVE (no BLOCKING findings; F1 RowVersion-exposure addition and F2 ETagHeader
extraction both ACCEPTED with rationale, F2 flagged as touching a file outside
tasks.md's named list for reviewer awareness). Phase B verdict APPROVE (F1 sidebar
invalidation bug found-and-fixed; F2 references the Visual Compliance Loop's four
fixed deviations plus one user-approved deviation, VI-004's board-delete icon).

## Phase A — Backend (all 9 write paths)

### Business Review

- [ ] Behavior matches the business intent in `spec.md` (not just the letter of the FRs)
- [ ] Domain correctness verified for business-critical outputs (spot-check real figures/cases)
- [ ] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred

### UI Review

*Deleted — no UI in Phase A (backend only); the UI review applies to Phase B.*

### Technical Review

- [ ] Code diff read end-to-end; no unrelated changes (`git diff --stat` matches the
      phase scope — note `Endpoints/CardsEndpoints.cs` is touched too, per F2, a
      disclosed refactor not in tasks.md's original file list)
- [ ] Architectural compliance (constitution IV) — no unapproved patterns/packages
- [ ] Security implications considered (authz on new surface, secrets, logging)
- [ ] Migrations/schema changes are additive or their rollback is documented
      (`AddBoardListRowVersion` — additive only, reviewed above)

## Gate Result

- [ ] Gate run **by the reviewer or user** (not the AI); exit code: `EXIT: ___`
      (`cd flowboard-api && dotnet build --warnaserror && dotnet test`)

## Approval

**Decision**: [APPROVED / CHANGES REQUESTED] — merge only on APPROVED (constitution XII).

## Comments

[Anything the next person touching this area should know.]

---

## Phase B — Frontend (all 9 UI surfaces, Visual Compliance Loop)

### Business Review

- [ ] Behavior matches the business intent in `spec.md`
- [ ] UI matches the reference screenshots — the Visual Compliance Loop's deviation
      table (`review-notes.md`) has four fixed rows and one user-approved row (VI-004's
      board-delete icon, absent from the reference because the prototype predates
      board-delete UI entirely)
- [ ] **Recommended**: open the running dev server and eyeball the list "⋯" popover
      once — this session's own browser tooling could not capture a final post-fix
      screenshot (documented in `review-notes.md`'s Visual Compliance Loop section);
      the fixes were verified by code review and content-level checks only
- [ ] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred

### UI Review

- [ ] Actual rendered UI compared against the visual references (not just the code)
- [ ] Loading / empty / error states behave sensibly

### Technical Review

- [ ] Code diff read end-to-end; no unrelated changes (`git diff --stat` matches the phase scope)
- [ ] Architectural compliance (constitution IV) — no unapproved patterns/packages
- [ ] Security implications considered (authz on new surface, secrets, logging)
- [ ] No migrations this phase

## Gate Result

- [ ] Gate run **by the reviewer or user** (not the AI); exit code: `EXIT: ___`
      (`cd flowboard-web && npm run lint && npm run build`)

## Approval

**Decision**: [APPROVED / CHANGES REQUESTED] — merge only on APPROVED (constitution XII).

## Comments

[Anything the next person touching this area should know.]
