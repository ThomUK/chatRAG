# Issue #10: Slice 9 — Connect Your Own Tab

**GitHub:** ThomUK/chatRAG#10
**Type:** AFK
**Blocked by:** #5 (fct_llm), #7 (App Shell)

## Parent PRD

#1

## What to build

Implement the Connect Your Own tab — the tab that lets a stakeholder paste in their own API key and see the system switch to their credentials live. This is the business case closer: it demonstrates that the demo is not magic, and that any organisation with an existing LLM agreement can be running this within days.

## Acceptance criteria

- [ ] Tab renders a provider dropdown with options: Claude (Anthropic), OpenAI, Azure OpenAI
- [ ] An API key text input field is present
- [ ] When Azure OpenAI is selected, additional fields appear for endpoint URL and deployment name; these fields are hidden for other providers
- [ ] A "Test Connection" button sends a real minimal API call ("Reply with the word OK") using the entered credentials
- [ ] On success, a green confirmation is shown: "Connected — [Provider] API responding"
- [ ] On failure, a red error message is shown containing the API error text
- [ ] When a new key is confirmed, the chat history and context window visualiser clear
- [ ] A confirmation banner is shown: "Now using your API key — conversation reset"
- [ ] The active provider and key are exposed as a reactive value consumed by the Chat tab
- [ ] A plain-English paragraph is displayed below the key management form explaining: what is sent to the API (the question + retrieved document chunks), and what stays local (PDFs, embeddings, the chat UI)

## Blocked by

- Blocked by #5 (fct_llm — test_connection and call_llm are used here)
- Blocked by #7 (App Shell — this is one of the three tabs)

## User stories addressed

- User story 34
- User story 35
- User story 36
- User story 37
- User story 38
- User story 39
- User story 40
- User story 41
- User story 42
