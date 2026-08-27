# Rulebooks — Pick Your Tiers

This directory is a **menu, not a requirement.** A *tier* is one kind of deliverable code
(a backend, a web frontend, a mobile app, a database, the seams between them). A *rulebook*
is one short file of MUST / MUST NOT rules for one tier of **one** project.

At adoption you pick only the tiers your project actually has; everything you did not pick
is deleted and never mentioned again. A backend-only service ends up with one or two
rulebooks. A backend + mobile project gets no frontend rules forced on it. That is the whole
mechanism for staying general across stacks — the kit fixes the *shape* of a rulebook, and
each project supplies the *content* for its own stack (PHP, .NET, Java, Python, anything).

## The menu

| Your project has… | Start from |
|---|---|
| A backend / API / service tier | `backend-rules-template.md` |
| A web frontend | `frontend-rules-template.md` |
| A mobile app | `mobile-rules-template.md` |
| A database it owns | `database-rules-template.md` |
| Tiers talking to each other, or an external API | `integration-rules-template.md` |
| (every project) CLAUDE.md's Stack Profile section | `stack-profile-template.md` |

Common shapes, fully supported:

- **Backend + web** → backend, frontend, database, integration
- **Backend + mobile** → backend, mobile, database, integration
- **Backend + web + mobile** → all five
- **Frontend-only** (consumes an API someone else owns) → frontend, integration
- **Backend-only service** → backend, database (integration too if it calls other systems)

## Instantiating a rulebook (three steps)

1. **Copy** the template to **docs/rulebooks/[tier]-rules.md** in your project.
2. **Fill** the `{{SLOT}}`s with what *your* stack actually does, and delete every baseline
   rule that is not true for your codebase. On an existing system, write rules
   **descriptively** — codify what the code already does, never what you wish it did
   (`adoption/existing-system.md`, step 7).
3. **Wire** it in: one row per tier in CLAUDE.md's Task-Scoped Reading table; delete the
   rows for tiers you don't have. Every path in that table must resolve.

After that the rulebook belongs to the project: it grows reactively (a class of mistake
caught twice in review becomes a rule — `adoption/greenfield.md`, step 6) and changes
through the project's normal review flow. The kit never sees it again.

## A tier with no template (worker, desktop, CLI, data pipeline, …)

Author your own: copy the closest template, or start from the universal skeleton below —
the same six questions every tier answers. Then wire it in exactly like step 3 above and
treat it as a first-class tier (its own compliance checklist, its own gate slice).

1. **Structure & placement** — where new code goes; what needs `plan.md` approval.
2. **Boundary** — what enters and leaves this tier; validation; the exact error shape.
3. **Domain logic** — the invariants pack applies here too; culture-invariant parsing;
   shared calculations live in one module.
4. **State & data** — how this tier reads, writes, and caches state.
5. **Testing** — the tier's test standard and its slice of the gate command.
6. **Security** — where secrets come from; what must never be stored, logged, or shipped
   in this tier.

The format is fixed even when the content is yours: every rule is MUST / MUST NOT with a
one-line **Why**, and no "prefer X" advice — advice is what agents drop first under pressure.

## Enforcement

Rulebooks explain; checklists assert. Each tier's rulebook is enforced through a compliance
checklist built from `compliance-checklist-template.md` (Definition of Done item 5,
`docs/sdlc/definition-of-done.md`). Where a lint or analyzer rule can enforce a rule, add it
and delete the checklist item — machine enforcement beats prose.
