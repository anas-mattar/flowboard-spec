# Human PR Review — 009 Card Attachments (Phase A: Foundational + Backend US1/US2/US3)

**Reviewer**: anas.m
**Date**: 2026-08-31
**AI review**: `specs/009-card-attachments/ai-code-review.md` — read first. Verdict: APPROVE
with follow-ups (F1/F2 doc drift, F3/F4 minor, none blocking).

## Business Review

- [x] Behavior matches the business intent in `spec.md` (US1/US2/US3), not just the letter of
  the FRs
- [x] Domain correctness verified for business-critical outputs (spot-check: upload a real
  file, confirm it lists correctly, download it, remove it, confirm the activity feed)
- [x] Open questions / CONFIRM findings from the AI review are answered or explicitly deferred
  (F1–F4 are all no-action-required per the AI review; confirmed)

## UI Review

N/A for this phase — backend only, nothing rendered yet (Phase B covers the UI).

## Technical Review

- [x] Code diff read end-to-end (`git diff bfe1a7c..a64e621` in `flowboard-api`); no
  unrelated changes
- [x] Architectural compliance (constitution IV) — no unapproved patterns/packages beyond
  plan.md's approved ADR-40/41/42/43 (and F1's `.DisableAntiforgery()`, a corollary of ADR-41)
- [x] Security implications considered (authz on the three new endpoints, no secrets, no
  sensitive logging, `Content-Disposition: attachment` forces download rather than inline
  rendering of attacker-controlled content-type)
- [x] Migrations/schema changes are additive (`AddCardAttachments` — one new table, two
  `Restrict` FKs, no existing table/column touched) or their rollback is documented

## Gate Result

- [x] Gate run **by the reviewer or user** (not the AI): `dotnet build --warnaserror &&
  dotnet test` in flowboard-api — **EXIT: 0**, covering the full Phase A diff
  (`bfe1a7c..a64e621`).

## Approval

**Decision**: **APPROVED** — merge is clear from a review-process standpoint (constitution
XII).

## Comments

Phase A (Foundational + backend US1/US2/US3, T001–T019) is approved for merge to `main` in
`flowboard-api`. `ai-code-review.md`'s F1–F4 remain on record as non-blocking follow-ups;
F2 (contract wording) is worth revisiting during the Polish-phase docs pass (T031), and F1
(new research.md entry documenting the `.DisableAntiforgery()` discovery) is optional.
