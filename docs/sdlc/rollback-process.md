# Rollback Process

Prefer `git revert`. Each implementation phase is its own commit precisely so that a bad phase
reverts cleanly (see `docs/sdlc/branch-strategy.md`).

## Rollback Checklist

- Can this phase be reverted by commit?
- Did it change database schema?
- Is schema change additive or destructive?
- Are data migrations reversible?
- Are deployment rollback steps documented?

## Database

Do not drop tables/columns without explicit approval.

## Protected Domain Data

Some domain data must never be physically deleted as a rollback mechanism — see
`{{DOMAIN_INVARIANTS_PATH}}` (constitution VII). For such records:

- Never `DELETE` or `DROP` protected records to undo a change.
- Correct them with the domain's approved additive mechanisms (e.g. reversal, adjustment,
  void, cancellation, or status change) — each itself auditable.
- Reverting code or a migration MUST NOT cascade into physical deletion of protected records.
  If a rollback would require touching protected data, **stop and report**; resolve it through
  a correcting entry, not a delete.
- A rollback that cannot preserve protected-data immutability is not approved.

*(Worked example: in a financial system, posted journals are append-only; corrections are
reversals, never edits or deletes — see `modules/finance/finance-invariants.md`.)*
