# Issue #3: Slice 2 — fct_embeddings (TDD)

**GitHub:** ThomUK/chatRAG#3
**Type:** AFK
**Blocked by:** #2 (Project Foundation)

## Parent PRD

#1

## What to build

Implement the complete embedding pipeline as a set of pure, testable R functions in `R/fct_embeddings.R`. This is the foundation of the knowledge base — it takes PDFs and a metadata CSV, produces a vector store, and saves/loads it as an `.rds` file. Build using red-green-refactor TDD throughout.

The pipeline must handle both the initial full build (all PDFs at once) and incremental addition (one new PDF appended to an existing knowledge base), since both the welcome screen and the upload modal use the same code path.

## Acceptance criteria

- [ ] `chunk_text(text, chunk_size = 500, overlap = 50)` returns a character vector of correctly sized, overlapping chunks
- [ ] `chunk_text` handles edge cases: text shorter than chunk size, empty input, exact multiple of chunk size
- [ ] `embed_chunks(chunks, doc_metadata)` calls Ollama `nomic-embed-text` and returns a tibble with columns: chunk_text, embedding, doc_title, doc_org, doc_date, doc_url
- [ ] `parse_pdf(pdf_path)` extracts plain text from a PDF using pdftools
- [ ] `build_knowledge_base(pdf_paths, documents_csv_path)` orchestrates parse → chunk → embed and returns a complete knowledge base tibble
- [ ] `append_to_knowledge_base(existing_kb, pdf_path, doc_metadata)` adds a single document's chunks to an existing knowledge base
- [ ] `save_knowledge_base(kb, path)` writes the knowledge base to an `.rds` file
- [ ] `load_knowledge_base(path)` reads and returns the knowledge base from an `.rds` file
- [ ] `check_ollama_running()` pings `localhost:11434` and returns TRUE/FALSE
- [ ] All pure functions (`chunk_text` at minimum) have full testthat coverage built during red-green-refactor
- [ ] Ollama-dependent functions have tests that mock the HTTP boundary

## Blocked by

- Blocked by #2 (Project Foundation)

## User stories addressed

This slice has no direct user stories — it is the engine that powers user stories 1–7, 13–21, and 22–27.
