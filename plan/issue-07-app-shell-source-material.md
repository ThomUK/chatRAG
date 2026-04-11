# Issue #7: Slice 6 — App Shell + Source Material Tab

**GitHub:** ThomUK/chatRAG#7
**Type:** AFK
**Blocked by:** #2 (Project Foundation)

## Parent PRD

#1

## What to build

Implement the main application shell — the three-tab layout, global CSS, and the Source Material tab. This slice establishes the visual container that all other tabs live inside, and delivers the first fully demoable screen: a clean, hyperlinked table of source documents.

The upload modal button appears on this tab but the modal itself is implemented in the next slice.

## Acceptance criteria

- [ ] App shell renders a three-tab layout with tabs labelled: "Source Material", "Chat", "Connect Your Own"
- [ ] Inter font loaded and applied globally
- [ ] Base CSS establishes the light, minimal, Stripe-dashboard aesthetic: lots of whitespace, clean typography, muted accent colour, subtle depth
- [ ] A polite "best viewed on a larger screen" message is displayed on viewports below 1024px wide
- [ ] Source Material tab shows the narrative introductory paragraph: "Every answer this assistant gives is grounded in real documents — the board papers and reports listed below. Nothing is invented or assumed. You can read the original source behind any answer by clicking the document link directly."
- [ ] Source Material tab shows a DT table with columns: Title, Organisation, Date, Source (hyperlinked to public URL)
- [ ] Table is sortable
- [ ] Table data is loaded from `inst/app/data/documents.csv`
- [ ] An "Add to Knowledge Base" button is present in the top-right of the Source Material tab (clicking it does nothing yet — modal wired in next slice)
- [ ] Layout is optimised for 1440px widescreen

## Blocked by

- Blocked by #2 (Project Foundation)

## User stories addressed

- User story 10
- User story 11
- User story 12
- User story 43
- User story 44
- User story 45
- User story 46
