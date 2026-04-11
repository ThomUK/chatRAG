test_that("provider_label returns correct display label for claude", {
  expect_equal(provider_label("claude"), "Claude (Anthropic)")
})

test_that("provider_label returns correct display label for openai", {
  expect_equal(provider_label("openai"), "OpenAI")
})

test_that("provider_label returns correct display label for azure", {
  expect_equal(provider_label("azure"), "Azure OpenAI")
})

test_that("provider_label errors on unknown provider", {
  expect_error(provider_label("unknown"), "unknown")
})

# ── connection_status_ui ───────────────────────────────────────────────────────

test_that("connection_status_ui returns success tag on success result", {
  result <- list(success = TRUE)
  ui     <- connection_status_ui(result, "claude")
  html   <- as.character(ui)
  expect_match(html, "alert-success")
  expect_match(html, "Connected")
  expect_match(html, "Claude \\(Anthropic\\)")
})

test_that("connection_status_ui returns danger tag on failure result", {
  result <- list(success = FALSE, message = "Invalid API key")
  ui     <- connection_status_ui(result, "openai")
  html   <- as.character(ui)
  expect_match(html, "alert-danger")
  expect_match(html, "Invalid API key")
})

test_that("connection_status_ui success includes provider label in message", {
  result <- list(success = TRUE)
  ui     <- connection_status_ui(result, "azure")
  html   <- as.character(ui)
  expect_match(html, "Azure OpenAI")
})

test_that("connection_status_ui failure shows error message text", {
  result <- list(success = FALSE, message = "401 Unauthorized")
  ui     <- connection_status_ui(result, "claude")
  html   <- as.character(ui)
  expect_match(html, "401 Unauthorized")
})

# ── connect_your_own_tab_ui ────────────────────────────────────────────────────

test_that("connect_your_own_tab_ui returns a shiny tag object", {
  ui <- connect_your_own_tab_ui()
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("connect_your_own_tab_ui contains provider selectInput", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_provider")
})

test_that("connect_your_own_tab_ui contains claude option", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "claude")
})

test_that("connect_your_own_tab_ui contains openai option", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "openai")
})

test_that("connect_your_own_tab_ui contains azure option", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "azure")
})

test_that("connect_your_own_tab_ui contains API key input", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_api_key")
})

test_that("connect_your_own_tab_ui contains Test Connection button", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_test")
})

test_that("connect_your_own_tab_ui contains Azure endpoint input", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_azure_endpoint")
})

test_that("connect_your_own_tab_ui contains Azure deployment input", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_azure_deployment")
})

test_that("connect_your_own_tab_ui contains privacy paragraph", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  # Should mention what is sent and what stays local
  expect_match(html, "sent to the API|retrieved document chunks", ignore.case = TRUE)
  expect_match(html, "local|stays on", ignore.case = TRUE)
})

test_that("connect_your_own_tab_ui contains uiOutput for status", {
  ui   <- connect_your_own_tab_ui()
  html <- as.character(ui)
  expect_match(html, "connect_status")
})
