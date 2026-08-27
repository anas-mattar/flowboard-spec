# Gate Command

The user must run the gate locally. AI must not claim success without the user's exit code.
In a team, "the user" means **the feature's owner** — the developer driving this feature's
agent (`docs/sdlc/team-workflow.md`).

## Define this project's gates

Fill these two slots when adopting the kit; everything else in this document is generic.

```text
Frontend (run in flowboard-web/): npm run lint && npm run build
Backend  (run in flowboard-api/): dotnet build --warnaserror && dotnet test
```

`npm run build` (Next.js) includes the TypeScript type check. `npm test` joins the frontend
gate once the first test exists. Run each gate from its own repository root.

> **Status: defined but NOT YET PROVEN.** Per `adoption/greenfield.md` step 3, these gates
> must run green on the empty scaffolds before the first feature — a gate that has never
> been green is not a gate. Delete this note once both gates have exited 0.

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
a phase is only **Done** against a gate run by the user, with the exit code confirmed by the
user (`docs/sdlc/definition-of-done.md`, item 3). The agent MUST NOT present its own gate run
as that confirmation, and MUST NOT skip asking the user to run the gate because its own run
passed. **Critical** features go further: agent-run gates are not used at all
(`docs/sdlc/critical-delivery.md`).

## Minimum Gate

When the full gate is too slow for a quick sanity check, define a minimum gate (typically the
build step alone, e.g. `yarn build` or `dotnet build`) — but a phase is only **Done** against
the full gate (`docs/sdlc/definition-of-done.md`).
