# Rollback — [NNN Feature Name]

## Rollback Method

```bash
git revert [commit-sha]        # one revert per phase commit, newest first
```

[If plain revert is insufficient, document the exact sequence here — and say why.]

## Changed Areas

[Repos, directories, and surfaces this feature touched — the blast radius of a revert.]

## Database Rollback

- Schema changes in this feature: [none / additive / destructive]
- Migration down-path: [migration name(s) + whether `down` is safe to run]
- Protected domain data touched: [none / list] — physical deletion is NOT a rollback
  mechanism (see `docs/sdlc/rollback-process.md`); corrections are additive.

## Deployment Rollback

[Config/env/permission changes that must be undone alongside the code revert — e.g.
permission grants, feature flags, environment variables.]

## Verification After Rollback

- [ ] Gate passes on the reverted state (user-confirmed exit code)
- [ ] [Feature-specific check that the pre-feature behavior is actually restored]
