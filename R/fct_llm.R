# fct_llm.R
# LLM integration layer: prompt construction, multi-provider dispatch,
# rolling conversation window, and connection testing.

# Internal API wrappers (mockable in tests) ------------------------------------

#' @noRd
.call_claude_api <- function(messages, system, api_key,
                             model = "claude-opus-4-6", max_tokens = 1024L) {
  body <- list(
    model      = model,
    system     = system,
    messages   = messages,
    max_tokens = max_tokens
  )

  resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      "x-api-key"         = api_key,
      "anthropic-version" = "2023-06-01",
      "content-type"      = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_error(body = function(resp) {
      parsed <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
      if (!is.null(parsed$error$message)) parsed$error$message else NULL
    }) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp)
  parsed$content[[1L]]$text
}


#' @noRd
.call_openai_api <- function(messages, api_key,
                             model = "gpt-4o") {
  body <- list(
    model    = model,
    messages = messages
  )

  resp <- httr2::request("https://api.openai.com/v1/chat/completions") |>
    httr2::req_headers(
      "Authorization" = paste("Bearer", api_key),
      "content-type"  = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp)
  parsed$choices[[1L]]$message$content
}


#' @noRd
.call_azure_api <- function(messages, api_key, endpoint, deployment,
                            api_version = "2024-02-01") {
  url  <- paste0(
    endpoint,
    "/openai/deployments/", deployment,
    "/chat/completions?api-version=", api_version
  )
  body <- list(messages = messages)

  resp <- httr2::request(url) |>
    httr2::req_headers(
      "api-key"      = api_key,
      "content-type" = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp)
  parsed$choices[[1L]]$message$content
}


# Helpers ----------------------------------------------------------------------

#' Strip ANSI escape sequences and produce a user-friendly error message
#'
#' httr2 includes terminal colour codes in its error messages.  This helper
#' removes them and, for common HTTP errors, appends a plain-English hint.
#'
#' @param e A condition object.
#' @return A clean character string suitable for display in the Shiny UI.
#' @noRd
friendly_error <- function(e) {
  # httr2 HTTP errors: reconstruct from raw parts to avoid cli truncation.
  # e$message is cli-formatted (respects terminal width and may be cut short).
  # e$body holds the API error text as a named character vector.
  # e$resp holds the raw response for status code/description.
  if (inherits(e, "httr2_http")) {
    status_line <- tryCatch(
      paste0("HTTP ", httr2::resp_status(e$resp), " ",
             httr2::resp_status_desc(e$resp), "."),
      error = function(err) "HTTP error."
    )
    body_text <- if (!is.null(e$body) && length(e$body) > 0L) {
      trimws(paste(unname(e$body), collapse = " "))
    } else {
      ""
    }
    msg <- if (nchar(body_text) > 0L) {
      paste0(status_line, "\n", body_text)
    } else {
      status_line
    }
  } else {
    msg <- gsub("\033\\[[0-9;]*m", "", conditionMessage(e))
  }

  hint <- if (grepl("401", msg, fixed = TRUE)) {
    "Check that your API key is correct and has not expired."
  } else if (grepl("429", msg, fixed = TRUE)) {
    "Rate limit reached. Please wait a moment and try again."
  } else if (grepl("500|502|503", msg)) {
    "The API is temporarily unavailable. Try again shortly."
  } else {
    ""
  }

  if (nchar(hint) > 0L) paste0(msg, "\n", hint) else msg
}


# Public API -------------------------------------------------------------------

#' Build the RAG system prompt
#'
#' Returns a fixed system prompt instructing the model to cite sources inline
#' by document name, disclose when falling back to general knowledge, and
#' maintain a professional boardroom tone.
#'
#' @return A single character string.
#' @noRd
build_system_prompt <- function() {
  paste(
    "You are an expert research assistant supporting senior leadership.",
    "When answering questions, always cite your sources inline by document name",
    "(e.g. '[Report Title]') so the reader can trace each claim.",
    "If the retrieved context does not fully address the question, explicitly",
    "disclose that you are drawing on general knowledge beyond the provided documents.",
    "Maintain a professional, boardroom-ready tone throughout: concise, precise,",
    "and free of jargon where possible."
  )
}


#' Build an API-ready messages payload
#'
#' Constructs the messages list sent to an LLM, combining the system prompt,
#' a rolling window of the last 6 turns of conversation history
#' (3 user + 3 assistant messages), injected context chunks, and the current
#' user query.
#'
#' @param chat_history  A list of `{role, content}` message pairs representing
#'   prior conversation turns.
#' @param context_chunks A tibble from [retrieve_chunks()] with columns
#'   `chunk_text`, `doc_title`, `doc_org`, `doc_date`, and `doc_url`.
#' @param user_query A single character string — the current user question.
#'
#' @return A named list with elements:
#'   \describe{
#'     \item{`system`}{The system prompt string.}
#'     \item{`messages`}{A list of `{role, content}` pairs ready for the API.}
#'   }
#' @noRd
build_messages <- function(chat_history, context_chunks, user_query) {
  # Rolling window: keep last 6 messages (3 user + 3 assistant turns)
  window_size <- 6L
  n_history   <- length(chat_history)
  if (n_history > window_size) {
    chat_history <- chat_history[(n_history - window_size + 1L):n_history]
  }

  # Strip to role + content only — UI fields like context_chunks must not reach the API
  chat_history <- lapply(chat_history, function(msg) {
    list(role = msg$role, content = msg$content)
  })

  # Build context block from retrieved chunks
  context_lines <- vapply(seq_len(nrow(context_chunks)), function(i) {
    row <- context_chunks[i, ]
    paste0(
      "[", row$doc_title, " (", row$doc_org, ", ", row$doc_date, ")]\n",
      row$chunk_text
    )
  }, character(1L))

  context_block <- paste(
    "Retrieved context:",
    paste(context_lines, collapse = "\n\n"),
    sep = "\n"
  )

  # Final user message: context + query
  user_message <- list(
    role    = "user",
    content = paste0(context_block, "\n\nUser question: ", user_query)
  )

  list(
    system   = build_system_prompt(),
    messages = c(chat_history, list(user_message))
  )
}


#' Call an LLM via the specified provider
#'
#' Dispatches to the appropriate API wrapper based on `provider`.
#'
#' For Claude: requires `api_key`.
#' For OpenAI: requires `api_key`.
#' For Azure OpenAI: requires `api_key`, `endpoint`, and `deployment`.
#'
#' @param messages  The payload produced by [build_messages()].
#' @param provider  One of `"claude"`, `"openai"`, or `"azure"`.
#' @param api_key   API key for the chosen provider.
#' @param ...       Additional arguments passed to the provider wrapper
#'   (e.g. `endpoint` and `deployment` for Azure; `model` for Claude/OpenAI).
#'
#' @return A single character string containing the model's reply.
#' @noRd
call_llm <- function(messages, provider, api_key, ...) {
  # ── STREAMING INSERTION POINT ──────────────────────────────────────────────
  # To add streaming support, replace the blocking req_perform() calls in
  # .call_claude_api, .call_openai_api, and .call_azure_api with
  # httr2::req_perform_stream(), passing a callback that appends each chunk
  # to a reactive value (e.g., shiny::reactiveVal or a Shiny session object).
  # The `...` passthrough here allows a `stream_callback` argument to flow
  # through to the internal wrappers without changing this dispatch layer.
  # ──────────────────────────────────────────────────────────────────────────

  switch(
    provider,
    claude = .call_claude_api(
      messages = messages$messages,
      system   = messages$system,
      api_key  = api_key,
      ...
    ),
    openai = .call_openai_api(
      messages = c(
        list(list(role = "system", content = messages$system)),
        messages$messages
      ),
      api_key = api_key,
      ...
    ),
    azure  = .call_azure_api(
      messages = c(
        list(list(role = "system", content = messages$system)),
        messages$messages
      ),
      api_key = api_key,
      ...
    ),
    stop("Unknown provider: '", provider, "'. Must be one of: claude, openai, azure.")
  )
}


#' Test LLM API connectivity
#'
#' Sends a minimal prompt to the specified provider and returns a list
#' indicating whether the connection succeeded.
#'
#' @param provider One of `"claude"`, `"openai"`, or `"azure"`.
#' @param api_key  API key for the chosen provider.
#' @param ...      Additional provider-specific arguments (see [call_llm()]).
#'
#' @return A named list:
#'   \describe{
#'     \item{`success`}{Logical. `TRUE` if the call succeeded.}
#'     \item{`message`}{Character. Present only on failure; contains the error text.}
#'   }
#' @noRd
test_connection <- function(provider, api_key, ...) {
  ping_payload <- build_messages(
    chat_history  = list(),
    context_chunks = tibble::tibble(
      chunk_text       = "Connection test.",
      doc_title        = "Test",
      doc_org          = "Test",
      doc_date         = as.character(Sys.Date()),
      doc_url          = "http://localhost",
      similarity_score = 1
    ),
    user_query = "Please reply with a single word: OK"
  )

  tryCatch(
    {
      call_llm(ping_payload, provider = provider, api_key = api_key, ...)
      list(success = TRUE)
    },
    error = function(e) {
      list(success = FALSE, message = friendly_error(e))
    }
  )
}
