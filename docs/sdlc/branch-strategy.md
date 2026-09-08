# Branch Strategy

Authoritative branch naming and spec-path convention. This kit adopts the **stock Spec Kit
convention** so the bundled scripts (`.specify/scripts/powershell/`) and `/speckit.*` commands
work unmodified: numbered feature branches map 1:1 to numbered spec directories.

## Decision

Feature branches are named **`NNN-short-name`** (three-digit sequential number + kebab-case
slug, e.g. `001-solution-scaffold`, `014-trial-balance`). The feature directory is
`specs/NNN-short-name/` — the same string as the branch name. Branches and spec directories
are created together by `/speckit.specify` (via `create-new-feature.ps1`), which allocates the
next number automatically.

> Do NOT hand-invent a different layout (e.g. nesting specs under an extra folder, or
> unnumbered descriptive branches). The Spec Kit scripts resolve the feature directory as
> `specs/<branch>` and reject branches that don't start with `NNN-`; a divergent convention
> silently disables the whole tooling layer.

## Number Allocation

`create-new-feature.ps1` allocates the next number from the **local** `specs/` directory —
fine for one developer, a collision for a team. With more than one developer, the remote is
the ledger. **The standard way to run this ritual is one command**:

```powershell
pwsh -File scripts/claim-feature.ps1 -ShortName <name> "<feature description>"
```

It fetches, allocates the next number free across local and remote branches and `specs/`
directories, delegates branch + spec creation to `create-new-feature.ps1`, pushes the
claim immediately, and renumbers automatically if another claim reached the remote first.
The manual recipe it automates (kept as the fallback):

1. `git fetch origin` before allocating.
2. Take the next number unused by any local **or remote** branch or spec directory
   (`git branch -r` / `git ls-remote --heads origin`).
3. **Push the branch immediately** (`git push -u origin NNN-<name>`) — the number belongs
   to whichever branch reaches the remote first. If you lose the race, renumber before any
   other work.

The rest of the multi-developer rules live in `docs/sdlc/team-workflow.md`.

## Branch Taxonomy

| Pattern | Use for | Spec dir? | Example |
|---------|---------|-----------|---------|
| `NNN-<name>` | New functionality / a deliverable feature (full spec workflow — or a single-page mini-spec alone when declared Micro) | `specs/NNN-<name>/` | `007-user-invitations` |
| `fix/<name>` | Bug fix or correction (incl. post-merge reverts) | no (lightweight lane) | `fix/aging-rounding` |
| `chore/<name>` | Tooling, config, maintenance (no behavior change) | no (lightweight lane) | `chore/upgrade-orm` |
| `docs/<name>` | Documentation / governance only | no (lightweight lane) | `docs/onboarding-guide` |

`<name>` is lowercase, kebab-case, descriptive, and stable for the life of the branch.

**Lightweight lane** (`fix/`, `chore/`, `docs/`): skips spec.md/plan.md/tasks.md, but still
requires the user-run gate, the `git diff --stat` scope check, and human review before merge.
If a "fix" grows into behavior change or schema change, stop and promote it to a numbered
feature.

**Delivery levels**: the kit has four, in ascending ceremony — **Lite < Micro < Standard <
Critical**. **Lite** is the lightweight lane above (`fix/`, `chore/`, `docs/` — no spec
directory). **Micro** is a numbered feature whose entire specification is a single-page
mini-spec (`spec.md` from `.specify/templates/micro-spec-template.md`, declaring
`**Delivery Level**: Micro`) delivered in exactly one phase inside hard bounds — at most
5 territory files and 400 changed lines, machine-enforced (constitution X, Micro lane).
**Standard** is the full numbered-feature workflow; it is the default for any numbered
feature without a declared level. High-risk work uses **Critical**: a numbered feature
plus the addendum in `docs/sdlc/critical-delivery.md` — Critical MUST NOT use the Micro
lane. The level is chosen per feature, not per project, declared in the feature's
`spec.md` at creation.

Boundaries between neighbors: **Lite vs Micro** — Lite is for work with no behavior
change (tooling, docs, straightforward bug corrections); the moment a small change alters
behavior, it is at least Micro — behavior change always gets written, approved intent. **Micro vs
Standard** — Micro requires fitting every bound (one phase, ≤5 files, ≤400 lines, and the
mini-spec's eligibility checklist: no schema/packages/architecture/domain-invariant/
visual-reference surface); anything larger, or any feature needing phases or planning, is
Standard. A Micro feature that outgrows its bounds mid-flight is **promoted in place to
Standard** (full spec + plan.md + tasks.md, committed before any further phase commit) —
exactly like promoting a `fix/` branch that grew into a feature.

## Rules

- `main` is **protected**. No direct commits to `main`.
- **One branch per feature.** Do not bundle unrelated work onto a single branch.
- Merge to `main` only **after the gate is certified (user-confirmed exit code — or,
  under a plan-declared `ci-held`, the owner's recorded approval on the CI evidence
  triplet) and human review is approved** (see `docs/sdlc/review-process.md`,
  `docs/sdlc/gate-command.md`, constitution IX–X).
- **Push the feature branch to `origin` before merging.** Once a feature is complete
  (gate green + human review approved), push the feature branch to its remote
  (`git push -u origin <branch>`) so the branch and its per-phase history are
  preserved on the server. Then merge to `main` with `--no-ff` (keeping the feature
  merge commit), and push `main`. For cross-repository features, do this in **each**
  repository (see `docs/sdlc/repository-strategy.md`).
- Never force-push `main`.
- Each implementation phase is its own commit on the feature branch so a bad phase
  reverts cleanly (see `docs/sdlc/rollback-process.md`).

## Spec Directory Contents

```text
specs/NNN-<name>/
├─ spec.md
├─ plan.md
├─ tasks.md
├─ research.md            (optional)
├─ data-model.md          (optional)
├─ contracts/             (optional)
├─ quickstart.md          (optional)
├─ notes.md               (optional)
├─ screenshots/           (optional — visual references, when the project has them)
├─ checklists/            (optional)
├─ ai-code-review.md      (per-feature; from specs/_templates/)
├─ human-pr-review.md     (per-feature; from specs/_templates/)
└─ rollback.md            (per-feature; from specs/_templates/)
```

A **Micro** feature's directory holds `spec.md` (the mini-spec) plus the per-feature
review files only — no `plan.md`/`tasks.md` until promoted to Standard (constitution X,
Micro lane).

## Cross-Repository Features

When a feature spans backend and frontend, create matching branches in each
repository using the same `NNN-<name>`, and follow the cross-repository feature rule in
`docs/sdlc/repository-strategy.md` (backend contract defined before frontend
implementation; backend merged after gate + review).
