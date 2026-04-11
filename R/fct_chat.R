# fct_chat.R
# Chat tab business logic: message formatting, bubble/pill UI helpers,
# and the context window panel renderer.

# ── Pure helpers ───────────────────────────────────────────────────────────────

#' Truncate text to first n words followed by an ellipsis
#'
#' @param text    A single character string.
#' @param n_words Maximum number of words to retain.  If `text` contains
#'   `n_words` or fewer words it is returned unchanged.
#'
#' @return A single character string.
#' @noRd
truncate_for_pill <- function(text, n_words = 5L) {
  words <- strsplit(text, "\\s+")[[1L]]
  if (length(words) <= n_words) {
    text
  } else {
    paste0(paste(words[seq_len(n_words)], collapse = " "), "\u2026")
  }
}


#' Create a chat message list
#'
#' @param role    One of `"user"` or `"assistant"`.
#' @param content A single character string.
#'
#' @return A named list with elements `role` and `content`.
#' @noRd
format_chat_message <- function(role, content) {
  list(role = role, content = content)
}


# ── UI helpers ─────────────────────────────────────────────────────────────────

#' Render a single chat message bubble
#'
#' @param role    One of `"user"` or `"assistant"`.
#' @param content Message text (character string).
#'
#' @return A `shiny.tag`.
#' @noRd
chat_bubble_ui <- function(role, content) {
  bubble_class   <- if (role == "user") "chat-bubble-user" else "chat-bubble-assistant"
  label          <- if (role == "user") "You" else "Assistant"
  wrapper_class  <- if (role == "user") "d-flex justify-content-end mb-3" else "d-flex justify-content-start mb-3"

  tags$div(
    class = wrapper_class,
    tags$div(
      class = paste("chat-bubble", bubble_class),
      tags$div(class = "chat-bubble-label small fw-semibold mb-1", label),
      tags$div(class = "chat-bubble-content", content)
    )
  )
}


#' Render the sources block shown beneath an assistant message
#'
#' Deduplicates by `doc_title` and renders one entry per unique source.
#'
#' @param context_chunks A tibble from [retrieve_chunks()] with columns
#'   `doc_title`, `doc_org`, `doc_date`, and `doc_url`.
#'
#' @return A `shiny.tag`.
#' @noRd
sources_block_ui <- function(context_chunks) {
  unique_sources <- context_chunks[!duplicated(context_chunks$doc_title), ]

  source_items <- lapply(seq_len(nrow(unique_sources)), function(i) {
    row <- unique_sources[i, ]
    tags$li(
      tags$a(
        href   = row$doc_url,
        target = "_blank",
        rel    = "noopener noreferrer",
        row$doc_title
      ),
      tags$span(
        class = "text-muted small ms-1",
        paste0("(", row$doc_org, ", ", row$doc_date, ")")
      )
    )
  })

  tags$div(
    class = "sources-block mt-2 p-2 border-start border-2 border-secondary",
    tags$p(class = "sources-label small fw-semibold mb-1 text-muted", "Sources"),
    tags$ul(class = "mb-0 ps-3 small", source_items)
  )
}


#' Render a single context window pill
#'
#' @param role       One of `"user"` or `"assistant"`.
#' @param content    The message text (will be truncated).
#' @param active     Logical.  `TRUE` for messages within the rolling window.
#' @param fade_rank  Integer 1-3 (or `NULL`).  When set on an inactive pill,
#'   adds a `pill-fade-{n}` CSS class where 1 = most recently dropped (least
#'   faded) and 3 = oldest visible dropped message (most faded).
#'
#' @return A `shiny.tag`.
#' @noRd
context_window_pill_ui <- function(role, content, active = TRUE, fade_rank = NULL) {
  role_class   <- if (role == "user") "pill-user" else "pill-assistant"
  state_class  <- if (active) "pill-active" else "pill-inactive"
  preview_text <- truncate_for_pill(content, n_words = 5L)
  role_label   <- if (role == "user") "You" else "Asst"

  fade_class <- if (!is.null(fade_rank)) paste0("pill-fade-", fade_rank) else ""

  tags$div(
    class = trimws(paste("context-pill", role_class, state_class, fade_class,
                         "d-flex align-items-center gap-1 mb-1 px-2 py-1 rounded")),
    tags$span(class = "pill-role-label small fw-semibold", role_label),
    tags$span(class = "pill-preview small text-truncate", preview_text)
  )
}


#' Render the active context window panel
#'
#' Shows all messages as pills.  Messages within the rolling `window_size`
#' are marked active; older messages are marked inactive.  At most the 3 most
#' recently dropped (inactive) messages are shown; messages older than that are
#' hidden entirely.
#'
#' @param all_messages  A list of `{role, content}` pairs representing the full
#'   conversation history (oldest first).
#' @param window_size   Number of most-recent messages to treat as active
#'   (default 6).
#'
#' @return A `shiny.tag`.
#' @noRd
context_window_panel_ui <- function(all_messages, window_size = 6L) {
  n_total    <- length(all_messages)
  n_active   <- min(n_total, window_size)
  n_inactive <- n_total - n_active

  # Only keep the last 3 inactive messages
  max_inactive_shown <- 3L
  n_inactive_shown   <- min(n_inactive, max_inactive_shown)

  # Indices of messages to display
  # inactive: from (n_total - n_active - n_inactive_shown + 1) to (n_total - n_active)
  # active:   from (n_total - n_active + 1) to n_total
  if (n_total == 0L) {
    pills <- list(
      tags$p(class = "text-muted small mt-2", "No messages yet.")
    )
  } else {
    inactive_start <- max(1L, n_total - n_active - n_inactive_shown + 1L)
    inactive_end   <- n_total - n_active
    active_start   <- n_total - n_active + 1L

    inactive_indices <- if (inactive_end >= inactive_start) {
      seq(inactive_start, inactive_end)
    } else {
      integer(0)
    }
    active_indices <- seq(active_start, n_total)

    # Assign fade ranks: the most recently dropped gets rank 1 (least faded),
    # the oldest shown dropped message gets the highest rank (most faded).
    n_inactive_rendered <- length(inactive_indices)
    inactive_pills <- lapply(seq_along(inactive_indices), function(j) {
      i         <- inactive_indices[[j]]
      msg       <- all_messages[[i]]
      # rank 1 = most recent (last in inactive_indices), n = oldest
      fade_rank <- n_inactive_rendered - j + 1L
      context_window_pill_ui(msg$role, msg$content, active = FALSE, fade_rank = fade_rank)
    })

    active_pills <- lapply(active_indices, function(i) {
      msg <- all_messages[[i]]
      context_window_pill_ui(msg$role, msg$content, active = TRUE)
    })

    pills <- c(inactive_pills, active_pills)
  }

  tags$div(
    class = "context-window-panel p-3",
    tags$h6(class = "fw-semibold mb-2 text-muted", "Active context window"),
    tags$div(
      class = "context-pills-container",
      pills
    )
  )
}
