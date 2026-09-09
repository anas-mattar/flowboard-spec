# Branch Protection Recipe

Makes `.github/workflows/ritual-checks.yml` an actual merge gate on GitHub, not just an
informative CI run — completing the enforcement pack (kit feature 002) and the
verification pack (kit feature 006). Without this, the checks in
`scripts/ritual-checks.ps1` (doc-lint + enforcement-pack + scope-check + digests +
roadmap-claims, plus the adoption doctor in adopted projects) run but nothing stops a
PR that fails them from being merged anyway.

> **Migrating from the 002-era checks**: `ritual-checks` supersedes the separate
> `doc-lint` and `enforcement-pack` workflows/check names. A repository that already
> requires those two must add `ritual-checks` to the required list and remove the two
> old names once the new workflow has run — a required check that no workflow produces
> blocks every merge.

## Prerequisite

The `ritual-checks` workflow (`.github/workflows/ritual-checks.yml`) must have run
at least once on this repository (any push or PR) — GitHub only lists a check as available
to require after it has appeared at least once.

## Steps (GitHub web UI)

1. Go to the repository on GitHub → **Settings** → **Branches**.
2. Under **Branch protection rules**, click **Add branch protection rule** (or edit the
   existing rule for `main`, if one exists).
3. **Branch name pattern**: `main`.
4. Enable **Require status checks to pass before merging**.
5. In the status-check search box, find and select **ritual-checks** (the job name from
   `.github/workflows/ritual-checks.yml`).
6. Enable **Require branches to be up to date before merging** — so the check re-runs
   against the latest `main`, matching `docs/sdlc/team-workflow.md` §6 ("Rebase before
   gate").
7. Enable **Do not allow bypassing the above settings** so the rule also applies to repo
   admins — a required check that admins can route around isn't a gate.
8. Save the rule.

## Steps (GitHub CLI, equivalent)

`gh api`'s `-f`/`-F` flags cannot express the nested `required_status_checks` object
reliably (tested while writing this recipe — GitHub rejects it as an invalid boolean/array
type). Use a JSON input file instead:

```bash
cat > branch-protection.json <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["ritual-checks"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON

gh api -X PUT repos/{owner}/{repo}/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input branch-protection.json
```

Replace `{owner}/{repo}` with this repository's path.

## Verifying it worked

Open a PR from a branch you know will fail a check (e.g. a `NNN-*` branch missing
`plan.md`, or a phase commit touching a file outside its declared territory). The PR page
should show the `ritual-checks` check as failing/red, and the merge button should be
disabled with a message naming the required check.

## Recommended addition: the project gate (adopted projects)

Where the project-gate workflow is wired (**.github/workflows/project-gate.yml**, copied
from the kit's template — `docs/sdlc/gate-command.md`, "Wiring the project gate in CI"),
also select **project-gate** as a required status check in step 5. Recommended, never
mandated by the kit: it makes the CI-held evidence (constitution X) a merge gate too, but
projects whose gates cannot run in CI keep the user-run gate as their lawful path.

## What this does NOT cover

- Cross-repository features (`docs/sdlc/repository-strategy.md`) need this rule applied in
  each repository separately.
- This protects `main` only. A project that also protects a `release/*` or similar branch
  should repeat these steps for that branch pattern.
