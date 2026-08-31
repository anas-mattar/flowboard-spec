# Feature Specification: Card Attachments

**Feature Branch**: `009-card-attachments`
**Created**: 2026-08-31
**Status**: Draft
**Input**: User description: "File attachments on cards. Users can attach files to a card from
the card detail modal: upload one or more files, see them listed with filename, size, and
uploader, download/open a file, and remove an attachment they have permission to remove.
Attached files are stored in object storage (not the database) and referenced from the card.
This is the first slice of v1.1 — Collaboration (FUNCTIONAL_SPEC.md §10), building on the
existing card detail modal (INV-007) shipped in 004-card-crud. Follow existing FlowBoard
conventions: board-scoped permissions/roles from 002-auth-workspaces (§6), activity event
logging alongside the other card activity events (§5.2), and the card detail modal's existing
sections (labels, members, due date, checklist, comments) as the pattern to extend rather than
redesign. No visual prototype/screenshots exist for attachments yet, so the modal's addition
should follow the established visual language of the other card detail sections rather than
inventing a new layout."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Attach and view files on a card (Priority: P1)

A board member opens a card and wants to attach supporting material — a design file, a
document, a screenshot — directly to the card so anyone who opens it later has the context
without hunting through chat history or email. They upload one or more files from the card
detail modal and immediately see each one listed with its filename, size, and who uploaded it.
Anyone who can view the card — including an Observer — can open or download a listed file.

**Why this priority**: This is the entire value proposition of the feature. Without upload and
visibility, there is nothing to remove or log, and the feature delivers no value on its own.

**Independent Test**: Can be fully tested by opening a card, uploading a file from the card
detail modal, confirming it appears in the attachments list with correct filename/size/uploader,
and opening or downloading it — delivers standalone value (durable, shared file context on a
card) with no dependency on the other stories below.

**Acceptance Scenarios**:

1. **Given** a card detail modal is open and the user is a board member or admin, **When** they
   choose one or more files to attach, **Then** each file appears in the card's attachment list
   with filename, human-readable size, and the uploader's name, without a full-page reload.
2. **Given** a card has one or more attachments, **When** any user who can view the board
   (including an Observer) opens the card, **Then** they see the same attachment list and can
   open or download each file.
3. **Given** an upload is in progress, **When** the user views the attachment list, **Then** the
   in-progress file shows a visible pending/uploading state until it completes or fails.
4. **Given** an upload fails (e.g., network interruption), **When** the failure occurs, **Then**
   no partial or broken attachment is added to the card, and the user sees a clear error they
   can retry.

---

### User Story 2 - Remove an attachment (Priority: P2)

A board member realizes an attached file is outdated, wrong, or was uploaded by mistake, and
removes it from the card. Once removed, the file is no longer listed on the card and is no
longer retrievable by anyone.

**Why this priority**: Removal is necessary for the feature to be trustworthy for real use (bad
uploads happen), but a card can be useful with attach-only capability first — this is a
refinement on top of US1, not a blocker for it.

**Independent Test**: Can be fully tested by attaching a file (using the US1 capability), then
removing it, and confirming it disappears from the attachment list and is no longer
downloadable — delivers standalone value (correcting mistakes) once US1 exists.

**Acceptance Scenarios**:

1. **Given** a card has an attachment uploaded by the current user, **When** that user chooses
   to remove it, **Then** the attachment disappears from the list for all viewers and can no
   longer be opened or downloaded.
2. **Given** a card has an attachment uploaded by someone else, **When** a board admin or
   workspace admin chooses to remove it, **Then** it is removed the same way.
3. **Given** a card has an attachment uploaded by someone else, **When** a board member who is
   not the uploader and not an admin views it, **Then** no remove control is available to them.
4. **Given** an Observer views a card with attachments, **When** they look at the attachment
   list, **Then** they see no upload or remove controls, only open/download.

---

### User Story 3 - Attachment activity and live visibility (Priority: P3)

A board member watching a board sees attachment additions and removals show up in the card's
activity feed and, if they have the board open at the time, sees the attachment list update
live — consistent with how every other card change already behaves.

**Why this priority**: This makes the feature consistent with FlowBoard's existing audit trail
and realtime behavior (shipped in 008-realtime-sync), but attach/view/remove already deliver
the core value without it — a user who reloads the card still sees the current attachment list.

**Independent Test**: Can be fully tested by attaching and removing a file and confirming both
actions produce corresponding entries in the card's activity feed, and by having a second
session open on the same board to confirm the attachment list updates without a manual refresh.

**Acceptance Scenarios**:

1. **Given** a user attaches a file to a card, **When** the upload completes, **Then** an
   activity entry recording who attached what and when appears in the card's activity feed.
2. **Given** a user removes an attachment, **When** the removal completes, **Then** an activity
   entry recording who removed what and when appears in the card's activity feed.
3. **Given** a second user has the same board open, **When** an attachment is added or removed
   by another user, **Then** the second user's view updates without a manual page reload.

---

### Edge Cases

- What happens when a user tries to upload a file that exceeds the maximum allowed size? The
  upload is rejected before any partial file is stored, with a clear message stating the limit.
- What happens when a user tries to upload a file type that is blocked? The upload is rejected
  with a clear message; no file is stored.
- What happens when the same filename is uploaded twice to the same card? Both are kept as
  separate attachments; filenames are not required to be unique on a card.
- What happens when a card is archived while it has attachments? Attachments remain associated
  with the card and are restored along with it, consistent with the existing 30-day archive
  restorability invariant.
- What happens when the uploader loses board access after uploading? The file remains attached;
  access to view/download it is governed by the viewer's current board membership, not by who
  uploaded it.
- What happens when a user's upload is interrupted mid-transfer (closed tab, lost connection)?
  No attachment record is created for the incomplete file; the user must retry.
- What happens when an attachment is removed while another user is actively downloading it? The
  in-flight download is allowed to complete; the file is no longer listed or available to start
  a new download.
- How does the system handle a card with a very large number of attachments? The list scrolls
  within the card detail modal rather than resizing the modal; there is no hard cap on count.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The card detail modal MUST provide a way to upload one or more files as
  attachments to a card, available to workspace admins, board admins, and board members (the
  same roles that can create/edit/move cards per §6), but not to Observers.
- **FR-002**: The system MUST store each uploaded file in object storage and keep only a
  reference (not the file bytes) on the card record.
- **FR-003**: The card detail modal MUST list every attachment on the card showing, at minimum,
  filename, human-readable file size, and the display name of the uploader.
- **FR-004**: Any user who can view the card — including Observers — MUST be able to open or
  download any listed attachment.
- **FR-005**: The system MUST allow an attachment to be removed by the user who uploaded it, or
  by a board admin or workspace admin, regardless of who uploaded it.
- **FR-006**: The system MUST NOT show upload or remove controls to Observers, and MUST NOT
  show a remove control to a board member who is neither the uploader nor an admin.
- **FR-007**: Once an attachment is removed, the system MUST make it immediately unavailable for
  new opens/downloads and remove it from the attachment list for all viewers.
- **FR-008**: The system MUST reject uploads that exceed the maximum allowed file size (see
  Assumptions) before storing any data, with a clear error shown to the user.
- **FR-009**: The system MUST reject uploads of disallowed file types (see Assumptions) before
  storing any data, with a clear error shown to the user.
- **FR-010**: The system MUST record an append-only activity event when an attachment is added
  and when one is removed, following the existing activity event pattern (§5.2), and these
  events MUST appear in the card's activity feed alongside existing event types.
- **FR-011**: Attachment add/remove events MUST propagate to other clients with an open view of
  the affected board through the existing realtime channel (008-realtime-sync), so the
  attachment list updates without a manual reload.
- **FR-012**: Attachments MUST remain associated with a card through archive and restore,
  consistent with the existing 30-day archive restorability invariant.
- **FR-013**: The attachment section of the card detail modal MUST visually follow the existing
  card detail modal's established sections (labels, members, checklist) rather than introducing
  a new visual pattern, since no prototype screenshot exists for this feature.

### Key Entities

- **Attachment**: A file associated with one card. Attributes: identifier, owning card,
  original filename, size in bytes, content type, a reference to the stored file in object
  storage (not the file itself), the uploading user, and creation timestamp. Related to `Card`
  (many attachments per card) and `User` (one uploader per attachment).
- **ActivityEvent (extended)**: Two new event types — attachment added and attachment removed —
  added to the existing card activity event vocabulary (§5.2), carrying enough payload (at
  least the attachment's filename and uploader) to render a human-readable activity line.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can attach a file to a card and see it listed in under 10 seconds for files
  up to the maximum allowed size on a standard broadband connection.
- **SC-002**: 100% of attachments removed from a card are no longer visible or downloadable to
  any user within 2 seconds of the removal action completing.
- **SC-003**: Every attachment addition and removal is reflected in the card's activity feed
  with no missing or duplicate entries, verified across 100 consecutive attach/remove actions.
- **SC-004**: A second board viewer sees an attachment added or removed by another user reflect
  in their own open card view within the same latency bound already established for other card
  changes (< 500 ms p95, per §8).
- **SC-005**: Users attempting to upload an oversized or disallowed file receive a clear
  rejection message and are not left with a stuck or broken attachment entry, verified across
  all rejection paths.

## Assumptions

- Maximum attachment size is capped at 25 MB per file, matching common practice for
  document/design-asset attachments at this scale; this is a product default, not user input,
  and can be revisited in `plan.md` if infrastructure constraints require a different number.
- Disallowed file types are limited to directly executable formats (e.g., `.exe`, `.bat`, `.sh`,
  `.cmd`, `.msi`) to reduce malware-distribution risk; all other common document, image,
  archive, and media types are allowed. Files are not scanned for malware content in this slice
  (object storage's own virus-scanning integration, if any, is a `plan.md`/infrastructure
  concern, not a product-scope one).
- There is no hard limit on the number of attachments per card in this slice; the attachment
  list scrolls within the card detail modal rather than the modal growing unbounded.
- Attachments do not get inline image previews/thumbnails in this slice — every attachment is
  shown as a generic file row (filename, size, uploader) with an open/download action,
  consistent with "follow the established visual language... rather than inventing a new
  layout." Thumbnail previews are a reasonable v1.2+ candidate, not required here.
- Removal permission follows a moderation pattern not previously needed for comments (which are
  append-only in v1.0): the uploader can always remove their own attachment, and board/workspace
  admins can remove any attachment; ordinary board members cannot remove attachments they did
  not upload.
- Attachment storage location and lifecycle (e.g., deletion of the underlying object on
  removal vs. soft-delete/retention) is an infrastructure decision deferred to `plan.md`; this
  spec only requires that a removed attachment is no longer accessible to users.
