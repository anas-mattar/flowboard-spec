# Quickstart — 009 Card Attachments

How to run and verify this feature locally once implemented.

## 0. Apply the migration

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet tool restore
dotnet ef database update --project src/Flowboard.Api --startup-project src/Flowboard.Api
```

## 1. Start both services

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

```powershell
cd D:\solutions\flowboard\flowboard-web
npm run dev
```

## 2. Verify upload and listing (US1)

1. Sign in as a board member, open a card's detail modal.
2. Attach a file (e.g. a small PDF) from the new attachments section. Confirm it appears in
   the list with filename, size, and your name, with no full-page reload.
3. Reload the page. Confirm the attachment is still listed (persisted, not just client state).
4. Sign in as an Observer on the same board (second browser profile), open the same card.
   Confirm the attachment is visible and no upload control is shown.

## 3. Verify download (US1)

1. Click the attachment (any role that can view the card, including Observer). Confirm the
   file downloads/opens with the correct filename and content.

## 4. Verify rejection paths (edge cases)

1. Attempt to upload a file larger than 25 MB. Confirm a clear error and no attachment is
   added.
2. Attempt to upload a file with a blocked extension (e.g. rename any file to `.exe`).
   Confirm a clear error and no attachment is added.

## 5. Verify removal permissions (US2)

1. As the uploader, remove your own attachment. Confirm it disappears from the list for
   everyone (check a second window/profile on the same card).
2. As a board member who did NOT upload a given attachment, confirm no remove control is shown
   for it.
3. As a board admin, remove an attachment uploaded by someone else. Confirm it is removed.
4. As an Observer, confirm no remove control is shown for any attachment.
5. After removal, attempt the previous download URL again (or via devtools). Confirm it now
   returns not-found rather than the file.

## 6. Verify activity feed and realtime (US3)

1. Attach and then remove a file. Open the card's activity feed. Confirm both actions appear
   with the correct actor and filename.
2. Open the same card in two windows. Attach a file in window A. Confirm it appears in window
   B's attachment list without a manual reload (same live-update path as 008).
