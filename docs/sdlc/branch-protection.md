# Branch Protection Recipe

Makes `.github/workflows/enforcement-pack.yml` an actual merge gate on GitHub, not just an
informative CI run — completing the enforcement pack (kit feature 002).
Without this, the checks in `scripts/enforcement-pack.ps1` run but nothing stops a PR that
fails them from being merged anyway.

## Prerequisite

The `enforcement-pack` workflow (`.github/workflows/enforcement-pack.yml`) must have run
at least once on this repository (any push or PR) — GitHub only lists a check as available
to require after it has appeared at least once.

## Steps (GitHub web UI)

1. Go to the repository on GitHub → **Settings** → **Branches**.
2. Under **Branch protection rules**, click **Add branch protection rule** (or edit the
   existing rule for `main`, if one exists).
3. **Branch name pattern**: `main`.
4. Enable **Require status checks to pass before merging**.
5. In the status-check search box, find and select **enforcement-pack** (the job name from
   `.github/workflows/enforcement-pack.yml`). Also select **doc-lint** if it isn't already
   required.
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
    "contexts": ["enforcement-pack", "doc-lint"]
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
`plan.md`). The PR page should show the `enforcement-pack` check as failing/red, and the
merge button should be disabled with a message naming the required check.

## What this does NOT cover

- Cross-repository features (`docs/sdlc/repository-strategy.md`) need this rule applied in
  each repository separately.
- This protects `main` only. A project that also protects a `release/*` or similar branch
  should repeat these steps for that branch pattern.
