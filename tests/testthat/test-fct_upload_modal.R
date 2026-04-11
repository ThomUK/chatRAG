test_that("validate_upload_inputs returns ok=TRUE when all fields are present", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "My Doc",
    org   = "ACME",
    date  = "2024-01-01",
    url   = "https://example.com/doc.pdf"
  )
  expect_true(result$ok)
  expect_equal(result$message, "")
})

test_that("validate_upload_inputs returns ok=FALSE when file is NULL", {
  result <- validate_upload_inputs(
    file  = NULL,
    title = "My Doc",
    org   = "ACME",
    date  = "2024-01-01",
    url   = "https://example.com/doc.pdf"
  )
  expect_false(result$ok)
  expect_match(result$message, "[Ff]ile")
})

test_that("validate_upload_inputs returns ok=FALSE when title is empty", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "",
    org   = "ACME",
    date  = "2024-01-01",
    url   = "https://example.com"
  )
  expect_false(result$ok)
  expect_match(result$message, "[Tt]itle")
})

test_that("validate_upload_inputs returns ok=FALSE when org is empty", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "My Doc",
    org   = "",
    date  = "2024-01-01",
    url   = "https://example.com"
  )
  expect_false(result$ok)
  expect_match(result$message, "[Oo]rganisation")
})

test_that("validate_upload_inputs returns ok=FALSE when date is empty", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "My Doc",
    org   = "ACME",
    date  = "",
    url   = "https://example.com"
  )
  expect_false(result$ok)
  expect_match(result$message, "[Dd]ate")
})

test_that("validate_upload_inputs returns ok=FALSE when url is empty", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "My Doc",
    org   = "ACME",
    date  = "2024-01-01",
    url   = ""
  )
  expect_false(result$ok)
  expect_match(result$message, "[Uu][Rr][Ll]")
})

test_that("validate_upload_inputs returns ok=FALSE when file is not a PDF", {
  fake_file <- list(datapath = tempfile(fileext = ".txt"), name = "test.txt")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "My Doc",
    org   = "ACME",
    date  = "2024-01-01",
    url   = "https://example.com"
  )
  expect_false(result$ok)
  expect_match(result$message, "[Pp][Dd][Ff]")
})

test_that("validate_upload_inputs trims whitespace before checking", {
  fake_file <- list(datapath = tempfile(fileext = ".pdf"), name = "test.pdf")
  result <- validate_upload_inputs(
    file  = fake_file,
    title = "   ",
    org   = "ACME",
    date  = "2024-01-01",
    url   = "https://example.com"
  )
  expect_false(result$ok)
})

# ── append_document_to_csv ─────────────────────────────────────────────────────

test_that("append_document_to_csv adds a row to an existing CSV", {
  tmp <- tempfile(fileext = ".csv")
  readr::write_csv(
    data.frame(
      title        = "Existing Doc",
      organisation = "Org A",
      date         = "2023-01-01",
      url          = "https://example.com/a.pdf",
      filename     = "a.pdf",
      stringsAsFactors = FALSE
    ),
    tmp
  )

  new_row <- list(
    title        = "New Doc",
    organisation = "Org B",
    date         = "2024-06-01",
    url          = "https://example.com/b.pdf",
    filename     = "b.pdf"
  )

  result_path <- append_document_to_csv(tmp, new_row)

  updated <- readr::read_csv(tmp, show_col_types = FALSE)
  expect_equal(nrow(updated), 2L)
  expect_equal(updated$title[2], "New Doc")
  expect_equal(updated$organisation[2], "Org B")
  expect_equal(updated$filename[2], "b.pdf")
})

test_that("append_document_to_csv returns the csv_path invisibly", {
  tmp <- tempfile(fileext = ".csv")
  readr::write_csv(
    data.frame(
      title = "A", organisation = "B", date = "2024-01-01",
      url = "https://x.com", filename = "x.pdf",
      stringsAsFactors = FALSE
    ),
    tmp
  )
  new_row <- list(title = "B", organisation = "C", date = "2024-02-01",
                  url = "https://y.com", filename = "y.pdf")
  result <- append_document_to_csv(tmp, new_row)
  expect_equal(result, tmp)
})

test_that("append_document_to_csv preserves all existing rows", {
  tmp <- tempfile(fileext = ".csv")
  existing <- data.frame(
    title        = c("Doc 1", "Doc 2"),
    organisation = c("Org A", "Org B"),
    date         = c("2021-01-01", "2022-01-01"),
    url          = c("https://a.com", "https://b.com"),
    filename     = c("a.pdf", "b.pdf"),
    stringsAsFactors = FALSE
  )
  readr::write_csv(existing, tmp)

  new_row <- list(title = "Doc 3", organisation = "Org C", date = "2023-01-01",
                  url = "https://c.com", filename = "c.pdf")
  append_document_to_csv(tmp, new_row)

  updated <- readr::read_csv(tmp, show_col_types = FALSE)
  expect_equal(nrow(updated), 3L)
  expect_equal(updated$title[1], "Doc 1")
  expect_equal(updated$title[2], "Doc 2")
  expect_equal(updated$title[3], "Doc 3")
})

test_that("append_document_to_csv writes correct column values", {
  tmp <- tempfile(fileext = ".csv")
  readr::write_csv(
    data.frame(
      title = character(0), organisation = character(0),
      date = character(0), url = character(0), filename = character(0)
    ),
    tmp
  )

  new_row <- list(
    title        = "Test Title",
    organisation = "Test Org",
    date         = "2025-03-15",
    url          = "https://test.com/doc.pdf",
    filename     = "doc.pdf"
  )
  append_document_to_csv(tmp, new_row)
  updated <- readr::read_csv(tmp, show_col_types = FALSE)

  expect_equal(updated$title,        "Test Title")
  expect_equal(updated$organisation, "Test Org")
  expect_equal(as.character(updated$date), "2025-03-15")
  expect_equal(updated$url,          "https://test.com/doc.pdf")
  expect_equal(updated$filename,     "doc.pdf")
})
