# Contract: Auth API

Cite this file in a top comment in `AuthEndpoints.cs` and in the frontend's
`lib/api/auth-client.ts` / `server/api/routers/auth.ts` (backend + frontend rulebooks'
contract-citation rule).

## `POST /v1/auth/signup`

Public (no auth required). Rate-limited (backend-security.md §12).

**Request**

```json
{
  "email": "maya@example.com",
  "password": "correct horse battery staple",
  "displayName": "Maya Chen"
}
```

- `email`: required, valid email format, ≤ 320 chars.
- `password`: required, minimum 10 characters (research R-10). Never logged, never
  echoed back.
- `displayName`: required, 1–100 chars.

**Response `201 Created`**

```json
{
  "user": {
    "publicId": "b6e6f9b2-...-...",
    "email": "maya@example.com",
    "displayName": "Maya Chen",
    "initials": "MC",
    "avatarColor": "#7c3aed"
  },
  "workspace": {
    "publicId": "9a1e2c40-...-...",
    "name": "Maya Chen's Workspace",
    "role": "WorkspaceAdmin"
  },
  "token": "eyJhbGciOi...",
  "expiresAtUtc": "2026-09-10T12:00:00Z"
}
```

Side effect (FR-006): a `Workspace` row is created in the same transaction, with this
user as `OwnerUserId`. If any pending `Invitation` rows exist for this email
(`Status = 'Pending'`), each is converted to a `BoardMember` row and marked `Accepted`
in the same transaction (FR-011).

**Failure responses** (via `Result<T>` → `ToHttpResult()`, ADR-5):

- `400` — validation failure (bad email format, password too short, missing
  `displayName`) — `ProblemDetails` naming the failing field(s).
- `409` — email already has an account (FR-002). Message: `"email already in use"` —
  no further detail.

## `POST /v1/auth/login`

Public. Rate-limited (backend-security.md §12).

**Request**

```json
{ "email": "maya@example.com", "password": "correct horse battery staple" }
```

**Response `200 OK`** — same shape as signup's response (`user`, `workspace`, `token`,
`expiresAtUtc`).

**Failure responses**:

- `401` — email not found OR password incorrect. **Identical message and status for
  both cases** (FR-004 — must not reveal whether the email is registered).

## Token usage

Every other protected endpoint (board membership, and every endpoint 003+ adds)
requires `Authorization: Bearer <token>`. A missing or invalid/expired token → `401`.
Token claims are identity-only (`sub` = user `PublicId`, `email`, `iat`, `exp`) — no
workspace or role claims (research R-6); callers must not assume the token encodes
current authorization state.

## Explicitly not in this contract

- No `POST /v1/auth/logout` endpoint. The backend JWT is stateless with no
  server-side revocation list (ADR-7, deferred); "signing out" is the frontend
  discarding its NextAuth session (spec FR-005) — see `plan.md` ADR-7/ADR-8.
- No `GET /v1/me` / session-refresh endpoint. Workspace identity is fixed at signup for
  the lifetime of this feature (ADR-10 — no reassignment flow); the NextAuth session
  already carries what was returned at login. A later feature reintroducing this
  becomes necessary only if workspace identity becomes mutable.
