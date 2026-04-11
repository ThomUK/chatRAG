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
