# Adoption Track A — New System From Scratch

The sequence below takes an empty repository to a working, gated delivery loop. Do the steps
in order — each one is the precondition of the next.

## 0. Verify the kit copied completely

`.specify/` and `.claude/` are **dot-directories** — file managers and naive copy globs
(`copy *`, drag-select) silently skip them. A partial install is worse than none: the agent
loses the `/speckit.*` commands and improvises its own structure. After copying, confirm
every one of these exists in the target project:

```text
CLAUDE.md                          AGENTS.md
.specify/memory/constitution.md    .specify/templates/   .specify/scripts/
.claude/commands/                  (the /speckit.* command files)
docs/sdlc/                         docs/rulebooks/
specs/_templates/                  scripts/doc-lint.ps1
```

Machine check: `pwsh -File scripts/doc-lint.ps1` — it asserts the kit's required paths
exist and exits non-zero on a partial install.

## 1. Ratify the constitution

Copy the kit, then fill every `{{SLOT}}` and `TODO(...)` in `.specify/memory/constitution.md`:
project name, PK standard, audit fields, repository names (or delete principle III for
single-repo). Write the domain-invariants pack (`modules/finance/finance-invariants.md` is the
model) and point principle VII at it. Bump to v1.0.0 with today's ratification date. Keep it
under ~20 principles — a constitution that says everything governs nothing.

## 2. Fill CLAUDE.md

Complete the Stack Profile (author it from `docs/rulebooks/stack-profile-template.md` — one
short, checkable block per tier) and the `{{..._PATH}}` slots in `CLAUDE.md`. Then **pick your
tiers** from the menu in `docs/rulebooks/README.md` — backend, frontend, mobile, database,
integration are templates, not requirements. Instantiate a rulebook only for each tier your
project actually has (copy the template to **docs/rulebooks/[tier]-rules.md**, keep only the
baseline rules that are true for your stack) and delete the Task-Scoped Reading rows for
tiers you don't have — every path in that file must resolve from day one. A tier with no
template (worker, desktop, CLI, …) is authored from the skeleton in the same README. Keep
the file thin; rules live in rulebooks, CLAUDE.md holds pointers.

Machine assist: `pwsh -File scripts/init-kit.ps1` does the mechanical part of steps 1–2 —
instantiates the selected tier rulebooks, wires the Task-Scoped Reading rows, fills
`{{PROJECT_NAME}}` and the repository slots — then prints the judgment slots that remain
yours. It never writes rulebook content or ratifies the constitution.

## 3. Define and PROVE the gate

Fill the gate slots in `docs/sdlc/gate-command.md`, scaffold the empty project(s), and run the
gate until it exits 0 on the empty scaffold. **A gate that has never been green is not a
gate.** Do this before any feature — otherwise the first feature debugs the toolchain and the
feature at once.

## 4. Ship `001-solution-scaffold` as a real feature

Run the full ritual on something harmless: `/speckit.specify` a scaffold feature, plan it,
task it, implement one phase, have the user run the gate, review, merge. This rehearses every
gear of the framework (branch → spec → phase → gate → diff → reviews → merge) while the
stakes are zero, and leaves the team knowing what "Done" feels like.

The scaffold feature's `plan.md` MUST record the selected architecture ADR-style — options
considered, the decision, and its consequences (layering, dependency direction, persistence
boundaries, error-handling strategy). Per the bootstrap clause of constitution principle IV,
this approved plan **is** the architecture until the scaffold merges; after that it is "the
existing architecture" every later feature must follow. There is no separate architecture
document to invent — the decision lives in the plan, where the Constitution Check already
reviews it.

## 5. Sequence thin vertical slices — foundations first, reads before writes

- Keep the feature queue in **docs/roadmap.md** (copy `specs/_templates/roadmap-template.md`);
  the roadmap carries no implementation authority — features become real via `/speckit.specify`.
- Foundations before domain logic: auth, core entities, permissions, reference data.
- **Read-only slices before write slices** for each domain area: a view/report over data
  teaches the agent (and validates the model) at zero risk before the first mutation ships.
- One deliverable per feature; one phase per commit.

## 6. Grow the rulebooks reactively

The tier templates in `docs/rulebooks/` seed each rulebook with structure and universal
baseline rules only — don't write project-specific rules up front. When review catches a
class of mistake **twice**, it becomes: (a) a MUST/MUST NOT rule in that tier's rulebook,
(b) a binary item in that tier's compliance checklist
(`docs/rulebooks/compliance-checklist-template.md`), and (c) where possible, a lint rule or
analyzer — machine enforcement beats prose. The checklist item can be deleted once the linter
owns it.

## 7. Keep the framework honest

From the first week:

- **Doc-lint**: a CI step (or scheduled check) asserting every path referenced by CLAUDE.md
  and the constitution exists. Drift between docs and reality is the disease that kills
  rule-based frameworks.
- **CI gate as second witness**: run the gate on every push. The user-run gate remains the
  trust ritual; CI catches the day someone skips it.
- **Institutional knowledge lives in the repo**, not in one person's chat memory: deployment
  residuals, protected test data, open sign-offs get a home under `docs/`.
