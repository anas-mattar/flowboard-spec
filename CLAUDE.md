# CLAUDE.md

Guidance for AI coding agents working in this repository. This project uses a controlled
SDLC workflow with Spec Kit documents. Do not implement everything at once.

<!-- KIT NOTE (delete after adoption): this file is deliberately thin. It is the always-loaded
     core; everything else loads per task via the pointers below. Keep it under ~150 lines —
     when a rule wants to live here, ask whether it belongs in a task-scoped rulebook instead. -->

## Stack Profile

```text
Backend: .NET 10 / ASP.NET Core Web API, EF Core 10, SignalR, SQL Server → repo `flowboard-api/`
  Runtime / package manager: .NET 10 SDK / NuGet
  Build: dotnet build --warnaserror     Test: dotnet test
  Gate slice: dotnet build --warnaserror && dotnet test
  Dependency policy: NuGet packages require plan.md approval (constitution IV)
  Known failure modes: run dotnet-ef via the repo-local tool manifest (dotnet tool restore),
    never a global install; verify the target DB is empty/owned before the first `database update`

Frontend: Next.js 16 App Router, TypeScript strict → repo `flowboard-web/`
  Runtime / package manager: node 22 / npm (package-lock.json committed)
  Build: npm run build (includes type check)     Lint: npm run lint
  Gate slice: npm run lint && npm run build      (npm test joins once the first test exists)
  Dependency policy: packages require plan.md approval (constitution IV)
  Known failure modes: create-next-app's default .gitignore excludes `.env*` — commit
    `.env.example`, keep real env files ignored

Database: SQL Server — dev `(localdb)\MSSQLLocalDB`, db `flowboard-db`; tests use a
  disposable `flowboard-db-test`. Migrations: EF Core, generated from flowboard-api with
  the API project as startup project.

Source roots per repo are fixed by 001-solution-scaffold's approved plan.md (constitution IV
bootstrap clause) and recorded here once the scaffold merges.
```

## The Law

- Constitution: `.specify/memory/constitution.md` — supersedes everything, including this file.
  It is the project's ONLY constitution.
- Definition of Done: `docs/sdlc/definition-of-done.md` — the six gates every phase must pass.
- Gate command: `docs/sdlc/gate-command.md` — the user runs it; you never claim success
  without the user-confirmed exit code.

## Source of Truth Priority

1. `specs/[feature]/screenshots/` *(only if this project keeps visual references — else delete)*
2. `specs/[feature]/spec.md`
3. `specs/[feature]/plan.md`
4. `specs/[feature]/contracts/`
5. `specs/[feature]/data-model.md`
6. `specs/[feature]/tasks.md`
7. `specs/[feature]/research.md`, then notes

**Conflict rules**: if any two rungs conflict, stop and report — never silently choose.
Never invent a new UI layout when visual references exist.

## Feature Structure

Branch `NNN-name` maps to directory `specs/NNN-name/` — always, with exactly these names:

```text
specs/NNN-name/
├── spec.md          # first
├── plan.md          # second
├── tasks.md         # third
├── screenshots/     # visual references, if the feature has any
├── contracts/       # external/API contracts, if any
├── data-model.md    # if the feature touches data
└── research.md      # optional
```

This structure is law even when tooling is absent. If the `/speckit.*` commands are
unavailable (kit partially installed), do NOT invent a different layout: create this exact
structure manually from the templates in `.specify/templates/`, and report the incomplete
install so the user can finish it (see `adoption/`, step 0).

## Workflow

1. Check current branch and working tree; stop if unrelated uncommitted changes exist.
2. Run the baseline gate on untouched code.
3. One feature branch per feature (`docs/sdlc/branch-strategy.md`).
4. Create/update `spec.md`, then `plan.md`, then `tasks.md` (the `/speckit.*` commands do this).
5. Implement **one phase only**. UI phase with visual references? Run the Visual
   Compliance Loop (`docs/sdlc/review-process.md`) until the deviation table is empty or
   user-approved. Then stop and ask the user to run the gate.
6. User checks `git diff --stat`; fix only current-phase issues.
7. Commit the successful phase. AI review, then human review. Merge only after approval.

## Strict Rules

- Implement one phase only. Do not continue without user approval.
- Do not refactor unrelated files or change unrelated features.
- Do not add packages unless approved in `plan.md`.
- Do not change architecture unless approved in `plan.md`.
- Do not claim success until the user runs the gate and confirms the exit code.
- Domain invariants (`{{DOMAIN_INVARIANTS_PATH}}`) carry constitutional force.

## Task-Scoped Reading

Read the pack that matches what you are about to touch — not everything, every time:

| Touching… | Read first |
|---|---|
| Any phase (always) | This file + `docs/sdlc/definition-of-done.md` |
| Branching / starting a feature | `docs/sdlc/branch-strategy.md`, `docs/sdlc/repository-strategy.md` |
| Project with more than one developer | `docs/sdlc/team-workflow.md` |
| Backend / service logic | `docs/rulebooks/backend-rules.md` |
| A schema / migration | `docs/rulebooks/database-rules.md` + `docs/sdlc/rollback-process.md` |
| Domain-critical logic | `{{DOMAIN_INVARIANTS_PATH}}` |
| A feature declared Critical (regulated / high-risk) | `docs/sdlc/critical-delivery.md` |
| Frontend UI | `docs/rulebooks/frontend-rules.md` + `docs/rulebooks/` compliance checklist for that tier |
| Reviewing / finishing a phase | `docs/sdlc/review-process.md` + the templates in `specs/_templates/` |

<!-- Tier rows are a MENU, not a requirement: keep only the tiers this project has, and add
     a row per extra tier (e.g. "Mobile UI | docs/rulebooks/mobile-rules.md", or a worker/CLI
     rulebook authored from the skeleton in docs/rulebooks/README.md). Rulebooks are
     instantiated at adoption (step 2) and grown reactively (step 6). Until a rulebook
     exists, delete its row rather than pointing at a file that isn't there. Every path in
     this file must resolve — a broken pointer teaches the agent to distrust all of them. -->

## Repositories

- Backend: `flowboard-api`
- Frontend/app: `flowboard-web`
- Per `docs/sdlc/repository-strategy.md`; always confirm the active repository.
<!-- e.g. flowboard-api / flowboard-web, per docs/sdlc/repository-strategy.md.
     Single-repo projects: "This repository is the only repository." -->

When implementing a feature, always confirm which repository is active before changing files.
