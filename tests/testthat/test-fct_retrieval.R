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
  result <- retrieve_chunks(query, kb, top_n = 5)
  expect_equal(nrow(result), 5)
})

test_that("retrieve_chunks returns fewer rows than top_n when kb is smaller", {
  kb    <- make_fake_kb(3)
  query <- c(1, 0, 0, 0)
  result <- retrieve_chunks(query, kb, top_n = 10)
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
  result <- retrieve_chunks(query, kb)
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
