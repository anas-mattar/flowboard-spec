# Roadmap — FlowBoard

> **This file carries no implementation authority.** Agents implement only from an
> approved `specs/NNN-name/spec.md`; this roadmap only says what to spec next. A roadmap
> row is never a requirement — if an agent is asked to implement from this file, it must
> stop and ask for a spec (constitution I).

## Inventory *(generated — regenerate freely)*

Every screen found in the prototype and every capability found in the functional spec.
Story-level detail lives in the spec's own IDs (B-*, L-*, C-*, F-*, X-*) — cite those in
`Covers` cells alongside the INV numbers.

**Generated from**: `docs/product/FUNCTIONAL_SPEC.md` §3–§8 + `docs/product/prototype/flowboard-prototype.html`
**Generated on**: 2026-08-27 — **by**: Claude, manual read of the spec and prototype

| Inv # | Screen / capability | Source |
|---|---|---|
| INV-001 | Sidebar (boards list, create board, collapse) | `FUNCTIONAL_SPEC.md §4.1` |
| INV-002 | Top bar (title, avatars, filter, search, theme) | `FUNCTIONAL_SPEC.md §4.2` |
| INV-003 | Filter chip bar | `FUNCTIONAL_SPEC.md §4.3` |
| INV-004 | Board canvas | `FUNCTIONAL_SPEC.md §4.4` |
| INV-005 | List (header, WIP counter, composer, ⋯ menu) | `FUNCTIONAL_SPEC.md §4.5` |
| INV-006 | Card front (labels, badges, avatars) | `FUNCTIONAL_SPEC.md §4.6` |
| INV-007 | Card detail modal | `FUNCTIONAL_SPEC.md §4.7` |
| INV-008 | Board stories B-01…B-06 | `FUNCTIONAL_SPEC.md §3.1` |
| INV-009 | List stories L-01…L-06 | `FUNCTIONAL_SPEC.md §3.2` |
| INV-010 | Card stories C-01…C-13 | `FUNCTIONAL_SPEC.md §3.3` |
| INV-011 | Search & filter F-01…F-04 | `FUNCTIONAL_SPEC.md §3.4` |
| INV-012 | Cross-cutting X-01…X-04 (toasts, theme, keyboard, sidebar collapse) | `FUNCTIONAL_SPEC.md §3.5` |
| INV-013 | Data model incl. ordering rules and activity events | `FUNCTIONAL_SPEC.md §5` |
| INV-014 | Permissions & roles | `FUNCTIONAL_SPEC.md §6` |
| INV-015 | API surface v1 | `FUNCTIONAL_SPEC.md §7` |
| INV-016 | Realtime & concurrency | `FUNCTIONAL_SPEC.md §7.1` |
| INV-017 | Non-functional requirements | `FUNCTIONAL_SPEC.md §8` |

## Roadmap *(authored — humans only, never regenerated)*

Thin vertical slices toward v1.0 (spec §10): foundations first, reads before writes.
v1.1+ scope (attachments, notifications, calendar/table views, automation) stays out of
this table until v1.0 ships.

Status flow: `idea → specified → in progress → shipped → dropped`

| Feature | Covers (Inv #) | Priority | Status | Owner | Spec |
|---|---|---|---|---|---|
| 001-solution-scaffold (architecture ADR, gate green end-to-end) | — (foundation) | P1 | shipped | anas.m | `specs/001-solution-scaffold/` |
| 002-auth-workspaces (auth, users, board membership, roles) | INV-014; B-05 | P1 | shipped | anas.m | `specs/002-auth-workspaces/` |
| 003-board-view-readonly (render seeded boards; theme; keyboard; Visual Compliance Loop vs prototype) | INV-001…006 render-only; B-01; X-02…X-04 | P1 | shipped | anas.m | `specs/003-board-view-readonly/` |
| 004-card-crud (composer, detail modal, labels, members, due date, checklist, comments) | INV-007; C-01, C-03…C-10, C-12, C-13; X-01 | P2 | idea | anas.m | — |
| 005-drag-drop-ordering (card/list drag, move-via-menu, ordering model) | C-02, C-11, L-03; INV-013 §5.1 | P2 | idea | anas.m | — |
| 006-board-list-management (board/list CRUD, star, archive, WIP limit, sort by due date) | B-02…B-04, B-06; L-01, L-02, L-04…L-06 | P2 | idea | anas.m | — |
| 007-search-filter (live search, label/member/due filters, chips, empty state) | INV-003; F-01…F-04 | P3 | idea | anas.m | — |
| 008-realtime-sync (websocket layer, concurrency rules) | INV-015 realtime part; INV-016 | P3 | idea | anas.m | — |

## Decisions log *(authored)*

- 2026-08-27 Layout: nested multi-repo — this governance repo + `flowboard-api` and
  `flowboard-web` nested inside and gitignored (expense-tracker pattern). Tiers: backend,
  frontend, database. Integration tier deferred until the first external contract exists.
- 2026-08-27 Reads before writes: 003 ships a read-only board view before any mutation
  feature; the Visual Compliance Loop runs there first against the prototype.
- 2026-08-27 Cross-cutting X-01 (action toasts) lands with the first mutation feature (004),
  not as its own feature.
- 2026-08-27 Spec §11 open questions (label scoping, hard vs advisory WIP, observer billing,
  data residency, archive retention) must be answered during constitution ratification /
  before the feature that touches each — L-04 already fixes WIP limits as advisory.
- 2026-08-27 v1.1+ scope (§10) deliberately excluded from the table above.
- 2026-08-27 Constitution v1.0.0 ratified. Decisions: PK = `INT IDENTITY` internal + opaque
  public identifier on every API-exposed entity (invariant 8); labels board-scoped (§11 Q1
  closed, invariant 7); archive restorability ≥ 30 days (§11 Q5 closed, invariant 4).
- 2026-08-27 Deferred as business (not engineering) questions: observer billing (§11 Q3),
  EU-only data residency at launch (§11 Q4). Revisit before 002-auth-workspaces ships billing-
  or hosting-relevant schema.
- 2026-08-27 Tier rulebooks + two compliance checklists authored from the team's existing
  engineering standards; the detailed rule packs live at `docs/rulebooks/backend/` and
  `docs/rulebooks/frontend/`, rewritten FlowBoard-specific (previous-project domain content
  removed). Adopted with them: the tRPC BFF pattern (browser → tRPC → server-only client →
  .NET API) as the frontend data flow — 001's plan.md ratifies it ADR-style per
  constitution IV.
