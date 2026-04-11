test_that("truncate_for_pill: returns first n words + ellipsis", {
  result <- truncate_for_pill("The quick brown fox jumped over the lazy dog", n_words = 5)
  expect_equal(result, "The quick brown fox jumped\u2026")
})

test_that("truncate_for_pill: short text returned as-is without ellipsis", {
  result <- truncate_for_pill("Hello world", n_words = 5)
  expect_equal(result, "Hello world")
})

test_that("truncate_for_pill: single word returns as-is", {
  result <- truncate_for_pill("Hello", n_words = 5)
  expect_equal(result, "Hello")
})

test_that("truncate_for_pill: exactly n words returns as-is", {
  result <- truncate_for_pill("one two three four five", n_words = 5)
  expect_equal(result, "one two three four five")
})

test_that("truncate_for_pill: n_words = 4 truncates at 4 words", {
  result <- truncate_for_pill("The quick brown fox jumped", n_words = 4)
  expect_equal(result, "The quick brown fox\u2026")
})

test_that("truncate_for_pill: returns character string", {
  expect_type(truncate_for_pill("Hello world foo bar baz qux"), "character")
})

test_that("format_chat_message: returns list with role and content", {
  msg <- format_chat_message("user", "What is the budget?")
  expect_type(msg, "list")
  expect_equal(msg$role, "user")
  expect_equal(msg$content, "What is the budget?")
})

test_that("format_chat_message: works for assistant role", {
  msg <- format_chat_message("assistant", "The budget is £1m.")
  expect_equal(msg$role, "assistant")
  expect_equal(msg$content, "The budget is £1m.")
})

test_that("chat_bubble_ui: returns shiny tag for user", {
  result <- chat_bubble_ui("user", "Hello")
  expect_s3_class(result, "shiny.tag")
})

test_that("chat_bubble_ui: user bubble has user class", {
  result <- chat_bubble_ui("user", "Hello")
  html   <- as.character(result)
  expect_match(html, "chat-bubble-user")
})

test_that("chat_bubble_ui: assistant bubble has assistant class", {
  result <- chat_bubble_ui("assistant", "I can help")
  html   <- as.character(result)
  expect_match(html, "chat-bubble-assistant")
})

test_that("chat_bubble_ui: content appears in output", {
  result <- chat_bubble_ui("user", "Budget question here")
  html   <- as.character(result)
  expect_match(html, "Budget question here")
})

test_that("sources_block_ui: returns shiny tag list", {
  chunks <- tibble::tibble(
    doc_title        = c("Annual Report 2024", "Strategy Paper"),
    doc_org          = c("NHS", "NHSE"),
    doc_date         = c("2024-01-01", "2024-06-01"),
    chunk_text       = c("chunk a", "chunk b"),
    doc_url          = c("http://a.com", "http://b.com"),
    similarity_score = c(0.9, 0.8)
  )
  result <- sources_block_ui(chunks)
  expect_s3_class(result, "shiny.tag")
})

test_that("sources_block_ui: doc titles appear in output", {
  chunks <- tibble::tibble(
    doc_title        = c("Annual Report 2024"),
    doc_org          = c("NHS"),
    doc_date         = c("2024-01-01"),
    chunk_text       = c("chunk a"),
    doc_url          = c("http://a.com"),
    similarity_score = c(0.9)
  )
  result <- sources_block_ui(chunks)
  html   <- as.character(result)
  expect_match(html, "Annual Report 2024")
})

test_that("sources_block_ui: unique doc titles only (deduplicates)", {
  chunks <- tibble::tibble(
    doc_title        = c("Report A", "Report A", "Report B"),
    doc_org          = c("NHS", "NHS", "NHSE"),
    doc_date         = c("2024-01-01", "2024-01-01", "2024-06-01"),
    chunk_text       = c("a", "b", "c"),
    doc_url          = c("http://a.com", "http://a.com", "http://b.com"),
    similarity_score = c(0.9, 0.85, 0.8)
  )
  result <- sources_block_ui(chunks)
  html   <- as.character(result)
  # "Report A" should appear only once in distinct source entries
  matches <- gregexpr("Report A", html)
  expect_equal(length(regmatches(html, matches)[[1]]), 1L)
})

test_that("context_window_pill_ui: returns shiny tag", {
  result <- context_window_pill_ui("user", "What is the budget for this year?", active = TRUE)
  expect_s3_class(result, "shiny.tag")
})

test_that("context_window_pill_ui: active pill has active class", {
  result <- context_window_pill_ui("user", "Hello world", active = TRUE)
  html   <- as.character(result)
  expect_match(html, "pill-active")
})

test_that("context_window_pill_ui: inactive pill has inactive class", {
  result <- context_window_pill_ui("assistant", "Hello world", active = FALSE)
  html   <- as.character(result)
  expect_match(html, "pill-inactive")
})

test_that("context_window_pill_ui: user pill has user colour class", {
  result <- context_window_pill_ui("user", "Hello world foo bar baz", active = TRUE)
  html   <- as.character(result)
  expect_match(html, "pill-user")
})

test_that("context_window_pill_ui: assistant pill has assistant colour class", {
  result <- context_window_pill_ui("assistant", "Hello world foo bar", active = TRUE)
  html   <- as.character(result)
  expect_match(html, "pill-assistant")
})

test_that("context_window_pill_ui: truncated text appears in pill", {
  result <- context_window_pill_ui("user", "The quick brown fox jumped over", active = TRUE)
  html   <- as.character(result)
  expect_match(html, "The quick brown fox jumped")
})

test_that("context_window_panel_ui: returns shiny tag", {
  history <- list(
    list(role = "user",      content = "First question here"),
    list(role = "assistant", content = "First answer here too")
  )
  result <- context_window_panel_ui(history)
  expect_s3_class(result, "shiny.tag")
})

test_that("context_window_panel_ui: panel label present", {
  result <- context_window_panel_ui(list())
  html   <- as.character(result)
  expect_match(html, "Active context window")
})

test_that("context_window_panel_ui: all messages within window_size are active", {
  history <- list(
    list(role = "user",      content = "Q1 question here yes"),
    list(role = "assistant", content = "A1 answer here yes"),
    list(role = "user",      content = "Q2 question here yes")
  )
  result <- context_window_panel_ui(history, window_size = 6L)
  html   <- as.character(result)
  active_count   <- length(regmatches(html, gregexpr("pill-active",   html))[[1]])
  inactive_count <- length(regmatches(html, gregexpr("pill-inactive", html))[[1]])
  expect_equal(active_count,   3L)
  expect_equal(inactive_count, 0L)
})

test_that("context_window_panel_ui: messages outside window are inactive", {
  # 7 messages with window_size = 6 → first message is inactive
  history <- lapply(1:7, function(i) {
    list(role = if (i %% 2 == 1) "user" else "assistant",
         content = paste("message number", i, "with extra words"))
  })
  result <- context_window_panel_ui(history, window_size = 6L)
  html   <- as.character(result)
  active_count   <- length(gregexpr("pill-active",   html)[[1]])
  inactive_count <- length(gregexpr("pill-inactive", html)[[1]])
  expect_equal(active_count,   6L)
  expect_equal(inactive_count, 1L)
})

test_that("context_window_panel_ui: at most 3 inactive pills shown", {
  # 11 messages, window_size = 6 → 5 inactive, but only last 3 shown
  history <- lapply(1:11, function(i) {
    list(role = if (i %% 2 == 1) "user" else "assistant",
         content = paste("message number", i, "with extra words"))
  })
  result <- context_window_panel_ui(history, window_size = 6L)
  html   <- as.character(result)
  inactive_count <- length(gregexpr("pill-inactive", html)[[1]])
  expect_equal(inactive_count, 3L)
})

test_that("context_window_panel_ui: empty history renders without error", {
  expect_no_error(context_window_panel_ui(list()))
})
