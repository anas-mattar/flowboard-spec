# [Tier] Compliance Checklist — MANDATORY

> **Binding**: This checklist is part of Definition of Done item 5
> (`docs/sdlc/definition-of-done.md`). The AI completes it for every phase touching this
> tier and records the result in the phase's review notes. **Any FAIL blocks the phase.**
>
> **Adopted**: [YYYY-MM-DD, feature NNN]. Code merged before this date is grandfathered:
> it is brought into compliance only when a feature touches it, never as a drive-by refactor
> (constitution XIII).

<!--
HOW TO WRITE THIS CHECKLIST (then delete this comment):

1. One section per concern (structure, data flow, forms, tables, state/auth, security &
   performance). Each section header links the deeper rulebook it enforces — the checklist
   POINTS at rules, it does not restate them.
2. Every item is a binary, AI-checkable assertion about the diff ("Zod schemas live in
   lib/<feature>/schemas.ts", "no hand-rolled <table> markup") — not advice ("prefer X").
3. Grow it reactively: when review catches a class of mistake twice, it becomes an item —
   and, where possible, ALSO a lint rule, so the checklist item can eventually be deleted.
4. Keep the closing ## Process section below — it is stack-independent and stays.
-->

## Structure ([link to the tier's rules doc])

- [ ] [Binary assertion about file/folder placement]
- [ ] [Binary assertion about module boundaries]

## Data Flow ([link])

- [ ] [Binary assertion — e.g. "no direct backend fetches from UI code; all calls go
      through the approved client layer"]

## [Concern] ([link])

- [ ] [Binary assertion]

## Security & Performance ([link])

- [ ] No secrets or server-only env vars reach client code
- [ ] Loading / empty / error states exist for every new data surface
- [ ] [Stack-specific items]

## Process

- [ ] No new packages beyond those approved in the feature's `plan.md` (constitution IV)
- [ ] Only the approved phase's files changed (`git diff --stat` reviewed)
- [ ] Gate run by the user with confirmed exit code 0 (constitution XIII)

---

*Worked example: the reference deployment's frontend checklist enforced — via section links
to its forms/tables/tRPC rulebooks — React Hook Form + zodResolver for all data-entry forms
(manual `useState` field state forbidden), composition of a shared `QueryDataTable` base
(hand-rolled `<table>` markup forbidden), Zod schemas in `lib/<feature>/schemas.ts`, all
backend calls through tRPC procedures and server-only API clients, and permission-gated
rendering via shared `RequirePermission` components.*
