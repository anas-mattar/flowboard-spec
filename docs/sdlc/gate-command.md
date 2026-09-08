# Gate Command

Certification is held by the user: by default the user runs the gate locally and confirms
the exit code; on a Lite/Standard feature whose approved plan declares
`**Gate Certification**: ci-held`, certification is the owner's recorded approval on the
CI evidence triplet (the "CI-held certification" section below). AI must not claim success
without the user-held certification, whichever form it takes. In a team, "the user" means
**the feature's owner** — the developer driving this feature's agent
(`docs/sdlc/team-workflow.md`).

## Define this project's gates

Fill these two slots when adopting the kit; everything else in this document is generic.

```text
Frontend (run in flowboard-web/): npm run lint && npm run build
Backend  (run in flowboard-api/): dotnet build --warnaserror && dotnet test
```

`npm run build` (Next.js) includes the TypeScript type check. `npm test` joins the frontend
gate once the first test exists. Run each gate from its own repository root.

Proven green on the empty scaffolds 2026-08-27, both exit codes confirmed by the user
(adoption step 3).

## Shell Syntax (reading the exit code)

The gate prints `EXIT: <code>` so the user can report it. The idiom differs per shell — the
bash form below does **not** work as-is on Windows:

| Shell | Run the chain | Print the exit code |
|-------|---------------|---------------------|
| **bash / zsh** (Linux, macOS, Git Bash) | `cmd1 && cmd2` | `; echo "EXIT: $?"` |
| **PowerShell** (Windows default) | `cmd1 && cmd2` | then on the next line: `"EXIT: $LASTEXITCODE"` |
| **cmd.exe** (Windows) | `cmd1 && cmd2` | then on the next line: `echo EXIT: %ERRORLEVEL%` |

> In **PowerShell**, `$?` is a boolean (`True`/`False`), not the exit code — use `$LASTEXITCODE`.
> In **cmd.exe**, `;` is **not** a command separator, so `sometool; echo ...` passes `echo ...`
> as arguments to `sometool`. Put the `echo` on its own line instead.
> Expected result for a passing gate is `EXIT: 0`.

## Running the gate

bash / Git Bash:

```bash
dotnet build --warnaserror && dotnet test; echo "EXIT: $?"   # backend, in flowboard-api/
npm run lint && npm run build; echo "EXIT: $?"               # frontend, in flowboard-web/
```

PowerShell:

```powershell
dotnet build --warnaserror && dotnet test   # backend, in flowboard-api/  (frontend: npm run lint && npm run build)
"EXIT: $LASTEXITCODE"
```

cmd.exe:

```bat
dotnet build --warnaserror && dotnet test   # backend, in flowboard-api/  (frontend: npm run lint && npm run build)
echo EXIT: %ERRORLEVEL%
```

## Agent-run gates (fast feedback, never certification)

During a phase, the AI agent MAY run the gate itself to get fast feedback, and MUST report
the exact command and its full output when it does. This changes nothing about who certifies:
a phase is only **Done** against a certification held by the owner — the user-run gate's
confirmed exit code, or, under a declared `ci-held` mode, the owner's recorded approval on
the CI evidence (`docs/sdlc/definition-of-done.md`, item 3). An agent-run gate NEVER
certifies in either mode: the agent MUST NOT present its own gate run as that confirmation,
and MUST NOT skip requesting the owner's certification because its own run passed.
**Critical** features go further: agent-run gates are not used at all
(`docs/sdlc/critical-delivery.md`).

## Batched gates (Lite/Standard only)

A Lite or Standard feature MAY declare, in its approved `plan.md` **before the batch's
first phase is implemented**, that up to **3 consecutive phases** share one certifying
user-run gate: `**Gate Batching**: phases N-M` (constitution X, Batched gates;
`docs/sdlc/definition-of-done.md`, item 3). What changes and what doesn't:

- The **owner runs the gate once**, at the end of the batch, and confirms the exit code.
- The **agent still runs the gate after every phase** for feedback and reports the output;
  a mid-batch agent-run failure pauses the batch at that phase boundary — the owner is
  asked to gate what is committed so far, not to push on.
- Every phase in the batch still gets its **own commit, machine scope check
  (`scripts/scope-check.ps1` against the phase's declared territory), and fresh-context
  AI review** — a failed batch-end gate localizes to a phase via the per-phase commits.
- **Critical features never batch** (`docs/sdlc/critical-delivery.md`);
  `scripts/enforcement-pack.ps1` fails a Critical branch whose plan declares a batch.

## CI-held certification (Lite/Standard only)

When the feature's approved `plan.md` declares `**Gate Certification**: ci-held`
(constitution X, CI-held certification; the default absent the line is `user-run`), gate
certification moves from "the owner runs the command" to "the owner approves on
unforgeable evidence" — asynchronously, at the owner's own moment. What certifies is the
**evidence triplet**, all three elements, cited in the owner's recorded approval:

1. **Run URL** — the CI run of the *project gate* on the branch. For this project the
   gates live in the code repositories (`flowboard-api/`, `flowboard-web/`): the evidence
   is that repository's project-gate workflow run ("Wiring the project gate in CI",
   below). This governance repository's own CI (`ritual-checks`) referees the governance
   law, not the code gates.
2. **Green conclusion** — the run succeeded. A red run followed by a green re-run on the
   same commit certifies (a deterministic gate is the project's own law), and both runs
   are visible on the run page — the owner approves knowingly.
3. **Exact commit sha** — the run executed on the phase commit itself (for a declared
   batch: the batch-end commit). A run on any other commit certifies nothing.

The approval is recorded where phase approvals already live — the feature's PR
conversation or phase notes. Worked example:

> Gate 3 certified (ci-held): run https://github.com/…/actions/runs/12345, conclusion
> success, commit `abc1234` (phase 2) — approved, <owner>, <date>.

Boundaries: per-phase (or per declared batch) approval, never blanket; the agent's
obligations are unchanged — it MUST NOT claim success, and under this mode it reports the
triplet and requests the owner's approval on it; the user-run gate above remains lawful
always (CI outage, fork PRs, or simple preference); **Critical features MUST NOT use
CI-held certification** (`docs/sdlc/critical-delivery.md`;
`scripts/enforcement-pack.ps1` fails a Critical plan declaring it).

## Wiring the project gate in CI

The kit ships a workflow template, **.github/workflows/project-gate.yml.template** (a
deletable slot-bearing template, like the tier rulebooks). To wire a gate:

1. Copy the template to **.github/workflows/project-gate.yml** in the repository whose
   gate it runs — for this project that means one copy per code repository
   (`flowboard-api/`, `flowboard-web/`), each running that repository's gate chain from
   this document. The copy is project-owned. The template itself is surgical-class: kit
   updates **report** upstream changes to it but never rewrite it — refresh it (or
   first-install it) by copying from the kit clone by hand (`adoption/updating.md`,
   section 3).
2. Fill the two slots: the working directory the gate runs in, and the exact gate chain
   from this document's slots above. Secrets go in the CI secret store, referenced via
   `env:` — never in the file, the chain, or any recorded evidence.
3. Push a governed branch. The run page carries the command, the conclusion, and the
   commit sha — the evidence triplet. Cite the **push-event** run: a pull_request-event
   run executes a merge preview, not the phase commit, and certifies nothing.
4. Recommended once the check has run at least once: require `project-gate` on `main`
   (`docs/sdlc/branch-protection.md`) — recommended, never mandated; a gate that cannot
   run in CI loses nothing, because the user-run gate is always lawful.

## Minimum Gate

When the full gate is too slow for a quick sanity check, define a minimum gate (typically the
build step alone, e.g. `yarn build` or `dotnet build`) — but a phase is only **Done** against
the full gate (`docs/sdlc/definition-of-done.md`).

## Strict-build flags vs transitive-dependency vulnerabilities

This project's backend gate uses `--warnaserror`; ESLint's zero-warning default in
`npm run lint` is the frontend equivalent. Such a gate will sometimes go red through no code
of ours: a **transitive** dependency (pulled in by a template or framework, pinned nowhere in
our files) gets a published vulnerability advisory, and the build fails on a warning nobody
wrote — exactly how the 001 scaffold's transitive `Microsoft.OpenApi` 2.0.0 failed
`--warnaserror` on GHSA-v5pm-xwqc-g5wc (resolved by pinning 2.12.2).

Triage in this order — the strict flag itself is never the thing that yields:

1. **Upgrade the direct dependency** to a version whose dependency graph includes the
   patched transitive version.
2. **Pin the patched transitive version directly** (an explicit `PackageReference` /
   `package.json` override that beats the transitive resolution) when no fixed direct
   release exists yet.
3. **Record a narrowly-scoped, reasoned suppression** — the single advisory ID, the single
   package, a written why, and a removal condition — in the feature's `plan.md` or the
   relevant rulebook, when neither of the above is possible.

Blanket-disabling the strict flag to get past one advisory is prohibited: it silently
removes the gate's ability to catch every future warning, which is the opposite of a
narrowly-scoped fix.
