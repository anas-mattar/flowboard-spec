# Frontend Security Rules

## Purpose

This file defines mandatory frontend security rules for FMS.

Frontend security does not replace backend security. The backend remains the authority. The frontend must avoid exposing secrets, leaking data, or misleading users about permissions.

## 1. No Secrets in Frontend

Never expose secrets to browser code.

Forbidden:

- API keys
- client secrets
- database connection strings
- private tokens
- backend service credentials

Only variables intended for browser exposure may use public environment prefixes.

## 2. Protected Routes

Protected pages must check session using the project-approved auth pattern.

Frontend route protection improves UX, but backend must still enforce authorization.

## 3. Permission-Based UI

Hide or disable actions the user cannot perform.

Examples:

- Post journal
- Reverse journal
- Close period
- Approve payment
- Export report
- Manage COA
- Manage integrations

Do not rely on UI permissions only. Backend must enforce the same rule.

## 4. Input Validation

Frontend forms must validate using Zod/React Hook Form patterns.

Frontend validation is for user experience. Backend validation is authoritative.

## 5. Unsafe HTML

Do not use `dangerouslySetInnerHTML` unless explicitly approved and sanitized.

If rich text is required:

- sanitize content
- document source
- review XSS risk

### 5.1 Approved static exception — theme bootstrap script

`src/app/layout.tsx` renders one inline `<script>` via `dangerouslySetInnerHTML` to set
the initial light/dark theme before first paint (prevents a flash of the wrong theme).
This is an **approved static exception** (feature 048, SEC-05):

- The script body is a **fixed string literal** — no user input, no request data, no
  interpolated variables ever reach it. It cannot carry an injection payload.
- Its only effect is reading `localStorage`/`matchMedia` and toggling a class on
  `<html>`.

Any change to this script must keep it a fixed literal. Adding a **new**
`dangerouslySetInnerHTML` still requires explicit approval per §5 — this exception does
not generalize.

## 5a. Content Security Policy (deferred roadmap item)

FMS does **not** yet ship a Content-Security-Policy header. This is a **known,
deliberately deferred** item (feature 048, SEC-05 — doc-only this batch):

- A hash/nonce CSP has a high blast radius (it can break every page, including the
  approved theme-bootstrap inline script in §5.1) and deserves its own feature with
  dedicated testing across all routes.
- Until CSP lands, the mitigations above stand: no unapproved inline scripts, no
  unsanitized `dangerouslySetInnerHTML`, and the single approved static inline script
  in §5.1.

Tracked as a roadmap item; do not add a CSP ad hoc inside an unrelated feature.

## 6. File Upload UI

If upload exists:

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
Unable to submit. Please check the data and try again.
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

Do not store sensitive tokens manually in localStorage unless the project auth design explicitly requires it.

Use the project-approved session/auth provider.

## 10. Data Leakage

Do not render data outside the user's authorized entity scope.

Do not keep sensitive data in global state longer than needed.

Be careful with console logs, browser storage, exported files, cached query data, and screenshots/debug tools.

## 11. Export Security

For export buttons:

- check permissions
- show scope being exported
- avoid exporting hidden unauthorized data
- backend should generate or authorize export

## 12. Frontend Security Review Checklist

Before completing a frontend phase, check:

- [ ] No secrets exposed to browser.
- [ ] Protected routes check session.
- [ ] Permission UI matches backend permissions.
- [ ] Forms validate input.
- [ ] No unsafe HTML.
- [ ] Upload UI has restrictions if relevant.
- [ ] Error messages are safe.
- [ ] External links are safe.
- [ ] Sensitive data is not logged.
- [ ] Export actions are permission-aware.
