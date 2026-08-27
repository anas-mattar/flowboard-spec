# Frontend Rules — FlowBoard

> **Binding**: this rulebook is enforced through the frontend tier's compliance checklist
> (Definition of Done item 5, `docs/sdlc/definition-of-done.md`): the checklist asserts,
> this rulebook explains. Visual references (rung 1 of Source of Truth) outrank it: never
> invent a layout when screenshots exist, and UI phases with visual references run the
> Visual Compliance Loop (`docs/sdlc/review-process.md`).

<!--
HOW TO FILL THIS RULEBOOK (then delete this comment): same three rules as the backend
template — fill descriptively at adoption (copy to docs/rulebooks/frontend-rules.md,
point {{FRONTEND_RULES_PATH}} at it), grow reactively via review → checklist → lint,
and write every rule as MUST / MUST NOT with a one-line Why.
-->

## Structure

- Code layout: {{FRONTEND_LAYOUT}} <!-- e.g. "App Router: src/app/<route>/page.tsx; shared components in src/components/" -->
- New routes, folders, or shared components follow the existing layout; new top-level
  structure requires approval in the feature's `plan.md`.

## Data Flow

- ALL backend calls MUST go through {{CLIENT_LAYER}}; UI components MUST NOT call the
  backend directly. **Why**: one place for base URL, auth, timeouts, and error mapping.
- Response types MUST mirror the feature's contract (the feature's `contracts/`
  directory) and cite it in a comment. **Why**: the citation makes rung-checking possible.
- Derived business values (totals, conversions, rounding) MUST come from the backend; the
  frontend renders them and MUST NOT re-compute them.
  **Why**: two implementations of one formula always diverge.

## UI States

- Every data surface MUST implement all states that apply: loading, empty,
  error/unavailable, and populated — and the error state MUST be visually and
  programmatically distinguishable from empty.
  **Why**: an error rendered as an empty list is silent data loss to the user.
- {{UI_STATE_CONVENTIONS}} <!-- e.g. "data-state attributes name the active state for tests" -->

## Forms & Input

- {{FORM_STANDARDS}} <!-- e.g. "React Hook Form + zodResolver for all data entry; manual useState field state forbidden; schemas in lib/<feature>/schemas.ts" -->

## Styling

- {{STYLING_STANDARDS}} <!-- e.g. "Tailwind only; every color has a dark: variant; tabular-nums for money columns" -->

## Security

- Server-only secrets and env vars MUST NOT reach client-side code or be exposed through
  public-prefixed variables. **Why**: everything shipped to the browser is public.
- {{FRONTEND_SECURITY_RULES}} <!-- e.g. permission-gated rendering standard -->
