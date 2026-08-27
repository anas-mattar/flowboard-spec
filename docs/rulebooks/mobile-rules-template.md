# Mobile Rules — {{PROJECT_NAME}}

> **Binding**: this rulebook is enforced through the mobile tier's compliance checklist
> (Definition of Done item 5, `docs/sdlc/definition-of-done.md`): the checklist asserts,
> this rulebook explains. Domain invariants (`{{DOMAIN_INVARIANTS_PATH}}`) carry
> constitutional force and always outrank this file.

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment):

1. At adoption, fill the {{SLOT}}s and keep only the baseline rules that are TRUE for your
   codebase. On an existing system, write rules descriptively, not aspirationally
   (`adoption/existing-system.md`, step 7). Copy to docs/rulebooks/mobile-rules.md and add
   a "Mobile UI" row to CLAUDE.md's Task-Scoped Reading table pointing at it.
2. Grow it reactively (`adoption/greenfield.md`, step 6): a class of mistake caught twice
   in review becomes a rule here, a binary item in the tier checklist, and — where
   possible — a lint/analyzer rule. Once the machine enforces it, the prose shrinks.
3. Every rule is MUST / MUST NOT with a one-line Why. No advice ("prefer X") — advice is
   what agents drop first under pressure.
-->

## Structure

- Platform and code layout: {{MOBILE_STACK_AND_LAYOUT}} <!-- e.g. "Flutter 3.x — lib/features/<feature>/ with data/ domain/ presentation/", or "React Native + Expo", ".NET MAUI", "Kotlin (Android) / Swift (iOS) native" -->
- New code MUST follow the existing layout. A new top-level folder, module, or navigation
  pattern requires approval in the feature's `plan.md`.
  **Why**: architecture changes ride in on "just one helper folder" — this is where drift starts.

## Data Flow

- ALL backend access MUST go through the single API client layer — {{API_CLIENT_LAYER}}.
  Screens and widgets MUST NOT issue HTTP calls directly.
  **Why**: one client layer is the only place timeouts, auth headers, and error mapping can
  be enforced once.
- Code consuming a feature contract MUST cite the contract file (the feature's `contracts/`
  directory) in a comment at the top of the file.
  **Why**: the citation makes rung-checking possible during review.
- Derived business values (totals, conversions, statuses) MUST NOT be re-computed on the
  device; display what the backend returns.
  **Why**: two implementations of one formula always diverge — and the stale app version in
  the field diverges forever.
- Offline and caching behavior is fixed here: {{OFFLINE_AND_CACHING_RULES}}
  <!-- e.g. "no offline support — a failed call shows the unavailable state", or the exact cache/sync policy. If you support offline writes, the conflict rule belongs here too. -->

## UI States

- Every screen that loads data MUST implement all four states: loading, empty,
  error/unavailable, populated. A backend failure MUST be visually distinguishable from an
  empty result. **Why**: an error rendered as "no data" silently hides outages from users.
- State/UI conventions: {{UI_STATE_CONVENTIONS}} <!-- e.g. state-management library and the idiom tests assert on -->
- When the feature has visual references (`specs/[feature]/screenshots/` — rung 1), they
  outrank this file: run the Visual Compliance Loop (`docs/sdlc/review-process.md`).

## Platform Discipline

- Tokens and credentials MUST be stored in the platform secure store — {{SECURE_STORAGE}}
  <!-- e.g. "Keychain (iOS) / EncryptedSharedPreferences (Android) via flutter_secure_storage" -->
  — never in plain preferences, files, or app state that survives logout.
- Secrets MUST NOT be embedded in the app bundle or source. Anything shipped in the binary
  is public. **Why**: mobile binaries are trivially decompiled; a bundled secret is a leak.
- The app MUST request only the device permissions listed in the feature's `plan.md`.
  **Why**: an unplanned permission is a store-review rejection and a user-trust cost.

## Testing

- {{MOBILE_TEST_STANDARDS}} <!-- e.g. "widget tests for every screen state; unit tests for the API client's error mapping; golden tests for visual-reference screens" -->
- The gate (`docs/sdlc/gate-command.md`) is run by the user; a phase is not done before
  the user confirms exit code 0.

## Release & Build

- Build and signing configuration comes from {{BUILD_AND_SIGNING_SOURCE}}; signing material
  MUST NOT be committed.
- Version and store-release steps MUST follow `docs/sdlc/deployment-standards.md`.
  **Why**: a mobile release cannot be rolled back like a server deploy — users keep the old
  binary; the release checklist is the only undo you get.
