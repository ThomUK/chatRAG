# Tests for fct_retrieval.R
# Using red-green-refactor TDD approach.
# cosine_similarity and retrieve_chunks use synthetic embedding matrices.
# embed_query is tested with a mocked HTTP boundary via .call_ollama_embed.

# ── cosine_similarity ─────────────────────────────────────────────────────────

test_that("cosine_similarity returns a numeric scalar", {
  a <- c(1, 0, 0)
  b <- c(1, 0, 0)
  result <- cosine_similarity(a, b)
  expect_type(result, "double")
  expect_length(result, 1)
})

test_that("cosine_similarity of identical vectors is 1", {
  a <- c(1, 2, 3)
  result <- cosine_similarity(a, a)
  expect_equal(result, 1, tolerance = 1e-8)
})

test_that("cosine_similarity of orthogonal vectors is 0", {
  a <- c(1, 0, 0)
  b <- c(0, 1, 0)
  result <- cosine_similarity(a, b)
  expect_equal(result, 0, tolerance = 1e-8)
})

test_that("cosine_similarity of opposite vectors is -1", {
  a <- c(1, 0, 0)
  b <- c(-1, 0, 0)
  result <- cosine_similarity(a, b)
  expect_equal(result, -1, tolerance = 1e-8)
})

test_that("cosine_similarity is symmetric", {
  a <- c(0.1, 0.5, 0.8)
  b <- c(0.9, 0.2, 0.4)
  expect_equal(cosine_similarity(a, b), cosine_similarity(b, a), tolerance = 1e-8)
})

test_that("cosine_similarity handles normalised unit vectors", {
  a <- c(1, 0) / sqrt(1)
  b <- c(0.6, 0.8)  # unit vector
  result <- cosine_similarity(a, b)
  expect_equal(result, 0.6, tolerance = 1e-8)
})

# ── embed_query ───────────────────────────────────────────────────────────────

test_that("embed_query returns a numeric vector", {
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) list(rep(0.1, 768))
  )
  result <- embed_query("What is the policy on remote work?")
  expect_type(result, "double")
})

test_that("embed_query returns a vector of the correct dimensionality", {
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) list(rep(0.42, 768))
  )
  result <- embed_query("test query")
  expect_length(result, 768)
})

test_that("embed_query passes the query text to the embed wrapper", {
  captured <- NULL
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) {
      captured <<- chunks
      list(rep(0.1, 768))
    }
  )
  embed_query("my specific query")
  expect_equal(captured, "my specific query")
})

# ── retrieve_chunks ───────────────────────────────────────────────────────────

make_fake_kb <- function(n = 10, dims = 4) {
  tibble::tibble(
    chunk_text = paste0("chunk ", seq_len(n)),
    embedding  = lapply(seq_len(n), function(i) {
      v <- rep(0, dims)
      v[((i - 1L) %% dims) + 1L] <- 1
      v
    }),
    doc_title  = paste0("doc_title_", seq_len(n)),
    doc_org    = paste0("doc_org_", seq_len(n)),
    doc_date   = "2024-01-01",
    doc_url    = paste0("http://example.com/", seq_len(n))
  )
}

test_that("retrieve_chunks returns a data frame", {
  kb    <- make_fake_kb(5)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3)
  expect_s3_class(result, "data.frame")
})

test_that("retrieve_chunks returns top_n rows", {
  kb    <- make_fake_kb(10)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 5, min_similarity = 0)
  expect_equal(nrow(result), 5)
})

test_that("retrieve_chunks returns fewer rows than top_n when kb is smaller", {
  kb    <- make_fake_kb(3)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 10, min_similarity = 0)
  expect_equal(nrow(result), 3)
})

test_that("retrieve_chunks includes required metadata columns", {
  kb    <- make_fake_kb(5)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3)
  expected_cols <- c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("retrieve_chunks does not expose the embedding column", {
  kb    <- make_fake_kb(5)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3)
  expect_false("embedding" %in% names(result))
})

test_that("retrieve_chunks returns rows ordered by descending similarity_score", {
  kb    <- make_fake_kb(4)
  # query aligns with chunk 1 (first basis vector)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 4)
  expect_equal(result$chunk_text[1], "chunk 1")
  expect_true(all(diff(result$similarity_score) <= 0))
})

test_that("retrieve_chunks similarity_score for best match is 1", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 1)
  expect_equal(result$similarity_score, 1, tolerance = 1e-8)
})

test_that("retrieve_chunks similarity_score is numeric", {
  kb    <- make_fake_kb(5)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3)
  expect_type(result$similarity_score, "double")
})

test_that("retrieve_chunks defaults top_n to 5", {
  kb    <- make_fake_kb(10)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, min_similarity = 0)
  expect_equal(nrow(result), 5)
})

test_that("retrieve_chunks works with a single-row knowledge base", {
  kb <- tibble::tibble(
    chunk_text = "only chunk",
    embedding  = list(c(1, 0, 0)),
    doc_title  = "Solo Doc",
    doc_org    = "Org",
    doc_date   = "2024-01-01",
    doc_url    = "http://example.com"
  )
  query  <- c(1, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 5)
  expect_equal(nrow(result), 1)
  expect_equal(result$similarity_score, 1, tolerance = 1e-8)
})

# ── min_similarity threshold ──────────────────────────────────────────────────

test_that("retrieve_chunks filters out chunks below min_similarity", {
  # KB: chunk 1 aligns with query (score=1), rest are orthogonal (score=0)
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 4, min_similarity = 0.5)
  expect_equal(nrow(result), 1)
  expect_equal(result$similarity_score, 1, tolerance = 1e-8)
})

test_that("retrieve_chunks returns 0-row data frame when all chunks below threshold", {
  kb    <- make_fake_kb(4)
  # query aligns with no chunk (45-degree angle to all basis vectors)
  query <- c(0.5, 0.5, 0, 0)
  # all scores = 0.5*0 + 0.5*0 ... actually this gives 0.5 for chunk 1 and 2
  # use a query orthogonal to all: won't work with basis vectors
  # instead, set threshold above 1 to guarantee zero results
  result <- retrieve_chunks(query, kb, top_n = 4, min_similarity = 1.1)
  expect_equal(nrow(result), 0)
  expect_s3_class(result, "data.frame")
})

test_that("retrieve_chunks result has correct columns even when empty", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 4, min_similarity = 1.1)
  expected_cols <- c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("retrieve_chunks min_similarity defaults to 0.5", {
  # make_fake_kb(10): chunks 1, 5, 9 have score=1 with query c(1,0,0,0)
  # chunks 2,3,4,6,7,8,10 have score=0
  # default min_similarity=0.5 should filter out score=0 chunks → 3 rows
  kb    <- make_fake_kb(10)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 10)
  expect_equal(nrow(result), 3)
})

test_that("retrieve_chunks min_similarity=0 returns all chunks (backward compat)", {
  kb    <- make_fake_kb(10)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 5, min_similarity = 0)
  expect_equal(nrow(result), 5)
})

# ── MMR (Maximal Marginal Relevance) ──────────────────────────────────────────

test_that("retrieve_chunks use_mmr=FALSE returns rows ordered by pure similarity", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 4, min_similarity = 0, use_mmr = FALSE)
  expect_true(all(diff(result$similarity_score) <= 0))
  expect_equal(result$chunk_text[1], "chunk 1")
})

test_that("retrieve_chunks MMR selects highest-similarity chunk first", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 2, min_similarity = 0, use_mmr = TRUE)
  expect_equal(result$chunk_text[1], "chunk 1")
})

test_that("retrieve_chunks MMR with lambda=1 ranks by similarity score only", {
  # All distinct scores, so lambda=1 (pure relevance) gives same order as non-MMR
  query <- c(1, 0, 0, 0)
  kb <- tibble::tibble(
    chunk_text = c("high", "mid", "low"),
    embedding  = list(
      c(1, 0, 0, 0),
      c(0.5, 0.866, 0, 0),
      c(0.1, 0.995, 0, 0)
    ),
    doc_title = c("a", "b", "c"), doc_org = c("a", "b", "c"),
    doc_date  = "2024-01-01",    doc_url  = c("a", "b", "c")
  )
  result <- retrieve_chunks(query, kb, top_n = 3, min_similarity = 0,
                            use_mmr = TRUE, lambda = 1)
  expect_equal(result$chunk_text, c("high", "mid", "low"))
})

test_that("retrieve_chunks MMR with low lambda prefers diverse chunk over near-duplicate", {
  # A and B are identical (near-duplicates); C is orthogonal.
  # lambda=0.3 (diversity-weighted): after picking A, MMR(B)=0.3-0.7=-0.4, MMR(C)=0
  # so C is selected second instead of B.
  query <- c(1, 0, 0, 0)
  kb <- tibble::tibble(
    chunk_text = c("A", "B", "C"),
    embedding  = list(c(1, 0, 0, 0), c(1, 0, 0, 0), c(0, 1, 0, 0)),
    doc_title  = c("a", "b", "c"), doc_org = c("a", "b", "c"),
    doc_date   = "2024-01-01",     doc_url  = c("a", "b", "c")
  )
  result <- retrieve_chunks(query, kb, top_n = 2, min_similarity = 0,
                            use_mmr = TRUE, lambda = 0.3)
  expect_equal(result$chunk_text[1], "A")
  expect_equal(result$chunk_text[2], "C")
})

test_that("retrieve_chunks MMR respects top_n limit", {
  kb    <- make_fake_kb(10)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3, min_similarity = 0, use_mmr = TRUE)
  expect_equal(nrow(result), 3)
})

test_that("retrieve_chunks MMR returns correct columns", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 2, min_similarity = 0, use_mmr = TRUE)
  expected_cols <- c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")
  expect_true(all(expected_cols %in% names(result)))
  expect_false("embedding" %in% names(result))
})

test_that("retrieve_chunks MMR with empty candidates returns empty data frame", {
  kb    <- make_fake_kb(4)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 4, min_similarity = 2, use_mmr = TRUE)
  expect_equal(nrow(result), 0)
  expected_cols <- c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")
  expect_true(all(expected_cols %in% names(result)))
})

# ── bm25_score ────────────────────────────────────────────────────────────────

test_that("bm25_score returns a numeric vector with one score per chunk", {
  chunks <- c("the cat sat on the mat", "the dog ran in the park", "birds fly south")
  result <- bm25_score("cat", chunks)
  expect_type(result, "double")
  expect_length(result, 3)
})

test_that("bm25_score gives higher score to chunk containing the query term", {
  chunks <- c("the cat sat on the mat", "the dog ran in the park")
  result <- bm25_score("cat", chunks)
  expect_gt(result[1], result[2])
})

test_that("bm25_score is case-insensitive", {
  chunks <- c("The Cat Sat", "the dog ran")
  result_lower <- bm25_score("cat", chunks)
  result_upper <- bm25_score("CAT", chunks)
  expect_equal(result_lower, result_upper, tolerance = 1e-8)
})

test_that("bm25_score returns all-zero vector for empty query", {
  chunks <- c("some text", "other text")
  result <- bm25_score("", chunks)
  expect_true(all(result == 0))
})

test_that("bm25_score returns all-zero vector for query term absent from all chunks", {
  chunks <- c("apples and oranges", "bananas and grapes")
  result <- bm25_score("zebra", chunks)
  expect_equal(result, c(0, 0))
})

test_that("bm25_score returns zero vector when chunk_texts is empty character vector", {
  result <- bm25_score("query", character(0))
  expect_type(result, "double")
  expect_length(result, 0)
})

# ── rrf_fuse ──────────────────────────────────────────────────────────────────

test_that("rrf_fuse returns a numeric vector of same length as input scores", {
  scores_a <- c(0.9, 0.5, 0.1)
  scores_b <- c(0.8, 0.6, 0.2)
  result <- rrf_fuse(list(scores_a, scores_b))
  expect_type(result, "double")
  expect_length(result, 3)
})

test_that("rrf_fuse gives highest score to item ranked first in both lists", {
  # item 1 top in cosine, item 1 top in BM25 → should have highest fused score
  cosine <- c(0.9, 0.5, 0.1)
  bm25   <- c(10,  5,   1  )
  result <- rrf_fuse(list(cosine, bm25))
  expect_equal(which.max(result), 1L)
})

test_that("rrf_fuse with k=60 uses standard RRF formula", {
  # Single list: top item gets 1/(60+1), second gets 1/(60+2)
  scores <- c(0.9, 0.5, 0.1)
  result <- rrf_fuse(list(scores), k = 60)
  expect_equal(result[1], 1 / (60 + 1), tolerance = 1e-8)
  expect_equal(result[2], 1 / (60 + 2), tolerance = 1e-8)
  expect_equal(result[3], 1 / (60 + 3), tolerance = 1e-8)
})

test_that("rrf_fuse combines multiple score lists correctly", {
  # Two identical orderings: item 1 is top in both → fused score = 2 * 1/(60+1)
  scores <- c(0.9, 0.5, 0.1)
  result <- rrf_fuse(list(scores, scores), k = 60)
  expect_equal(result[1], 2 / 61, tolerance = 1e-8)
})

# ── Hybrid retrieval (query_text parameter) ───────────────────────────────────

make_hybrid_kb <- function() {
  tibble::tibble(
    chunk_text = c(
      "The Q3-2024-FIN report shows record profits for the finance division.",
      "Employees should submit timesheets by Friday each week.",
      "The Q3-2024-FIN audit was completed successfully with no issues."
    ),
    embedding = list(
      c(1, 0, 0, 0),
      c(1, 0, 0, 0),
      c(1, 0, 0, 0)
    ),
    doc_title = c("Finance Report", "HR Policy", "Audit Summary"),
    doc_org   = "Acme",
    doc_date  = "2024-01-01",
    doc_url   = c("http://a.com", "http://b.com", "http://c.com")
  )
}

test_that("retrieve_chunks with query_text returns correct columns", {
  kb    <- make_hybrid_kb()
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3, min_similarity = 0,
                            use_mmr = FALSE, query_text = "Q3-2024-FIN")
  expected_cols <- c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")
  expect_true(all(expected_cols %in% names(result)))
  expect_false("embedding" %in% names(result))
})

test_that("retrieve_chunks hybrid ranks exact-match chunks above non-matching when cosine scores are equal", {
  # All embeddings identical → cosine scores all equal → BM25 breaks the tie
  kb    <- make_hybrid_kb()
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3, min_similarity = 0,
                            use_mmr = FALSE, query_text = "Q3-2024-FIN")
  # Chunks 1 and 3 mention "Q3-2024-FIN"; chunk 2 (HR Policy) does not
  expect_false(result$doc_title[1] == "HR Policy")
})

test_that("retrieve_chunks with query_text=NULL uses pure cosine (backward compat)", {
  kb    <- make_hybrid_kb()
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 3, min_similarity = 0,
                            use_mmr = FALSE, query_text = NULL)
  expect_equal(nrow(result), 3)
  # similarity_score should be raw cosine (all equal = 1 for identical embeddings)
  expect_true(all(result$similarity_score == 1))
})

test_that("retrieve_chunks hybrid respects top_n limit", {
  kb    <- make_hybrid_kb()
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 2, min_similarity = 0,
                            use_mmr = FALSE, query_text = "report")
  expect_equal(nrow(result), 2)
})
