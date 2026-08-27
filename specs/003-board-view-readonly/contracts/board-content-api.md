# Contract: Board Content API (read-only)

Cite this file in a top comment in `BoardsEndpoints.cs` and in the frontend's
`lib/api/boards-client.ts` / `server/api/routers/boards.ts`.

Both endpoints below require `Authorization: Bearer <token>` (see `auth-api.md`).
`GET /v1/boards/{boardPublicId}` resolves the caller's access via `BoardAccessService`
(ADR-9, 002) first, same as every board-scoped endpoint in `board-membership-api.md`:

- No access at all → **`404`** (FR-013, board existence not confirmed to a non-member).
- Any role (`BoardAdmin`, `BoardMember`, `Observer`) may view — "View board" is ✓ for
  every role (FUNCTIONAL_SPEC §6).

`GET /v1/boards` has no per-board access check by definition — it returns exactly the
boards the caller has access to (workspace-owned + explicit membership), nothing more.

## `GET /v1/boards`

Query params: `cursor` (opaque string, omit for the first page), `limit` (default `20`,
max `50`).

Sort order (R-3): starred boards first, then `CreatedDate` ascending, `Id` ascending as
the tiebreaker (invariant 2's tiebreak convention, applied here for determinism even
though this isn't itself a `position`-ordered list).

**Response `200 OK`**

```json
{
  "items": [
    { "publicId": "...", "name": "Product Roadmap Q3", "color": "#4f46e5", "starred": true, "cardCount": 13 },
    { "publicId": "...", "name": "Marketing Launch", "color": "#7c3aed", "starred": false, "cardCount": 4 }
  ],
  "nextCursor": null
}
```

`nextCursor` is a string to pass as the next request's `cursor`, or `null` when this is
the last page. An empty `items` array (with `nextCursor: null`) is the empty-state case
(SC-005) — a valid `200`, not an error.

**Failure responses**: `400` — malformed `cursor` or `limit` out of range.

## `GET /v1/boards/{boardPublicId}`

Single hydration call — the whole board's lists and cards in one response (no
pagination within a board this feature; FUNCTIONAL_SPEC §7 names this endpoint
explicitly as "single hydration call").

**Response `200 OK`**

```json
{
  "publicId": "...",
  "name": "Product Roadmap Q3",
  "color": "#4f46e5",
  "starred": true,
  "lists": [
    {
      "publicId": "...",
      "name": "Backlog",
      "wipLimit": null,
      "cardCount": 3,
      "cards": [
        {
          "publicId": "...",
          "title": "Define SSO requirements for Enterprise",
          "dueAt": "2026-09-08T00:00:00Z",
          "dueStatus": "future",
          "hasDescription": false,
          "checklistDone": null,
          "checklistTotal": null,
          "commentCount": 0,
          "labels": [ { "publicId": "...", "name": "Feature", "color": "#16a34a" } ],
          "members": []
        }
      ]
    },
    {
      "publicId": "...",
      "name": "In Progress",
      "wipLimit": 3,
      "cardCount": 4,
      "cards": [ "..." ]
    }
  ]
}
```

**Field notes**:

- `dueAt: null` whenever there is no due date; `dueStatus: null` in that case too.
- `dueStatus` (server-computed, `frontend-rules.md`: derived display values come from
  the backend, never recomputed client-side) — one of:
  - `"complete"` — `DueComplete = true`, regardless of `DueAt`.
  - `"overdue"` — `DueAt` is in the past and not complete.
  - `"soon"` — `DueAt` is within 2 days from now (inclusive) and not complete.
  - `"future"` — `DueAt` is more than 2 days out and not complete.
  - `null` — no `DueAt` at all.
- `checklistDone`/`checklistTotal`: both `null` together when the card has zero
  checklist items (VI-011's "no placeholder for data the card doesn't have"); both
  present (including `0`) once at least one item exists.
- `wipLimit: null` renders as a plain count pill; a number renders `count/limit`, red
  when `cardCount > wipLimit` (VI-007) — this endpoint never blocks anything on this
  value (invariant 3).
- `lists`/`cards` are already in their stored `Position` order (invariant 2) — the
  frontend MUST NOT re-sort them.

**Failure responses**: `404` — no access to this board (or it doesn't exist).

## Explicitly not in this contract

- No `POST`/`PATCH`/`DELETE` for boards, lists, or cards — 004 (cards)/005
  (drag-drop)/006 (board/list management).
- No `GET /v1/boards/{id}/search` — 007's endpoint (FUNCTIONAL_SPEC §7).
- No individual `GET`/route for a `List`, `Card`, `Label`, `ChecklistItem`, or `Comment`
  by its own identifier — everything this feature needs is returned inside the one
  `GET /v1/boards/{id}` hydration call.
