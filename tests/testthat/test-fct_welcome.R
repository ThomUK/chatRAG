# Tests for fct_welcome.R
# Using red-green-refactor TDD approach.
# External calls (.call_ollama_ping, .list_pdf_files, .read_documents_csv,
# .check_file_exists) are isolated behind internal wrappers for test mockability.

# ── check_ollama_status ────────────────────────────────────────────────────────

test_that("check_ollama_status returns a list with ok and message", {
  local_mocked_bindings(
    check_ollama_running = function() TRUE
  )
  result <- check_ollama_status()
  expect_type(result, "list")
  expect_true("ok" %in% names(result))
  expect_true("message" %in% names(result))
})

test_that("check_ollama_status ok=TRUE when Ollama is running", {
  local_mocked_bindings(
    check_ollama_running = function() TRUE
  )
  result <- check_ollama_status()
  expect_true(result$ok)
})

test_that("check_ollama_status ok=FALSE when Ollama is not running", {
  local_mocked_bindings(
    check_ollama_running = function() FALSE
  )
  result <- check_ollama_status()
  expect_false(result$ok)
})

test_that("check_ollama_status message is a non-empty string", {
  local_mocked_bindings(
    check_ollama_running = function() TRUE
  )
  result <- check_ollama_status()
  expect_type(result$message, "character")
  expect_gt(nchar(result$message), 0)
})

test_that("check_ollama_status message mentions 'ollama serve' when not running", {
  local_mocked_bindings(
    check_ollama_running = function() FALSE
  )
  result <- check_ollama_status()
  expect_match(result$message, "ollama serve", ignore.case = TRUE)
})

# ── check_nomic_model_status ──────────────────────────────────────────────────

test_that("check_nomic_model_status returns a list with ok and message", {
  local_mocked_bindings(
    .call_ollama_list_models = function() data.frame(name = "nomic-embed-text:latest")
  )
  result <- check_nomic_model_status()
  expect_type(result, "list")
  expect_true("ok" %in% names(result))
  expect_true("message" %in% names(result))
})

test_that("check_nomic_model_status ok=TRUE when nomic-embed-text is available", {
  local_mocked_bindings(
    .call_ollama_list_models = function() data.frame(name = "nomic-embed-text:latest")
  )
  result <- check_nomic_model_status()
  expect_true(result$ok)
})

test_that("check_nomic_model_status ok=TRUE when model listed without tag", {
  local_mocked_bindings(
    .call_ollama_list_models = function() data.frame(name = "nomic-embed-text")
  )
  result <- check_nomic_model_status()
  expect_true(result$ok)
})

test_that("check_nomic_model_status ok=FALSE when nomic-embed-text is absent", {
  local_mocked_bindings(
    .call_ollama_list_models = function() data.frame(name = "llama3:latest")
  )
  result <- check_nomic_model_status()
  expect_false(result$ok)
})

test_that("check_nomic_model_status failure message mentions ollama pull", {
  local_mocked_bindings(
    .call_ollama_list_models = function() data.frame(name = "llama3:latest")
  )
  result <- check_nomic_model_status()
  expect_match(result$message, "ollama pull", ignore.case = TRUE)
})

test_that("check_nomic_model_status ok=FALSE when list_models errors", {
  local_mocked_bindings(
    .call_ollama_list_models = function() stop("connection refused")
  )
  result <- check_nomic_model_status()
  expect_false(result$ok)
})

# ── check_pdfs_status ─────────────────────────────────────────────────────────

test_that("check_pdfs_status returns a list with ok and message", {
  local_mocked_bindings(
    .list_pdf_files = function(pdf_dir) character(0)
  )
  result <- check_pdfs_status("dummy/dir")
  expect_type(result, "list")
  expect_true("ok" %in% names(result))
  expect_true("message" %in% names(result))
})

test_that("check_pdfs_status ok=FALSE when no PDFs present", {
  local_mocked_bindings(
    .list_pdf_files = function(pdf_dir) character(0)
  )
  result <- check_pdfs_status("dummy/dir")
  expect_false(result$ok)
})

test_that("check_pdfs_status ok=TRUE when PDFs present", {
  local_mocked_bindings(
    .list_pdf_files = function(pdf_dir) c("doc1.pdf", "doc2.pdf")
  )
  result <- check_pdfs_status("dummy/dir")
  expect_true(result$ok)
})

test_that("check_pdfs_status message mentions PDF count when PDFs found", {
  local_mocked_bindings(
    .list_pdf_files = function(pdf_dir) c("doc1.pdf", "doc2.pdf")
  )
  result <- check_pdfs_status("dummy/dir")
  expect_match(result$message, "2")
})

test_that("check_pdfs_status failure message explains how to resolve", {
  local_mocked_bindings(
    .list_pdf_files = function(pdf_dir) character(0)
  )
  result <- check_pdfs_status("dummy/dir")
  expect_match(result$message, "pdf", ignore.case = TRUE)
})

# ── check_documents_csv_status ────────────────────────────────────────────────

# Helper: a valid single-row CSV data frame whose filename matches one PDF
valid_csv_df <- function(filename = "doc.pdf") {
  data.frame(
    title = "T", organisation = "O", date = "D",
    url = "U", filename = filename,
    stringsAsFactors = FALSE
  )
}

test_that("check_documents_csv_status returns a list with ok and message", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) valid_csv_df("doc.pdf"),
    .list_pdf_files     = function(pdf_dir) "doc.pdf"
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_type(result, "list")
  expect_true("ok" %in% names(result))
  expect_true("message" %in% names(result))
})

test_that("check_documents_csv_status ok=FALSE when file does not exist", {
  local_mocked_bindings(
    .check_file_exists = function(path) FALSE
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
})

test_that("check_documents_csv_status ok=TRUE when CSV and PDFs match", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) valid_csv_df("doc.pdf"),
    .list_pdf_files     = function(pdf_dir) "doc.pdf"
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_true(result$ok)
})

test_that("check_documents_csv_status ok=FALSE when required columns missing", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) data.frame(title = "t", stringsAsFactors = FALSE),
    .list_pdf_files     = function(pdf_dir) character(0)
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
  expect_match(result$message, "missing", ignore.case = TRUE)
})

test_that("check_documents_csv_status ok=FALSE when CSV has zero rows", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) {
      data.frame(title = character(0), organisation = character(0),
                 date = character(0), url = character(0),
                 filename = character(0), stringsAsFactors = FALSE)
    },
    .list_pdf_files     = function(pdf_dir) character(0)
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
  expect_match(result$message, "no entries", ignore.case = TRUE)
})

test_that("check_documents_csv_status ok=FALSE when PDF has no CSV entry", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) valid_csv_df("other.pdf"),
    .list_pdf_files     = function(pdf_dir) "missing.pdf"
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
  expect_match(result$message, "missing.pdf")
})

test_that("check_documents_csv_status ok=FALSE when CSV entry has no matching PDF", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) valid_csv_df("ghost.pdf"),
    .list_pdf_files     = function(pdf_dir) character(0)
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
  expect_match(result$message, "ghost.pdf")
})

test_that("check_documents_csv_status ok=FALSE when CSV cannot be parsed", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) stop("parse error"),
    .list_pdf_files     = function(pdf_dir) character(0)
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_false(result$ok)
  expect_match(result$message, "parse", ignore.case = TRUE)
})

test_that("check_documents_csv_status message mentions row count when ok", {
  local_mocked_bindings(
    .check_file_exists  = function(path) TRUE,
    .read_documents_csv = function(path) {
      data.frame(
        title = c("t1", "t2"), organisation = c("o", "o"),
        date = c("d", "d"), url = c("u", "u"),
        filename = c("a.pdf", "b.pdf"),
        stringsAsFactors = FALSE
      )
    },
    .list_pdf_files     = function(pdf_dir) c("a.pdf", "b.pdf")
  )
  result <- check_documents_csv_status("dummy.csv", "dummy/dir")
  expect_match(result$message, "2")
})

# ── run_prerequisite_checks ───────────────────────────────────────────────────

test_that("run_prerequisite_checks returns a list with four named elements", {
  local_mocked_bindings(
    check_ollama_status        = function() list(ok = TRUE, message = "ok"),
    check_nomic_model_status   = function() list(ok = TRUE, message = "ok"),
    check_pdfs_status          = function(pdf_dir) list(ok = TRUE, message = "ok"),
    check_documents_csv_status = function(csv_path, pdf_dir) list(ok = TRUE, message = "ok")
  )
  result <- run_prerequisite_checks("dir", "path.csv")
  expect_type(result, "list")
  expect_setequal(names(result), c("ollama", "nomic_model", "pdfs", "documents_csv"))
})

test_that("run_prerequisite_checks passes pdf_dir and csv_path through", {
  captured <- list()
  local_mocked_bindings(
    check_ollama_status        = function() list(ok = TRUE, message = "ok"),
    check_nomic_model_status   = function() list(ok = TRUE, message = "ok"),
    check_pdfs_status          = function(pdf_dir) {
      captured[["pdf_dir"]] <<- pdf_dir
      list(ok = TRUE, message = "ok")
    },
    check_documents_csv_status = function(csv_path, pdf_dir) {
      captured[["csv_path"]] <<- csv_path
      list(ok = TRUE, message = "ok")
    }
  )
  run_prerequisite_checks("my/pdf/dir", "my/doc.csv")
  expect_equal(captured$pdf_dir, "my/pdf/dir")
  expect_equal(captured$csv_path, "my/doc.csv")
})

# ── all_checks_pass ───────────────────────────────────────────────────────────

test_that("all_checks_pass returns TRUE when all checks have ok=TRUE", {
  checks <- list(
    ollama       = list(ok = TRUE,  message = "ok"),
    pdfs         = list(ok = TRUE,  message = "ok"),
    documents_csv = list(ok = TRUE,  message = "ok")
  )
  expect_true(all_checks_pass(checks))
})

test_that("all_checks_pass returns FALSE when any check has ok=FALSE", {
  checks <- list(
    ollama       = list(ok = TRUE,  message = "ok"),
    pdfs         = list(ok = FALSE, message = "fail"),
    documents_csv = list(ok = TRUE,  message = "ok")
  )
  expect_false(all_checks_pass(checks))
})

test_that("all_checks_pass returns FALSE when all checks have ok=FALSE", {
  checks <- list(
    ollama       = list(ok = FALSE, message = "fail"),
    pdfs         = list(ok = FALSE, message = "fail"),
    documents_csv = list(ok = FALSE, message = "fail")
  )
  expect_false(all_checks_pass(checks))
})

test_that("all_checks_pass returns logical scalar", {
  checks <- list(a = list(ok = TRUE, message = "ok"))
  result <- all_checks_pass(checks)
  expect_type(result, "logical")
  expect_length(result, 1)
})

# ── embeddings_file_exists ────────────────────────────────────────────────────

test_that("embeddings_file_exists returns TRUE when file exists", {
  local_mocked_bindings(
    .check_file_exists = function(path) TRUE
  )
  expect_true(embeddings_file_exists("some/path.rds"))
})

test_that("embeddings_file_exists returns FALSE when file does not exist", {
  local_mocked_bindings(
    .check_file_exists = function(path) FALSE
  )
  expect_false(embeddings_file_exists("some/path.rds"))
})

test_that("embeddings_file_exists returns a logical scalar", {
  local_mocked_bindings(
    .check_file_exists = function(path) TRUE
  )
  result <- embeddings_file_exists("some/path.rds")
  expect_type(result, "logical")
  expect_length(result, 1)
})
