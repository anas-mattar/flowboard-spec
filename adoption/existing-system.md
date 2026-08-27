# Adoption Track B — Existing System

Adopting the framework on a living codebase is different from greenfield in one fundamental
way: **the codebase, not the documents, is the incumbent source of truth.** The sequence
below wraps governance around what exists before changing any of it.

## 0. Verify the kit copied completely

Same as greenfield step 0 — and it matters even more here, because an existing repository
already has files, so a half-copied kit is easy to miss in the noise. `.specify/` and
`.claude/` are **dot-directories** that file managers and naive copy globs silently skip;
without them the agent loses the `/speckit.*` commands and improvises its own structure.
Confirm `CLAUDE.md`, `AGENTS.md`, `.specify/memory/constitution.md`, `.specify/templates/`,
`.specify/scripts/`, `.claude/commands/`, `docs/sdlc/`, `docs/rulebooks/`,
`specs/_templates/`, and `scripts/doc-lint.ps1` all exist, then run
`pwsh -File scripts/doc-lint.ps1` — it asserts the kit's required paths exist and exits
non-zero on a partial install.

## 1. Start with a baseline audit feature — not code

Your first "feature" writes documents only:

- Inventory the stack, repositories, build/test commands, environments.
- Get the gate green **on untouched code** and record the command + exit code. If the gate
  can't go green as-is, fixing that is the first (and only) code change — nothing else ships
  over a red baseline.
- Write down the architecture as it actually is (a short technical-handover doc), including
  the parts you don't like.

## 2. Write the constitution DESCRIPTIVELY, not aspirationally

Codify the conventions the codebase already has — its real PK strategy, its real audit
columns, its real layering — even where they're imperfect. An aspirational constitution makes
the agent "improve" code it shouldn't touch; principle IV (Architecture Consistency) only
works when the constitution describes the actual architecture. Park the improvements you want
in a roadmap doc (`specs/_templates/roadmap-template.md` → copy to **docs/roadmap.md**; the
generated inventory / authored roadmap split matters — see the template); promote them to
constitutional rules only after a feature actually migrates the codebase to them.

## 3. Reverse-engineer reference docs for load-bearing logic

For every subsystem the agent will touch, extract the truth from wherever it lives (legacy
code, spreadsheets, an old prototype, tribal knowledge) into a citable reference doc under
`docs/`. This is what makes rung-checking possible: an agent can only "stop and report a
conflict" against a source of truth that exists in writing.

## 4. Golden-fixture tests BEFORE the agent touches critical logic

For business-critical calculations, add characterization tests first: feed real inputs,
pin the current outputs as exact expected values (to the cent, to the row). These tests
define "unchanged" — without them, an agent's silent behavioral drift is invisible until
production. Do this at feature 001, not after the first incident.

## 5. First agent features are read-only derivations

New views, reports, exports, and statements over existing data: full framework rehearsal,
zero mutation risk, and each one deepens the agent's (documented) understanding of the domain
before the first write slice.

## 6. Run a second-model adversarial audit early

Have a different model/agent audit the codebase and the new governance docs, prompted to
refute and find gaps. Convert every confirmed finding into a **numbered remediation feature**
that travels the normal spec → plan → phase → gate pipeline — never ad-hoc patches. Repeat
periodically; the audit → numbered-remediation loop is how the reference deployment closed
14 production-hardening gaps without ever bypassing its own process.

## 7. Grandfather deliberately

Adopt each compliance checklist with an explicit date and grandfathering rule (see
`docs/rulebooks/compliance-checklist-template.md`), and instantiate a rulebook for each tier
the system actually has — pick from the menu in `docs/rulebooks/README.md` —
**descriptively**: codifying the conventions the code
already has, exactly like the constitution (step 2): old code is brought into compliance only
when a feature touches it. This keeps "adopt the framework" from mutating into "rewrite the
system" — the drive-by refactor the framework exists to prevent.

Machine assist: `pwsh -File scripts/init-kit.ps1` handles the mechanical part — instantiates
the selected tier rulebooks, wires CLAUDE.md's rows, fills the name/repository slots — and
prints what remains for a human. The descriptive content of each rulebook is still yours to
write.

## 8. Keep the framework honest

Same as greenfield step 7: doc-lint in CI (every referenced path exists), CI gate as second
witness, and institutional knowledge (deploy residuals, protected data registers, open
sign-offs) in the repo — not in one person's chat memory.
