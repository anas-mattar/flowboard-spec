# Frontend Security Rules

## Purpose

This file defines mandatory frontend security rules for FlowBoard.

Frontend security does not replace backend security. The backend remains the authority
(domain invariant 5). The frontend must avoid exposing secrets, leaking data, or
misleading users about permissions.

## 1. No Secrets in Frontend

Never expose secrets to browser code.

Forbidden:

- API keys
- client secrets
- database connection strings
- private tokens
- backend service credentials

Only variables intended for browser exposure may use public environment prefixes. The
backend API token never reaches the browser — all calls go through the tRPC BFF
(frontend rulebook, Data Flow); the SignalR connection uses its own short-lived scoped
token (feature 008).

## 2. Protected Routes

Protected pages must check session using the project-approved auth pattern (feature
002's `plan.md`).

Frontend route protection improves UX, but backend must still enforce authorization.

## 3. Permission-Based UI

Hide or disable actions the user's role cannot perform (spec §6):

- Create / edit / move cards (not for Observers)
- Manage lists and labels (not for Observers)
- Invite / remove board members (board admin)
- Rename / archive / delete board (board admin)
- Manage workspace members & billing (workspace admin)

Do not rely on UI permissions only. Backend must enforce the same rule.

## 4. Input Validation

Frontend forms must validate using Zod/React Hook Form patterns.

Frontend validation is for user experience. Backend validation is authoritative.

## 5. Unsafe HTML

Do not use `dangerouslySetInnerHTML` unless explicitly approved and sanitized.

Card descriptions are rich text (C-05): they MUST render through a sanitizing renderer
approved in feature 004's `plan.md` — document the sanitizer and review XSS risk there.

### 5.1 Theme bootstrap script (pre-approved pattern, pending 001)

A single inline `<script>` in the root layout that sets the initial light/dark theme
before first paint (prevents a flash of the wrong theme — X-02) is the accepted pattern,
subject to approval in the scaffold feature's `plan.md`:

- The script body MUST be a **fixed string literal** — no user input, no request data,
  no interpolated variables. It cannot carry an injection payload.
- Its only effect is reading `localStorage`/`matchMedia` and toggling a class on
  `<html>`.

Any change to this script must keep it a fixed literal. Adding any **other**
`dangerouslySetInnerHTML` still requires explicit approval per §5 — this pattern does
not generalize.

## 5a. Content Security Policy (roadmap item)

Ship a hash/nonce CSP as its own feature, not ad hoc inside an unrelated feature — it
has a high blast radius (it can break every page, including the §5.1 theme script) and
deserves dedicated testing across all routes. Until CSP lands, the mitigations above
stand: no unapproved inline scripts and no unsanitized `dangerouslySetInnerHTML`.

## 6. File Upload UI

Attachments are v1.1 scope. When they arrive:

- restrict accepted file types in UI
- show file size limits
- validate before upload
- show upload result clearly
- backend must still validate

## 7. Error Messages

Do not show raw stack traces or sensitive backend errors.

Show user-safe messages.

Good:

```text
Unable to save. Please check the data and try again.
```

Bad:

```text
SQL exception at connection string...
```

## 8. External Links

External links should open safely.

Use:

```tsx
target="_blank"
rel="noopener noreferrer"
```

## 9. Authentication State

Do not store sensitive tokens manually in localStorage.

Use the project-approved session/auth provider. (localStorage is fine for the theme
preference — §5.1.)

## 10. Data Leakage

Do not render data outside the user's board/workspace scope.

Do not keep sensitive data in global state longer than needed.

Be careful with console logs, browser storage, exported files, cached query data, and
screenshots/debug tools.

## 11. Export Security

For any export action (data-export per spec §8):

- check permissions
- show scope being exported
- avoid exporting hidden unauthorized data
- backend must generate or authorize the export

## 12. Frontend Security Review Checklist

Before completing a frontend phase, check:

- [ ] No secrets exposed to browser.
- [ ] Protected routes check session.
- [ ] Permission UI matches the spec §6 matrix.
- [ ] Forms validate input.
- [ ] No unsafe HTML; rich text goes through the approved sanitizer.
- [ ] Upload UI has restrictions if relevant.
- [ ] Error messages are safe.
- [ ] External links are safe.
- [ ] Sensitive data is not logged.
- [ ] Export actions are permission-aware.
