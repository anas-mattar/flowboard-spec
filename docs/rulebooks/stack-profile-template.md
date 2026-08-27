# Stack Profile — FlowBoard

> This template produces the content of CLAUDE.md's **Stack Profile** section — the few
> lines every agent session loads before touching anything. Fill it per tier your project
> has, delete the tiers it doesn't, keep the result under ~20 lines, and paste it into the
> `{{STACK_PROFILE}}` slot. The kit deliberately ships this as a template, not a library of
> pre-written stacks: the profile describes what YOUR project actually runs, pinned to the
> versions it actually pins — a pre-written profile would rot and lie.

<!-- HOW TO FILL (then delete this comment):
     One block per tier. Every line must be checkable against the repository — if the
     agent can't verify it (a version, a command, a path), it doesn't belong here.
     Anything longer than a line belongs in that tier's rulebook, not the profile. -->

## Per tier (repeat for each tier you have)

```text
<Tier>: <framework + pinned major version> → repo <repository, if multi-repo>
  Runtime / package manager: <e.g. .NET 10 SDK / node 22 + yarn 4.x (corepack)>
  Source roots: <where deliverable code lives, e.g. src/Api/, app/>
  Build: <exact command>        Test: <exact command>
  Gate slice: <this tier's contribution to docs/sdlc/gate-command.md>
  Dependency policy: <e.g. no new packages without plan.md approval — constitution IV;
                      lockfile committed; renovate/dependabot cadence if any>
  Known failure modes: <the 1–3 stack-specific traps agents hit here, e.g.
                        "corepack must be enabled or yarn resolves to 1.x">
```

## Worked example (delete)

```text
Backend: .NET 10 / ASP.NET Core Web API, EF Core, SQL Server → repo contoso-api
  Runtime / package manager: .NET 10 SDK
  Source roots: src/Api/, src/Domain/, src/Infrastructure/
  Build: dotnet build            Test: dotnet test
  Gate slice: dotnet build && dotnet test
  Dependency policy: NuGet packages require plan.md approval; central package management
  Known failure modes: EF migrations must be generated from src/Api as startup project

Frontend: Next.js App Router, TypeScript strict → repo contoso-web
  Runtime / package manager: node 22, yarn 4.x via corepack
  Source roots: app/, components/, lib/
  Build: yarn build              Test: yarn test
  Gate slice: yarn build && yarn typecheck && yarn lint && yarn test
  Dependency policy: packages require plan.md approval; yarn.lock committed
  Known failure modes: run corepack enable first, or yarn resolves to the global 1.x
```

## What the profile is NOT

- Not the rulebook — MUST/MUST NOT rules live in `docs/rulebooks/` per tier.
- Not the architecture — that is recorded ADR-style in the scaffold feature's `plan.md`
  (constitution IV, bootstrap clause) and followed thereafter.
- Not aspirational — on an existing system, describe what the code does today
  (`adoption/existing-system.md`, step 2 applies here too).
