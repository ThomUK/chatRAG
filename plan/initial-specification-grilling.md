# Initial Specification Grilling — chatRAG

## Background

Prior conversation established the following before this grilling session:

**Stack:** R Shiny, bslib, pdftools, ollamar (Ollama + nomic-embed-text for local embeddings), httr2, Claude API. In-memory cosine similarity vector store saved to .rds.

**3 tabs (+ stretch 4th):**
1. Source Material — table of docs (title, org, date, hyperlink to public URL), brief intro sentence
2. Chat — chat interface, responses cite source document by name
3. Connect Your Own — API key paste field + test/confirm button + plain-English paragraph about data flow
4. (Stretch) Upload new documents

**Design:** Light theme, lots of whitespace, Inter font, Stripe-dashboard aesthetic.

**Data:** ~20 NHS board papers (10 own trust, 10 NHSE), stored in data/pdfs/. Public documents.

**Build approach:** Ingestion + embeddings as a preparatory offline script, app loads .rds at startup.

**Timeline:** 2 full days to build.

**Purpose:** Boardroom demo for leadership to build business case for an internal LLM/RAG system. Real production use would use confidential LLM API with data governance.

---

## Q1: Chunking strategy

**Question:** When splitting the PDFs into chunks for embedding, you have two main choices:
- Fixed-size chunks — e.g. 500 tokens with 50-token overlap. Simple, predictable, fast to implement.
- Semantic/paragraph chunks — split on natural paragraph or section boundaries from the PDF. More meaningful chunks but NHS PDFs are often poorly structured and pdftools doesn't reliably detect structure.

For board papers specifically, fixed-size with overlap is the pragmatic choice — they're dense prose, not clean hierarchical docs, and overlap ensures you don't cut a sentence mid-thought.

**Recommendation:** 500 tokens, 50-token overlap, fixed-size.

**Answer:** Agree - it's a demo app after all.

**Locked:** 500 tokens, 50-token overlap.

---

## Q2: How many chunks to retrieve per query?

**Question:** When a user asks a question, the retrieval step pulls the top-N most similar chunks and injects them into Claude's prompt as context. Your options:
- Top 3 — tight, focused context. Less noise, lower token cost, faster. Risk: might miss something relevant across a large set of 20 docs.
- Top 5 — the standard sweet spot for demos. Enough coverage to impress, still coherent context for Claude to reason over.
- Top 10 — more complete but the prompt gets long, Claude has more to synthesise, and you'll hit token limits faster.

For 20 board papers in a boardroom demo, you want answers that feel comprehensive without being slow or hallucination-prone. Top 5 gives Claude enough to cite 2-3 sources per answer, which looks impressive.

**Recommendation:** Top 5 chunks.

**Answer:** Agree.

**Locked:** Top 5 chunks.

---

## Q3: Does chat history feed into Claude's context window?

**Question:** Two options for how the conversation works:
- Stateless — each question is answered using only the retrieved chunks + that single question. No memory of prior turns. Simpler, cheaper, no risk of context overflow.
- Stateful — prior chat turns are included in the Claude API call. Feels more natural (you can say "tell me more about that"), but context window fills up fast with 5 chunks already going in each time, and for a boardroom demo someone won't be having a 10-turn conversation.

For a demo, stateless is actually fine — the demo will show single focused questions landing well. Stateful adds complexity and failure modes with minimal upside in a 10-minute presentation.

**Recommendation:** Stateless — no chat history in the API call.

**Answer:** Hmm, I think probably stateful. Although it's a demo people have got used to stateful conversations and I don't want the difference to create an obvious rough edge. We need to sell this convincingly.

**Locked:** Stateful, with a rolling window capped at the last 6 turns (3 user + 3 assistant) to prevent context overflow.

---

## Q4: How should citations appear in the UI?

**Question:** When Claude cites its sources, there are a few ways to surface that in the chat interface:
- Inline in the response text — Claude writes "According to the NHSE Board paper (Feb 2025)..." as part of its answer. Simple, no extra UI work, looks natural.
- Below the response as a "Sources" block — a small greyed-out section under each assistant message listing the retrieved documents. Looks polished, separates citation from prose, easy to scan.
- Both — Claude cites inline and you also render a sources block from the retrieved chunk metadata.

The sources block is only a small amount of extra UI work (you already have the metadata from retrieval) and it looks noticeably more product-like in a demo — it signals "this isn't just ChatGPT, it knows exactly where it got this from."

**Recommendation:** Both — inline citation in Claude's prose + a small "Sources" block below each response.

**Answer:** Yes, we should be transparent about the conversation history cap, perhaps even with a little UI element that scrolls and shows messages dropping out of old context. On Q4 I agree, both.

**Locked:** Stateful, 6-turn rolling window, with a live context window UI element. Citations: inline + sources block.

---

## Q5: What does the "Test Connection" button on Tab 3 actually do?

**Question:** When someone pastes their API key and hits the button, it needs to do something verifiable. Options:
- Send a minimal test prompt — e.g. "Reply with the word OK." to the Claude API with their key. Confirms the key is valid and the model is reachable. Costs fractions of a penny.
- Just validate the key format — check it starts with sk-ant- etc. No API call, instant, but doesn't actually prove connectivity.
- Run a full RAG query — overkill and slow for a test.

A real API call is the right choice — format validation is hollow and a savvy CTO in the room will ask "did it actually connect?" You want to be able to say yes.

**Recommendation:** Send a minimal test prompt, show a green "Connected — Claude API responding" confirmation on success, red error message with the API error text on failure.

**Answer:** Agree. But why is this even a question. I will be demo-ing the app with Claude API key and want to be able to paste in a Claude or Azure key. Is that too complicated?

**Follow-up clarification:** Not too complicated. The API call structure for Claude (Anthropic SDK via httr2) and Azure OpenAI are different enough that you need a provider selector to know which endpoint and auth format to use. So the tab becomes a provider dropdown, key paste field, and for Azure a second field for the endpoint URL.

**Answer on providers:** Back to Q5, does Microsoft Copilot have an API endpoint? We should probably also include OpenAI too.

**Clarification on Copilot:** Microsoft Copilot has no simple API key. Microsoft 365 Copilot is embedded in M365 and accessed via Graph API with OAuth — not paste-a-key accessible. What NHS orgs actually get API access to from Microsoft is Azure OpenAI. OpenAI direct: yes, simple API key, very similar call structure to Anthropic. Worth including.

Provider list:
| Provider | Key needed | Extra field? |
|---|---|---|
| Claude (Anthropic) | API key | No |
| OpenAI (direct) | API key | No |
| Azure OpenAI | API key | Yes — endpoint URL + deployment name |

**Answer:** Yes all 3, and drop Copilot.

**Locked:** Claude, OpenAI, Azure OpenAI. Copilot dropped. Tab 3 has provider dropdown, key field, Azure endpoint + deployment fields (shown conditionally), test button with real API call, green/red confirmation state.

---

## Q6: Loading and error states in the Chat tab

**Question:** While Claude is generating a response, what does the user see?
- Spinner only — simple, clean
- "Thinking..." placeholder message in the chat stream — more conversational, feels like the product is alive
- Streaming responses — tokens appear word by word as Claude generates them. Genuinely impressive in a demo but adds meaningful implementation complexity with httr2

Streaming is doable but risks eating into your 2-day timeline. A "Thinking..." placeholder with a spinner is honest and still feels modern.

**Recommendation:** "Thinking..." placeholder with a spinner. No streaming for now — ship it, don't over-engineer.

**Answer:** OK, thinking placeholder, but I want to code so that streaming is possible to implement if we have time. Is that worth doing?

**Follow-up:** Yes, absolutely worth doing — low-cost insurance policy. Build the Claude API call as a clean function with a clear interface, add a comment block at the streaming insertion point marking exactly where streaming would be wired in.

**Locked:** "Thinking..." placeholder for now, code structured so streaming can be dropped in without refactoring.

---

## Q7: The `.rds` file — where does it live and how is it created?

**Question:** The embeddings get computed once offline and saved so the app loads instantly. If the `.rds` file is missing when the app starts, should it crash with a clear error message, or offer to build it on the fly?

**Recommendation:** Crash with a clear, helpful error message — "Run scripts/build_embeddings.R first." Building on-the-fly adds complexity and Ollama must be running, which you can't guarantee at demo time.

**Answer:** Well, I can make sure Ollama is running at demo time. We'll need that to be able to demo adding a new document too. Is that too complex?

**Follow-up:** Good point — if Ollama is running for the demo anyway, building on-the-fly is viable. But separate two scenarios:
- App startup with missing .rds: Still recommend the clear error message rather than auto-building. The startup embedding of 20 docs takes a few minutes — you don't want that happening silently when you open the app in front of an audience.
- Tab 4 (Upload new document): Real-time embedding of a new PDF during the demo is a compelling live moment. With Ollama running it's technically straightforward. Risk: PDF parsing can be slow, embedding 100+ chunks takes 30-60 seconds, failure live is awkward.

**Answer:** Yes, core feature please. If the app starts without an rds it should show a welcome message detailing the next steps.

**Follow-up on welcome screen:** Suggested welcome screen flow:
1. Check Ollama is running (ping it)
2. Check data/pdfs/ exists and has PDFs
3. Show a "Getting Started" card with status indicators for each prerequisite
4. A single "Build Knowledge Base" button that runs the embedding pipeline in-app with a progress bar

This replaces the separate build_embeddings.R script entirely — the welcome screen IS the setup step. Cleaner for a demo, and Tab 4 and the initial setup use the same embedding pipeline code.

**Answer:** Agree on both counts.

**Locked:** Tab 4 is core. In-app welcome/setup screen replaces standalone script. One code path for all embedding. `data/documents.csv` as the metadata source.

---

## Q8: The Source Material table metadata

**Question:** The metadata (title, organisation, date, URL) needs to live somewhere — the PDF filename alone won't have it. Options:
- A manually maintained data/documents.csv — you fill in title, org, date, URL for each PDF before the demo.
- Extract metadata from the PDF itself — pdftools can read PDF metadata but NHS board papers are notoriously inconsistent.
- Infer from filename — fragile, not reliable.

**Recommendation:** data/documents.csv — you curate it once, it feeds the Source Material table directly, and it also attaches to each chunk at embedding time so citations are accurate.

**Answer:** Agree.

**Locked:** data/documents.csv as the metadata source.

---

## Q9: Prompt engineering for Claude

**Question:** The system prompt needs to tell Claude to:
1. Answer only from the retrieved chunks, not general knowledge
2. Cite sources by document name
3. Admit when it doesn't know rather than hallucinate
4. Stay professional and concise — boardroom tone

Key tension: groundedness vs. helpfulness. Strict "documents only" can feel brittle. Too permissive and the RAG story breaks down.

**Recommendation:** "Answer using the provided documents as your primary source. If the answer is not in the documents, say so clearly but offer what general context you can. Always cite the document name when drawing from a source."

**Answer:** No, falling back to general knowledge is fine but it should say it has done so clearly.

**Locked:** Claude uses documents as primary source, falls back to general knowledge with an explicit "I don't have this in the loaded documents, but from general knowledge..." disclosure.

---

## Q10: The context window visualiser

**Question:** The rolling window holds the last 6 turns. Options for placement:
- A collapsible sidebar panel within the Chat tab
- A small expandable panel below the chat
- A fixed narrow column to the right of the chat — always visible, strongest demo impact

**Recommendation:** Fixed right column. Messages in active window shown clearly, oldest message at top fades/greys as it's about to drop, disappears when a new turn pushes it out.

**Answer:** Agree on the right is fine, with old messages disappearing upwards to mirror the actual chat interface. It doesn't need to display actual text, maybe first few words then ...? Or what are your thoughts?

**Follow-up recommendation:** Each message shown as a compact pill/chip: role label (You or Claude), first 4-5 words then `...`, subtle left border colour distinguishing user vs assistant, oldest pill at top newest at bottom, smooth CSS transition as pills slide up and out, panel labelled "Active context window."

**Answer on Q10 revision:** Rather than out of context messages disappearing completely we should strongly grey them out. Coloured messages = active context, grey = lost context. OK?

**Further refinement:** On Q10 again, we don't need to keep all grey messages visible, perhaps the most recent 3 and then fade out to white to show it's gone.

**Locked:** Active context pills coloured, most recent 3 dropped messages shown greyed out, then fade to white — suggesting history extending beyond view. Full conversation visible but context state clear at a glance.

---

## Q11: Tab 4 — Upload interface

**Question:** When someone uploads a new document, do they fill in metadata manually via form fields, or just upload the PDF?

**Recommendation:** Simple form — file upload + 4 fields (title, organisation, date, URL) + "Add to Knowledge Base" button.

**Answer:** Agree we need to capture the metadata at upload time.

**Locked:** Upload form with file + 4 metadata fields + "Add to Knowledge Base" button. On success: appends to .rds and documents.csv, confirms success.

---

## Q12: App state when a new document is added

**Question:** When embedding completes and the knowledge base is updated, should the app hot reload the vector store reactively, or require app restart?

**Recommendation:** Hot reload — vector store updates reactively on successful embedding, no restart needed.

**Answer:** Yes hot reload, but do it with some UI engagement to make the workings transparent.

**Locked:** Hot reload with visible UI engagement:
1. Progress bar during chunking/embedding with status labels ("Parsing PDF...", "Creating embeddings...", "Updating knowledge base...")
2. On completion: brief success state ("Knowledge base updated — 47 chunks added")
3. Subtle pulse or flash on the Source Material tab indicator
4. Vector store silently updates — Tab 2 immediately has the new document

---

## Q13: Connect Your Own tab — what happens to chat when a new key is activated?

**Question:** When someone pastes their own key and hits confirm, should it clear chat history or keep it?

**Recommendation:** Clear chat history on key switch, show a brief confirmation banner "Now using your API key — conversation reset." The context window visualiser also clears.

**Answer:** Agree.

**Locked:** Key switch clears chat history and context window visualiser, shows confirmation banner.

---

## Q14: Source Material tab intro copy

**Question:** The introductory copy above the table. Functional vs narrative tone.

**Recommendation:** Narrative tone, 2-3 sentences max. Emphasise grounding, transparency, and the link back to original sources.

**Answer:** Agree, you write it I may adjust later.

**Locked copy:**
> "Every answer this assistant gives is grounded in real documents — the board papers and reports listed below. Nothing is invented or assumed. You can read the original source behind any answer by clicking the document link directly."

---

## Q15: Mobile / screen size assumptions

**Question:** Optimise for what screen size? This is a boardroom demo — fixed-width is fine.

**Recommendation:** Optimise for 1440px widescreen, set a minimum width of 1024px below which a "best viewed on a larger screen" message appears. Don't spend time on responsive design — it's a demo, not a product.

**Answer:** Agree.

**Locked:** Optimised for 1440px, minimum 1024px with a polite message below that threshold.

---

## Q16: File and folder structure

**Question:** Golem conventions needed — user confirmed they want a golem app (dev/01_start.R already open, golem already initialised).

**Locked structure:**
```
chatRAG/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── app_ui.R              # Main UI
│   ├── app_server.R          # Main server
│   ├── run_app.R             # Launch function
│   ├── app_config.R          # Golem config helpers
│   ├── mod_source_material.R # Tab 1 module
│   ├── mod_chat.R            # Tab 2 module
│   ├── mod_connect.R         # Tab 3 module
│   ├── mod_upload.R          # Tab 4 module (modal, launched from Tab 1)
│   ├── fct_embeddings.R      # Embedding logic
│   ├── fct_retrieval.R       # Cosine similarity search
│   └── fct_llm.R             # API calls
├── inst/app/www/
│   └── styles.css
├── inst/app/data/
│   ├── pdfs/
│   ├── documents.csv
│   └── embeddings.rds
└── dev/
    ├── 01_start.R
    ├── 02_dev.R
    └── 03_deploy.R
```

---

## Q17: Dependencies and DESCRIPTION file

**Full package dependency list:**

| Package | Purpose |
|---|---|
| shiny | Core framework |
| golem | App framework |
| bslib | UI theming |
| pdftools | PDF parsing |
| ollamar | Ollama embeddings |
| httr2 | API calls |
| dplyr | Data wrangling |
| readr | CSV read/write |
| stringr | Text chunking |
| DT | Interactive table on Tab 1 |
| config | Golem config management |

**Secrets management:**

- `.Renviron` (never committed, in .gitignore): `ANTHROPIC_API_KEY=sk-ant-...`
- `inst/golem-config.yml`: `anthropic_api_key: !expr Sys.getenv("ANTHROPIC_API_KEY")`
- `R/app_config.R` exposes a `get_api_key()` helper
- `.gitignore` includes: `.Renviron`, `inst/app/data/pdfs/`, `inst/app/data/embeddings.rds`
- `.Renviron.example` committed with placeholder values and explanatory comments

**Answer:** The package list looks good. Yes read the key in via golem-config, but I will store it in .Renviron. Just point golem-config there so that it's transparent for future devs. I'm not putting my API in version control.

**Locked:** .Renviron for secrets, golem-config.yml points to env vars, .Renviron.example as documentation, PDFs and .rds gitignored.

---

## Q18: The welcome/setup screen

**Question:** When the app starts without an embeddings.rds, the welcome screen needs to handle a prerequisite sequence:
1. Is Ollama running? (ping localhost:11434)
2. Is inst/app/data/pdfs/ populated?
3. Is inst/app/data/documents.csv present and valid?

Only when all three are green should the "Build Knowledge Base" button activate.

- If Ollama isn't running: plain-English instructions or just a red indicator?
- Should the welcome screen disappear automatically once .rds is built, or require a page refresh?

**Recommendation:** Plain-English instructions for each failed prerequisite. Welcome screen disappears automatically and transitions smoothly into the main tabbed UI once the build completes. No refresh needed.

**Answer:** Agree.

**Locked:** Plain-English prerequisite instructions, automatic transition to main UI on build completion, no refresh needed.

---

## Final structural change: Tab 4 → Modal

**Discussion:** Tab 4 should not be a tab. Make it a modal that opens from an "Add to Knowledge Base" button in Tab 1. 3 tabs is clean.

**Locked:** Tab 4 dropped. Upload functionality lives in a modal triggered from Tab 1. 3 tabs only.

Revised Tab 1 structure:
- Narrative intro copy
- "Add to Knowledge Base" button — top right of the tab
- DT table below
- Clicking the button opens a modal with the upload form (file + 4 metadata fields + "Add to Knowledge Base" button)
- Progress indicators appear within the modal
- On success: modal closes, success notification appears, table updates reactively, subtle pulse on the tab

---

## Complete Locked Specification

**Stack:** golem, shiny, bslib, pdftools, ollamar, httr2, DT, dplyr, readr, stringr, config

**Structure:** Golem package conventions. 3 tab modules + upload modal logic (`mod_`), business logic in `fct_` files, assets in `inst/app/www/`

**Data:** ~20 NHS PDFs in `inst/app/data/pdfs/`, metadata in `inst/app/data/documents.csv`, vector store in `inst/app/data/embeddings.rds`. All three gitignored.

**Secrets:** `.Renviron` → `golem-config.yml` → `get_api_key()` helper. `.Renviron.example` committed as documentation.

**Chunking:** Fixed-size, 500 tokens, 50-token overlap

**Embeddings:** Ollama + `nomic-embed-text`, local

**Retrieval:** Top 5 chunks, cosine similarity

**LLM:** Claude primary. Falls back to general knowledge with explicit disclosure. Stateful, 6-turn rolling window.

**Providers:** Claude, OpenAI, Azure OpenAI (conditional endpoint + deployment fields)

**Welcome screen:** Prerequisite checklist (Ollama, PDFs, CSV), plain-English instructions, "Build Knowledge Base" button, progress indicators, auto-transitions to main UI on completion

**Tab 1 — Source Material:**
- Narrative intro copy (pre-written, adjustable)
- "Add to Knowledge Base" button (top right) — opens upload modal
- DT table: title, organisation, date, hyperlinked URL
- Upload modal: file + 4 metadata fields, progress indicators, hot reload on success, chunk count confirmation, subtle tab pulse

**Tab 2 — Chat:**
- "Thinking..." placeholder with spinner, streaming-ready code structure
- Inline citations + sources block below each response
- Right column context window visualiser: coloured pills (active), greyed pills (last 3 dropped), fades to white beyond that. Pills show role + first 4-5 words. Oldest slides upward as context drops.

**Tab 3 — Connect Your Own:**
- Provider dropdown (Claude / OpenAI / Azure OpenAI)
- API key field, conditional Azure endpoint + deployment fields
- Test button — real API call, green/red confirmation
- Key switch clears chat history + visualiser, shows confirmation banner
- Plain-English data flow paragraph below the form

**Design:** Light theme, Inter font, lots of whitespace, Stripe-dashboard aesthetic. Optimised for 1440px, minimum 1024px with polite message below threshold.
