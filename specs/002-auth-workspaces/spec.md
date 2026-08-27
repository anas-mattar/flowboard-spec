# Feature Specification: Auth & Workspaces

**Feature Branch**: `002-auth-workspaces`
**Created**: 2026-08-27
**Status**: Draft
**Delivery Level**: **Critical** (`docs/sdlc/critical-delivery.md`) — this feature
implements authentication and authorization, one of the addendum's explicit
must-be-Critical triggers. The full addendum applies on top of the standard workflow:
rollback plan before Phase 1, domain-invariant review in both AI and human review, audit
evidence retained, human-executed gates only, independent (or second-model adversarial,
for a solo developer) approval.
**Input**: User description: "Authentication, user accounts, workspaces/organizations, board membership, and roles/permissions. Covers roadmap Inv INV-014 (Permissions & roles) and story B-05 from docs/product/FUNCTIONAL_SPEC.md. This is the foundation feature that lets users sign up/log in, belong to a workspace, and be assigned roles that gate access to boards — required before 003-board-view-readonly can enforce any access control."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create an account and sign in (Priority: P1)

A new visitor creates a FlowBoard account with an email address and password, and is
signed in immediately. A returning user signs back in with the same credentials on any
device.

**Why this priority**: Nothing else in the product is reachable without an authenticated
identity — every other story in this feature, and every later feature, depends on it.

**Independent Test**: Create an account with a fresh email, confirm the session survives
a page reload, sign out, then sign back in with the same credentials.

**Acceptance Scenarios**:

1. **Given** no account exists for an email, **When** the user submits a valid email and
   password, **Then** an account is created and the user is signed in immediately.
2. **Given** an account already exists, **When** the user submits correct credentials,
   **Then** they are signed in.
3. **Given** an account already exists, **When** the user submits an incorrect password,
   **Then** sign-in is refused with a message that does not reveal whether the email is
   registered.
4. **Given** a signed-in user, **When** they reload the page or return later within the
   session lifetime, **Then** they remain signed in without re-entering credentials.

---

### User Story 2 - Land in a personal workspace (Priority: P1)

When a new user finishes creating their account, a workspace is created for them
automatically and they become its Workspace admin, so there is somewhere for their
boards to live with no separate setup step.

**Why this priority**: Boards belong to a workspace (FUNCTIONAL_SPEC §5); a user with no
workspace has nowhere to create a board. This is the minimum needed for any Kanban
feature to have a home.

**Independent Test**: Sign up with a fresh email; verify exactly one workspace exists for
that account, the new user holds the Workspace admin role in it, and it has zero boards.

**Acceptance Scenarios**:

1. **Given** a brand-new account, **When** signup completes, **Then** exactly one
   workspace exists for that user and they hold the Workspace admin role in it.
2. **Given** an existing user, **When** they sign in, **Then** they see their own
   workspace only — never another user's workspace they have not been invited into.

---

### User Story 3 - Invite someone to a board with a role (Priority: P2)

A Board admin or Workspace admin invites another person to a specific board by email and
assigns them a role — Board admin, Board member, or Observer (B-05, FUNCTIONAL_SPEC §6).

**Why this priority**: Collaboration is FlowBoard's whole purpose; a board only the
creator can ever see delivers no team value.

**Independent Test**: As a Board admin, invite a teammate's email to a board with a
chosen role; confirm the invitee sees that board with exactly that role's capabilities
on their next sign-in.

**Acceptance Scenarios**:

1. **Given** a Board admin, **When** they invite an email address that already has a
   FlowBoard account, **Then** that user immediately gains the assigned role on the
   board and the board appears in their accessible boards.
2. **Given** a Board admin, **When** they invite an email already a member of that
   board, **Then** the request is rejected as already-a-member rather than creating a
   duplicate membership.
3. **Given** a Board member or Observer (not an admin), **When** they attempt to invite
   someone to the board, **Then** the action is refused.

---

### User Story 4 - Access is denied without the right role (Priority: P2)

A user who is not a member of a board cannot view or act on it. A user with a lesser
role (e.g. Observer) cannot perform an action above their role's capability, even by
calling the API directly rather than clicking a hidden button.

**Why this priority**: This is the enforcement layer that 003-board-view-readonly and
every later feature depends on — permissions must hold at the API boundary, not just
hide UI controls (domain invariant 5).

**Independent Test**: As a user with no membership on a board, attempt to load it and
confirm access is denied. As an Observer, attempt a Board-admin-only action against the
API directly and confirm it is refused server-side.

**Acceptance Scenarios**:

1. **Given** a user who is neither a Workspace admin of the owning workspace nor a
   member of the board, **When** they request that board's data, **Then** the request
   is denied and no board data is returned.
2. **Given** an Observer on a board, **When** they attempt to create, edit, or move a
   card, or manage members, **Then** the action is refused; they may still view and
   comment.
3. **Given** a Board member (non-admin), **When** they attempt to invite or remove
   members, or rename/archive/delete the board, **Then** the action is refused.
4. **Given** a Workspace admin, **When** they access any board owned by their own
   workspace, **Then** they have Board-admin-level capabilities without a separate
   per-board invite.

---

### User Story 5 - Sign out (Priority: P3)

A signed-in user can end their session from anywhere in the app.

**Why this priority**: Baseline account hygiene, especially on a shared device.

**Independent Test**: Sign in, sign out, then confirm previously accessible pages now
require signing in again.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they choose sign out, **Then** their session
   ends immediately and protected pages require signing in again.

---

### Edge Cases

- Signup with an email that already has an account → refused, no duplicate account
  created.
- A password below the minimum strength standard → refused, with the specific rule that
  failed.
- An invite is sent for a board the inviter no longer has admin rights on (e.g. their
  role was downgraded moments earlier) → the invite is refused, not honored from stale
  state.
- A user's board role is downgraded or their membership removed while they are actively
  viewing the board → their very next request is subject to the new role/absence of
  membership, not just their next sign-in.
- The same person is invited to the same board twice with different roles before
  accepting → the most recent invite's role applies; no duplicate membership rows.
- A session expires while a user is mid-edit → the next request is treated as
  unauthenticated rather than silently discarding or misattributing the edit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a person to create a FlowBoard account with an email
  address and a password.
- **FR-002**: System MUST reject signup when the email already has an account, without
  creating a duplicate account.
- **FR-003**: System MUST enforce a minimum password strength standard and reject
  weaker passwords, naming the specific rule that failed.
- **FR-004**: System MUST allow a user with correct credentials to sign in, and MUST
  reject incorrect credentials with a message that does not reveal whether the email is
  registered.
- **FR-005**: System MUST keep a signed-in user's session valid across page reloads
  until they sign out or the session expires, and MUST let the user sign out at will,
  ending the session immediately.
- **FR-006**: System MUST automatically create exactly one workspace for a user at the
  moment their account is created, and MUST assign that user the Workspace admin role
  for it.
- **FR-007**: System MUST NOT allow a user to create or own a second workspace via
  self-service signup (multiple workspaces per account are out of scope for v1.0,
  FUNCTIONAL_SPEC §1.2).
- **FR-008**: A Board admin or the owning Workspace's admin MUST be able to invite a
  user to a specific board by email address and assign one of the roles defined in
  FUNCTIONAL_SPEC §6 (Board admin, Board member, Observer).
- **FR-009**: System MUST reject an invite for an email address that already holds
  membership on the target board, rather than creating a duplicate membership.
- **FR-010**: When the invited email already has a FlowBoard account, System MUST grant
  the board membership and role immediately, and the board MUST appear among that
  user's accessible boards on their next request.
- **FR-011**: When the invited email has no FlowBoard account yet, System MUST hold the
  invitation as pending and grant the board membership automatically the moment that
  person completes signup with the invited email address.
- **FR-012**: System MUST enforce the full FUNCTIONAL_SPEC §6 capability matrix at the
  server boundary for every board-scoped action — never relying on the client to hide a
  control as the only safeguard (domain invariant 5).
- **FR-013**: System MUST deny access to a board's data to any user who is neither the
  Workspace admin of its owning workspace nor a member of that specific board.
- **FR-014**: Only Workspace admins and Board admins MUST be able to invite or remove
  board members; Board members and Observers attempting to do so MUST be refused.
- **FR-015**: A Workspace admin MUST have Board-admin-level access to every board owned
  by their own workspace without a separate per-board membership row.
- **FR-016**: System MUST expose every user, workspace, and board-membership identifier
  in API responses as an opaque public identifier, never the internal primary key
  (domain invariant 8).
- **FR-017**: System MUST record which role each board member holds so later features
  (card CRUD, board management) can key their own permission checks off it without
  re-deriving membership.
- **FR-018**: System MUST claim a pending invitation only for a signup whose email
  address exactly matches the invited address. This is an exact-match check on a
  self-asserted signup field, **not** proof that the signer-upper owns that mailbox —
  email verification is out of scope for v1.0 (see Assumptions and the accepted
  residual risk below); FR-018 does not by itself prevent one account from claiming an
  invitation intended for a different, not-yet-registered person at that address.

### Key Entities

- **User**: An individual account holder — email, password credential, display name,
  initials/avatar color (FUNCTIONAL_SPEC §5). Creates exactly one Workspace at signup.
- **Workspace**: The top-level container from FUNCTIONAL_SPEC §5; owns Boards. In this
  feature's scope, a workspace has exactly one Workspace admin — its creator.
- **BoardMember**: The join between a User and a Board carrying a role (Board admin /
  Board member / Observer, FUNCTIONAL_SPEC §6) — the record every board-scoped
  permission check is made against.
- **Invitation**: A pending grant of a specific role on a specific board to an email
  address, created by an inviter holding sufficient role; resolves into a BoardMember
  when the invitee has (or creates) a matching account.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user goes from landing on the signup page to seeing their own
  (empty) workspace in under 60 seconds.
- **SC-002**: 100% of board-scoped actions attempted by a user lacking the required
  role are refused when tested directly against the API — zero cases where only a
  hidden UI control stood between the user and the action.
- **SC-003**: An invited user who already has an account can see and open the board
  they were invited to on their very next request after the invite is sent — no manual
  refresh workaround, no re-login required.
- **SC-004**: Zero duplicate accounts are ever created for the same email address, even
  under concurrent signup attempts.
- **SC-005**: No signed-out or session-expired request is ever able to retrieve or
  mutate board data — verified across every protected endpoint in security testing.

## Assumptions

- Authentication is FlowBoard's own email/password login. Enterprise SSO (SAML/OIDC,
  FUNCTIONAL_SPEC §8) is a later-tier addition and out of scope for this feature; the
  data model here does not preclude adding it.
- A workspace has exactly one admin — its creator — for v1.0. There is no
  workspace-level invite/add-admin flow, matching "multiple workspaces per account" being
  explicitly out of scope (FUNCTIONAL_SPEC §1.2) and no workspace-membership story
  existing among the FUNCTIONAL_SPEC B-*/L-*/C-* stories. Workspace admin count and
  transfer are not addressed by this feature.
- Board collaboration crosses workspace boundaries: a user can hold a BoardMember role
  (including Observer) on a board owned by a different user's workspace — only that
  board's owning-workspace admin gets automatic Board-admin rights on it.
- Password hashing algorithm, session token mechanism, and exact session lifetime are
  implementation details for `plan.md` (constitution IV); this spec only requires
  industry-standard practice (FUNCTIONAL_SPEC §8: bcrypt/argon2, TLS in transit).
- Email verification before granting write access is out of scope for v1.0; a new
  account can use the product immediately after signup.
- Workspace lifecycle beyond creation (rename, delete, transfer ownership) is out of
  scope for this feature.
- Session lifetime: a signed-in session survives page reloads and normal return visits;
  exact expiry policy is a `plan.md` decision, not fixed here.

## Accepted Residual Risk

- **Unverified invitation claiming (H2, `second-model-adversarial-review.md`)**: because
  email verification is out of scope for v1.0 (see Assumptions) and invitation claiming
  (FR-018) matches on a self-asserted email string, two attacks are accepted as
  known, unmitigated risk for this release: (1) an attacker who learns that an email
  address has a pending invitation can sign up with that exact address first and inherit
  its board access; (2) any user can pre-create a pending invitation for an email they
  don't own, silently enrolling that person in their board (with no accept step) the
  next time that person signs up for any reason. Mitigation is deferred to a future
  feature — most directly, a per-invitation claim token required at signup, which closes
  attack (1) without needing to send email. Until then, this is a known trade-off of
  shipping v1.0 without email verification, not an oversight.
