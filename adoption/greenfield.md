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
single-repo). Write the domain-invariants pack (**modules/finance/finance-invariants.md** is the
model — bold because you replace or delete it; `modules/**` is surgical) and point principle V at it. Bump to v1.0.0 with today's ratification date. Keep it
under ~20 principles — a constitution that says everything governs nothing.

## 2. Fill CLAUDE.md

Complete the Stack Profile (author it from **docs/rulebooks/stack-profile-template.md** — one
short, checkable block per tier) and the `{{..._PATH}}` slots in `CLAUDE.md`. Then **pick your
tiers** from the menu in **docs/rulebooks/README.md** — backend, frontend, mobile, database,
integration are templates, not requirements. Instantiate a rulebook only for each tier your
project actually has (copy the template to **docs/rulebooks/[tier]-rules.md**, keep only the
baseline rules that are true for your stack) and delete the Task-Scoped Reading rows for
tiers you don't have — every path in that file must resolve from day one. A tier with no
template (worker, desktop, CLI, …) is authored from the skeleton in the same README. Keep
the file thin; rules live in rulebooks, CLAUDE.md holds pointers.

Machine assist: `pwsh -File scripts/init-kit.ps1` does the mechanical part of steps 1–2 —
instantiates the selected tier rulebooks, wires the Task-Scoped Reading rows, fills
`{{PROJECT_NAME}}` and the repository slots, and writes **kit-adoption.json** (the durable
record of your name/topology/tier choices — the adoption doctor's source of truth,
owner-editable if tiers change later). **Two or more developers? Pass
`-Developers ada,grace` now** — a comma-separated list, which the initializer splits, so it
works under `pwsh -File` where PowerShell would otherwise hand the whole string over as one
name. Or hand-edit the record later: that array decides whether a **Critical** feature owes an
independent human review or the solo substitute (`docs/sdlc/critical-delivery.md` item 5). Left
undeclared it stays solo, which is the stricter arm — so declaring nothing is safe, and
declaring a team you do not have is not. Then it prints the judgment slots that remain yours
and finishes by running `scripts/verify-kit.ps1`, whose red verdict at that moment is your
remaining to-do list, not a failure. It never writes rulebook content or ratifies the
constitution.

**Normalizing externally authored rulebook content**: when a rulebook is seeded from material
written outside this kit (a prior project's rule pack, a team wiki export), normalize it
before it lands, or doc-lint fails on paths that don't resolve here: write paths that refer to
the adopter's code (not kit governance files) in **bold**, not backticks, and fill or remove
anything that looks like a `{{SLOT}}` placeholder. The authoring convention is documented in
`scripts/doc-lint.ps1`'s header comment.

## 3. Define and PROVE the gate

Fill the gate slots in `docs/sdlc/gate-command.md`, scaffold the empty project(s), and run the
gate until it exits 0 on the empty scaffold. **A gate that has never been green is not a
gate.** Do this before any feature — otherwise the first feature debugs the toolchain and the
feature at once.

**Record the proof** in **kit-adoption.json** (written by `init-kit.ps1`; shape documented in
`adoption/updating.md`): add a `gateProof` entry with the exact command, its exit code (0),
the date, and who ran it — never paste secrets into the command line. This is your
attestation; no tool writes it for you, and `scripts/verify-kit.ps1` (the adoption doctor)
fails until at least one exit-0 proof exists.

**Scaffolding-tool traps** — check these immediately after each scaffolding CLI runs, before
the first commit:

- **Env-file gitignore swallow**: some scaffolding tools (e.g. `create-next-app`) generate a
  `.gitignore` with a blanket `.env*` pattern that also excludes `.env.example`, silently
  dropping it from every commit. Run `git status --ignored` right after scaffolding and
  confirm `.env.example` is not listed as ignored; if it is, add a `!.env.example` negation
  line.
- **Skipped or re-initialized `git init`**: some scaffolding CLIs skip `git init` when run
  inside a directory that is already part of a git repository — or worse, initialize a stray
  nested repo. Run `git status` and `git rev-parse --show-toplevel` right after scaffolding and
  confirm new files appear as untracked additions at the expected parent-repo root, not inside
  a stray nested `.git`.
- **Scaffolder writes its own agent files**: some scaffolding CLIs (e.g. `create-next-app`)
  now generate `CLAUDE.md` / `AGENTS.md` inside the code repository, and some regenerate a
  marked block in them on every dev-server run. In the nested layout that puts a second,
  tool-authored agent file between the agent and the governance tree above it. Rewrite both
  to point at the parent repository's law, and keep your content OUTSIDE any regenerated
  marker block so it survives — deleting the block only re-creates it as an uncommitted
  change.
- **Strict-build flag fails on a transitive vulnerability**: if proving the gate trips a
  strict-build flag on a dependency the scaffold pulled in transitively, triage per
  `docs/sdlc/gate-command.md` ("Strict-build flags vs transitive-dependency
  vulnerabilities") — never by disabling the flag.

## 4. Ship `001-solution-scaffold` as a real feature

Run the full ritual on something harmless: `/speckit.specify` a scaffold feature, plan it,
task it, implement one phase, have the user run the gate, review, merge. This rehearses every
gear of the framework (branch → spec → phase → gate → diff → reviews → merge) while the
stakes are zero, and leaves the team knowing what "Done" feels like.

Rehearse the **amendment** ritual here too, because 001 is where it is free: the moment you
change an approved `spec.md`, `plan.md`, `tasks.md` or `contracts/`, the amended section carries
`**Amendment approved by**: <name>, <YYYY-MM-DD>` and the commit message names the same person —
and the agent implementing the change is never the one who approves it (constitution I,
Amendment authority; `scripts/enforcement-pack.ps1` grades it). A team that meets this rule at
feature 001 meets it as a habit; one that meets it at feature 004 meets it as a failing check on
a branch it has already written.

Two edits are deliberately *not* amendments, and 001 is where that is worth learning: approving
a `spec.md` or `plan.md` in the first place — the `**Status**: Draft` → `**Status**: Approved`
flip the templates ask for, alone in its commit — and ticking a task box. Everything else in
`spec.md`, `plan.md`, `tasks.md` and `contracts/` is. Evidence of what a phase actually found
belongs in `notes.md`, which is ungraded precisely so that recording it never costs an
approval (`docs/sdlc/branch-strategy.md`).

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
  When planning the first write slice, run the dedicated-database check in
  **docs/rulebooks/database-rules-template.md** (Setup) — or in the project's instantiated
  database rulebook — before its first migration.
- One deliverable per feature; one phase per commit.

## 6. Grow the rulebooks reactively

The tier templates in `docs/rulebooks/` seed each rulebook with structure and universal
baseline rules only — don't write project-specific rules up front. When review catches a
class of mistake **twice**, it becomes: (a) a MUST/MUST NOT rule in that tier's rulebook,
(b) a binary item in that tier's compliance checklist
(**docs/rulebooks/compliance-checklist-template.md**), and (c) where possible, a lint rule or
analyzer — machine enforcement beats prose. The checklist item can be deleted once the linter
owns it.

## 7. Keep the framework honest

From the first week:

- **Ritual checks in CI**: the kit ships `.github/workflows/ritual-checks.yml`, which runs
  `scripts/ritual-checks.ps1` (doc-lint + enforcement-pack + scope-check + scope-repos +
  digests + roadmap-claims + the adoption doctor in adopted projects) on every push to a
  governed branch. **Finishing adoption includes wiring `ritual-checks` as a required status
  check** (`docs/sdlc/branch-protection.md`); until then, or on a CI host other than GitHub
  Actions, run the same single command locally or from your CI:
  `pwsh -File scripts/ritual-checks.ps1` — the wrapper and CI produce identical verdicts by
  construction. Drift between docs and reality is the disease that kills rule-based
  frameworks; a check that runs only by discipline eventually doesn't run.
- **Multi-repo: give gate 4 reach into the code.** Declare the nested code repositories in
  **kit-adoption.json**'s `codeRepos` array (`init-kit.ps1` writes it for a `multi`
  topology) and copy **.github/workflows/code-repo-scope-check.yml.template** into each code
  repository, filling its two slots. Skip this and the scope check governs only the
  governance repository, leaving every code phase commit's territory reviewer-verified prose
  (`docs/sdlc/repository-strategy.md`, "Territory across repositories").
- **Check the `developers` array is right** (step 1 writes it). It decides which independence
  evidence a **Critical** feature owes. What the team check proves is bounded — two names in
  one file, written by the same team; it makes an omission falsifiable, it does not verify the
  review happened. See **adoption/updating.md** for the full table.
- **CI gate as second witness**: run the gate on every push. The owner-held certifying
  gate (user-run — or plan-declared `ci-held`, where the CI run itself becomes the
  approved evidence; `docs/sdlc/gate-command.md`) remains the trust ritual; CI catches
  the day someone skips it.
- **Institutional knowledge lives in the repo**, not in one person's chat memory: deployment
  residuals, protected test data, open sign-offs get a home under `docs/`.
