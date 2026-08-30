# Research — 007 Search & Filter

## R-1: Where does live filtering run — client or a new API call per keystroke?

**Decision**: Entirely client-side, over the board content already fetched by
`trpc.boards.getContent` (003/004's existing query, already the single source of truth
`BoardCanvas` renders from). No new tRPC procedure, no new endpoint.

**Rationale**: FR-001/FR-002 require the visible set to update after every keystroke/
selection with no perceptible delay and zero additional API calls (SC-002). A board's
full card set (title, description, labels, members, due data) is already resident in the
`getContent` query's cache the instant the board is open — every list and every card on
it is already rendered. Filtering is a pure, synchronous transform of data already in
memory; a per-keystroke network round trip would violate SC-002 for no benefit.

**Alternatives considered**: A `boards.searchCards` tRPC procedure that filters
server-side. Rejected — it would add a new procedure/endpoint the spec's own framing
("no new API writes... client-side/read-side feature") doesn't ask for, add per-keystroke
network latency, and duplicate filtering logic the client would still need for the
"combine live typing with an already-open filter" UX (the two must compose instantly
together, not resolve against two different code paths).

## R-2: Card descriptions are not currently in the board-content payload

**Decision**: Add `Description` (nullable string) to `CardSummaryDto` (backend) /
`CardSummary` (frontend) — an additive field on the existing `GET /v1/boards/{id}`
response (via `GetBoardContentAsync`), not a new endpoint, not a schema/persistence
change.

**Rationale**: F-01/FR-001 require search to match title **and** description. Today
`BoardContentService.GetBoardContentAsync` (`flowboard-api/src/Flowboard.Api/Services/
BoardContentService.cs:157`) already selects `c.Description` from the database for every
card on every board load — it's used today only to compute the boolean `HasDescription`
flag (line 209). The full text already crosses the DB→API boundary on every request; it
is simply not currently forwarded into the API→browser JSON. Adding it costs zero
additional database query cost and zero additional DB round trips — the only change is
including a field already in memory in the outbound DTO. This is the same shape of change
006-board-list-management already made (adding `RowVersion` to `BoardContentDto`/
`ListContentDto` — additive, no new endpoint, no migration) and satisfies constitution X
(Performance Responsibility): the added transfer is the minimum necessary for an approved
requirement, not "unnecessary" transfer.

**Alternatives considered**:
- *Fetch each card's description lazily via the existing single-card `cards.getById`
  query, only while searching.* Rejected — defeats "live, updates after every keystroke,
  zero additional API calls" (FR-001/SC-002): this would mean one API call per card the
  first time a search touches it, and searching-before-fetch would silently miss matches.
- *Title-only search, drop description from scope.* Rejected — contradicts
  `FUNCTIONAL_SPEC.md` F-01 ("Matches title and description") and this feature's own
  approved spec.md (FR-001, Acceptance Scenario 3); no reason to narrow an already-cheap
  requirement.

Descriptions render as plain text today (`card-description-panel.tsx`: "plain-text
description", `whitespace-pre-wrap`), not HTML — substring matching against the raw text
is safe (no markup to strip, no XSS surface from matching/highlighting it).

## R-3: The "Next 7 days" due-date bucket is not the same thing as the existing `dueStatus`

**Decision**: The due-date filter's "Overdue" and "No due date" buckets reuse the
already-server-computed `card.dueStatus`/`card.dueAt` fields directly (`dueStatus ===
"overdue"`, `dueAt === null`) with no new computation. The "Next 7 days" bucket is a new,
one-off client-side window check over the existing raw `card.dueAt`
(`-1 day ≤ (dueAt − now) ≤ +7 days`, matching the prototype's own window exactly:
`docs/product/prototype/flowboard-prototype.html` `passesFilter`'s `due === 'week'`
branch), not a re-derivation of `dueStatus`.

**Rationale**: `frontend-rules.md`'s Data Flow rule says derived values the backend owns
("due-date buckets' server side") must come from the backend, not be re-implemented by the
frontend — but the existing `dueStatus` enum (`complete | overdue | soon | future`) is a
*display-badge* bucketing (`soon` = "≤ 2 days", per `FUNCTIONAL_SPEC.md`'s card-badge
color rule), a different concept from this filter's "Next 7 days" window. There is no
existing backend-computed value this bucket could reuse — inventing one purely to satisfy
the letter of the rule would add a bespoke, single-use backend field for a value that is
naturally a view-time predicate over data already present (`dueAt`), not a value ever
persisted, sorted by, or reused elsewhere. "Overdue" and "No due date", by contrast,
already have an exact backend-computed equivalent, so those two reuse it as-is rather than
recomputing.

**Alternatives considered**: Add a fourth server-computed bucket value. Rejected as
unnecessary backend surface for a one-off, feature-local filter window with no other
consumer — the two-tier decision above (reuse where an equivalent exists, compute locally
where none does) keeps the "don't re-derive what the backend owns" rule meaningful instead
of stretched to cover something it was never protecting.

## R-4: Where does filter/search state live, given it's read by two different parts of the tree?

**Decision**: A new React Context, `BoardFilterProvider`/`useBoardFilter`
(`flowboard-web/src/components/board/board-filter-context.tsx`), holding `{ text,
labelIds, memberIds, due }` plus setters and `clearAll()`. Instantiated once per board
page (`app/(app)/boards/[boardPublicId]/page.tsx`), wrapping both `<TopBar>` (search input
+ filter popover trigger) and `<BoardCanvas>` (chip bar + actual filtering), keyed by
`boardPublicId` so switching boards remounts the provider and resets state (FR-009) rather
than requiring a manual reset effect.

**Rationale**: `TopBar` (search box, Filter popover trigger) and `BoardCanvas` (which
cards are visible, chip bar) are page-level siblings, not parent/child
(`app/(app)/boards/[boardPublicId]/page.tsx`) — exactly the same shape
`sidebar-context.tsx` already solves for sidebar-collapse state shared between `TopBar`
(the ☰ control) and `Sidebar` (layout-rendered). `frontend-rules.md`'s State rule
explicitly sanctions React Context for ephemeral, non-server UI state ("Session/theme use
React Context") and prohibits duplicating *server* state into it — this context holds only
transient view-filter selections, never card/label/member data itself (that stays in
`trpc.boards.getContent`'s React Query cache, read directly by `BoardCanvas`).

**Alternatives considered**:
- *URL search params.* Rejected — no other view-state in this product is URL-driven
  (sidebar collapse, open-card-modal, and theme are all plain client state), and a
  shareable/bookmarkable filtered-board URL isn't in spec.md's scope.
- *Lift state into `BoardCanvas` and pass it up via a callback/ref to `TopBar`.* Rejected
  — `TopBar` and `BoardCanvas` are siblings returned directly by the server-component
  page, not nested; there's no natural "up" to lift into without inventing a new
  client-component wrapper anyway, which is exactly what the Context is.

## R-5: `passesFilter` semantics — verified against the reference prototype

**Decision**: Match `docs/product/prototype/flowboard-prototype.html`'s `passesFilter`
exactly: search text matches case-insensitive substring against `title + " " + description`;
label/member filters are OR-within-category (`some`); at most one due-date bucket is active
at a time; every active category combines with AND. The search term itself renders as its
own removable chip (`Text: "…"`), same as any label/member/due chip.

**Rationale**: This is rung-2 source of truth per constitution II — verified directly by
loading the prototype and exercising it (see Visual Inventory screenshots), not inferred
from `FUNCTIONAL_SPEC.md` prose alone. No conflict found between the prototype and
`FUNCTIONAL_SPEC.md` §3.4/§4.2/§4.3 or this feature's own spec.md.
