# test-design_polish.R
# TDD tests for Slice 10: Design Polish
# Covers CSS correctness, UI component structural improvements, and
# accessibility of design tokens.

# ── Helpers ────────────────────────────────────────────────────────────────────

read_css <- function() {
  css_path <- system.file("app/www/app.css", package = "chatRAG")
  if (nchar(css_path) == 0) {
    # Fallback for devtools::load_all() / testthat dev environments
    # testthat sets the working directory to the package root
    css_path <- file.path(testthat::test_path("../../inst/app/www/app.css"))
  }
  paste(readLines(css_path, warn = FALSE), collapse = "\n")
}


# ── CSS: bug fixes ─────────────────────────────────────────────────────────────

test_that("app.css has no undefined var(--border) references", {
  css <- read_css()
  expect_false(
    grepl("var\\(--border\\)", css),
    label = "Found var(--border) which is not defined in :root — should be var(--color-border)"
  )
})


# ── CSS: pill animations ───────────────────────────────────────────────────────

test_that("app.css defines a @keyframes animation for pill slide-in", {
  css <- read_css()
  expect_match(css, "@keyframes.*pill", perl = TRUE)
})

test_that("app.css applies an animation to .context-pill", {
  css <- read_css()
  # Extract the .context-pill block and check it mentions 'animation'
  expect_true(
    grepl("\\.context-pill[^}]*animation", css) ||
      grepl("animation[^}]*pill", css),
    label = ".context-pill block should include an animation declaration"
  )
})


# ── CSS: pill fade classes ─────────────────────────────────────────────────────

test_that("app.css defines .pill-fade-1 with lowest opacity (most recent dropped)", {
  css <- read_css()
  expect_match(css, "\\.pill-fade-1")
})

test_that("app.css defines .pill-fade-2 with mid opacity", {
  css <- read_css()
  expect_match(css, "\\.pill-fade-2")
})

test_that("app.css defines .pill-fade-3 with highest fade (oldest shown)", {
  css <- read_css()
  expect_match(css, "\\.pill-fade-3")
})


# ── CSS: context pills fade-to-white gradient ──────────────────────────────────

test_that("app.css has a fade-to-white gradient for dropped pills section", {
  css <- read_css()
  # Either a ::after pseudo-element or a dedicated .context-pills-dropped block
  # should contain a linear-gradient to white
  expect_true(
    grepl("linear-gradient.*white|linear-gradient.*#fff", css, perl = TRUE),
    label = "app.css should define a linear-gradient-to-white fade for dropped pills"
  )
})


# ── CSS: improved form controls ────────────────────────────────────────────────

test_that("app.css overrides .form-control with custom padding or border", {
  css <- read_css()
  expect_match(css, "\\.form-control")
})

test_that("app.css overrides .form-select styling", {
  css <- read_css()
  expect_match(css, "\\.form-select")
})


# ── CSS: modal improvements ────────────────────────────────────────────────────

test_that("app.css styles .modal-header or .modal-content", {
  css <- read_css()
  expect_true(
    grepl("\\.modal-header|\\.modal-content|\\.modal-body", css),
    label = "app.css should include modal element styles"
  )
})

test_that("app.css styles .progress-bar", {
  css <- read_css()
  expect_match(css, "\\.progress-bar")
})


# ── CSS: heading hierarchy ─────────────────────────────────────────────────────

test_that("app.css includes styles for h1, h2, h3 headings", {
  css <- read_css()
  expect_true(
    grepl("h1|h2|h3", css),
    label = "app.css should define heading styles for h1/h2/h3"
  )
})


# ── R: chat_bubble_ui alignment wrapper ───────────────────────────────────────

test_that("chat_bubble_ui wraps user bubble in right-align flex container", {
  result <- chat_bubble_ui("user", "Hello world")
  html   <- as.character(result)
  expect_match(html, "justify-content-end")
})

test_that("chat_bubble_ui wraps assistant bubble in left-align flex container", {
  result <- chat_bubble_ui("assistant", "I can help")
  html   <- as.character(result)
  expect_match(html, "justify-content-start")
})

test_that("chat_bubble_ui outer wrapper has d-flex class", {
  result <- chat_bubble_ui("user", "Hello")
  html   <- as.character(result)
  expect_match(html, "d-flex")
})

test_that("chat_bubble_ui still contains chat-bubble-user class", {
  result <- chat_bubble_ui("user", "Hello")
  html   <- as.character(result)
  expect_match(html, "chat-bubble-user")
})

test_that("chat_bubble_ui still contains chat-bubble-assistant class", {
  result <- chat_bubble_ui("assistant", "I can help")
  html   <- as.character(result)
  expect_match(html, "chat-bubble-assistant")
})


# ── R: context_window_pill_ui fade_rank parameter ─────────────────────────────

test_that("context_window_pill_ui: fade_rank=1 adds pill-fade-1 class", {
  result <- context_window_pill_ui("user", "hello world test pill", active = FALSE, fade_rank = 1L)
  html   <- as.character(result)
  expect_match(html, "pill-fade-1")
})

test_that("context_window_pill_ui: fade_rank=2 adds pill-fade-2 class", {
  result <- context_window_pill_ui("user", "hello world test pill", active = FALSE, fade_rank = 2L)
  html   <- as.character(result)
  expect_match(html, "pill-fade-2")
})

test_that("context_window_pill_ui: fade_rank=3 adds pill-fade-3 class", {
  result <- context_window_pill_ui("user", "hello world test pill", active = FALSE, fade_rank = 3L)
  html   <- as.character(result)
  expect_match(html, "pill-fade-3")
})

test_that("context_window_pill_ui: fade_rank=NULL (default) adds no pill-fade class", {
  result <- context_window_pill_ui("user", "hello world test pill", active = FALSE, fade_rank = NULL)
  html   <- as.character(result)
  expect_false(grepl("pill-fade-", html))
})


# ── R: context_window_panel_ui assigns fade ranks ─────────────────────────────

test_that("context_window_panel_ui: dropped pills have pill-fade classes", {
  msgs <- lapply(1:6, function(i) list(role = "user", content = paste("message number", i)))
  html <- as.character(context_window_panel_ui(msgs, window_size = 3L))
  # Should have at least one pill-fade class for the dropped messages
  expect_match(html, "pill-fade-")
})

test_that("context_window_panel_ui: most recent dropped pill gets pill-fade-1", {
  msgs <- lapply(1:5, function(i) list(role = "user", content = paste("message number", i)))
  html <- as.character(context_window_panel_ui(msgs, window_size = 3L))
  expect_match(html, "pill-fade-1")
})

test_that("context_window_panel_ui: no pill-fade classes when all messages are active", {
  msgs <- lapply(1:3, function(i) list(role = "user", content = paste("message", i)))
  html <- as.character(context_window_panel_ui(msgs, window_size = 6L))
  expect_false(grepl("pill-fade-", html))
})
