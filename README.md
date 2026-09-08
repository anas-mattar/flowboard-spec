# FlowBoard — Governance Repository

The governance parent for FlowBoard, a real-time kanban board: constitution, SDLC law,
feature specs, and rulebooks. **No runnable code lives here** — the code is in two
nested, independent repositories (gitignored by this one; see
`docs/sdlc/repository-strategy.md`, Nested Layout):

- `flowboard-api/` — backend (.NET 10 / ASP.NET Core Web API, EF Core 10, SignalR, SQL Server)
- `flowboard-web/` — frontend (Next.js 16 App Router, TypeScript strict, tRPC BFF, Tailwind v4 + shadcn/ui)

## How work happens here

This project runs the [Agentic SDLC Kit](https://github.com/anas-mattar/agentic-sdlc-kit)
ritual — spec-first, one gated phase at a time, human-held certification:

- **The law**: `.specify/memory/constitution.md` (this project's ONLY constitution) ·
  `docs/sdlc/definition-of-done.md` · `docs/sdlc/gate-command.md`
- **The whole ritual on one page**: `docs/sdlc/flow.md`
- **Agent entry point**: `CLAUDE.md`
- **Domain law**: `docs/domain/flowboard-invariants.md` (constitutional force)
- **UI reference**: `docs/product/prototype/flowboard-prototype.html`
- **Machine checks**: `pwsh -File scripts/ritual-checks.ps1` (doc-lint + enforcement-pack
  + scope-check + adoption doctor — the same chain CI runs on every push)

## Gates

Defined in `docs/sdlc/gate-command.md`: frontend `npm run lint && npm run build`
(in `flowboard-web/`), backend `dotnet build --warnaserror && dotnet test`
(in `flowboard-api/`). Certification is held by the owner — a user-run exit code, or, on
a plan-declared `ci-held` feature (Lite/Standard only), recorded approval on the CI
evidence triplet.

## Updating from the kit

`adoption/updating.md` is the flow-down channel; `pwsh -File scripts/verify-kit.ps1`
(the adoption doctor) audits kit integrity; `kit-adoption.json` records what this
project declared.
