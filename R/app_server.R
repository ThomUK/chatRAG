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
  embeddings_path <- app_sys("app/data/embeddings.rds")
  csv_path        <- app_sys("app/data/documents.csv")

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

    # Clear input and show spinner
    updateTextAreaInput(session, "chat_input", value = "")
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
      },
      error = function(e) {
        output$chat_thinking <- renderUI({
          tags$div(
            class = "alert alert-danger mt-2",
            paste0("Error: ", conditionMessage(e))
          )
        })
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
  observeEvent(input$build_kb, {
    pdf_dir  <- app_sys("app/data/pdfs")
    rds_path <- embeddings_path

    tryCatch(
      {
        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-muted small mt-2", "Parsing PDFs\u2026")
          )
        })

        pdf_files <- list.files(pdf_dir, pattern = "\\.pdf$",
                                ignore.case = TRUE, full.names = TRUE,
                                recursive = TRUE)

        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-muted small mt-2", "Creating embeddings\u2026")
          )
        })

        kb <- build_knowledge_base(pdf_files, csv_path)

        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-muted small mt-2", "Updating knowledge base\u2026")
          )
        })

        save_knowledge_base(kb, rds_path)

        output$build_progress <- renderUI(NULL)
        knowledge_base(kb)
        kb_ready(TRUE)
      },
      error = function(e) {
        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(
              class = "text-danger small mt-2",
              paste0("Build failed: ", conditionMessage(e))
            )
          )
        })
      }
    )
  })
}
