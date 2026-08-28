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
