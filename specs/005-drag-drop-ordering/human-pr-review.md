# Human PR Review — 005 Drag & Drop Ordering

**Reviewer**: anas.m
**Date**: 2026-08-28
**AI review**: `specs/005-drag-drop-ordering/review-notes.md` — APPROVE, no BLOCKING findings;
F1 (RowVersion bypass via `ExecuteUpdateAsync`) and F2 (duplicated `CanMutate` helper) both
ACCEPTED with rationale.

## Phase A — Backend (Card move + List move)

### Business Review

- [x] Behavior matches the business intent in `spec.md`: US1 (drag/reorder/move a card),
      US2's backend half (the "Move" menu calls the same endpoint), US3 (reorder lists) —
      all three are callable end-to-end through the API per `quickstart.md` §1's curl
      example and §3's backend-reachable rows.
- [x] Domain correctness verified: `card.moved` written only on an actual list change
      (never a same-list reorder), WIP limits never block a move, last-write-wins with no
      `409` ever on either move endpoint.
- [x] No open CONFIRM findings from the AI review to answer.

### UI Review

*Deleted — no UI in Phase A (backend only); the UI review applies to Phase B.*

### Technical Review

- [x] Code diff read end-to-end; matches the phase scope exactly (T001–T008,
      `flowboard-api` only) — no unrelated changes.
- [x] Architectural compliance: dedicated move endpoints (ADR-20), no `If-Match`/`409` on
      moves (ADR-21), minimal-API + service layer unchanged, no new package.
- [x] Security implications considered: both routes authorize per board role
      (`BoardAdmin`/`BoardMember` only; Observer `403`; no access `404`); no secrets or PII
      in the `card.moved` payload.
- [x] No migration this phase — nothing to assess for rollback.

## Gate Result

- [x] Gate run by the user; exit code: `EXIT: 0`

## Approval

**Decision**: **APPROVED** — merge `flowboard-api`'s `005-drag-drop-ordering` (Phase A) to
`main` now.

## Comments

Phase B (frontend) may now begin per `docs/sdlc/repository-strategy.md`'s
cross-repository rule — backend gates and merges first.

## Phase B — Frontend (card drag, "Move" menu, list drag, Visual Compliance Loop)

**Date**: 2026-08-29
**AI review read**: Phase B section of `review-notes.md` — verdict APPROVE. Visual
Compliance Loop passed with an empty deviation table on the first pass (VI-001–VI-009, no
fixes needed); frontend-compliance-checklist all PASS; one disclosed ACCEPTED finding
(F1 — list reorder/US3 has no keyboard/menu equivalent, a pre-approved `plan.md` ADR-23
scoping decision, not an implementation gap) surfaced for this review; dark theme left
unverified this session (low risk, no theme-conditional code added).

### Business Review

- [x] Behavior matches the business intent in `spec.md`: US1 (drag a card within/across
      lists), US2 (the "Move" menu, keyboard-operable), US3 (drag a list to reorder) — all
      three verified against the live app during the Visual Compliance Loop.
- [x] UI matches the reference screenshots — the Visual Compliance Loop's deviation table
      (`review-notes.md`) is empty; the reference prototype's more saturated accent color
      is explicitly not counted as a deviation (this app's own established monochrome
      color decision from 001–003, unchanged here).
- [x] F1 (list reorder has no keyboard equivalent) reviewed and accepted: confirmed the
      "Move" menu alone is a sufficient accessibility equivalent for this feature — no
      list-level keyboard equivalent required. *("Confirmed, Move menu alone is enough —
      go ahead.")*
- [x] No other open CONFIRM findings from the AI review to answer.

### Technical Review

- [x] Code diff read end-to-end (commit `1b939b2`); matches the phase scope exactly
      (T009–T021, `flowboard-web` only, 14 files) — no unrelated changes.
- [x] Architectural compliance: native HTML5 drag-and-drop, no new library (ADR-23);
      optimistic `boards.getContent` cache patch + snapshot-restore on both move mutations
      (ADR-22); no new npm package.
- [x] Security implications considered: no backend token reaches the client bundle;
      `canMutate` gates both new drag surfaces and the Move button the same way 004 gates
      every other mutating control — Observer gets neither a draggable card/list nor the
      menu.
- [x] Accessibility spot-checked: Escape closes the Move popover with no move (Radix
      `Popover`); opacity + outline are always paired with the drag interaction itself, not
      a standalone color cue.

## Gate Result

- [x] Gate run by the user: `npm run lint && npm run build` in `flowboard-web` —
      **EXIT: 0** (2026-08-29)

## Approval

**Decision**: **APPROVED** (2026-08-29) — Phase B cleared for merge to `flowboard-web`'s
`main`.
