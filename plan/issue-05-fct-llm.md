# Issue #5: Slice 4 — fct_llm (TDD)

**GitHub:** ThomUK/chatRAG#5
**Type:** AFK
**Blocked by:** #2 (Project Foundation)

## Parent PRD

#1

## What to build

Implement the LLM integration layer in `R/fct_llm.R`. This module handles all communication with external LLM APIs (Claude, OpenAI, Azure OpenAI), constructs prompts with retrieved context, manages the 6-turn rolling conversation window, and tests API connectivity. Build using red-green-refactor TDD throughout.

This slice is independent of the embedding/retrieval pipeline and can be built in parallel with slices 3 and 5.

## Acceptance criteria

- [ ] `build_system_prompt()` returns a character string instructing the model to: cite sources inline by document name; disclose explicitly when falling back to general knowledge; maintain professional boardroom tone
- [ ] `build_messages(chat_history, context_chunks, user_query)` returns an API-ready messages list with: system prompt, rolling window of last 6 turns (3 user + 3 assistant), context chunks injected, and the current user query
- [ ] `build_messages` correctly trims chat history to the 6-turn window when history exceeds it
- [ ] `call_llm(messages, provider, api_key, ...)` dispatches correctly to Claude, OpenAI, and Azure OpenAI endpoints; Azure additionally requires endpoint URL and deployment name
- [ ] `test_connection(provider, api_key, ...)` sends a minimal prompt and returns `list(success = TRUE)` on success or `list(success = FALSE, message = <error text>)` on failure
- [ ] Code contains a clearly marked comment block indicating the streaming insertion point in `call_llm`
- [ ] All pure functions (`build_system_prompt`, `build_messages`) have full testthat coverage
- [ ] `test_connection` and `call_llm` are tested with mocked httr2 responses for all three providers

## Blocked by

- Blocked by #2 (Project Foundation)

## User stories addressed

This slice has no direct user stories — it powers user stories 22–27 and 34–42.
