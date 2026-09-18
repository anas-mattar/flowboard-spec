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
flowboard-web     # Frontend repository
```

Optional shared documentation/spec repository, when specs and governance need a home that is
neither tier:

```text
flowboard            # This governance repository — specs, constitution, docs
```

## flowboard-api

Contains:

- ASP.NET Core Web API (.NET 10), EF Core 10, SignalR hubs, SQL Server migrations
- Backend tests
- Database migrations

Does not contain:

- Frontend source code
- UI assets
- Frontend build tooling

## flowboard-web

Contains:

- Next.js 16 App Router, TypeScript strict, tRPC BFF, Tailwind v4 + shadcn/ui
- Frontend tests

Does not contain:

- Backend source code
- Database migrations
- Server-side secrets

## flowboard (this governance repository)

Contains:

- The constitution, `CLAUDE.md`, `docs/`, and `specs/` feature trail
- No runnable source code

Use it when backend and frontend teams need one canonical place for governance; otherwise keep
specs in the primary repository.

## Nested Layout (in use here)

Clone the code repositories **inside** the governance repository's working directory and list
them in its `.gitignore` (the kit's `.gitignore` ships commented-out lines for exactly this).
They remain fully independent repositories — **never git submodules** (pinned SHAs and detached
HEADs are chronic friction, especially for AI agents).

```text
flowboard/                   # governance repo (this one)
├── CLAUDE.md  .specify/  docs/  specs/  scripts/
├── flowboard-api/           # independent code repo (ignored by parent)
└── flowboard-web/           # independent code repo (ignored by parent)
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

## Territory across repositories

The feature's **Territory** is declared once, in the governance repository
(`specs/NNN-name/tasks.md`; a Micro feature's mini-spec `spec.md`), and it covers every
repository the phase touches. Entries are written **repo-prefixed and relative to the
governance root** — the way the tree looks from where you run the check:

```text
**Territory**:

- `flowboard-api/src/Boards/**`
- `flowboard-web/app/(boards)/**`
- `specs/NNN-name/`
```

`pwsh -File scripts/scope-check-repos.ps1` grades each code repository's phase commits
against that declaration, prefixing the repository's own paths with its directory name
before matching. It reads the repositories named in **kit-adoption.json**'s `codeRepos`
array, and reports `n/a` when none is declared or none is present — so a governance-only
checkout is unaffected. Two rules make it work:

- **Matching branch names.** The code repository must carry the same `NNN-name` branch as
  the governance repository (the Cross-Repository Feature Rule below) — that is how the
  check finds the declaration for a code commit.
- **Declare before you commit.** The declaration is read as it stood *when the code was
  committed*: widening it afterwards cannot turn a FAIL into a PASS, exactly as in the
  single-repository check. Legitimate scope discovery is amended in a governance commit
  made **before** the code phase commit that relies on it — and that amendment records who
  approved it, exactly as constitution I requires of any change to an approved feature
  document.
- **Territory is never back-declared.** A declaration that post-dates a phase's code commit
  FAILs that commit even when every file it touched is inside the declared paths — the
  ordering is the violation. Turning this on mid-flight therefore means one of two things
  for phases already committed: re-commit them on top of the declaration, or leave those
  phases undeclared (a lawful non-blocking WARN) and declare from the next phase forward.

In CI the reach is inverted: the governance repository's CI clones itself alone and reports
`n/a`, while each code repository runs the check for itself by checking out the governance
repository as a sibling — the kit ships
**.github/workflows/code-repo-scope-check.yml.template** for exactly that.

<!-- digest: Multi-repo Territory entries are repo-prefixed from the governance root; scope-check-repos.ps1 grades code repos. -->
<!-- digest: A code commit is graded against the declaration as of its own date — later widening never turns FAIL into PASS. -->

## Cross-Repository Feature Rule

When a feature spans repositories:

1. Create matching branches (same `NNN-<name>`) in each affected repository — plus the spec
   branch in this governance repository.
2. Define the API contract in the feature's `contracts/` **before** any consuming tier
   (web, mobile, worker) implements against it.
3. Implement and gate the providing tier (usually the backend) first.
4. Merge the provider after its gate passes and human review approves.
5. Merge each consuming tier after the contract is stable (or it was mocked against the
   agreed contract), its own gate passes, and human review approves.

Always confirm which repository is active before changing files.
