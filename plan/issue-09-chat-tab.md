# Issue #9: Slice 8 — Chat Tab + Context Window Visualiser

**GitHub:** ThomUK/chatRAG#9
**Type:** AFK
**Blocked by:** #4 (fct_retrieval), #5 (fct_llm), #7 (App Shell)

## Parent PRD

#1

## What to build

Implement the Chat tab — the centrepiece of the demo. This includes the full RAG-powered chat interface and the context window visualiser panel that makes the rolling conversation window tangible and visible to a non-technical audience.

## Acceptance criteria

- [ ] Chat tab renders a clean chat interface with a text input and submit button
- [ ] Submitting a question shows a "Thinking..." placeholder with a loading spinner while the API call is in progress
- [ ] On response, the assistant message is displayed with inline source citations in the prose
- [ ] A "Sources" block is displayed below each assistant message listing the retrieved document names
- [ ] When Claude draws on general knowledge rather than loaded documents, the response explicitly discloses this ("I don't have this in the loaded documents, but from general knowledge...")
- [ ] Conversation is stateful: the last 6 turns (3 user + 3 assistant) are included in each API call
- [ ] A fixed right-column panel labelled "Active context window" is present alongside the chat
- [ ] Active context messages are shown as coloured pills (distinct colours for user vs. assistant) displaying the role label and first 4–5 words followed by "..."
- [ ] When a turn drops out of the active 6-turn window, its pill becomes greyed out and remains visible
- [ ] The 3 most recently dropped turns are shown greyed out; beyond that the panel fades to white
- [ ] When a new turn is added, the oldest pill slides upward with a smooth CSS transition
- [ ] The active API provider and key are sourced reactively from mod_connect (Tab 3) — the chat uses whatever credentials are currently configured

## Blocked by

- Blocked by #4 (fct_retrieval)
- Blocked by #5 (fct_llm)
- Blocked by #7 (App Shell)

## User stories addressed

- User story 22
- User story 23
- User story 24
- User story 25
- User story 26
- User story 27
- User story 28
- User story 29
- User story 30
- User story 31
- User story 32
- User story 33
