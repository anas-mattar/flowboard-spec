# Team Workflow — Multiple Developers, Multiple Agents

The kit was extracted from a single-developer deployment; this document is the layer that
makes it safe for N developers, each driving their own agent. Single-developer projects can
ignore this file — nothing else depends on it.

## 1. Feature ownership — who "the user" is

Every feature has exactly **one owner**: the developer whose agent implements it, who runs
the gate for it, and who confirms the exit code. Wherever this kit says "the user"
(gate-command, review-process, definition-of-done, CLAUDE.md), it means **the feature's
owner** — not any teammate, and never the agent.

## 2. Number reservation — the remote is the ledger

Feature numbers are claimed on the remote, not computed locally
(see `docs/sdlc/branch-strategy.md`, "Number Allocation"). One command runs the whole
ritual — fetch, remote-aware allocation, branch + spec creation, immediate push, and
automatic renumbering on a lost race:

```powershell
pwsh -File scripts/claim-feature.ps1 -ShortName <name> "<feature description>"
```

The recipe it automates (kept as the manual fallback):

1. `git fetch origin` before allocating.
2. Take the next `NNN` unused by any local **or remote** branch or `specs/` directory.
3. `git push -u origin NNN-<name>` **immediately** — the number belongs to whichever
   branch reaches the remote first. Lose the race → renumber before any other work.

## 3. Picking up a feature — the claim lives in git, not in a conversation

How a developer takes a feature from the roadmap (**docs/roadmap.md**, see
`specs/_templates/roadmap-template.md`):

1. **Choose** from the top of the roadmap's priority order, checking two things first:
   dependencies (don't pick a feature whose foundations are unshipped) and territory —
   `git fetch origin`, list the open `NNN-*` remote branches, skim their `plan.md`s. If
   your candidate overlaps an in-flight feature, pick something else or agree merge order
   with that owner now (rule 5), not at merge time.
2. **Claim by pushing.** Run `/speckit.specify`, then `git push -u origin NNN-<name>`
   immediately. **A remote `NNN-*` branch IS the claim** — no meeting, no chat message.
   Everyone checks remote branches before picking, never the roadmap alone.
3. **Update the roadmap row in your first commit on the branch** — Owner, Status →
   `specified`, spec link — so the claim reaches `main`'s roadmap when the feature merges.
   Until then, the remote branch (step 2) is the authoritative claim.
4. From here the normal ritual applies unchanged; the picker is the feature's owner
   (rule 1), and picks their cross-reviewer (rule 4) at claim time — the owner of a
   neighboring feature is usually the best choice.

**WIP limit — one active feature per developer, with a pipelining exception.** Multiple
claimed branches are number squatting: claims stop meaning "being worked on." To park a
feature, push your progress and note it in the roadmap's decisions log so someone else
can adopt it.

**Pipelining — working through the review wait.** A developer MAY claim a second feature
while their first awaits review, under all of these conditions:

- The first feature is fully done from the owner's side: **every phase committed
  gate-green, the branch pushed, and human review formally requested** (a PR opened, or
  the reviewer explicitly asked). "Almost done" does not qualify.
- **Hard cap: one feature awaiting review + one active feature.** A third claim is
  number squatting, whatever the states.
- The second feature's territory is **disjoint** from the awaiting feature's
  (`scripts/territory-check.ps1`), or explicitly sequenced behind it in both features'
  `plan.md` — change requests may reopen the first feature's files at any time.
- **When change requests arrive** on the awaiting feature while the second is mid-phase:
  finish the current phase of the second feature to a clean gate-green commit, then
  return to the first feature and resolve the change requests **before starting any
  further phase**. No half-done phase is ever left behind; review turnaround waits at
  most one phase.

**Stale claims may be reclaimed.** A claimed branch with no commits for two weeks
(adjust to taste) is up for adoption: new owner, one line in the decisions log.

## 4. Cross-review — the owner never approves their own feature

With one developer, human review means reviewing your own agent's work. With a team there
is no excuse: **the human reviewer of a feature MUST NOT be its owner** (constitution IX
gains teeth). The owner completes the AI review; a different developer completes
`human-pr-review.md` and holds the merge approval.

## 5. Territory check — before a phase, not at merge

`plan.md` declares what the feature touches. Before starting each phase, the owner (or
agent) checks that no *other open feature branch* claims the same files — one command:

```powershell
pwsh -File scripts/territory-check.ps1
```

It fetches, diffs the current branch and every open remote `NNN-*` branch against
`main`, and reports overlapping files per branch. Exit codes: `0` clean, `2` live
overlap found, `1` execution error — so an agent can run it as a pre-phase check. Stale
claims (no commits for two weeks) are flagged as reclaimable rather than treated as live
conflicts; freshly claimed branches with no work yet are noted, not errors. The manual
equivalent (kept as the fallback):

```bash
git fetch origin
git diff --stat main...origin/<other-open-branch>   # per open feature branch
```

Overlap is not forbidden — it is **sequenced**: the owners agree on merge order, and the
later feature rebases after the earlier one lands. Discovering overlap at merge time is a
process failure; record the agreed order in both features' `plan.md`.

## 6. Rebase before gate

The gate certifies the phase **as it will land**, not as it was written. Before asking for
the gate on the final phase (and after any teammate's merge that touches your territory):
rebase the feature branch on current `main`, re-run the loop if UI was touched, then gate.

## 7. Governance changes ride alone

Constitution and `docs/sdlc/` changes never travel inside a feature branch. They get their
own `docs/<name>` branch and require team-lead (or whole-team) approval — a feature merge
must never silently change the law the next feature is judged by.

## 8. CI on main is the referee

With concurrent merges, two individually-green features can be jointly red. The CI gate
must run on `main` after every merge; a merge that turns `main` red is **reverted
immediately** via the `fix/` lane — no debugging on a red `main`. The user-run gate remains
the per-feature trust ritual; CI is the cross-feature one.
