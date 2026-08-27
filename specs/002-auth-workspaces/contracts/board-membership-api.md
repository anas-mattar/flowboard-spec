# Contract: Board Membership & Invitations API

Cite this file in a top comment in `BoardMembersEndpoints.cs` and in the frontend's
`lib/api/board-members-client.ts` / `server/api/routers/board-members.ts`.

All endpoints below require `Authorization: Bearer <token>` (see `auth-api.md`).
Every endpoint resolves the caller's effective role via `BoardAccessService` (ADR-9)
before doing anything else:

- No access at all (not the workspace owner, no `BoardMember` row) → **`404`** (the
  board's existence is not confirmed to a non-member — FR-013).
- Access exists but the role is insufficient for this specific action → **`403`**.

## `GET /v1/boards/{boardPublicId}/members`

Any role (`BoardAdmin`, `BoardMember`, `Observer`) may view — "View board" is ✓ for
every role in FUNCTIONAL_SPEC §6.

**Response `200 OK`**

```json
{
  "members": [
    {
      "user": { "publicId": "...", "displayName": "Maya Chen", "initials": "MC", "avatarColor": "#7c3aed" },
      "role": "BoardAdmin",
      "isWorkspaceOwner": true
    },
    {
      "user": { "publicId": "...", "displayName": "Dan Osei", "initials": "DO", "avatarColor": "#0ea5e9" },
      "role": "BoardMember",
      "isWorkspaceOwner": false
    }
  ],
  "pendingInvitations": [
    { "publicId": "...", "email": "sofia@example.com", "role": "Observer", "invitedBy": "Maya Chen" }
  ]
}
```

`isWorkspaceOwner: true` marks the implicit-admin row that has no underlying
`BoardMember` record (ADR-9) — the UI needs this to know it can't be "removed" the same
way an invited member can.

## `POST /v1/boards/{boardPublicId}/invitations`

Only `BoardAdmin` (including the implicit workspace-owner admin) may call this
(FR-014). A `BoardMember`/`Observer` caller gets `403`.

**Request**

```json
{ "email": "sofia@example.com", "role": "Observer" }
```

- `role`: one of `BoardAdmin`, `BoardMember`, `Observer`.

**Response `201 Created`**

- If the email already has an account: the `BoardMember` row is created immediately
  (FR-010) and the response is the new member entry (same shape as the `members` array
  item above).
- If the email has no account yet: a `Pending` `Invitation` row is created (FR-011) and
  the response is the pending-invitation entry (same shape as `pendingInvitations`
  above).

**Failure responses**:

- `400` — invalid email format, invalid `role` value.
- `409` — the email already holds a `BoardMember` role on this board (FR-009). Inviting
  an email with an existing **pending** invitation on this board is NOT a conflict — it
  updates that invitation's `Role` in place (data-model.md's filtered unique index) and
  returns `200 OK` with the updated pending-invitation entry.

## `DELETE /v1/invitations/{invitationPublicId}`

Only `BoardAdmin` on the invitation's board (or the workspace owner) may revoke a
`Pending` invitation.

**Response `204 No Content`** — the invitation's `Status` becomes `Revoked`
(`UpdatedDate`/`UpdatedBy` set) — not physically deleted (audit trail, backend-security
§13).

**Failure responses**:

- `404` — invitation not found, already `Accepted`/`Revoked`, or caller has no access
  to its board.
- `403` — caller has board access but is not a `BoardAdmin`.

## `DELETE /v1/boards/{boardPublicId}/members/{userPublicId}`

Only `BoardAdmin` (or the workspace owner) may remove a member (FR-014). A member
cannot remove the workspace owner's implicit access (it isn't a `BoardMember` row to
begin with — `404`/`400` as appropriate).

**Response `204 No Content`** — the `BoardMember` row is hard-deleted (data-model.md —
not master data, no 30-day restorability requirement).

**Failure responses**:

- `404` — no such member on this board, or caller has no board access.
- `403` — caller has board access but is not a `BoardAdmin`.

## Explicitly not in this contract

- No `GET /v1/boards` (list boards visible to the caller) — that's 003/007's endpoint;
  this feature's tests exercise membership directly against the one seeded test board
  (data-model.md).
- No board create/rename/archive endpoints — 006's scope (ADR-11).
