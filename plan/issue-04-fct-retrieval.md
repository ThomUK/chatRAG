# Issue #4: Slice 3 — fct_retrieval (TDD)

**GitHub:** ThomUK/chatRAG#4
**Type:** AFK
**Blocked by:** #3 (fct_embeddings)

## Parent PRD

#1

## What to build

Implement the retrieval layer in `R/fct_retrieval.R`. Given a natural language query, this module embeds it, searches the knowledge base by cosine similarity, and returns the top N most relevant chunks with their full source metadata. Build using red-green-refactor TDD throughout.

## Acceptance criteria

- [ ] `cosine_similarity(vec_a, vec_b)` returns a numeric scalar; identical vectors return 1, orthogonal vectors return 0
- [ ] `embed_query(query_text)` calls Ollama `nomic-embed-text` and returns a numeric vector
- [ ] `retrieve_chunks(query_embedding, knowledge_base, top_n = 5)` returns a tibble of the top N chunks ranked by cosine similarity, preserving all metadata columns (chunk_text, doc_title, doc_org, doc_date, doc_url, similarity_score)
- [ ] `retrieve_chunks` returns fewer than top_n rows gracefully if the knowledge base has fewer chunks than requested
- [ ] `cosine_similarity` and `retrieve_chunks` are tested with synthetic embedding matrices (no Ollama required for these tests)
- [ ] `embed_query` is tested with a mocked HTTP boundary

## Blocked by

- Blocked by #3 (fct_embeddings — defines the knowledge base tibble structure this module consumes)

## User stories addressed

This slice has no direct user stories — it powers the retrieval step behind user stories 22–27.
