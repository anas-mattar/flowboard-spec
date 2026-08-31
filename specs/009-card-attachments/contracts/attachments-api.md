# Contract: Card Attachments API

Cite this file in a top comment in `AttachmentsEndpoints.cs`, `CardService.cs`'s attachment
methods, the frontend's `lib/api/attachments-client.ts`, and both new Route Handlers
(research.md R-2).

## `POST /v1/cards/{cardPublicId}/attachments` — upload an attachment

FR-001, FR-002, FR-008, FR-009, US1. `Content-Type: multipart/form-data`, one field: `file`.
Requires `Authorization: Bearer <backend session JWT>`. Authorization: caller must resolve to
`BoardAdmin` or `BoardMember` on the card's board (`CanMutate`, research.md R-5) — `Observer`
or no role → `403`/`404` per the existing pattern (no role at all → `404`, matching every other
card endpoint's "board's existence is not confirmed to a non-member" rule).

**Response `201 Created`**:

```json
{
  "publicId": "b8e...",
  "fileName": "wireframe-v3.pdf",
  "sizeBytes": 842213,
  "uploadedBy": { "publicId": "...", "displayName": "...", "initials": "...", "avatarColor": "..." },
  "createdAt": "2026-08-31T10:00:00Z"
}
```

**Failure responses**:

- `400` (validation) — no `file` field, empty file, filename extension on the blocked list,
  or file exceeds the 25 MB cap (spec.md Assumptions, research.md R-4). `backend-rules.md`'s
  fixed status-code list has no `413`, so an oversized file is a validation failure like any
  other, not a distinct status — the request body itself is still allowed up to a higher
  server-level hard cap (research.md R-4) purely as an abuse backstop, never surfaced to the
  client as a different error shape than any other rejected upload.
- `401` — unauthenticated.
- `403` — caller has a role on the board but it is `Observer`.
- `404` — card does not exist, or caller has no role on the card's board.

**Side effects**: writes the file via `IAttachmentStorage`; inserts one `Attachment` row;
inserts one `ActivityEvent` row (`attachment.added`); broadcasts it on the board's realtime
channel (research.md R-6) — all three, or none if any step fails before `SaveChangesAsync()`
commits (backend-rules.md's Realtime section: broadcast only after commit).

## `GET /v1/attachments/{attachmentPublicId}/content` — download an attachment

FR-004, US1/US2. Requires `Authorization: Bearer <backend session JWT>`. Authorization: caller
must resolve to any role on the attachment's card's board — `BoardAdmin`, `BoardMember`, or
`Observer` (spec.md acceptance scenario 2: Observers can open/download). No resolvable role →
`404`.

**Response `200 OK`**: the file's bytes, streamed from `IAttachmentStorage`, with
`Content-Type` set to the stored `ContentType` and
`Content-Disposition: attachment; filename="<FileName>"` (RFC 6266 quoting/escaping for
non-ASCII filenames).

**Failure responses**:

- `401` — unauthenticated.
- `404` — attachment does not exist (including: already removed — spec.md FR-007), or caller
  has no role on its card's board.

**Side effects**: none.

## `DELETE /v1/attachments/{attachmentPublicId}` — remove an attachment

FR-005, FR-006, FR-007, US2. Requires `Authorization: Bearer <backend session JWT>`.
Authorization: caller must be the attachment's uploader, OR resolve to `BoardAdmin` on the
board (`CanRemoveAttachment`, research.md R-5). A `BoardMember` who is not the uploader, or an
`Observer`, → `403`. No resolvable role on the board → `404`.

**Response `204 No Content`**.

**Failure responses**:

- `401` — unauthenticated.
- `403` — caller has a role on the board but cannot remove this specific attachment
  (not the uploader, not `BoardAdmin`).
- `404` — attachment does not exist, or caller has no role on its card's board.

**Side effects**: deletes the `Attachment` row; deletes the underlying file via
`IAttachmentStorage` (best-effort after the row is committed — if physical deletion fails, the
row is already gone and the file is orphaned but permanently inaccessible through the API,
satisfying FR-007's user-visible guarantee); inserts one `ActivityEvent` row
(`attachment.removed`); broadcasts it.

## Card detail payload (extends the existing contract, no new endpoint)

`GET /v1/cards/{cardPublicId}` (specs/004-card-crud/contracts/card-crud-api.md) gains one new
field on the existing response, alongside `labels`/`members`/`checklistItems`:

```json
"attachments": [
  {
    "publicId": "b8e...",
    "fileName": "wireframe-v3.pdf",
    "sizeBytes": 842213,
    "uploadedBy": { "publicId": "...", "displayName": "...", "initials": "...", "avatarColor": "..." },
    "createdAt": "2026-08-31T10:00:00Z"
  }
]
```

FR-003. No `If-Match`/`RowVersion` implication — attachments are not part of the card's own
optimistic-concurrency surface (only `title`/`description`/`dueAt`/`dueComplete` are, per
004's contract); adding/removing an attachment never conflicts with a concurrent card field
edit.
