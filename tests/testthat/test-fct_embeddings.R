# Tests for fct_embeddings.R
# Using red-green-refactor TDD approach.
# External package calls (pdftools, ollamar) are isolated behind internal
# wrappers so tests run without those packages being installed.
# `local_mocked_bindings()` sets bindings for the current test scope.

# ── chunk_text ────────────────────────────────────────────────────────────────

test_that("chunk_text returns a character vector", {
  result <- chunk_text("Hello world this is a test", chunk_size = 10, overlap = 2)
  expect_type(result, "character")
})

test_that("chunk_text returns single chunk when text is shorter than chunk_size", {
  text <- "Short text"
  result <- chunk_text(text, chunk_size = 500, overlap = 50)
  expect_equal(result, text)
  expect_length(result, 1)
})

test_that("chunk_text returns empty character vector for empty input", {
  expect_equal(chunk_text("", chunk_size = 500, overlap = 50), character(0))
})

test_that("chunk_text handles NULL input", {
  expect_equal(chunk_text(NULL, chunk_size = 500, overlap = 50), character(0))
})

test_that("chunk_text splits text into overlapping chunks", {
  # step = chunk_size - overlap = 10 - 2 = 8
  # text = 20 chars: chunk1 chars 1-10, chunk2 starts at char 9
  text <- "abcdefghijklmnopqrst"  # 20 chars
  result <- chunk_text(text, chunk_size = 10, overlap = 2)
  expect_gte(length(result), 2)
  expect_equal(substr(result[1], 1, 10), substr(text, 1, 10))
  expect_equal(substr(result[2], 1, 2), substr(text, 9, 10))
})

test_that("chunk_text produces chunks of at most chunk_size characters", {
  text <- paste(rep("a", 1000), collapse = "")
  result <- chunk_text(text, chunk_size = 100, overlap = 10)
  expect_true(all(nchar(result) <= 100))
})

test_that("chunk_text handles text that is an exact multiple of chunk_size with zero overlap", {
  text <- "1234567890"  # 10 chars
  result <- chunk_text(text, chunk_size = 5, overlap = 0)
  expect_length(result, 2)
  expect_equal(result[1], "12345")
  expect_equal(result[2], "67890")
})

# ── parse_pdf ─────────────────────────────────────────────────────────────────

test_that("parse_pdf returns a single character string", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("Page one text", "Page two text")
  )
  result <- parse_pdf("dummy.pdf")
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("parse_pdf concatenates pages into one string", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("Page one.", "Page two.")
  )
  result <- parse_pdf("dummy.pdf")
  expect_match(result, "Page one")
  expect_match(result, "Page two")
})

test_that("parse_pdf separates pages with PAGE BREAK sentinel", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("Page one.", "Page two.")
  )
  result <- parse_pdf("dummy.pdf")
  expect_match(result, "--- PAGE BREAK ---", fixed = TRUE)
})

test_that("parse_pdf does not smash pages together without separator", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("Page one.", "Page two.")
  )
  result <- parse_pdf("dummy.pdf")
  expect_false(grepl("Page one\\.Page two", result))
  expect_false(grepl("Page one\\. Page two", result))
})

test_that("parse_pdf uses double-newline boundaries around PAGE BREAK", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("First page.", "Second page.")
  )
  result <- parse_pdf("dummy.pdf")
  expect_match(result, "First page\\.\n\n--- PAGE BREAK ---\n\nSecond page\\.")
})

test_that("parse_pdf single-page PDF returns text without PAGE BREAK", {
  local_mocked_bindings(
    .call_pdf_text = function(pdf_path) c("Only page text.")
  )
  result <- parse_pdf("dummy.pdf")
  expect_false(grepl("PAGE BREAK", result))
  expect_equal(result, "Only page text.")
})

# ── embed_chunks ──────────────────────────────────────────────────────────────

test_that("embed_chunks returns a tibble with required columns", {
  chunks <- c("chunk one", "chunk two")
  doc_metadata <- list(
    doc_title = "Test Doc",
    doc_org   = "Test Org",
    doc_date  = "2024-01-01",
    doc_url   = "http://example.com"
  )
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) list(rep(0.1, 768), rep(0.2, 768))
  )
  result <- embed_chunks(chunks, doc_metadata)
  expect_s3_class(result, "data.frame")
  expect_true(all(
    c("chunk_text", "embedding", "doc_title", "doc_org", "doc_date", "doc_url") %in% names(result)
  ))
})

test_that("embed_chunks has one row per chunk", {
  chunks <- c("chunk one", "chunk two", "chunk three")
  doc_metadata <- list(
    doc_title = "Test Doc",
    doc_org   = "Test Org",
    doc_date  = "2024-01-01",
    doc_url   = "http://example.com"
  )
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) list(rep(0.1, 768), rep(0.2, 768), rep(0.3, 768))
  )
  result <- embed_chunks(chunks, doc_metadata)
  expect_equal(nrow(result), 3)
})

test_that("embed_chunks propagates doc_metadata to all rows", {
  chunks <- c("chunk one", "chunk two")
  doc_metadata <- list(
    doc_title = "My Title",
    doc_org   = "My Org",
    doc_date  = "2024-06-01",
    doc_url   = "http://mysite.com"
  )
  local_mocked_bindings(
    .call_ollama_embed = function(chunks) list(rep(0.1, 768), rep(0.2, 768))
  )
  result <- embed_chunks(chunks, doc_metadata)
  expect_true(all(result$doc_title == "My Title"))
  expect_true(all(result$doc_org == "My Org"))
  expect_true(all(result$doc_url == "http://mysite.com"))
})

# ── check_ollama_running ──────────────────────────────────────────────────────

test_that("check_ollama_running returns TRUE when Ollama responds with 200", {
  local_mocked_bindings(.call_ollama_ping = function() 200L)
  result <- check_ollama_running()
  expect_true(result)
})

test_that("check_ollama_running returns FALSE when Ollama is not reachable", {
  local_mocked_bindings(.call_ollama_ping = function() stop("Connection refused"))
  result <- check_ollama_running()
  expect_false(result)
})

# ── save_knowledge_base / load_knowledge_base ─────────────────────────────────

test_that("save_knowledge_base writes an rds file", {
  kb <- tibble::tibble(
    chunk_text = "hello",
    embedding  = list(c(0.1, 0.2)),
    doc_title  = "test",
    doc_org    = "org",
    doc_date   = "2024-01-01",
    doc_url    = "http://example.com"
  )
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  save_knowledge_base(kb, tmp)
  expect_true(file.exists(tmp))
})

test_that("load_knowledge_base returns the saved knowledge base", {
  kb <- tibble::tibble(
    chunk_text = c("hello", "world"),
    embedding  = list(c(0.1, 0.2), c(0.3, 0.4)),
    doc_title  = c("doc1", "doc1"),
    doc_org    = c("org", "org"),
    doc_date   = c("2024-01-01", "2024-01-01"),
    doc_url    = c("http://example.com", "http://example.com")
  )
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  save_knowledge_base(kb, tmp)
  result <- load_knowledge_base(tmp)

  expect_equal(result$chunk_text, kb$chunk_text)
  expect_equal(nrow(result), 2)
})

# ── append_to_knowledge_base ──────────────────────────────────────────────────

test_that("append_to_knowledge_base increases row count", {
  existing_kb <- tibble::tibble(
    chunk_text = "existing chunk",
    embedding  = list(rep(0.1, 768)),
    doc_title  = "Old Doc",
    doc_org    = "Old Org",
    doc_date   = "2023-01-01",
    doc_url    = "http://old.com"
  )
  doc_metadata <- list(
    doc_title = "New Doc",
    doc_org   = "New Org",
    doc_date  = "2024-01-01",
    doc_url   = "http://new.com"
  )
  local_mocked_bindings(
    .call_pdf_text     = function(pdf_path) "New document content here.",
    .call_ollama_embed = function(chunks) lapply(seq_along(chunks), function(i) rep(0.2, 768))
  )
  result <- append_to_knowledge_base(
    existing_kb, "new.pdf", doc_metadata,
    chunk_size = 500, overlap = 50
  )
  expect_gt(nrow(result), nrow(existing_kb))
})

# ── interim embedding cache ───────────────────────────────────────────────────

test_that("interim_cache_path returns an rds path inside cache_dir", {
  path <- interim_cache_path("/some/cache", "report.pdf")
  expect_equal(path, "/some/cache/report.rds")
})

test_that("interim_cache_path strips subdirectory from pdf_filename", {
  path <- interim_cache_path("/cache", "subdir/report.pdf")
  expect_equal(path, "/cache/report.rds")
})

test_that("save_interim_embedding writes a file", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))

  result <- tibble::tibble(
    chunk_text = "hello",
    embedding  = list(c(0.1, 0.2)),
    doc_title  = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(result, cache_dir, "doc.pdf")
  expect_true(file.exists(file.path(cache_dir, "doc.rds")))
})

test_that("save_interim_embedding creates cache_dir if it does not exist", {
  cache_dir <- file.path(tempdir(), paste0("newcache_", Sys.getpid()))
  on.exit(unlink(cache_dir, recursive = TRUE))

  result <- tibble::tibble(
    chunk_text = "hello",
    embedding  = list(c(0.1, 0.2)),
    doc_title  = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  expect_false(dir.exists(cache_dir))
  save_interim_embedding(result, cache_dir, "doc.pdf")
  expect_true(dir.exists(cache_dir))
})

test_that("load_interim_embedding returns NULL when no cache file exists", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))
  dir.create(cache_dir)

  result <- load_interim_embedding(cache_dir, "missing.pdf")
  expect_null(result)
})

test_that("load_interim_embedding returns the saved tibble", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))

  original <- tibble::tibble(
    chunk_text = c("a", "b"),
    embedding  = list(c(0.1, 0.2), c(0.3, 0.4)),
    doc_title  = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(original, cache_dir, "doc.pdf")
  loaded <- load_interim_embedding(cache_dir, "doc.pdf")

  expect_equal(loaded$chunk_text, original$chunk_text)
  expect_equal(nrow(loaded), 2L)
})

test_that("load_interim_embedding is the round-trip inverse of save_interim_embedding", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))

  original <- tibble::tibble(
    chunk_text = "round trip",
    embedding  = list(c(1, 2, 3)),
    doc_title  = "RT", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(original, cache_dir, "rt.pdf")
  expect_equal(load_interim_embedding(cache_dir, "rt.pdf"), original)
})

test_that("clear_interim_cache removes all rds files", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))
  dir.create(cache_dir)

  # Write two interim files
  stub <- tibble::tibble(
    chunk_text = "x", embedding = list(c(0.1)),
    doc_title = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(stub, cache_dir, "a.pdf")
  save_interim_embedding(stub, cache_dir, "b.pdf")
  expect_length(list.files(cache_dir, pattern = "\\.rds$"), 2L)

  clear_interim_cache(cache_dir)
  expect_length(list.files(cache_dir, pattern = "\\.rds$"), 0L)
})

test_that("clear_interim_cache returns the paths it removed", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))

  stub <- tibble::tibble(
    chunk_text = "x", embedding = list(c(0.1)),
    doc_title = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(stub, cache_dir, "a.pdf")
  removed <- clear_interim_cache(cache_dir)
  expect_length(removed, 1L)
  expect_match(removed[[1L]], "a\\.rds$")
})

test_that("clear_interim_cache is a no-op on an empty directory", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))
  dir.create(cache_dir)

  expect_silent(clear_interim_cache(cache_dir))
  expect_length(list.files(cache_dir), 0L)
})

test_that("save then clear leaves no rds files but preserves cache_dir", {
  cache_dir <- tempfile()
  on.exit(unlink(cache_dir, recursive = TRUE))

  stub <- tibble::tibble(
    chunk_text = "x", embedding = list(c(0.1)),
    doc_title = "T", doc_org = "O", doc_date = "D", doc_url = "U"
  )
  save_interim_embedding(stub, cache_dir, "doc.pdf")
  clear_interim_cache(cache_dir)

  expect_true(dir.exists(cache_dir))
  expect_length(list.files(cache_dir, pattern = "\\.rds$"), 0L)
})

# ── chunk_text_sentence ───────────────────────────────────────────────────────

test_that("chunk_text_sentence returns a character vector", {
  text   <- "First sentence. Second sentence. Third sentence."
  result <- chunk_text_sentence(text, chunk_size = 100)
  expect_type(result, "character")
})

test_that("chunk_text_sentence returns single chunk when text is shorter than target size", {
  text   <- "Short text."
  result <- chunk_text_sentence(text, chunk_size = 1000)
  expect_length(result, 1)
  expect_equal(result, text)
})

test_that("chunk_text_sentence handles empty input", {
  expect_equal(chunk_text_sentence("", chunk_size = 500), character(0))
})

test_that("chunk_text_sentence handles NULL input", {
  expect_equal(chunk_text_sentence(NULL, chunk_size = 500), character(0))
})

test_that("chunk_text_sentence never cuts mid-sentence", {
  sentences <- c(
    "Alpha is the first sentence here.",
    "Beta is the second sentence here.",
    "Gamma is the third sentence here.",
    "Delta is the fourth sentence here.",
    "Epsilon is the fifth sentence here."
  )
  text   <- paste(sentences, collapse = " ")
  result <- chunk_text_sentence(text, chunk_size = 60)
  for (chunk in result) {
    expect_match(trimws(chunk), "[.!?]$")
  }
})

test_that("chunk_text_sentence carries last sentence of previous chunk as overlap", {
  sentences <- c(
    "The quick brown fox.",
    "Jumped over the lazy dog.",
    "A stitch in time saves nine.",
    "All that glitters is not gold."
  )
  text   <- paste(sentences, collapse = " ")
  result <- chunk_text_sentence(text, chunk_size = 50)
  if (length(result) >= 2L) {
    # Split chunk 1 into sentences; the last one should start chunk 2
    sents_in_chunk1 <- strsplit(result[[1L]], "(?<=[.!?])\\s+", perl = TRUE)[[1L]]
    last_sent       <- trimws(tail(sents_in_chunk1, 1L))
    expect_true(startsWith(trimws(result[[2L]]), last_sent))
  }
})

test_that("chunk_text_sentence handles text with a single very long sentence", {
  long_sentence <- paste0(paste(rep("word", 500), collapse = " "), ".")
  result        <- chunk_text_sentence(long_sentence, chunk_size = 100)
  expect_length(result, 1)
  expect_equal(result, long_sentence)
})

test_that("chunk_text_sentence handles text with many short sentences", {
  sentences <- paste0("Sentence ", seq_len(20), ".")
  text      <- paste(sentences, collapse = " ")
  result    <- chunk_text_sentence(text, chunk_size = 60)
  expect_true(length(result) > 1L)
})

test_that("chunk_text_sentence all chunks end at sentence boundaries", {
  sentences <- paste0("Word number ", seq_len(10), " ends here.")
  text      <- paste(sentences, collapse = " ")
  result    <- chunk_text_sentence(text, chunk_size = 50)
  for (chunk in result) {
    expect_match(trimws(chunk), "[.!?]$")
  }
})

# ── chunk_text_sentence: abbreviation handling ─────────────────────────────────

test_that("chunk_text_sentence does not produce orphaned abbreviation fragments like 'Dr.'", {
  # With a small chunk_size, the regex-based splitter incorrectly treats "Dr." as
  # a sentence boundary, producing a fragment chunk containing just "Dr."
  text <- paste(
    "Dr. Smith presented the annual report.",
    "The team reviewed it carefully.",
    "Mr. Jones raised several concerns.",
    "All points were noted for follow-up."
  )
  result <- chunk_text_sentence(text, chunk_size = 60)
  # No chunk should be a bare abbreviation fragment
  for (chunk in result) {
    expect_false(grepl("^(Dr|Mr|Mrs|Ms|Prof)\\.$", trimws(chunk)))
  }
})

test_that("chunk_text_sentence keeps 'Dr. Smith' together in the same chunk", {
  text <- paste(
    "Dr. Smith presented the annual report.",
    "The team reviewed it carefully.",
    "Mr. Jones raised several concerns.",
    "All points were noted for follow-up."
  )
  result <- chunk_text_sentence(text, chunk_size = 60)
  # "Dr. Smith" must appear together (not split across chunks)
  combined <- paste(result, collapse = "\n")
  expect_true(grepl("Dr. Smith", combined, fixed = TRUE))
  # No chunk should start with "Smith" (orphaned from its "Dr.")
  for (chunk in result) {
    expect_false(grepl("^Smith", trimws(chunk)))
  }
})

test_that("chunk_text_sentence does not split inside acronyms like U.S.A.", {
  text <- paste(
    "The policy applies across the U.S.A. and Canada.",
    "Both countries agreed on the terms.",
    "Implementation begins next quarter.",
    "Details will follow in the annexe."
  )
  result <- chunk_text_sentence(text, chunk_size = 60)
  # "U.S.A." must appear intact somewhere in the output
  combined <- paste(result, collapse = "\n")
  expect_true(grepl("U.S.A.", combined, fixed = TRUE))
  # No chunk should start with a bare "A." or "S." fragment from the acronym
  for (chunk in result) {
    expect_false(grepl("^[A-Z]\\. and", trimws(chunk)))
  }
})

test_that("chunk_text_sentence does not split on e.g. or etc.", {
  text <- paste(
    "Common items include e.g. apples and oranges.",
    "Other products are also accepted.",
    "Required accessories, etc. are listed below.",
    "Please review the full catalogue."
  )
  result <- chunk_text_sentence(text, chunk_size = 60)
  combined <- paste(result, collapse = "\n")
  expect_true(grepl("e.g.", combined, fixed = TRUE))
  expect_true(grepl("etc.", combined, fixed = TRUE))
  # No chunk should start with a lowercase continuation after e.g. or etc.
  for (chunk in result) {
    expect_false(grepl("^apples", trimws(chunk)))
    expect_false(grepl("^are listed", trimws(chunk)))
  }
})

test_that("chunk_text_sentence still splits on genuine sentence boundaries with abbreviations present", {
  text <- paste(
    "Dr. Smith presented the U.S.A. data.",
    "He noted that e.g. inflation was high.",
    "Mr. Jones disagreed with the conclusion.",
    "The meeting ended at five o'clock sharp."
  )
  result <- chunk_text_sentence(text, chunk_size = 50)
  expect_true(length(result) >= 2L)
  # Each chunk must end at a real sentence boundary
  for (chunk in result) {
    expect_match(trimws(chunk), "[.!?']$")
  }
})


# ── build_knowledge_base ──────────────────────────────────────────────────────

test_that("build_knowledge_base returns a tibble with required columns", {
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv))

  readr::write_csv(
    tibble::tibble(
      title        = "Test Doc",
      organisation = "Test Org",
      date         = "2024-01-01",
      url          = "http://example.com",
      filename     = "test.pdf"
    ),
    tmp_csv
  )

  local_mocked_bindings(
    .call_pdf_text     = function(pdf_path) "This is test document content.",
    .call_ollama_embed = function(chunks) lapply(seq_along(chunks), function(i) rep(0.1, 768))
  )

  result <- build_knowledge_base(
    pdf_paths          = "test.pdf",
    documents_csv_path = tmp_csv
  )
  expect_s3_class(result, "data.frame")
  expect_true(all(
    c("chunk_text", "embedding", "doc_title", "doc_org", "doc_date", "doc_url") %in% names(result)
  ))
})
