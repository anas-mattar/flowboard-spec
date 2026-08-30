# Contract Addendum: `GET /v1/boards/{boardPublicId}` gains `description` per card

Extends `specs/003-board-view-readonly/contracts/board-content-api.md`'s
`GET /v1/boards/{boardPublicId}` response (as extended by
`specs/006-board-list-management/data-model.md`'s `rowVersion` addendum). Same endpoint,
same method, same status codes, same authorization (`BoardAccessService`, any role may
view) — one additive field per card, nothing else changes.

## Before (003, as amended by 006)

```json
{
  "publicId": "...", "name": "...", "color": "...", "starred": false, "rowVersion": "...",
  "lists": [
    {
      "publicId": "...", "name": "Design", "wipLimit": null, "cardCount": 2, "rowVersion": "...",
      "cards": [
        {
          "publicId": "...", "title": "Card detail redesign",
          "dueAt": "2026-09-02T00:00:00Z", "dueStatus": "soon",
          "hasDescription": true,
          "checklistDone": 2, "checklistTotal": 3, "commentCount": 0,
          "labels": [{ "publicId": "...", "name": "Design", "color": "#7c3aed" }],
          "members": [{ "publicId": "...", "displayName": "Priya Nair", "initials": "PN", "avatarColor": "#ea580c" }]
        }
      ]
    }
  ]
}
```

## After (this feature)

Each card object gains exactly one field, `description`, placed next to the existing
`hasDescription` boolean (which is unchanged and still used by 004's card-front badge):

```json
{
  "publicId": "...", "title": "Card detail redesign",
  "dueAt": "2026-09-02T00:00:00Z", "dueStatus": "soon",
  "hasDescription": true,
  "description": "Redesign the card detail modal to fit the new label chip layout.",
  "checklistDone": 2, "checklistTotal": 3, "commentCount": 0,
  "labels": [ /* unchanged */ ],
  "members": [ /* unchanged */ ]
}
```

`description` is `null` when the card has no description (`hasDescription: false`).
Plain text (no HTML/markdown), matching how `card-description-panel.tsx` already renders
it via `whitespace-pre-wrap` — no sanitization concern, nothing new to escape.

## Non-changes

- No new endpoint, no new query parameter, no new status code.
- No migration — `Card.Description` already exists (004) and is already read into memory
  by `GetBoardContentAsync` today; this only forwards a value already loaded into the
  response DTO (research.md R-2).
- `GET /v1/cards/{cardPublicId}` (single-card detail, `cards-client.ts`) is unchanged — it
  already returns `description`.
