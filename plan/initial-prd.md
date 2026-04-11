# PRD: chatRAG — Internal LLM + RAG Demo Application

## Problem Statement

NHS organisations generate large volumes of governance documents — board papers, meeting minutes, strategy documents, annual reports — that are theoretically accessible but practically unsearchable. Staff and leadership spend significant time manually searching through PDFs for specific decisions, figures, or positions. Institutional knowledge is locked in documents that people know exist but cannot efficiently query.

There is no easy way to demonstrate to non-technical NHS leadership that AI-powered document search is achievable *now*, at low cost, using existing confidentiality agreements with LLM providers. The gap between awareness of AI tools and belief in their practical deployability is the key blocker for investment decisions.

## Solution

chatRAG is a working prototype of an internal LLM + Retrieval-Augmented Generation (RAG) system, built as an R Shiny application using the golem framework. It is designed to be run as a boardroom demonstration to NHS leadership, showing in concrete, interactive terms that:

1. An AI assistant can answer natural language questions grounded in real organisational documents
2. Every answer is traceable to its source — nothing is invented
3. The same system could run on an organisation's own API agreement within days
4. The technology is not experimental — it works, today, with off-the-shelf tools

The demo uses ~20 publicly available NHS board papers (10 from the user's own trust, 10 from NHSE) as its knowledge base. The application has three tabs: **Source Material** (what documents the system knows about), **Chat** (the actual RAG interface), and **Connect Your Own** (a live demonstration that the system can be switched to any authorised API key).

## User Stories

### Setup & Onboarding

1. As a developer, I want a welcome screen that appears when no knowledge base exists, so that I know what steps to take before the app is usable.
2. As a developer, I want the welcome screen to check whether Ollama is running and show a plain-English status indicator, so that I can diagnose the most common setup failure immediately.
3. As a developer, I want the welcome screen to check whether the PDFs folder is populated and show a status indicator, so that I know whether source documents are present.
4. As a developer, I want the welcome screen to check whether documents.csv is present and valid, so that I know whether document metadata is ready.
5. As a developer, I want a single "Build Knowledge Base" button that activates only when all prerequisites are met, so that I cannot accidentally trigger a build that will fail.
6. As a developer, I want a progress bar and status labels during the knowledge base build ("Parsing PDF...", "Creating embeddings...", "Updating knowledge base..."), so that I can see that work is happening and roughly where in the process it is.
7. As a developer, I want the app to transition automatically into the main tabbed interface once the knowledge base build completes, without requiring a page refresh, so that the onboarding flow feels seamless.
8. As a developer, I want API keys stored in .Renviron and referenced via golem-config.yml using environment variables, so that secrets are never committed to version control.
9. As a developer, I want a .Renviron.example file committed to the repo with placeholder values and explanatory comments, so that future developers know exactly what environment variables are required.

### Source Material Tab

10. As a demo presenter, I want a narrative introductory paragraph above the document table explaining that every answer is grounded in real documents and traceable to source, so that non-technical stakeholders understand the system's transparency before they ask a question.
11. As a demo presenter, I want a clean, sortable table showing each document's title, organisation, date, and a hyperlink to its public URL, so that stakeholders can see exactly what the system knows about and verify it is real.
12. As a demo presenter, I want an "Add to Knowledge Base" button in the top-right of the Source Material tab, so that I can demonstrate live document ingestion during the presentation.
13. As a demo presenter, I want the document table to update reactively when a new document is successfully added, so that the change is immediately visible without a page reload.
14. As a demo presenter, I want a subtle visual pulse on the Source Material tab indicator when the knowledge base is updated, so that the audience sees the system respond to the change.

### Upload Modal

15. As a demo presenter, I want clicking "Add to Knowledge Base" to open a modal dialog, so that the upload flow feels focused without navigating away from the main interface.
16. As a demo presenter, I want the modal to include a file upload field accepting PDF files, so that I can select a new document from my machine.
17. As a demo presenter, I want the modal to include form fields for document title, organisation, date, and public URL, so that the knowledge base maintains accurate, citable metadata.
18. As a demo presenter, I want a progress bar and status labels within the modal during document processing, so that the audience can follow along as the document is parsed, chunked, and embedded.
19. As a demo presenter, I want a success confirmation showing the number of chunks added (e.g. "Knowledge base updated — 47 chunks added") when processing completes, so that I can describe what just happened to the audience.
20. As a demo presenter, I want the modal to close automatically on success and the main document table to update, so that the flow feels polished and complete.
21. As a demo presenter, I want the chat interface to have immediate access to the newly added document after upload, so that I can ask a question about it straight away without restarting the app.

### Chat Tab

22. As a demo presenter, I want a clean chat interface where I can type a question and receive an answer, so that stakeholders can see a familiar, intuitive interaction model.
23. As a demo presenter, I want a "Thinking..." placeholder with a loading spinner to appear while Claude is generating a response, so that the interface feels responsive rather than frozen.
24. As a demo presenter, I want Claude's responses to cite the source document(s) inline in its prose (e.g. "According to the NHSE Board paper, February 2025..."), so that stakeholders see grounded, traceable answers.
25. As a demo presenter, I want a "Sources" block displayed below each assistant response listing the retrieved document names, so that traceability is explicit and scannable even if stakeholders miss the inline citation.
26. As a demo presenter, I want Claude to explicitly disclose when it draws on general knowledge rather than the loaded documents (e.g. "I don't have this in the loaded documents, but from general knowledge..."), so that the boundary between RAG and general knowledge is always transparent.
27. As a demo presenter, I want the conversation to be stateful across up to 6 turns (3 user, 3 assistant), so that follow-up questions like "tell me more about that" work naturally.
28. As a demo presenter, I want a context window visualiser panel on the right side of the Chat tab, so that I can show the audience exactly what the model can currently "see" in its conversation history.
29. As a demo presenter, I want active context messages displayed as coloured pills (user vs. assistant distinguished by colour) showing the first 4–5 words followed by "...", so that the visualiser is readable at a glance.
30. As a demo presenter, I want dropped messages (outside the 6-turn rolling window) to remain visible as greyed-out pills rather than disappearing, so that the audience can see the full conversation history while understanding what is and isn't in active context.
31. As a demo presenter, I want the most recent 3 dropped messages shown greyed out, fading to white below that, so that the visualiser conveys "history continues" without becoming cluttered.
32. As a demo presenter, I want old context pills to slide upwards with a smooth CSS transition when they drop out of the active window, so that the motion mirrors the direction of the chat interface and feels intentional.
33. As a demo presenter, I want the context window visualiser labelled "Active context window", so that its purpose is self-explanatory.

### Connect Your Own Tab

34. As a demo presenter, I want a provider dropdown on the Connect Your Own tab with options for Claude (Anthropic), OpenAI, and Azure OpenAI, so that I can show the system is not locked to a single vendor.
35. As a demo presenter, I want a text field to paste an API key, so that I or a stakeholder can activate the system with their own credentials.
36. As a demo presenter, I want additional fields for Azure endpoint URL and deployment name to appear conditionally when Azure OpenAI is selected, so that the interface is clean for non-Azure providers while fully supporting Azure's requirements.
37. As a demo presenter, I want a "Test Connection" button that makes a real minimal API call (e.g. "Reply with the word OK") to verify the key works, so that I can confirm live connectivity in front of the audience.
38. As a demo presenter, I want a green "Connected — [Provider] API responding" confirmation when the test succeeds, so that the audience sees a clear, positive signal.
39. As a demo presenter, I want a red error message showing the API error text when the test fails, so that failures are diagnosable rather than opaque.
40. As a demo presenter, I want the chat history and context window visualiser to clear when a new key is activated, so that the new session feels like a clean start under the new credentials.
41. As a demo presenter, I want a confirmation banner ("Now using your API key — conversation reset") when a key switch occurs, so that the change is explicitly acknowledged.
42. As a demo presenter, I want a plain-English paragraph below the key management form explaining what data is sent to the API (the question + retrieved document chunks) and what stays local (the PDFs, embeddings, and chat UI), so that security-conscious stakeholders are reassured.

### Design & UX

43. As a demo presenter, I want the application to use a light, minimal design with lots of whitespace and Inter font, so that it feels like a modern, professional product rather than a government tool.
44. As a demo presenter, I want the visual design to evoke a Stripe-style dashboard aesthetic — clean typography, subtle depth, muted accent colour — so that it reads as credible and contemporary in a boardroom.
45. As a demo presenter, I want the layout optimised for 1440px widescreen, so that it looks its best on the laptop I will present from.
46. As a demo presenter, I want a polite "best viewed on a larger screen" message to appear on viewports below 1024px wide, so that accidental mobile viewing does not show a broken layout.

## Implementation Decisions

### Architecture

- Built as a golem R package following golem conventions throughout
- Three Shiny modules for the three tabs: `mod_source_material`, `mod_chat`, `mod_connect`
- Upload logic encapsulated in `mod_upload`, launched as a modal from `mod_source_material`
- Business logic entirely in `fct_` files: `fct_embeddings`, `fct_retrieval`, `fct_llm`
- Custom CSS in `inst/app/www/styles.css`; no inline styles
- `app_ui.R` and `app_server.R` are thin wrappers — all logic delegated to modules and `fct_` files

### Dependency list (DESCRIPTION Imports)

golem, shiny, bslib, pdftools, ollamar, httr2, DT, dplyr, readr, stringr, config

### Data & File Layout

- Source PDFs: `inst/app/data/pdfs/` (gitignored)
- Document metadata: `inst/app/data/documents.csv` — columns: title, organisation, date, url, filename
- Vector store: `inst/app/data/embeddings.rds` (gitignored)
- All three are gitignored; `.Renviron.example` documents required environment variables

### fct_embeddings — Embedding Pipeline

- Fixed-size chunking: 500 tokens, 50-token overlap
- Embeddings via Ollama `nomic-embed-text` model running locally on `localhost:11434`
- Each chunk stored with its source document metadata (title, org, date, url) so retrieval always returns citable provenance
- Knowledge base persisted as `.rds` containing a tibble of chunks + embedding vectors
- Same pipeline used for initial build (via welcome screen) and incremental addition (via upload modal)
- On incremental add: new chunks appended to existing `.rds`, Shiny reactive value updated in memory — no app restart

### fct_retrieval — Retrieval

- Query text embedded via Ollama before search
- Cosine similarity computed between query embedding and all chunk embeddings
- Top 5 chunks returned with full metadata
- Returned as a tibble: chunk_text, doc_title, doc_org, doc_date, doc_url, similarity_score

### fct_llm — LLM Integration

- Supports three providers: Claude (Anthropic), OpenAI (direct), Azure OpenAI
- Provider abstracted behind a single `call_llm()` function that dispatches on provider argument
- Azure requires endpoint URL and deployment name in addition to API key
- System prompt instructs Claude to: use retrieved documents as primary source; cite by document name inline; explicitly disclose when falling back to general knowledge; maintain professional boardroom tone
- Chat history: stateful, rolling window of last 6 turns (3 user + 3 assistant messages)
- Retrieved chunks injected into each API call as part of the user message context
- Code structured with a clearly marked streaming insertion point — streaming not implemented in v1 but architecturally straightforward to add
- `test_connection()` sends a minimal prompt ("Reply with the word OK") and returns success/failure with error message

### Secrets Management

- API key stored in `.Renviron` as `ANTHROPIC_API_KEY` (and equivalent for other providers)
- `inst/golem-config.yml` references environment variables via `!expr Sys.getenv(...)`
- `get_golem_config()` used throughout — no hardcoded keys anywhere in source
- `.Renviron.example` committed with placeholder values and comments explaining each variable

### Welcome / Setup Screen

- Shown when `inst/app/data/embeddings.rds` does not exist at app startup
- Three prerequisite checks with plain-English status indicators: Ollama running (HTTP ping to localhost:11434), PDFs folder populated, documents.csv present and parseable
- "Build Knowledge Base" button disabled until all checks pass
- Progress bar with status labels during build
- Automatic transition to main tabbed UI on completion — no refresh

### Context Window Visualiser

- Fixed right-column panel within the Chat tab
- Pills show: role label ("You" / "Claude"), first 4–5 words of message, "..."
- User and assistant pills distinguished by left border colour
- Active context (last 6 turns): full colour
- Dropped turns (up to 3 most recent): greyed out, remain visible
- Beyond 3 dropped: fades to white
- New messages push oldest upward with CSS transition
- Panel labelled "Active context window"

### Responsive Design

- Optimised for 1440px widescreen
- Minimum supported width: 1024px
- Below 1024px: a polite "best viewed on a larger screen" overlay — no attempt at responsive layout

## Testing Decisions

**What makes a good test here:** Test the external behaviour of pure functions — given this input, produce this output. Do not test Shiny internals or golem scaffolding. Do not test that Ollama or the Claude API return specific values — mock at the boundary.

### Modules to test

**fct_embeddings**
- `chunk_text(text, chunk_size, overlap)` — pure function. Test: correct number of chunks produced, overlap preserved, edge cases (text shorter than chunk size, empty input)
- `build_knowledge_base()` — integration test using a small test PDF. Verify output tibble has expected columns and non-zero rows.

**fct_retrieval**
- `cosine_similarity(vec_a, vec_b)` — pure math. Test: known vectors with known similarity values, identical vectors return 1, orthogonal vectors return 0
- `retrieve_chunks(query_embedding, knowledge_base, top_n)` — test with synthetic embedding matrix. Verify top N returned, correctly ranked by similarity, metadata columns preserved

**fct_llm**
- `build_system_prompt()` — test that output is a non-empty character string containing expected phrases (source citation instruction, general knowledge fallback disclosure)
- `build_messages(chat_history, context_chunks, user_query)` — pure function. Test: correct message structure, rolling window applied correctly (6 turns max), context chunks injected in expected position
- `test_connection()` — test with a mock httr2 response. Verify success returns `list(success=TRUE)`, failure returns `list(success=FALSE, message=...)`

**Prior art:** No existing tests in the repo. Use `testthat` following golem's `use_recommended_tests()` scaffold already initialised.

## Out of Scope

- Production deployment or hosting — this is a local demo app only
- Authentication or user management
- Audit trails or access controls for document ingestion
- Multi-user concurrent sessions
- Persistent chat history across sessions
- Document deletion or knowledge base management beyond addition
- Support for non-PDF document formats
- Microsoft Copilot / Microsoft 365 Copilot integration (requires OAuth, not key-based)
- Streaming API responses (architecturally prepared for, not implemented in v1)
- Responsive / mobile layout
- Automated PDF discovery or ingestion from URLs — PDFs are manually placed in the data folder
- Any data governance, information security review, or clinical safety assessment required for production NHS use

## Further Notes

- **Demo context:** This app will be presented live in a boardroom. Stability and visual polish matter more than feature completeness. The context window visualiser is a deliberate pedagogical feature — it makes an abstract concept (LLM context limits) immediately tangible for a non-technical audience.
- **Ollama dependency:** Ollama must be running locally for embeddings to work. This includes both the initial build and the live document upload demo on Tab 1. The presenter should confirm Ollama is running before the demo.
- **Documents.csv is the source of truth for metadata:** All citations in chat responses are derived from document metadata attached at embedding time. If documents.csv is inaccurate, citations will be inaccurate. Curate it carefully before the demo.
- **NHS board papers:** All source documents are publicly available. No patient data, no confidential information. This is important for the demo narrative — the point is that a production system would use the same architecture but over governed internal documents.
- **Future production path:** A production deployment would require: a governed document ingestion process with access controls; a confidential LLM API agreement; information governance sign-off; and a persistent vector store (e.g. pgvector or a managed vector DB) rather than an in-memory .rds file. None of this is in scope here, but the architecture of chatRAG is designed to make these steps plausible and explainable.
