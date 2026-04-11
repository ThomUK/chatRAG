# Ubiquitous Language

## Documents

| Term | Definition | Aliases to avoid |
|------|-----------|-----------------|
| **Board Paper** | A PDF governance document (board meeting paper, annual report, strategy document) that forms part of the knowledge base | Source document, PDF, file |
| **Source Material** | The full collection of board papers currently loaded into the knowledge base | Documents, corpus, dataset |
| **Document Metadata** | The structured record for a board paper: title, organisation, date, and public URL | Document info, document details |

## Knowledge Base

| Term | Definition | Aliases to avoid |
|------|-----------|-----------------|
| **Knowledge Base** | The complete set of embedded chunks, persisted as an `.rds` file, that the app searches at query time | Vector store, embeddings file, index |
| **Chunk** | A fixed-size fragment of text extracted from a board paper, with overlap to preserve sentence boundaries | Passage, segment, piece |
| **Embedding** | A numeric vector representation of a chunk produced by the Ollama model, used for similarity search | Vector, encoding |
| **Chunking** | The process of splitting a board paper's text into overlapping chunks | Splitting, segmentation |
| **Ingestion** | The end-to-end process of parsing a board paper, chunking it, embedding the chunks, and adding them to the knowledge base | Indexing, processing, uploading |
| **Retrieval** | The process of embedding a query and returning the top-N most similar chunks from the knowledge base | Search, lookup |

## Conversation

| Term | Definition | Aliases to avoid |
|------|-----------|-----------------|
| **Turn** | A single exchange consisting of one user message and one assistant response | Message pair, round |
| **Chat History** | The full ordered list of turns in the current session | Conversation history, messages |
| **Active Context** | The subset of the most recent turns (up to 6) that are included in each API call | Context window (as a noun for the active set), live context |
| **Dropped Turn** | A turn that has scrolled out of the active context window and is no longer sent to the API | Expired turn, lost context |
| **Rolling Window** | The mechanism that keeps the last 6 turns in active context and drops older ones | Sliding window, context limit |
| **Context Window Visualiser** | The right-column UI panel in the Chat tab that shows which turns are in active context and which are dropped | Context panel, history panel |

## LLM Integration

| Term | Definition | Aliases to avoid |
|------|-----------|-----------------|
| **Provider** | An LLM API vendor: Claude (Anthropic), OpenAI, or Azure OpenAI | LLM provider, API provider, model |
| **API Key** | The authentication credential used to call a Provider's API | Token, secret, credential |
| **Citation** | A reference to a specific board paper embedded in an assistant response, either inline in prose or in the Sources block | Source reference, attribution |
| **Sources Block** | The structured list of board papers displayed below each assistant response from which chunks were retrieved | Sources list, references |
| **General Knowledge Fallback** | An assistant response that draws on the model's training data because the answer was not found in the loaded source material | Out-of-context answer, hallucination (not the same thing — avoid this term) |
| **Test Connection** | A minimal API call used to verify that a given API key and provider are reachable | Ping, health check, key validation |

## App Structure

| Term | Definition | Aliases to avoid |
|------|-----------|-----------------|
| **Welcome Screen** | The setup screen displayed when no knowledge base exists, guiding the user through prerequisites and the initial knowledge base build | Onboarding screen, setup wizard |
| **Knowledge Base Build** | The initial bulk ingestion of all board papers in the PDFs folder, triggered from the welcome screen | Index build, initial ingestion |
| **Upload Modal** | The dialog opened from the Source Material tab that allows a single new board paper to be ingested into a live knowledge base | Upload tab, upload screen, document uploader |
| **Presenter** | The person running the app during the boardroom demo | User, demo-er |
| **Stakeholder** | A member of NHS leadership attending the boardroom demo as an audience member | Leader, executive, audience |

## Relationships

- A **Knowledge Base** is composed of many **Chunks**, each belonging to exactly one **Board Paper**
- Each **Chunk** carries its **Board Paper**'s **Document Metadata**, so every retrieval result is citable
- **Retrieval** produces a ranked list of **Chunks** that are injected into the API call alongside the **Active Context**
- A **Turn** enters the **Active Context** when created; it becomes a **Dropped Turn** when a new turn pushes it beyond the 6-turn **Rolling Window**
- **Ingestion** is the same process whether triggered from the **Welcome Screen** (bulk) or the **Upload Modal** (single document)
- A **Provider** requires an **API Key**; Azure OpenAI additionally requires an endpoint URL and deployment name

## Example dialogue

> **Dev:** "When the **Presenter** adds a new document during the demo, does it go through **Ingestion**?"
> **Domain expert:** "Yes — the **Upload Modal** runs the full **Ingestion** pipeline: parse, **Chunk**, embed, and append to the **Knowledge Base**."
> **Dev:** "And the **Chat** tab can use it straight away?"
> **Domain expert:** "Immediately. The in-memory **Knowledge Base** is hot-reloaded — no restart. The audience can ask a question about the new **Board Paper** within seconds of it being added."
> **Dev:** "If the question isn't covered by any of the **Source Material**, what happens?"
> **Domain expert:** "The assistant uses the **General Knowledge Fallback** and says so explicitly — it never silently invents an answer and presents it as a **Citation**."
> **Dev:** "And after six **Turns**, the earliest ones stop going to the API?"
> **Domain expert:** "Right — they become **Dropped Turns**. The **Context Window Visualiser** shows them greyed out so the audience understands the **Rolling Window** without needing an explanation."

## Flagged ambiguities

- **"Context window"** was used in two senses: (1) the LLM concept of how much text the model can see at once, and (2) the UI panel that visualises it. The canonical terms are **Active Context** (the LLM concept) and **Context Window Visualiser** (the UI element). Do not use "context window" without qualification.
- **"Vector store"** and **"knowledge base"** were used interchangeably. Prefer **Knowledge Base** as the domain term. "Vector store" is an implementation detail.
- **"Board paper"** and **"source document"** were used interchangeably. Prefer **Board Paper** — it is specific to the NHS domain and will resonate with the boardroom audience.
- **"Chunk"** is used as both a noun (a fragment of text) and a verb (to split text). This is acceptable — "chunking" as the gerund is unambiguous in context.
- **"Hallucination"** was mentioned in passing. Avoid this term entirely in the app and in conversations with stakeholders — it triggers anxiety. Use **General Knowledge Fallback** when the model draws on training data, and reserve factual error language for actual errors.
