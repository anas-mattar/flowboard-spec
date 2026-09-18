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

<!-- digest: update-kit.ps1 runs from a kit clone with -Target: verbatim files copied, surgical only reported, never written. -->

**Reading the report:**

| Section | What it means |
|---|---|
| Applied | Verbatim kit files it copied — pure kit prose/scripts, nothing project-specific in them. Safe to accept as-is. |
| Surgical | Files that changed upstream but were never touched — see step 2/3 below. This report is delivered **once**, at the update that carries it: handle it in the same session. |
| Conflicts | A verbatim file your project has locally modified. Not overwritten. |
| Result | The kit version now recorded, or "up to date" if nothing was pending. |
| (never listed) | `generated`-class paths — `docs/digests/*-digest.md` — are neither copied nor reported: each project generates its own digests from its **own** law with `scripts/build-digests.ps1` (the generator and `docs/digests/digest-packs.json` arrive verbatim). |
| Adoption doctor | An apply run ends with `scripts/verify-kit.ps1`'s verdict for your project — flow-down damage surfaces in the same session that caused it. A red verdict exits 2 ("attention needed"); get the doctor green before committing the flow-down. `-DryRun` skips it; `-Json` callers run `verify-kit.ps1 -Json -Root <project>` themselves. |

<!-- digest: generated-class paths (docs/digests/*-digest.md) never flow down — each project generates digests from its own law. -->

**Resolving a conflict**: a verbatim file only conflicts when someone edited kit-owned
prose or a kit script directly, which normally shouldn't happen — verbatim files exist to
be replaced wholesale. Review the diff; if the local edit was a mistake, re-run with
`-Force <path>` to take the kit version. If the edit was deliberate, keep it and leave the
file conflicted (it'll keep being reported) or move the customization to a project-owned
file instead.

**The surgical report is delivered once**: every apply advances the recorded kit commit
in `.kit-version` to the kit HEAD it ran against, so the next run reports only what is
new since — a surgical backlog is never re-listed. Handle the report in the session that
produced it (steps 2–3 below). A past report is always recoverable: the old recorded
commit is in the superseded `.kit-version` (visible in your flow-down commit's diff), and
`git log <old>..<new>` in the kit clone re-derives exactly what that update named.

<!-- digest: The surgical report is delivered once — handle it in the session that produced it; the record advances to kit HEAD. -->

**Commit the run**: the update never commits for you. Review `git status`, commit the
applied files and the updated `.kit-version` together, exactly like any other governance
change.

**Idempotence**: running the update again immediately after a clean apply reports "up to
date" and changes nothing — a good way to confirm you're current. This holds after a
surgical-bearing apply too: the record advanced with the apply, so the re-run has nothing
new to report (unresolved verbatim conflicts are the one exception — they are re-detected
from file content every run until resolved).

## 2. When the surgical report names the constitution

The constitution is the one surgical file every amendment eventually touches, and it
needs its own procedure because your project's constitution is not a copy of the kit's —
it is *your own document*, ratified under *your own* version number, that happens to have
been founded on the kit's principles.

An amendment never gets copied in. It gets **re-expressed**:

<!-- digest: Constitution amendments are re-expressed, never copied: your own version bump, your own SYNC IMPACT, citation sweep. -->

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

   <!-- digest: Verify demoted content lands in your project before deleting the principle — nowhere to land means a rule is lost. -->

5. **Sweep citations.** Grep your own governance docs for the old principle number or
   name (renumbering is common when principles are added, demoted, or deleted) and fix
   every reference — CLAUDE.md, plan/spec/task templates, rulebooks, anything that cites
   the constitution by number.
6. **Human approval adopts it.** Same rule as any other constitutional change: a person
   reviews and approves before the amendment counts as adopted in your project. The
   update script only delivers the report; it never amends your constitution for you.

   <!-- digest: Human approval adopts an amendment — the update script only delivers the report, never amends your constitution. -->

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

### Flow-down note: the 2026-09-08 CI-held certification amendment (kit 0.4.1 → 0.5.0)

The kit's constitution X gained a CI-held certification clause: a Lite/Standard feature's
approved plan MAY declare `**Gate Certification**: ci-held`, making certification the
owner's recorded approval on the CI evidence triplet (run URL + green conclusion + exact
phase-commit sha) instead of a live user-run gate. Like every amendment, it arrives here
by **re-expression** (this section's procedure), never by copy:

- Adopting it is a **MINOR bump of your own version** — a principle materially expanded.
  What you adopt is the clause's six boundaries (Lite/Standard only; declared before the
  first phase it governs; approval on the triplet; agent obligations unchanged; Critical
  excluded; absent = `user-run`) plus its mirrors in your own DoD, gate-command,
  critical-delivery, plan template, and CLAUDE.md.
- **Nothing changes until you ratify it.** The user-run gate remains your project's law —
  and stays lawful for every feature even after adoption; ci-held is an opt-in per
  feature, per plan, never a default.

### Flow-down note: the 2026-09-09 Micro-lane amendment (kit 0.5.0 → 0.6.0)

The kit's constitution gained a fourth delivery level — **Lite < Micro < Standard <
Critical** (Principles I and X): a numbered feature MAY be declared Micro, delivered from
a single-page mini-spec (`spec.md` only, no plan.md/tasks.md) in exactly one phase inside
hard machine-checked bounds (at most 5 territory files and 400 changed lines), with every
verification layer unchanged and in-place promotion to Standard when the work outgrows a
bound; CI-held eligibility widened to Lite/Micro/Standard. Like every amendment, it
arrives by **re-expression** (this section's procedure), never by copy:

- Adopting it is a **MINOR bump of your own version**. What you adopt: Principle I's
  Micro arm, Principle X's Micro-lane clause (one phase; both bound constants; the
  eligibility checklist; promotion in place; Critical excluded; absent declaration =
  Standard) and the widened CI-held eligibility, plus its mirrors in your own DoD,
  gate-command, branch-strategy, critical-delivery, spec template, and CLAUDE.md.
- The **machine half and the template arrive verbatim** through the normal update
  channel: `scripts/scope-check.ps1`, `scripts/enforcement-pack.ps1`, and
  `.specify/templates/micro-spec-template.md`. The Micro checks are inert until a
  feature's `spec.md` declares `**Delivery Level**: Micro`, so taking the scripts before
  (or without) ratifying the amendment leaves your existing features' verdicts unchanged —
  with one general hardening that rides along: scope-check now also FAILs a commit that
  deletes or renames away a feature's `spec.md` or `tasks.md` on any numbered branch
  (never a legitimate move; previously only tasks.md deletion was guarded).
- **Nothing changes until you ratify it.** Absent a declaration, every numbered feature
  is Standard — exactly as before.

### Flow-down note: the 2026-09-09 law digests (kit feature 010 — no constitution amendment)

The kit grew a per-pack law-digest machine: curated one-line markers beside binding rules,
a deterministic generator, and a CI freshness check. **No constitutional change is
involved** (the kit's constitution stayed 0.6.0) — there is nothing to re-express; this
note is the whole adoption story:

- **What arrives verbatim**: `scripts/build-digests.ps1` (generator + `-Check`),
  `docs/digests/digest-packs.json` (pack composition), and the updated
  `scripts/ritual-checks.ps1` with its `digests` member.
- **What never arrives**: the kit's own `docs/digests/*-digest.md` files — they are
  `generated`-class (neither copied nor reported; see the report table in step 1). A
  digest summarizes the law of the repository it lives in, so each project generates its
  own.
- **The flow-down includes generating your digests.** The kit's verbatim pack documents
  (DoD, flow, branch-strategy, team-workflow, critical-delivery, and this file) now carry
  digest markers, and the update copies them in — so the moment the marked law lands, the
  `digests` member demands the digests it produces. Run
  `pwsh -File scripts/build-digests.ps1` and **commit the generated digests together with
  the update**; skipping the step fails ritual-checks loudly, naming exactly those digest
  files and that command — never silently. The `n/a (no digest markers)` inert state
  belongs only to a tree with no markers anywhere (a pre-010 copy adoption that never
  updates, or a project that deletes the markers — they are ordinary comment lines in
  your law, yours to keep or remove).
- **Marking your own law (optional)**: add markers beside the binding rules of your own
  documents — gate-command, review-process, rollback-process, and repository-strategy are
  your surgical copies, so markers there summarize *your* filled-in law — then
  regenerate:

  ```markdown
  <!-- digest: <one-line rule statement, at most 120 chars> -->
  ```

  A marker counts only as a standalone line, in exact lowercase grammar, outside HTML
  comment blocks and code fences (this example is safely inside one); a near-miss line
  fails the check rather than vanishing. Bounds: at most 40 lines per pack digest,
  120 chars per one-liner. CI fails on any drift between a rule and its digest —
  regenerate with `pwsh -File scripts/build-digests.ps1`.
- **Mirror by hand (surgical)**: the CLAUDE.md Task-Scoped Reading "Orientation first"
  paragraph — the pointer that sends agents to a pack's digest before the full read —
  is surgical-class; copy the kit's wording into your own CLAUDE.md, as with the 008/009
  mirrors above. Without it your digests exist but nothing points agents at them.
- **Digests are orientation only**: never a source-of-truth rung, never a substitute for
  reading the full document before acting on its area (each digest's header says so).

### Flow-down note: the 2026-09-09 roadmap-claim check (kit feature 011 — no constitution amendment)

The kit's `ritual-checks` grew a sixth member, `roadmap-claims`: every `NNN-*` feature branch
visible on `origin` must have a `docs/roadmap.md` row, in a table with a Status column, whose
Status is not `idea`. **No constitutional change is involved** (the kit's constitution stayed
0.6.0) — there is nothing to re-express; this note is the whole adoption story:

- **What arrives verbatim**: `scripts/roadmap-claim-check.ps1` (new), the updated
  `scripts/ritual-checks.ps1` that runs it, and `scripts/claim-feature.ps1`, which now
  prints the flip reminder after a successful claim.
- **What it enforces**: the second half of the claim ritual — when you claim `NNN-name`,
  flip that feature's roadmap row in a main-side `docs/` commit in the same sitting
  (`docs/sdlc/branch-strategy.md`, Number Allocation). A claim whose row still reads `idea`
  tells the next agent the work is unstarted and invites a duplicate spec; the field
  incident this closes ran 13 days that way.
- **It can turn your CI red on the first run, by design.** The check reads the branches
  actually on your remote, so a *stale* `NNN-*` branch still sitting there — merged long
  ago, or abandoned — needs its row to read `shipped`/`dropped`, or the branch deleted.
  That sweep is the point: a lingering claim with a stale row is the same lie.
- **Three inert states, all exit 0 and reported as `n/a`, never failed**: no `origin`
  remote, a remote it cannot reach, and a `docs/roadmap.md` with no Status-bearing table.
  `docs/roadmap.md` never flows down, so a project whose ledger is shaped differently from
  the kit's is left alone rather than forced into the kit's table.
- **The branch's own number is exempt**, so a fresh claim can commit its mini-spec before
  the row exists without deadlocking itself; every *other* visible claim still has to have
  a row for the branch to go green.

### Flow-down note: the 2026-09-09 cross-repo scope check (kit feature 012 — no constitution amendment)

Machine gate 4 reaches the nested code repositories. **No constitutional change is involved**
(the kit's constitution stayed 0.6.0); this note is the whole adoption story, and it matters
most to projects in the nested multi-repo layout — until now, every phase commit containing
code was outside the scope check's reach (GAP-016).

- **What arrives verbatim**: `scripts/scope-lib.ps1` (new — the parsing/matching helpers, now
  shared), `scripts/scope-check-repos.ps1` (new — the cross-repo grader),
  `scripts/scope-check.ps1` (unchanged behavior, now dot-sourcing the library),
  `scripts/ritual-checks.ps1` (new `scope-repos` member), `scripts/init-kit.ps1` and
  `scripts/verify-kit.ps1` (the `codeRepos` field), and
  `.github/workflows/code-repo-scope-check.yml.template` (surgical — you copy it).
- **It is inert until you declare something.** With no `codeRepos` in `kit-adoption.json`, the
  member reports `n/a` and your CI verdict is unchanged. A single-repo project never declares
  it and is unaffected.
- **What a multi-repo project does**: add `codeRepos` to the record (§4), write this feature's
  **Territory** entries repo-prefixed from the governance root
  (`` `your-api/src/**` ``), and copy the code-repo workflow template into each code repository,
  filling its governance-repository and directory slots. The doctor WARNs until the field is
  there — absent and empty count the same.
- **Two rules that bite immediately**: the code repository must carry the same `NNN-name`
  branch as the governance repository (the Cross-Repository Feature Rule), and the territory
  must be declared **before** the code is committed — a declaration that post-dates a code
  phase commit FAILs it, which is the same anti-retroactivity rule the in-repo check has
  always applied to its own commits.
- **Reading a code-repo CI run**: PASS or FAIL means it graded. A run showing only WARN or
  `n/a` graded nothing — a mismatched directory name, a missing branch, or a code repository
  whose trunk is not `main` (pass `-BaseRef`). Do not accept that as a green gate.

### Flow-down note: the 2026-09-16 amendment authority (kit 0.6.0 → 0.7.0, feature 014)

Principle I gains an **Amendment authority** clause, and `scripts/enforcement-pack.ps1` gains
the check that grades it. The rule: once a feature's `spec.md` or `plan.md` has been approved,
a later change to that feature's `spec.md`, `plan.md`, `tasks.md` or `contracts/` must record
who approved it, and **an implementing agent must not approve its own amendment**. It closes
GAP-019 — until now an agent could widen its own Territory and pass the scope check by
construction, because the check reads the Territory that same agent just wrote.

- **What the update writes for you (verbatim)**: `scripts/enforcement-pack.ps1` (the new
  `Invoke-AmendmentAuthorityCheck`), `.specify/templates/tasks-template.md`,
  `docs/sdlc/definition-of-done.md` (gates 5 and 6), `docs/sdlc/branch-strategy.md`, and both
  review templates — `specs/_templates/ai-code-review-template.md` and
  `specs/_templates/human-pr-review-template.md`, which is what makes your reviewers see
  amendments at all.
- **What you mirror by hand (surgical — the update reports these, it never writes them)**:
  `CLAUDE.md` (the Strict Rules bullet: you never approve your own amendment),
  `docs/sdlc/review-process.md` (the human-reviewer check — whether the named approver really
  agreed) and `docs/sdlc/repository-strategy.md` (the multi-repo twin of the clause). Skip these
  and you get the machine while your agent instructions and your review checklist never mention
  the rule — live and unenforced, which `spec.md` US4 calls the worst state in the kit.
  `.specify/memory/constitution.md` is surgical too, and is yours: §2 reports it, nothing
  writes it.
- **Ratify the clause first.** The kit shipped the law one phase before the machine
  deliberately: a kit must not enforce a rule it has not ratified. Do the same — adopt the
  Principle I wording into your constitution as its own reviewed change, then let the check
  arrive. The wording is itself adopted from an adopting project's ratified text (FitForge
  constitution 1.1.0), so a project already carrying that clause reconciles rather than
  collides.
- **If you already carry that clause, one paragraph of it stops being true.** The field
  wording closes with an "Enforcement, honestly stated" paragraph saying the rule is enforced
  by review and not by machine, because the check was owed to the kit and did not yet exist.
  It exists now. Delete or rewrite that paragraph when the check arrives, and keep the
  honesty it was written for by replacing it with what the check does *not* verify (below) —
  otherwise your constitution understates your own enforcement, which is the same defect as
  overstating it. **This is an edit in your repository, by you, under your own ritual**: the
  kit never writes your constitution, and an update only reports it (§2).

**What the check grades.** On an `NNN-*` branch, every non-merge commit in the branch's range,
and within each commit only the paths `specs/NNN-name/spec.md`, `plan.md`, `tasks.md` and
`contracts/*`. Nothing else in your repository is in scope — `notes.md`, `research.md`,
`screenshots/`, and every file outside the feature directory are ungraded, which is why
recording evidence never costs an approval.

- A document's **first appearance is creation**, not amendment, and owes no record. This kit
  has no approval token, so existence is the proxy for approval (stated plainly in the clause).
  A branch renumbered by a lost claim race is creation too: the whole `specs/NNN-name`
  directory moves, `claim-feature.ps1` mandates the header edits that ride along, and the check
  skips a rename whose old path was in a different feature directory (FR-010). It is the one
  exempted case where a document's text did change — the alternative was a state with no legal
  path to green.
- Every later change to the document's **text** is an amendment. The test is the text, never
  the intent: re-wording, re-scoping or annotating a task is an amendment even when the work
  itself was already agreed.
- **Two exemptions, both narrow.** A `tasks.md` change that alters nothing but checkbox state
  — `- [ ]` to `- [x]` or back — is progress, not amendment. Un-ticking counts too. But
  rewriting a task's text *while* ticking it is an amendment: record what was done in
  `notes.md` and leave the task saying what was agreed.
- And the **approval transition itself**, on `spec.md` or `plan.md`: `**Status**: Draft`
  becoming `**Status**: Approved` is the act that starts the rule, not a change to an approved
  document, so it owes no record.
  The kit's own spec templates mandate that edit; a rule that charged an approver record for
  obeying the template would be charging for the approval. It is exempt only in that exact
  shape — exactly one line differs in the whole file, it is the document's **first**
  `**Status**:` line and not one inside a fenced block, the old value is `Draft`, and the new
  value is `Approved` plus at most a date, an `(owner: …)` parenthetical and the template's
  trailing comment. Anything riding along on that line, a second status line rewritten beside
  it, or `Approved` going back to `Draft`, is an amendment like any other. A `tasks.md` status
  line is not exempt — no kit template gives it one.

**A conforming record** is two halves, and the check wants both:

```text
**Amendment approved by**: anas.m, 2026-09-13
```

in the amended section of the document itself — not in `notes.md`, not inside an HTML comment —
**and** the same approver named in the amendment commit's message. The message is the half a
later edit cannot fake, which is the whole reason it is asked for. Two failures you may meet:

```text
AmendmentAuthority: commit a1b2c3d amends specs/014-amendment-authority/plan.md after
approval with no conforming approver record. Add '**Amendment approved by**: <name>,
<YYYY-MM-DD>' to the amended section and name the same approver in the commit message
(constitution I, Amendment authority). Ticking a task off is exempt …

AmendmentAuthority: commit a1b2c3d records 'anas.m' as the approver of its change to
specs/014-amendment-authority/plan.md, but its commit message does not name them — the
message is fixed at commit time and is the half a later edit cannot fake
(constitution I; plan D5)
```

"Not inside a comment" means what a Markdown renderer means by it, and the check reads your
documents the way a renderer does. A comment opener quoted in backticks, or sitting inside a
fenced block, is literal text that hides nothing; an escaped backtick opens no code span; and
an unterminated opener hides everything after it to the end of the file, because that is what
a reader would see:

```text
**Amendment approved by**: anas.m, 2026-09-13    <- counts

The syntax is `<!--`.                            <- prose. The record below still counts.
**Amendment approved by**: anas.m, 2026-09-13

<!-- **Amendment approved by**: anas.m, 2026-09-13 -->   <- hidden. Does not count.

<!-- a note someone forgot to close
**Amendment approved by**: anas.m, 2026-09-13    <- hidden too, and so is the rest of the file
```

So a graded document may freely *discuss* comment syntax and still carry a visible record. The
`<-` notes above are margin annotations, not part of the lines: a real record line ends at the
date, and anything appended to it — including a note like those — defeats the pattern and is no
record at all. The kit learned this the hard way:
 a `tasks.md` task describing this very check quoted a comment
opener in backticks, an earlier implementation read it as a real one, and every approver record
below that line went invisible — the rule was briefly impossible to comply with in any document
that mentioned it. If a record you can see is reported missing, look upward for an opener that
was never closed; that is the one case where the renderer hides it from a human too.

<!-- digest: The amendment check grades spec.md, plan.md, tasks.md and contracts/ only; a checkbox flip is progress. -->
<!-- digest: Approving a document is not amending it: a lone Draft-to-Approved status flip owes no approver record. -->

**What it does not verify, stated honestly.** It grades that a record exists, is well-formed,
and names the same approver as its commit. Three things it cannot do. It cannot verify that the
named person agreed — on a solo project the approver is the same human who drove the session.
It does **not** enforce the self-approval prohibition: the kit records no link between a commit
and the session that produced its diff, so **that half of the rule is held by review alone**.
And it does not observe approval itself. What you gain is that an amendment is now visible in
the diff and gradeable — not that consent is proven. A determined implementer can still write a
name. The record has the strength of the Reviewer Provenance block, not of an authentication;
treat it as a written claim a reviewer can falsify, and falsify it at gate 5 and gate 6.

**Arrival day is silent — the boundary.** A commit is graded only if
`Invoke-AmendmentAuthorityCheck` existed in the repository **before that commit was made**.
Nothing you committed before the update that delivers the check is graded, here or in any
adopted project. No in-flight branch turns red on arrival; the first commit the rule can fail
is one you make afterwards, knowing it applies.

One exception, worth checking *before* you update rather than after: if your CI clones
shallowly, the check fails on the first `NNN-*` branch it sees, because it will not guess at a
boundary it cannot compute. That is a verdict on the checkout, not on your history — set
`fetch-depth: 0` (below) and arrival day is silent as described.

The boundary is not a courtesy, and it is worth understanding rather than just relying on.
Half of every record lives in the commit message, and a commit message is immutable. A
retroactive rule would therefore be one **no adopter could comply with** — the only remedy
would be rewriting published history. A rule whose commonest remedy is impossible is a rule
people route around, so it binds forward only. The stated cost: between ratifying the clause
and the check landing, the rule is law and ungraded. Keep that window to one phase, as the kit
did on its own branch.

**Give CI the whole history.** The boundary is computed by reading each commit's own tree, so
the check needs real objects to read. In a shallow clone — `actions/checkout` defaults to
depth 1 — those objects are not there, and a check that grades nothing would look
exactly like a branch that is legitimately pre-boundary: green, and meaningless. So on an
`NNN-*` branch the check refuses to guess. It fails, and names the condition it met: a shallow
clone, an integration branch it cannot diff against — absent, or present but sharing no
commit with your branch — or a parent commit this clone cannot read. A
Lite branch (`fix/`, `chore/`, `docs/`) is unaffected — the check returns before it consults
history at all. The kit's `.github/workflows/ritual-checks.yml` ships with `fetch-depth: 0`;
if you wrote your own workflow, or fetch shallowly on a build agent, set it there too. That is
still the fix. What it buys you is a red build instead of a green one that graded nothing.

<!-- digest: The amendment check binds forward only — nothing committed before it arrived is graded. -->
<!-- digest: The amendment check needs full history — fetch-depth 0 in CI, or it fails naming the shallow clone. -->

## 3. Other surgical files

Not every surgical report is a constitution amendment. `docs/sdlc/gate-command.md`,
`docs/sdlc/repository-strategy.md`, `docs/sdlc/review-process.md`,
`docs/sdlc/rollback-process.md`, and `docs/sdlc/deployment-standards.md` carry
project-filled content (your gate commands, your repository layout, your customizations)
that an update must never overwrite. `docs/rulebooks/` and `modules/` are the same story
at a larger scale — instantiated tier rules and worked examples, replaced with your own
content at adoption. **`.github/workflows/project-gate.yml.template`** (deletable) is
surgical for the same reason: your copy is `project-gate.yml`, filled with your gate
chain. Updates only *report* changes to surgical paths — they never write them — so a
changed template is refreshed by hand into your filled copy; a project adopted before
the template existed (pre-008) never receives it through the update channel at all and
installs it the first time by copying it from a kit clone.

For these, read the commits the report names, and re-apply by hand only what's relevant:
most kit-side changes to these files are structural or illustrative and don't require any
action in your project at all. When one does apply — a new required section, a changed
convention — add it to your own version the same way you'd make any other governance
edit: reviewed, committed, no different from hand-written project documentation.

<!-- digest: Surgical files carry project-filled content: re-apply by hand only what applies — an ordinary governance edit. -->

## 4. The adoption doctor and its records

`pwsh -File scripts/verify-kit.ps1` audits your project's kit integrity any time (structure
essentials, unfilled slots in project-owned files, constitution ratification, declared-tier
rulebooks + gate proof, declared code repositories, `.kit-version`). It runs automatically at the end of `init-kit.ps1`
and of every `update-kit.ps1` apply, and as part of the `ritual-checks` CI in adopted
projects. It is read-only: it reports, you repair.

<!-- digest: verify-kit.ps1 is the adoption doctor: read-only, runs at init end, update end, and in adopted-project CI. -->

**kit-adoption.json** (project root) is its source of truth for what you declared.
`init-kit.ps1` writes it; you own it afterwards — adding a tier later means adding it here
*and* instantiating the rulebook. Projects adopted before the doctor existed create it by
hand:

```json
{
  "schemaVersion": 1,
  "projectName": "your project",
  "topology": "single",
  "tiers": ["backend", "database"],
  "initDate": "2026-09-08",
  "kitVersionAtInit": "copy",
  "gateProof": [
    { "gate": "default", "command": "your gate chain", "exitCode": 0,
      "date": "2026-09-08", "recordedBy": "you" }
  ]
}
```

`topology` is `single` or `multi`; `tiers` are the menu tiers (backend, frontend, mobile,
database, integration) **or any custom tier** (lowercase name — worker, cli, …; custom
tiers are first-class, `docs/rulebooks/README.md`) — every declared tier must have its
instantiated `docs/rulebooks/<tier>-rules.md`; `codeRepos` is the multi-repo-only list of
nested code repositories the machine scope check reaches into
(`scripts/scope-check-repos.ps1`) — plain directory names, one level under this repository,
never paths; `developers` names the people who work on the project, and is what selects
the Critical lane's evidence rule (below); `kitVersionAtInit` is informational — the kit's constitution
version at init time, or `copy` (the doctor never validates it); `gateProof` is your
attestation that the gate has been green at least once (adoption step 3) — record the
exact command (never with secrets in it), the exit code, the date, and who ran it. No
tool writes proof entries for you, and `init-kit.ps1` never overwrites an existing
record — your attestation survives a re-init.

**Multi-repo projects adopted before feature 012** add `codeRepos` by hand — one line, no
migration tool. Put it after `topology`, keeping the record valid JSON:

```json
  "topology": "multi",
  "codeRepos": ["your-api", "your-web"],
```

Until it is there, the doctor WARNs and `scripts/scope-check-repos.ps1` reports `n/a`: the
code phase commits in those repositories are graded by a reviewer's eye, not by a machine
(GAP-016). An empty array counts as "not there" — same WARN, same silence. A single-repo project omits the field entirely — its code lives in this
repository, where `scripts/scope-check.ps1` already reaches it.

**Declaring `developers` (feature 013)** — one line, and it changes exactly one thing:
which evidence a **Critical** feature must produce for independent approval
(`docs/sdlc/critical-delivery.md` item 5).

```json
  "developers": ["ada", "grace"],
```

| What the record says | What a Critical feature must produce |
|---|---|
| nothing (the default) | `second-model-review.md` + the 24-hour cooling-off — the solo substitute |
| one name | the same; one developer *is* the solo case |
| two or more names | a committed `specs/NNN-name/human-pr-review.md` with a filled `## Review Provenance` block — Reviewer, Owner (not the same person), and the verbatim attestation line the template carries — and **no** cooling-off |

Read the table in the direction that matters: **declaring nothing changes nothing.** Every
project adopted before this feature keeps the behaviour it has today, forever, without
touching its record. The field only ever moves a project *off* the substitute, and only when
it says two or more people are here — because the substitute is what a solo developer does
*instead of* independent review, and a second person is not a substitute for anything.

Declare it when your project genuinely has two or more people who review each other's work.
Do not declare it to make a check pass: a team declaration on a one-person project removes
the cooling-off period and asks a reviewer line you will end up filling with your own name,
which the check rejects — correctly.

The count is taken **after** blank *and non-string* entries are dropped and duplicates
collapsed case-insensitively — so `["Ada","ada"]` is one developer and stays solo,
`["ada","grace"," "]` is two and is team, and `["ada",5,"grace"]` is also two, because the
number is discarded rather than counted. A value that is not an array at all, or a file whose
root is not a JSON object, is ignored entirely and the project falls back to solo.

Every one of those fallbacks is safe — they all land on the stricter arm — but they are
**silent** in the check itself, so the doctor reports each as a FAIL *and* prints the mode
the record actually produces — on every one of those paths, including the not-an-array case.
The doctor and the check read the record through the same function
(`scripts/adoption-lib.ps1`), so the mode it prints is the mode you will be held to. Without both halves, a project could believe it declared a team for
months while being checked as solo.

<!-- digest: kit-adoption.json is project-owned: every declared tier needs an instantiated rulebook; gateProof is your attestation. -->

**.kit-version** is written by `update-kit.ps1` (a JSON record of the kit version/commit
you're on). A project adopted by copy that has never run an update can create it as a bare
kit commit sha, or simply run `update-kit.ps1` once. One caveat while both files are
absent: if your `docs/roadmap.md` still carries the kit's own title line, the doctor
cannot tell your project from the kit template and declines to audit — creating either
file (or retitling your roadmap) makes you auditable.

## Partial-install note

If `update-kit.ps1` refuses your target as a partial install, your kit copy is missing
one of the required paths doc-lint checks for — most often a dot-directory
(`.specify/`, `.claude/`) that a file manager or a naive copy silently skipped. Finish
the install (see `adoption/`, step 0) before updating.
