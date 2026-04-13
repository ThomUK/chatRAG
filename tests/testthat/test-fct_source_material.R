test_that("load_documents_csv returns a tibble with expected columns", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(
    "title,organisation,date,url,filename\nAnnual Report,Org A,2024-01-01,https://example.com/a,a.pdf",
    tmp
  )

  result <- load_documents_csv(tmp)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("title", "organisation", "date", "url", "filename") %in% names(result)))
  expect_equal(nrow(result), 1L)
  expect_equal(result$title, "Annual Report")
  expect_equal(result$organisation, "Org A")
  expect_equal(result$url, "https://example.com/a")
})

test_that("load_documents_csv returns empty tibble when CSV has only headers", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines("title,organisation,date,url,filename", tmp)

  result <- load_documents_csv(tmp)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
})

test_that("load_documents_csv errors on missing file", {
  expect_error(load_documents_csv("/nonexistent/path.csv"))
})

test_that("prepare_source_table returns data frame with display columns", {
  docs <- data.frame(
    title        = "Annual Report",
    organisation = "Org A",
    date         = "2024-01-01",
    url          = "https://example.com/a",
    filename     = "a.pdf",
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("Title", "Organisation", "Date", "Source") %in% names(result)))
})

test_that("prepare_source_table Source column contains an HTML anchor tag", {
  docs <- data.frame(
    title        = "Annual Report",
    organisation = "Org A",
    date         = "2024-01-01",
    url          = "https://example.com/a",
    filename     = "a.pdf",
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_true(grepl("<a", result$Source[[1]]))
  expect_true(grepl("https://example.com/a", result$Source[[1]]))
})

test_that("prepare_source_table Source link opens in new tab", {
  docs <- data.frame(
    title        = "Report",
    organisation = "Org B",
    date         = "2024-06-01",
    url          = "https://example.com/b",
    filename     = "b.pdf",
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_true(grepl('target="_blank"', result$Source[[1]]))
})

test_that("prepare_source_table preserves row count", {
  docs <- data.frame(
    title        = c("Report A", "Report B", "Report C"),
    organisation = c("Org A", "Org B", "Org C"),
    date         = c("2024-01-01", "2024-02-01", "2024-03-01"),
    url          = c("https://a.com", "https://b.com", "https://c.com"),
    filename     = c("a.pdf", "b.pdf", "c.pdf"),
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_equal(nrow(result), 3L)
})

test_that("prepare_source_table drops internal columns (url, filename)", {
  docs <- data.frame(
    title        = "Report",
    organisation = "Org",
    date         = "2024-01-01",
    url          = "https://example.com",
    filename     = "r.pdf",
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_false("url" %in% names(result))
  expect_false("filename" %in% names(result))
})

test_that("prepare_source_table returns 0-row data frame for empty input", {
  docs <- data.frame(
    title        = character(0),
    organisation = character(0),
    date         = character(0),
    url          = character(0),
    filename     = character(0),
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("Title", "Organisation", "Date", "Source") %in% names(result)))
})

test_that("prepare_source_table includes an Actions column with an Edit button", {
  docs <- data.frame(
    title        = "Annual Report",
    organisation = "Org A",
    date         = "2024-01-01",
    url          = "https://example.com/a",
    filename     = "a.pdf",
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_true("Actions" %in% names(result))
  expect_true(grepl("Edit", result$Actions[[1]]))
})

test_that("prepare_source_table Actions column encodes row index for Shiny input", {
  docs <- data.frame(
    title        = c("Report A", "Report B"),
    organisation = c("Org A", "Org B"),
    date         = c("2024-01-01", "2024-02-01"),
    url          = c("https://a.com", "https://b.com"),
    filename     = c("a.pdf", "b.pdf"),
    stringsAsFactors = FALSE
  )

  result <- prepare_source_table(docs)

  expect_true(grepl("edit_row_idx.*1", result$Actions[[1]]))
  expect_true(grepl("edit_row_idx.*2", result$Actions[[2]]))
})

# ── update_document_in_csv ────────────────────────────────────────────────────

test_that("update_document_in_csv updates the matching row by filename", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(
    "title,organisation,date,url,filename\nOld Title,Old Org,2020-01-01,https://old.com,doc.pdf",
    tmp
  )

  update_document_in_csv(tmp, "doc.pdf",
                         new_title = "New Title",
                         new_organisation = "New Org",
                         new_date = "2025-06-01",
                         new_url  = "https://new.com")

  result <- readr::read_csv(tmp, show_col_types = FALSE)
  expect_equal(result$title,            "New Title")
  expect_equal(result$organisation,     "New Org")
  expect_equal(as.character(result$date), "2025-06-01")
  expect_equal(result$url,              "https://new.com")
  expect_equal(result$filename,         "doc.pdf")  # filename unchanged
})

test_that("update_document_in_csv leaves other rows unchanged", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(
    paste0(
      "title,organisation,date,url,filename\n",
      "Report A,Org A,2024-01-01,https://a.com,a.pdf\n",
      "Report B,Org B,2024-02-01,https://b.com,b.pdf"
    ),
    tmp
  )

  update_document_in_csv(tmp, "a.pdf",
                         new_title = "Updated A",
                         new_organisation = "Org A",
                         new_date = "2024-01-01",
                         new_url  = "https://a.com")

  result <- readr::read_csv(tmp, show_col_types = FALSE)
  expect_equal(nrow(result), 2L)
  expect_equal(result$title[result$filename == "b.pdf"], "Report B")
})

test_that("update_document_in_csv errors when filename not found", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(
    "title,organisation,date,url,filename\nReport,Org,2024-01-01,https://x.com,x.pdf",
    tmp
  )

  expect_error(
    update_document_in_csv(tmp, "missing.pdf",
                           new_title = "T", new_organisation = "O",
                           new_date = "2024-01-01", new_url = "https://x.com"),
    "not found"
  )
})

# ── update_kb_metadata ────────────────────────────────────────────────────────

test_that("update_kb_metadata updates matching chunk metadata", {
  kb <- data.frame(
    chunk_text = c("chunk1", "chunk2"),
    doc_title  = c("Old Title", "Other Doc"),
    doc_org    = c("Old Org",   "Other Org"),
    doc_date   = c("2020-01-01", "2021-01-01"),
    doc_url    = c("https://old.com", "https://other.com"),
    stringsAsFactors = FALSE
  )

  result <- update_kb_metadata(
    kb,
    old_title = "Old Title", old_org = "Old Org",
    old_date  = "2020-01-01", old_url = "https://old.com",
    new_title = "New Title", new_org = "New Org",
    new_date  = "2025-06-01", new_url = "https://new.com"
  )

  expect_equal(result$doc_title[1L], "New Title")
  expect_equal(result$doc_org[1L],   "New Org")
  expect_equal(result$doc_date[1L],  "2025-06-01")
  expect_equal(result$doc_url[1L],   "https://new.com")
})

test_that("update_kb_metadata leaves non-matching chunks unchanged", {
  kb <- data.frame(
    chunk_text = c("chunk1", "chunk2"),
    doc_title  = c("Old Title", "Other Doc"),
    doc_org    = c("Old Org",   "Other Org"),
    doc_date   = c("2020-01-01", "2021-01-01"),
    doc_url    = c("https://old.com", "https://other.com"),
    stringsAsFactors = FALSE
  )

  result <- update_kb_metadata(
    kb,
    old_title = "Old Title", old_org = "Old Org",
    old_date  = "2020-01-01", old_url = "https://old.com",
    new_title = "New Title", new_org = "New Org",
    new_date  = "2025-06-01", new_url = "https://new.com"
  )

  expect_equal(result$doc_title[2L], "Other Doc")
  expect_equal(result$doc_org[2L],   "Other Org")
})
