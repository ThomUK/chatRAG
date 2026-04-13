# Tests for fct_llm.R
# Using red-green-refactor TDD approach.
# Pure functions (build_system_prompt, build_messages) are tested directly.
# call_llm and test_connection are tested with mocked internal API wrappers.

# ── build_system_prompt ────────────────────────────────────────────────────────

test_that("build_system_prompt returns a single character string", {
  result <- build_system_prompt()
  expect_type(result, "character")
  expect_length(result, 1L)
})

test_that("build_system_prompt mentions citing sources by document name", {
  result <- build_system_prompt()
  expect_true(grepl("cit", result, ignore.case = TRUE))
})

test_that("build_system_prompt instructs disclosure when using general knowledge", {
  result <- build_system_prompt()
  expect_true(
    grepl("general knowledge", result, ignore.case = TRUE) |
    grepl("not.*document|outside.*source|beyond.*context", result, ignore.case = TRUE)
  )
})

test_that("build_system_prompt references professional or boardroom tone", {
  result <- build_system_prompt()
  expect_true(
    grepl("professional|boardroom|formal", result, ignore.case = TRUE)
  )
})

test_that("build_system_prompt instructs model to say so when context is irrelevant", {
  result <- build_system_prompt()
  expect_true(
    grepl("does not contain|not.*relevant|say so|no.*information|cannot answer",
          result, ignore.case = TRUE)
  )
})

# ── build_messages ─────────────────────────────────────────────────────────────

make_history <- function(n_turns) {
  # n_turns: number of complete user+assistant exchanges
  msgs <- vector("list", n_turns * 2L)
  for (i in seq_len(n_turns)) {
    msgs[[2L * i - 1L]] <- list(role = "user",      content = paste0("user turn ",      i))
    msgs[[2L * i]]      <- list(role = "assistant",  content = paste0("assistant turn ", i))
  }
  msgs
}

make_chunks <- function(n = 2) {
  tibble::tibble(
    chunk_text = paste0("chunk ", seq_len(n)),
    doc_title  = paste0("Doc ",   seq_len(n)),
    doc_org    = "Org",
    doc_date   = "2024-01-01",
    doc_url    = paste0("http://example.com/", seq_len(n)),
    similarity_score = seq(0.9, by = -0.1, length.out = n)
  )
}

test_that("build_messages returns a list", {
  result <- build_messages(list(), make_chunks(), "What is the policy?")
  expect_type(result, "list")
})

test_that("build_messages result contains a 'system' element", {
  result <- build_messages(list(), make_chunks(), "Hello")
  expect_true("system" %in% names(result))
})

test_that("build_messages result contains a 'messages' element", {
  result <- build_messages(list(), make_chunks(), "Hello")
  expect_true("messages" %in% names(result))
})

test_that("build_messages system element is a character string", {
  result <- build_messages(list(), make_chunks(), "Hello")
  expect_type(result$system, "character")
  expect_length(result$system, 1L)
})

test_that("build_messages messages is a list", {
  result <- build_messages(list(), make_chunks(), "Hello")
  expect_type(result$messages, "list")
})

test_that("build_messages with empty history has one message (user query)", {
  result <- build_messages(list(), make_chunks(), "Hello")
  expect_length(result$messages, 1L)
  expect_equal(result$messages[[1L]]$role, "user")
})

test_that("build_messages user message contains the context chunks", {
  chunks <- make_chunks(2)
  result <- build_messages(list(), chunks, "My question")
  user_content <- result$messages[[length(result$messages)]]$content
  expect_true(grepl("chunk 1", user_content, fixed = TRUE))
  expect_true(grepl("chunk 2", user_content, fixed = TRUE))
})

test_that("build_messages user message contains the user query", {
  result <- build_messages(list(), make_chunks(), "What is the capital of France?")
  user_content <- result$messages[[length(result$messages)]]$content
  expect_true(grepl("What is the capital of France?", user_content, fixed = TRUE))
})

test_that("build_messages includes all history when within 6-turn window", {
  history <- make_history(3)  # 3 pairs = 6 messages
  result  <- build_messages(history, make_chunks(), "Hello")
  # 6 history + 1 current user = 7
  expect_equal(length(result$messages), 7L)
})

test_that("build_messages trims history to last 6 turns when history exceeds window", {
  history <- make_history(5)  # 5 pairs = 10 messages; should be trimmed to 6
  result  <- build_messages(history, make_chunks(), "Hello")
  # 6 history + 1 current user = 7
  expect_equal(length(result$messages), 7L)
})

test_that("build_messages keeps the most recent turns when trimming", {
  history <- make_history(5)  # turns 1-5; after trim should have turns 3-5
  result  <- build_messages(history, make_chunks(), "Hello")
  # First history message should be user turn 3 (oldest retained)
  expect_equal(result$messages[[1L]]$content, "user turn 3")
})

test_that("build_messages roles alternate user/assistant correctly in history", {
  history <- make_history(2)
  result  <- build_messages(history, make_chunks(), "Hello")
  expect_equal(result$messages[[1L]]$role, "user")
  expect_equal(result$messages[[2L]]$role, "assistant")
  expect_equal(result$messages[[3L]]$role, "user")
  expect_equal(result$messages[[4L]]$role, "assistant")
})

test_that("build_messages last message is always role 'user'", {
  history <- make_history(4)
  result  <- build_messages(history, make_chunks(), "Final question")
  last <- result$messages[[length(result$messages)]]
  expect_equal(last$role, "user")
})

test_that("build_messages user message includes relevance score prefix", {
  chunks <- make_chunks(1)
  result <- build_messages(list(), chunks, "test")
  user_content <- result$messages[[length(result$messages)]]$content
  expect_true(grepl("[Relevance:", user_content, fixed = TRUE))
})

test_that("build_messages relevance score is rounded to 2 decimal places", {
  chunks <- tibble::tibble(
    chunk_text       = "test chunk",
    doc_title        = "Doc",
    doc_org          = "Org",
    doc_date         = "2024-01-01",
    doc_url          = "http://example.com",
    similarity_score = 0.87654
  )
  result <- build_messages(list(), chunks, "test")
  user_content <- result$messages[[length(result$messages)]]$content
  expect_true(grepl("[Relevance: 0.88]", user_content, fixed = TRUE))
})

test_that("build_messages relevance score appears before doc metadata", {
  chunks <- make_chunks(1)
  result <- build_messages(list(), chunks, "test")
  user_content <- result$messages[[length(result$messages)]]$content
  rel_pos  <- regexpr("[Relevance:", user_content, fixed = TRUE)
  meta_pos <- regexpr("[Doc 1", user_content, fixed = TRUE)
  expect_true(rel_pos < meta_pos)
})

# ── call_llm ───────────────────────────────────────────────────────────────────

make_messages_payload <- function() {
  build_messages(list(), make_chunks(1), "Test question")
}

test_that("call_llm dispatches to claude wrapper for 'claude' provider", {
  called_with <- NULL
  local_mocked_bindings(
    .call_claude_api = function(messages, system, api_key, ...) {
      called_with <<- "claude"
      "mock response"
    }
  )
  call_llm(make_messages_payload(), provider = "claude", api_key = "key")
  expect_equal(called_with, "claude")
})

test_that("call_llm dispatches to openai wrapper for 'openai' provider", {
  called_with <- NULL
  local_mocked_bindings(
    .call_openai_api = function(messages, api_key, ...) {
      called_with <<- "openai"
      "mock response"
    }
  )
  call_llm(make_messages_payload(), provider = "openai", api_key = "key")
  expect_equal(called_with, "openai")
})

test_that("call_llm dispatches to azure wrapper for 'azure' provider", {
  called_with <- NULL
  local_mocked_bindings(
    .call_azure_api = function(messages, api_key, endpoint, deployment, ...) {
      called_with <<- "azure"
      "mock response"
    }
  )
  call_llm(
    make_messages_payload(),
    provider   = "azure",
    api_key    = "key",
    endpoint   = "https://my.openai.azure.com",
    deployment = "gpt-4"
  )
  expect_equal(called_with, "azure")
})

test_that("call_llm passes api_key to claude wrapper", {
  captured_key <- NULL
  local_mocked_bindings(
    .call_claude_api = function(messages, system, api_key, ...) {
      captured_key <<- api_key
      "mock"
    }
  )
  call_llm(make_messages_payload(), provider = "claude", api_key = "test-key-abc")
  expect_equal(captured_key, "test-key-abc")
})

test_that("call_llm passes api_key to openai wrapper", {
  captured_key <- NULL
  local_mocked_bindings(
    .call_openai_api = function(messages, api_key, ...) {
      captured_key <<- api_key
      "mock"
    }
  )
  call_llm(make_messages_payload(), provider = "openai", api_key = "openai-key-xyz")
  expect_equal(captured_key, "openai-key-xyz")
})

test_that("call_llm passes endpoint and deployment to azure wrapper", {
  captured_ep  <- NULL
  captured_dep <- NULL
  local_mocked_bindings(
    .call_azure_api = function(messages, api_key, endpoint, deployment, ...) {
      captured_ep  <<- endpoint
      captured_dep <<- deployment
      "mock"
    }
  )
  call_llm(
    make_messages_payload(),
    provider   = "azure",
    api_key    = "key",
    endpoint   = "https://myendpoint.openai.azure.com",
    deployment = "my-deployment"
  )
  expect_equal(captured_ep,  "https://myendpoint.openai.azure.com")
  expect_equal(captured_dep, "my-deployment")
})

test_that("call_llm returns a character string", {
  local_mocked_bindings(
    .call_claude_api = function(...) "The answer is 42."
  )
  result <- call_llm(make_messages_payload(), provider = "claude", api_key = "k")
  expect_type(result, "character")
  expect_length(result, 1L)
})

test_that("call_llm errors on unknown provider", {
  expect_error(
    call_llm(make_messages_payload(), provider = "unknown_provider", api_key = "k"),
    "provider"
  )
})

# ── test_connection ────────────────────────────────────────────────────────────

test_that("test_connection returns list(success = TRUE) on successful call", {
  local_mocked_bindings(
    .call_claude_api = function(...) "Hello!"
  )
  result <- test_connection(provider = "claude", api_key = "key")
  expect_type(result, "list")
  expect_true(result$success)
})

test_that("test_connection returns list(success = FALSE, message = ...) on error", {
  local_mocked_bindings(
    .call_claude_api = function(...) stop("Authentication failed")
  )
  result <- test_connection(provider = "claude", api_key = "bad-key")
  expect_type(result, "list")
  expect_false(result$success)
  expect_true("message" %in% names(result))
  expect_type(result$message, "character")
})

test_that("test_connection error message contains the underlying error text", {
  local_mocked_bindings(
    .call_openai_api = function(...) stop("Invalid API key")
  )
  result <- test_connection(provider = "openai", api_key = "bad")
  expect_true(grepl("Invalid API key", result$message, fixed = TRUE))
})

test_that("test_connection works for openai provider", {
  local_mocked_bindings(
    .call_openai_api = function(...) "Hi there!"
  )
  result <- test_connection(provider = "openai", api_key = "key")
  expect_true(result$success)
})

test_that("test_connection works for azure provider", {
  local_mocked_bindings(
    .call_azure_api = function(...) "Hi there!"
  )
  result <- test_connection(
    provider   = "azure",
    api_key    = "key",
    endpoint   = "https://ep.openai.azure.com",
    deployment = "gpt-4"
  )
  expect_true(result$success)
})
