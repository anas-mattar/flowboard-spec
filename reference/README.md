# Reference Rule Packs (shop standards — read second, not first)

These packs are the shop's proven rulebooks, imported 2026-08-27 from the FMS project.
They are **reference material**: the binding rules for FlowBoard are the tier rulebooks
one level up (`docs/rulebooks/backend-rules.md`, `frontend-rules.md`, `database-rules.md`)
and their compliance checklists. Where a pack and a FlowBoard rulebook disagree, the
rulebook wins; where both are silent, the constitution and
`docs/domain/flowboard-invariants.md` win.

Reading notes:

- Text mentioning **FMS, journals, periods, COA, legal entities, finance protection**
  is FMS domain content — it does not apply here. FlowBoard's equivalent of "entity
  scope" is **board membership scope** (invariant 5).
- `backend/database-table-catalog.md` is the FMS table catalog — kept only as a format
  example for a future FlowBoard catalog; none of its tables exist here.
- `backend/external-api-rules.md` and `backend/integration-patterns.md` apply when
  FlowBoard's first external integration is specced (the integration tier is currently
  deferred — see `docs/roadmap.md` decisions log).
- Paths inside these packs (`docs/frontend/...`, `docs/backend/...`) are FMS repo paths;
  FlowBoard's equivalents live under `docs/rulebooks/`.
