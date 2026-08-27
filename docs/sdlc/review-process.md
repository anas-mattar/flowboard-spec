# Review Process

## Visual Compliance Loop *(UI phases — runs BEFORE requesting the gate)*

Required for any phase that touches UI when the feature has visual references
(`specs/[feature]/screenshots/`). The agent MUST NOT ask the user to run the gate while
this loop is open. "Looks close" is not a resolution.

1. **Render the real output.** Start the app and capture a screenshot of the implemented
   screen at the **same viewport size** as the reference — web via browser automation;
   mobile via the emulator (`adb exec-out screencap -p` / `xcrun simctl io booted screenshot`).
   If the agent's environment cannot capture, it asks the user to capture and paste the
   screenshot — the loop still runs, with the user as the camera.
2. **Compare side by side** against the reference, walking the spec's Visual Inventory
   item by item (`spec.md`, Visual Inventory section). Compare structure and
   specification — layout, hierarchy, spacing, ordering, exact labels, colors, states —
   not pixels: prototypes are never pixel-identical to real renders, so pixel-diff
   tooling does not apply here.
3. **Produce the deviation table** in the phase notes:

   | # | Element (VI ref) | Reference shows | Implemented shows | Severity | Resolution |
   |---|---|---|---|---|---|

4. **Fix and repeat** (recapture after every fix) until the table is **empty**, or every
   remaining row is marked `proposed to accept` **and the user has approved it**
   (e.g. the prototype shows sample data the real app cannot reproduce).

Exit rule: empty table, or user-approved rows only. Attach the final table and both
screenshots to the phase notes — the AI review verifies they exist.

## After Each Phase

1. User runs the gate command (`docs/sdlc/gate-command.md`).
2. User checks:

```bash
git diff --stat
```

3. Fix only current phase issues.
4. Revert unrelated changes.
5. Commit successful phase.
6. Do not start next phase without approval.

## AI Review

Complete `specs/_templates/ai-code-review-template.md`. Check:

- Spec match
- Visual-reference match (where visual references exist): the Visual Compliance Loop's
  deviation table is attached and is empty or user-approved
- Backend rules
- Frontend rules
- Security
- Tests
- Migrations
- Unrelated changes
- Rollback safety

## Human Review

AI review alone is insufficient. **Human review is required before merge**, and a
change MUST NOT be merged until a human reviewer approves it (constitution XII).

Human reviewer checks (record in `specs/_templates/human-pr-review-template.md`):

- Actual UI vs visual references
- Business behavior
- Domain correctness (business-critical calculations against `{{DOMAIN_INVARIANTS_PATH}}`)
- Security implications
- Architectural compliance
- Code diff
- Gate result
- No unrelated changes

## Merge

Merge only after the human reviewer approves. See the consolidated gates in
`docs/sdlc/definition-of-done.md`.
