#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {

  # ── Chat state (shared with Connect Your Own tab) ────────────────────────────
  active_provider <- reactiveVal("claude")
  active_api_key  <- reactiveVal(get_api_key("anthropic"))

  # Full conversation history — list of {role, content} maps
  chat_history <- reactiveVal(list())

  # ── Reactive state ───────────────────────────────────────────────────────────
  data_dir        <- app_sys("app/data")
  embeddings_path <- file.path(data_dir, "embeddings.rds")
  csv_path        <- file.path(data_dir, "documents.csv")

  kb_ready <- reactiveVal(embeddings_file_exists(embeddings_path))

  # In-memory knowledge base — loaded once, updated on upload
  knowledge_base <- reactiveVal(
    if (embeddings_file_exists(embeddings_path)) load_knowledge_base(embeddings_path) else NULL
  )

  # Documents list — drives the source table reactively
  documents_rv <- reactiveVal(load_documents_csv(csv_path))

  # Prerequisite check results (refreshed every 3 s while on welcome screen)
  checks <- reactiveVal(NULL)

  check_timer <- reactiveTimer(3000)

  observe({
    check_timer()
    if (!kb_ready()) {
      checks(run_prerequisite_checks())
    }
  })

  # Run once immediately on startup
  observe({
    if (!kb_ready()) {
      checks(run_prerequisite_checks())
    }
  })

  # Open documents.csv in Excel (Windows shell default handler)
  observeEvent(input$open_csv_excel, {
    shell.exec(normalizePath(csv_path))
  })

  # ── Main content ─────────────────────────────────────────────────────────────
  output$main_content <- renderUI({
    if (kb_ready()) {
      main_tabbed_ui()
    } else {
      welcome_screen_ui(checks())
    }
  })

  # ── Source Material tab ───────────────────────────────────────────────────────
  output$source_table <- DT::renderDT({
    docs       <- documents_rv()
    table_data <- prepare_source_table(docs)

    DT::datatable(
      table_data,
      escape    = FALSE,
      rownames  = FALSE,
      selection = "none",
      options   = list(
        pageLength = 25,
        dom        = "tp",
        order      = list(list(0, "asc"))
      )
    )
  })

  # ── Upload Modal ─────────────────────────────────────────────────────────────

  # Open the modal when the button is clicked
  observeEvent(input$open_upload_modal, {
    showModal(upload_modal_ui())
  })

  # Handle form submission
  observeEvent(input$submit_upload, {

    validation <- validate_upload_inputs(
      file  = input$upload_pdf,
      title = input$upload_title,
      org   = input$upload_org,
      date  = input$upload_date,
      url   = input$upload_url
    )

    if (!validation$ok) {
      output$upload_progress <- renderUI({
        tags$div(
          class = "alert alert-danger mt-2 mb-0",
          validation$message
        )
      })
      return()
    }

    pdf_path <- input$upload_pdf$datapath
    filename <- input$upload_pdf$name

    # Step 1 — Parsing
    output$upload_progress <- renderUI({
      tags$div(
        class = "mt-3",
        tags$div(
          class = "progress mb-2",
          tags$div(
            class = "progress-bar progress-bar-striped progress-bar-animated",
            style = "width: 33%",
            role  = "progressbar"
          )
        ),
        tags$p(class = "text-muted small mb-0", "Parsing PDF\u2026")
      )
    })

    tryCatch(
      {
        doc_metadata <- list(
          doc_title = trimws(input$upload_title),
          doc_org   = trimws(input$upload_org),
          doc_date  = trimws(input$upload_date),
          doc_url   = trimws(input$upload_url)
        )

        # Step 2 — Embedding
        output$upload_progress <- renderUI({
          tags$div(
            class = "mt-3",
            tags$div(
              class = "progress mb-2",
              tags$div(
                class = "progress-bar progress-bar-striped progress-bar-animated",
                style = "width: 66%",
                role  = "progressbar"
              )
            ),
            tags$p(class = "text-muted small mb-0", "Creating embeddings\u2026")
          )
        })

        existing_kb <- knowledge_base()
        updated_kb  <- append_to_knowledge_base(existing_kb, pdf_path, doc_metadata)
        n_new_chunks <- nrow(updated_kb) - nrow(existing_kb)

        # Step 3 — Updating knowledge base
        output$upload_progress <- renderUI({
          tags$div(
            class = "mt-3",
            tags$div(
              class = "progress mb-2",
              tags$div(
                class = "progress-bar progress-bar-striped progress-bar-animated",
                style = "width: 90%",
                role  = "progressbar"
              )
            ),
            tags$p(class = "text-muted small mb-0", "Updating knowledge base\u2026")
          )
        })

        save_knowledge_base(updated_kb, embeddings_path)

        # Append metadata to documents.csv
        new_doc_row <- list(
          title        = trimws(input$upload_title),
          organisation = trimws(input$upload_org),
          date         = trimws(input$upload_date),
          url          = trimws(input$upload_url),
          filename     = filename
        )
        append_document_to_csv(csv_path, new_doc_row)

        # Update reactives
        knowledge_base(updated_kb)
        documents_rv(load_documents_csv(csv_path))

        # Pulse the Source Material tab
        session$sendCustomMessage("pulse_source_tab", list())

        # Show success and close modal after brief delay
        output$upload_progress <- renderUI({
          tags$div(
            class = "alert alert-success mt-3 mb-0",
            paste0(
              "Knowledge base updated \u2014 ",
              n_new_chunks, " chunk",
              if (n_new_chunks == 1L) "" else "s",
              " added."
            )
          )
        })

        # Auto-close after 1.5 seconds
        shinyjs::delay(1500, removeModal())
      },
      error = function(e) {
        output$upload_progress <- renderUI({
          tags$div(
            class = "alert alert-danger mt-2 mb-0",
            paste0("Upload failed: ", conditionMessage(e))
          )
        })
      }
    )
  })

  # ── Chat Tab ─────────────────────────────────────────────────────────────────

  # Render the conversation bubbles
  output$chat_messages <- renderUI({
    history <- chat_history()
    if (length(history) == 0L) {
      return(tags$p(
        class = "text-muted mt-3",
        "No conversation yet. Ask a question below."
      ))
    }

    # Render each message as a bubble; assistant messages also get sources
    # (sources are stored as an attribute on the assistant message)
    bubble_list <- lapply(history, function(msg) {
      bubble <- chat_bubble_ui(msg$role, msg$content)
      if (!is.null(msg$context_chunks)) {
        tagList(bubble, sources_block_ui(msg$context_chunks))
      } else {
        bubble
      }
    })
    tagList(bubble_list)
  })

  # Render the context window panel
  output$context_window_panel <- renderUI({
    context_window_panel_ui(chat_history(), window_size = 6L)
  })

  # "Thinking…" placeholder (shown while RAG call is in flight)
  output$chat_thinking <- renderUI(NULL)

  # Handle chat submission
  observeEvent(input$chat_submit, {
    query <- trimws(input$chat_input)
    if (nchar(query) == 0L) return()

    kb <- knowledge_base()
    if (is.null(kb) || nrow(kb) == 0L) {
      output$chat_thinking <- renderUI({
        tags$div(
          class = "alert alert-warning mt-2",
          "No knowledge base loaded. Please build or upload documents first."
        )
      })
      return()
    }

    # Append user message to history immediately so UI updates
    current_history <- chat_history()
    user_msg        <- format_chat_message("user", query)
    chat_history(c(current_history, list(user_msg)))

    # Clear input, disable controls, and show spinner
    updateTextAreaInput(session, "chat_input", value = "")
    shinyjs::disable("chat_input")
    shinyjs::disable("chat_submit")
    output$chat_thinking <- renderUI({
      tags$div(
        class = "d-flex align-items-center gap-2 text-muted mt-2",
        tags$span(
          class = "spinner-border spinner-border-sm",
          role  = "status"
        ),
        tags$span("Thinking\u2026")
      )
    })

    tryCatch(
      {
        # RAG pipeline
        query_emb      <- embed_query(query)
        context_chunks <- retrieve_chunks(query_emb, kb, top_n = 5L)
        payload        <- build_messages(current_history, context_chunks, query)

        # Call LLM
        reply <- call_llm(payload,
                          provider = active_provider(),
                          api_key  = active_api_key())

        # Attach context_chunks to assistant message so sources_block_ui can use them
        asst_msg <- format_chat_message("assistant", reply)
        asst_msg$context_chunks <- context_chunks

        chat_history(c(chat_history(), list(asst_msg)))
        output$chat_thinking <- renderUI(NULL)
        shinyjs::enable("chat_input")
        shinyjs::enable("chat_submit")
        session$sendCustomMessage("scroll_to_last_query", list())
        shinyjs::runjs("document.getElementById('chat_input').focus();")
      },
      error = function(e) {
        output$chat_thinking <- renderUI({
          parts <- strsplit(friendly_error(e), "\n", fixed = TRUE)[[1L]]
          tags$div(
            class = "alert alert-danger mt-2",
            tags$strong(paste0("Error: ", parts[[1L]])),
            if (length(parts) > 1L) tagList(tags$br(), parts[[2L]])
          )
        })
        shinyjs::enable("chat_input")
        shinyjs::enable("chat_submit")
      }
    )
  })

  # ── Connect Your Own Tab ─────────────────────────────────────────────────────

  # Show/hide Azure-specific fields when provider changes
  observe({
    req(input$connect_provider)
    if (input$connect_provider == "azure") {
      shinyjs::show("connect_azure_fields")
    } else {
      shinyjs::hide("connect_azure_fields")
    }
  })

  # Test Connection button handler
  observeEvent(input$connect_test, {
    provider <- input$connect_provider
    api_key  <- trimws(if (is.null(input$connect_api_key)) "" else input$connect_api_key)

    if (nchar(api_key) == 0L) {
      output$connect_status <- renderUI({
        tags$div(
          class = "alert alert-warning mt-3 mb-0",
          "Please enter an API key before testing."
        )
      })
      return()
    }

    # Show spinner while testing
    output$connect_status <- renderUI({
      tags$div(
        class = "d-flex align-items-center gap-2 text-muted mt-3",
        tags$span(
          class = "spinner-border spinner-border-sm",
          role  = "status"
        ),
        tags$span("Testing connection\u2026")
      )
    })

    # Build extra args for Azure
    extra_args <- if (provider == "azure") {
      list(
        endpoint   = trimws(if (is.null(input$connect_azure_endpoint))   "" else input$connect_azure_endpoint),
        deployment = trimws(if (is.null(input$connect_azure_deployment)) "" else input$connect_azure_deployment)
      )
    } else {
      list()
    }

    result <- do.call(test_connection, c(
      list(provider = provider, api_key = api_key),
      extra_args
    ))

    output$connect_status <- renderUI({
      connection_status_ui(result, provider)
    })

    # On success: update active credentials and reset chat history
    if (isTRUE(result$success)) {
      active_provider(provider)
      active_api_key(api_key)
      chat_history(list())

      # Show confirmation banner after the status update
      output$connect_status <- renderUI({
        tagList(
          connection_status_ui(result, provider),
          tags$div(
            class = "alert alert-info mt-2 mb-0",
            "Now using your API key \u2014 conversation reset."
          )
        )
      })
    }
  })

  # ── Build Knowledge Base ─────────────────────────────────────────────────────

  cache_dir <- file.path(data_dir, "embeddings_cache")

  # State carried across per-document observer ticks
  build_state_rv <- reactiveVal(NULL)

  # Cancel button (debug): clear state and close modal
  observeEvent(input$cancel_build, {
    message("[BUILD] Cancelled by user (debug cancel button)")
    build_state_rv(NULL)
    removeModal()
  })

  # Kick off the build: load any cached results, queue only uncached PDFs
  observeEvent(input$build_kb, {
    pdf_dir   <- app_sys("app/data/pdfs")
    pdf_files <- list.files(pdf_dir, pattern = "\\.pdf$",
                            ignore.case = TRUE, full.names = TRUE,
                            recursive = TRUE)
    n_total <- length(pdf_files)

    message("[BUILD] Build triggered. PDFs found: ", n_total)
    message("[BUILD] PDF directory: ", pdf_dir)
    if (n_total > 0L) {
      message("[BUILD] Files: ", paste(basename(pdf_files), collapse = ", "))
    }

    tryCatch(
      {
        docs_meta <- readr::read_csv(csv_path, show_col_types = FALSE)
        message("[BUILD] documents.csv loaded: ", nrow(docs_meta), " rows")

        # Load any previously cached interim results
        cached_results  <- list()
        uncached_files  <- character(0)

        for (pdf_path in pdf_files) {
          cached <- load_interim_embedding(cache_dir, basename(pdf_path))
          if (!is.null(cached)) {
            cached_results <- c(cached_results, list(cached))
            message("[BUILD]   Cache hit: ", basename(pdf_path),
                    " (", nrow(cached), " chunks)")
          } else {
            uncached_files <- c(uncached_files, pdf_path)
          }
        }

        n_cached    <- length(cached_results)
        n_remaining <- length(uncached_files)
        message("[BUILD] Cached: ", n_cached, " / ", n_total,
                "  —  remaining: ", n_remaining)

        showModal(build_kb_modal_ui(
          n       = n_total,
          current = n_cached,
          filename = if (n_remaining > 0L) basename(uncached_files[[1L]]) else NULL
        ))
        message("[BUILD] Modal shown. Scheduling first document tick...")

        if (n_remaining == 0L) {
          # Everything is cached — go straight to saving
          message("[BUILD] All documents already cached. Saving knowledge base...")
          showModal(build_kb_modal_ui(n = n_total, current = n_total, saving = TRUE))
          kb <- dplyr::bind_rows(cached_results)
          save_knowledge_base(kb, embeddings_path)
          clear_interim_cache(cache_dir)
          message("[BUILD] Knowledge base saved. Cache cleared.")
          removeModal()
          knowledge_base(kb)
          kb_ready(TRUE)
          message("[BUILD] Build complete. kb_ready = TRUE")
          return()
        }

        build_state_rv(list(
          pdf_files   = uncached_files,
          docs_meta   = docs_meta,
          results     = cached_results,
          idx         = 1L,
          n_remaining = n_remaining,
          n_total     = n_total
        ))

        session$sendCustomMessage("trigger_next_doc", list(delay = 100L))
        message("[BUILD] trigger_next_doc message sent to browser")
      },
      error = function(e) {
        message("[BUILD ERROR] Build initiation failed: ", conditionMessage(e))
        session$sendCustomMessage("force_close_modal", list())
        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-danger small mt-2",
                   paste0("Build failed: ", conditionMessage(e)))
          )
        })
      }
    )
  })

  # Process one document per tick so the modal updates between each
  observeEvent(input$process_next_doc, {
    state <- build_state_rv()
    if (is.null(state)) {
      message("[BUILD] process_next_doc fired but build_state_rv is NULL — ignoring")
      return()
    }

    i           <- state$idx
    n_remaining <- state$n_remaining
    n_total     <- state$n_total
    n_done      <- length(state$results)   # cached + embedded this session
    pdf_path    <- state$pdf_files[[i]]
    filename    <- basename(pdf_path)

    message("[BUILD] Processing document ", i, " / ", n_remaining,
            " remaining (", n_done, " / ", n_total, " total): ", filename)

    tryCatch(
      {
        meta_row <- state$docs_meta[state$docs_meta$filename == filename, ]

        if (nrow(meta_row) == 0L) {
          stop("No matching row in documents.csv for file: ", filename)
        }

        doc_metadata <- list(
          doc_title = meta_row$title,
          doc_org   = meta_row$organisation,
          doc_date  = as.character(meta_row$date),
          doc_url   = meta_row$url
        )

        message("[BUILD]   Parsing PDF...")
        text   <- parse_pdf(pdf_path)
        message("[BUILD]   PDF parsed. Characters: ", nchar(text))

        chunks <- chunk_text(text)
        message("[BUILD]   Chunks created: ", length(chunks))

        message("[BUILD]   Embedding chunks via Ollama...")
        result <- embed_chunks(chunks, doc_metadata)
        message("[BUILD]   Embedding complete. Rows: ", nrow(result))

        # Persist immediately so progress survives a crash/restart
        save_interim_embedding(result, cache_dir, filename)
        message("[BUILD]   Interim cache saved: ", filename)

        new_results <- c(state$results, list(result))
        n_completed <- n_done + 1L

        if (i < n_remaining) {
          next_file <- basename(state$pdf_files[[i + 1L]])
          build_state_rv(modifyList(state, list(results = new_results, idx = i + 1L)))
          message("[BUILD]   Scheduling next document (", i + 1L,
                  " / ", n_remaining, "): ", next_file)
          # Update modal AFTER embedding completes so it flushes to browser
          # before the next blocking operation starts
          session$sendCustomMessage("update_build_modal", list(
            step       = paste0("Embedding document ", n_completed + 1L,
                                " of ", n_total, "\u2026"),
            count_line = paste0(n_completed, " of ", n_total,
                                " embedded \u2014 processing: ", next_file),
            pct        = round(n_completed / n_total * 100L)
          ))
          session$sendCustomMessage("trigger_next_doc", list(delay = 50L))
        } else {
          message("[BUILD] All ", n_total, " documents embedded. Saving knowledge base...")
          session$sendCustomMessage("update_build_modal", list(
            step       = "Saving knowledge base\u2026",
            count_line = "Almost done\u2026",
            pct        = 100L
          ))

          kb <- dplyr::bind_rows(new_results)
          save_knowledge_base(kb, embeddings_path)
          message("[BUILD] Knowledge base saved to: ", embeddings_path)

          clear_interim_cache(cache_dir)
          message("[BUILD] Interim cache cleared.")

          removeModal()
          build_state_rv(NULL)
          knowledge_base(kb)
          kb_ready(TRUE)
          message("[BUILD] Build complete. kb_ready = TRUE")
        }
      },
      error = function(e) {
        message("[BUILD ERROR] Failed on document ", i, " (", filename, "): ",
                conditionMessage(e))
        session$sendCustomMessage("force_close_modal", list())
        build_state_rv(NULL)
        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-danger small mt-2",
                   paste0("Build failed on '", filename, "': ", conditionMessage(e)))
          )
        })
      }
    )
  })
}
