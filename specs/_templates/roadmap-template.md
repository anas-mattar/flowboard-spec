# Roadmap — [PROJECT NAME]

> **This file carries no implementation authority.** Agents implement only from an
> approved `specs/NNN-name/spec.md`; this roadmap only says what to spec next. A roadmap
> row is never a requirement — if an agent is asked to implement from this file, it must
> stop and ask for a spec (constitution I).

Copy this template to **docs/roadmap.md** when adopting the kit. Keep the two sections
separate: the **inventory** is generated and safe to regenerate; the **roadmap** is
authored by humans and MUST NEVER be regenerated — regeneration silently destroys
priority, sequencing, and scope decisions.

## Inventory *(generated — regenerate freely)*

Every screen found in the prototypes and every capability found in the docs. Mechanical,
no judgment. Record the generator command so regeneration is reproducible.

**Generated from**: [e.g. `docs/prototypes/*.html`, `docs/requirements/*.md`]
**Generated on**: [YYYY-MM-DD] — **by**: [command or agent prompt used]

| Inv # | Screen / capability | Source |
|---|---|---|
| INV-001 | [e.g. Invoice list screen] | `[docs/prototypes/invoices.html]` |
| INV-002 | [e.g. Aging report calculation] | `[docs/requirements/reporting.md §3]` |

## Roadmap *(authored — humans only, never regenerated)*

One row per candidate feature. `Spec` is filled when the feature is promoted via
`/speckit.specify`; from that moment the spec directory is the truth and this row is just
a pointer. Sequence thin vertical slices: foundations first, reads before writes
(`adoption/greenfield.md` step 5).

**Features map many-to-many to inventory items — never default to one page = one
feature.** A feature may cover several screens (login + forgot-password + reset = one
auth feature), and one screen may split into several features (a page's read-only view
ships before its edit actions — reads before writes). Group by entity + risk class;
split anything that crosses the read/write line. Every inventory id must appear in some
feature's `Covers` cell or be explicitly dropped in the decisions log.

Status flow: `idea → specified → in progress → shipped → dropped`

| Feature | Covers (Inv #) | Priority | Status | Owner | Spec |
|---|---|---|---|---|---|
| [Invoice list (read-only)] | INV-001 | P1 | idea | [name] | — |
| [Aging report] | INV-002 | P2 | specified | [name] | `[specs/004-aging-report/]` |

## Decisions log *(authored)*

Scope cuts and sequencing choices live here so a regenerated inventory can never erase
them. One line each, dated:

- [YYYY-MM-DD] [e.g. "Mobile layouts dropped from v1 — INV-014, INV-015 marked dropped."]
