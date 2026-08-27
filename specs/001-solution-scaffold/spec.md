# Feature Specification: Solution Scaffold

**Feature Branch**: `001-solution-scaffold`
**Created**: 2026-08-27
**Status**: Draft
**Input**: User description: "Solution scaffold: establish the FlowBoard delivery skeleton end-to-end. Backend health endpoint + frontend app shell calling it through the BFF, theme toggle, proving every gear of the delivery framework while stakes are zero."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the system alive end-to-end (Priority: P1)

A team member opens the FlowBoard web application and immediately sees the product name
and a live indicator that the backend service is up. This proves the whole delivery
chain — two deployable applications talking to each other — before any real product
functionality exists.

**Why this priority**: Everything later (boards, cards, realtime) rides on this chain.
If the frontend cannot reach the backend and report it, no other feature can be trusted
to. It is also the vehicle for rehearsing the full delivery ritual at zero stakes.

**Independent Test**: Start both applications, open the web app in a browser, and
observe the product name and a backend status of "ok" without any manual API calls.

**Acceptance Scenarios**:

1. **Given** both applications are running, **When** a user opens the web app's home
   page, **Then** the page shows the FlowBoard product name and a backend status
   indicator that reads as healthy.
2. **Given** the web app is loading the backend status, **When** the check is still in
   flight, **Then** the page shows a recognizable loading state (not a blank area and
   not a premature error).
3. **Given** an automated check exists, **When** the backend's health endpoint is
   called, **Then** it responds successfully with a machine-readable status.

---

### User Story 2 - Switch between light and dark theme (Priority: P2)

A user switches the application between light and dark theme from the app shell. The
choice applies instantly, is remembered on their next visit, and the page never flashes
the wrong theme while loading.

**Why this priority**: The theme system must exist in the shell before any board UI is
built on top of it (the product spec makes theme switching a cross-cutting requirement,
X-02). Retro-fitting theming after screens exist is rework; the wrong-theme flash is
the classic defect this story exists to prevent.

**Independent Test**: Toggle the theme, reload the page, and observe both that the
chosen theme is still active and that no flash of the other theme occurs during load.

**Acceptance Scenarios**:

1. **Given** the app is in light theme, **When** the user activates the theme toggle,
   **Then** the whole page switches to dark theme immediately without a reload.
2. **Given** the user chose dark theme previously, **When** they reload or revisit the
   app, **Then** the page renders in dark theme from the first paint, with no light
   flash.

---

### User Story 3 - Backend unavailable is visible, not silent (Priority: P3)

When the backend service is down or unreachable, a user opening the web app sees an
explicit "backend unavailable" indication instead of a blank area, a spinner that never
resolves, or a fake-healthy display.

**Why this priority**: The governing frontend rules require error states to be
distinguishable from empty and loading states on every data surface; the health
indicator is the first data surface, so it sets the precedent.

**Independent Test**: Stop the backend, open the web app, and observe a clear error
indication for the backend status while the rest of the shell still renders.

**Acceptance Scenarios**:

1. **Given** the backend is stopped, **When** a user opens the web app, **Then** the
   shell still renders (product name, theme toggle) and the status area shows an
   explicit error state, visually distinct from loading and from healthy.

---

### Edge Cases

- What happens when the backend responds slowly (seconds rather than milliseconds)?
  The status area stays in its loading state until resolution — it must not show an
  error prematurely or block the rest of the shell from rendering.
- What happens when the backend returns an unexpected payload? The status area treats
  it as the error state, never as healthy.
- What happens on a first-ever visit with no stored theme preference? The app follows
  the visitor's system theme preference.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The backend service MUST expose a health check at a versioned public
  path that responds with a machine-readable status without requiring authentication.
- **FR-002**: The web application MUST render an app shell showing the FlowBoard
  product name.
- **FR-003**: The app shell MUST query the backend health check through the
  application's sanctioned data path (no direct browser-to-backend calls) and display
  the result.
- **FR-004**: The backend status display MUST implement three visually and
  programmatically distinguishable states: loading, healthy, and unavailable/error.
- **FR-005**: The app shell MUST provide a theme toggle switching the entire page
  between light and dark instantly, remembering the choice across visits, and
  rendering the stored choice from first paint (no wrong-theme flash).
- **FR-006**: An automated test MUST prove the health check responds successfully.
- **FR-007**: The feature MUST introduce no domain entities, no database, and no
  user accounts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person with both applications running can open the web app and see a
  healthy backend status within 5 seconds, with zero manual steps beyond navigation.
- **SC-002**: With the backend stopped, 100% of page loads still render the shell and
  show the explicit unavailable state — never a blank page or an unresolved spinner.
- **SC-003**: Theme choice survives a reload in 100% of attempts, with no visible
  wrong-theme flash.
- **SC-004**: The feature completes the entire delivery ritual — spec, plan (with the
  founding architecture decision recorded), tasks, phased implementation, user-run
  gates exiting 0, AI and human review, merge — leaving a written trail for each step.

## Assumptions

- The health check is a public liveness signal; it carries no sensitive detail and
  therefore needs no authentication (the constitution's security principle applies to
  protected functionality, which this is not).
- The app shell's layout is NOT derived from the product prototype — the prototype
  depicts board screens that later features implement. This feature has no visual
  references, so no Visual Inventory and no Visual Compliance Loop apply; the shell is
  a minimal, clean page consistent with the product name and theming.
- "Remembering" the theme is per browser (local preference), not per account — user
  accounts do not exist yet (FR-007).
- The founding architecture decision (constitution IV bootstrap clause) is recorded in
  this feature's plan, not in this spec; this spec deliberately says nothing about how
  the applications are structured internally.
- Both applications already exist as gate-green empty scaffolds (adoption step 3,
  certified 2026-08-27); this feature gives them their first real behavior.
