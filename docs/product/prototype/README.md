# FlowBoard — Prototype & Documentation Package

A Trello-style Kanban board: a working clickable prototype plus the functional and business
documentation behind it.

**Prepared for:** Anas Matar, DPOInternational · 27 August 2026

---

## What's in this folder

| File | What it is |
|---|---|
| **`flowboard-prototype.html`** | The clickable prototype. Single file, no dependencies — double-click to open in any browser. |
| **`FUNCTIONAL_SPEC.md`** | Full functional specification: personas, user stories with acceptance criteria, screen behaviour, data model, permissions, API surface, non-functional requirements, release plan. |
| **`BUSINESS_MODEL.md`** | Business model: value proposition, market, competitive position, pricing tiers, cost structure, unit economics, three-year projection, go-to-market, metrics, risks. |
| `smoke.py` | Automated Playwright smoke test used to verify the prototype (optional — see below). |
| `preview-board.png` / `preview-card.png` | Screenshots of the board view and the card detail modal. |

---

## Running the prototype

Open `flowboard-prototype.html` in Chrome, Edge, Firefox or Safari. That's it — no server,
no install, no build step.

### Things to try

| Action | How |
|---|---|
| Move work between stages | Drag any card onto another list |
| Reorder stages | Drag a list by its header |
| Open a card | Click it — description, labels, members, due date, checklist, comments |
| Add a card fast | Click **＋ Add a card**, type, press **Enter** (composer stays open) |
| Rename anything | Click a board or list title and type |
| Set a WIP limit | List **⋯** menu → *Set WIP limit* — the counter turns red when exceeded |
| Filter | **Filter** button, or type in search; active filters appear as removable chips |
| Switch boards | Sidebar — three seeded boards with different shapes of work |
| Dark mode | **◐** in the top-right |
| Keyboard | `/` focuses search · `Esc` closes modals and popovers |

### Known limits (deliberate)

The prototype holds its state **in memory only** — refreshing the page resets everything to the
seeded data. There is no login, no server, and no multi-user sync. This is intentional: the
prototype demonstrates interaction design, while §7 of the functional spec defines the API and
realtime layer that a production build would sit on.

---

## Verifying the prototype (optional)

`smoke.py` drives the prototype in headless Chromium and asserts that board rendering, card
creation, the detail modal, checklists, comments, labels, search, filtering, board switching,
drag & drop and the theme toggle all work with a clean browser console.

```bash
pip install playwright && playwright install chromium
python smoke.py          # edit the path at the top if you move the file
```

---

## Suggested reading order

1. **Open the prototype** — five minutes of clicking explains more than either document.
2. **`FUNCTIONAL_SPEC.md` §1–§4** — what the product does and why each screen behaves as it does.
3. **`BUSINESS_MODEL.md` §2, §4, §6** — the promise, the pricing, and the economics that follow.
4. **`FUNCTIONAL_SPEC.md` §5–§8** — the engineering detail, when you're ready to scope a build.

Both documents end with open questions and next steps rather than pretending the decisions are
settled — those are the right places to start a review conversation.

> **On the numbers:** every figure in the business model is an illustrative planning assumption
> chosen to show the shape of the model, not researched market data. The document says so at the
> top and again in §13. Replace them with validated inputs before using this for funding or budgets.
