# Repository Strategy

## Rule

Every deployable project has its own repository. Do not mix tiers in one repository unless
explicitly approved in `plan.md`. *(Single-repo projects: delete this file's multi-repo
sections and constitution principle III, and keep everything in one repository — the rest of
the kit works unchanged.)*

One repository per tier the project has — the tier set mirrors the rulebook menu
(`docs/rulebooks/README.md`): keep a repository (and a section below) for each tier you
actually have — backend, web frontend, mobile app, worker, … — and delete the rest. The two
sections below are examples of the shape; a mobile or worker repository gets the same
treatment.

```text
flowboard-api     # Backend repository
flowboard-web    # Frontend repository (and/or {{MOBILE_REPO}}, {{WORKER_REPO}}, …)
```

Optional shared documentation/spec repository, when specs and governance need a home that is
neither tier:

```text
{{SPECS_REPO}}       # Optional shared specs/documentation repository
```

## flowboard-api

Contains:

- {{BACKEND_STACK_ITEMS}} <!-- e.g. ASP.NET Core Web API, EF Core, SQL Server migrations -->
- Backend tests
- Database migrations

Does not contain:

- Frontend source code
- UI assets
- Frontend build tooling

## flowboard-web

Contains:

- {{FRONTEND_STACK_ITEMS}} <!-- e.g. Next.js App Router, TypeScript, tRPC client -->
- Frontend tests

Does not contain:

- Backend source code
- Database migrations
- Server-side secrets

## {{SPECS_REPO}} (optional)

Contains:

- The constitution, `CLAUDE.md`, `docs/`, and `specs/` feature trail
- No runnable source code

Use it when backend and frontend teams need one canonical place for governance; otherwise keep
specs in the primary repository.

## Nested Layout (recommended when {{SPECS_REPO}} exists)

Clone the code repositories **inside** the governance repository's working directory and list
them in its `.gitignore` (the kit's `.gitignore` ships commented-out lines for exactly this).
They remain fully independent repositories — **never git submodules** (pinned SHAs and detached
HEADs are chronic friction, especially for AI agents).

```text
{{SPECS_REPO}}/                # governance repo
├── CLAUDE.md  .specify/  docs/  specs/  scripts/
├── flowboard-api/          # independent code repo (ignored by parent)
└── flowboard-web/         # independent code repo (ignored by parent)
                               # …one nested repo per tier: mobile, worker, etc.
```

Why nest: AI agents read `CLAUDE.md` from the working directory *and its ancestors*, so an
agent working inside a code repository automatically inherits the governance rules — no pointer
copies, no drift, one constitution. Governance changes merge in the parent without touching
code repositories.

The cost: three histories share one directory tree, so "which repository is active" becomes the
discipline to watch — a commit from the wrong `cwd` lands in the wrong history. The parent's
`.gitignore` makes most accidents harmless; confirm the active repository before every commit.

One more consequence: **a standalone clone of a code repository has no governance** — no
constitution, no rulebooks, no specs. CI may clone a code repository alone to build and test,
but any environment where an agent *authors* changes (including cloud agents) MUST reproduce
the nested layout first.

## Cross-Repository Feature Rule

When a feature spans repositories:

1. Create matching branches (same `NNN-<name>`) in each affected repository — plus the spec
   branch in {{SPECS_REPO}}, when one exists.
2. Define the API contract in the feature's `contracts/` **before** any consuming tier
   (web, mobile, worker) implements against it.
3. Implement and gate the providing tier (usually the backend) first.
4. Merge the provider after its gate passes and human review approves.
5. Merge each consuming tier after the contract is stable (or it was mocked against the
   agreed contract), its own gate passes, and human review approves.

Always confirm which repository is active before changing files.
