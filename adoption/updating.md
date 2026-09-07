# Updating an Adopted Project

The kit changes after you adopt it. This page is the flow-down channel: how to pull
those changes into your project without losing anything you filled in yourself.

## 1. Run the update

From a clone of the kit (not from your project):

```powershell
pwsh -File scripts/update-kit.ps1 -Target <path to your project root>
```

`-Target` is required — the script never defaults to updating itself. Add `-DryRun`
first if you want to see the report with zero writes, and re-run without it once you're
ready to apply. The script refuses to run (exit 1) against a dirty working tree, a
partial kit install, or the kit repository itself — commit or stash first if it stops you
there.

**Reading the report:**

| Section | What it means |
|---|---|
| Applied | Verbatim kit files it copied — pure kit prose/scripts, nothing project-specific in them. Safe to accept as-is. |
| Surgical | Files that changed upstream but were never touched — see step 2/3 below. |
| Conflicts | A verbatim file your project has locally modified. Not overwritten. |
| Result | The kit version now recorded, or "up to date" if nothing was pending. |

**Resolving a conflict**: a verbatim file only conflicts when someone edited kit-owned
prose or a kit script directly, which normally shouldn't happen — verbatim files exist to
be replaced wholesale. Review the diff; if the local edit was a mistake, re-run with
`-Force <path>` to take the kit version. If the edit was deliberate, keep it and leave the
file conflicted (it'll keep being reported) or move the customization to a project-owned
file instead.

**Commit the run**: the update never commits for you. Review `git status`, commit the
applied files and the updated `.kit-version` together, exactly like any other governance
change.

**Idempotence**: running the update again immediately after a clean apply reports "up to
date" and changes nothing — a good way to confirm you're current.

## 2. When the surgical report names the constitution

The constitution is the one surgical file every amendment eventually touches, and it
needs its own procedure because your project's constitution is not a copy of the kit's —
it is *your own document*, ratified under *your own* version number, that happens to have
been founded on the kit's principles.

An amendment never gets copied in. It gets **re-expressed**:

1. **Read the kit's rationale.** The commits the report names are the amendment log (the
   kit has no separate changelog) — read what changed and why before touching anything.
2. **Bump your own version, not the kit's.** Your constitution's version footer is your
   project's semver history, independent of the kit's. A principle added or materially
   expanded is a MINOR bump for you; a principle removed or redefined is MAJOR; wording
   only is PATCH — the same policy the kit itself uses, applied to your own number.
3. **Write your own SYNC IMPACT entry.** State what changed in *your* constitution:
   which principle, what the old and new text said, and which of your own dependent
   templates and docs it touches. Do not paste the kit's SYNC IMPACT entry — it describes
   the kit's history, not yours.
4. **Verify demoted content lands before you delete anything.** If the amendment demotes
   a principle out of constitutional law (into a rulebook, a standards doc, or a template),
   confirm the target file in *your* project actually carries the demoted content — filled
   in for your stack, not left as a slot — before removing the principle from your
   constitution. A demotion with nowhere to land is a silent loss of a rule, not a
   simplification.
5. **Sweep citations.** Grep your own governance docs for the old principle number or
   name (renumbering is common when principles are added, demoted, or deleted) and fix
   every reference — CLAUDE.md, plan/spec/task templates, rulebooks, anything that cites
   the constitution by number.
6. **Human approval adopts it.** Same rule as any other constitutional change: a person
   reviews and approves before the amendment counts as adopted in your project. The
   update script only delivers the report; it never amends your constitution for you.

### Worked example: the 2026-09-01 kit 0.3.0 → 0.4.0 flow-back

Two sample adoptions carried out this exact procedure the same day the kit shipped a
batched-gates amendment (kit constitution 0.3.0 → 0.4.0, itself built on an earlier
0.2.0 → 0.3.0 amendment that had demoted two principles and deleted a third). Neither
project copied the kit's version string or its SYNC IMPACT text:

- Each project's **own** constitution moved **1.0.0 → 2.0.0** — a MAJOR bump, because
  from that project's point of view principles were being removed and renumbered, which
  is backward-incompatible for anything citing them by number. The kit's own version
  number (0.3.0 → 0.4.0) never appeared in either project's constitution.
- Each project wrote its **own** SYNC IMPACT entry, in its own words, listing what its
  13 principles becoming 10 meant for that project specifically.
- **Demoted-content verification**: the Data Standards and Auditability principles were
  being demoted out of constitutional law. Before either project deleted them from its
  constitution, its `database-rules.md` rulebook was confirmed to already carry that
  content in project-specific, filled-in form — not a bare template slot. Only then did
  the principle text come out of the constitution.
- **Citation sweep**: both projects grepped their own docs for the old principle numbers
  and fixed every reference — CLAUDE.md's Task-Scoped Reading table, rulebook headers,
  and plan/spec templates that cited principles by number.
- Everything non-constitutional flowed down as ordinary verbatim/surgical updates in the
  same pass: the flow ritual page, the claim/territory/enforcement scripts and their CI
  workflow, and the kit's own templates.
- **Human approval**: each project owner reviewed the resulting diff and merged it as a
  normal governance change before the amendment counted as adopted.

## 3. Other surgical files

Not every surgical report is a constitution amendment. `docs/sdlc/gate-command.md`,
`docs/sdlc/repository-strategy.md`, `docs/sdlc/review-process.md`,
`docs/sdlc/rollback-process.md`, and `docs/sdlc/deployment-standards.md` carry
project-filled content (your gate commands, your repository layout, your customizations)
that an update must never overwrite. `docs/rulebooks/` and `modules/` are the same story
at a larger scale — instantiated tier rules and worked examples, replaced with your own
content at adoption.

For these, read the commits the report names, and re-apply by hand only what's relevant:
most kit-side changes to these files are structural or illustrative and don't require any
action in your project at all. When one does apply — a new required section, a changed
convention — add it to your own version the same way you'd make any other governance
edit: reviewed, committed, no different from hand-written project documentation.

## Partial-install note

If `update-kit.ps1` refuses your target as a partial install, your kit copy is missing
one of the required paths doc-lint checks for — most often a dot-directory
(`.specify/`, `.claude/`) that a file manager or a naive copy silently skipped. Finish
the install (see `adoption/`, step 0) before updating.
