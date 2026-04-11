#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {

  # ── Reactive state ───────────────────────────────────────────────────────────
  embeddings_path <- app_sys("app/data/embeddings.rds")

  kb_ready <- reactiveVal(embeddings_file_exists(embeddings_path))

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
    csv_path  <- app_sys("app/data/documents.csv")
    documents <- load_documents_csv(csv_path)
    table_data <- prepare_source_table(documents)

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

  # ── Build Knowledge Base ─────────────────────────────────────────────────────
  observeEvent(input$build_kb, {
    pdf_dir   <- app_sys("app/data/pdfs")
    csv_path  <- app_sys("app/data/documents.csv")
    rds_path  <- embeddings_path

    tryCatch(
      {
        output$build_progress <- renderUI({
          tagList(
            tags$hr(),
            tags$p(class = "text-muted small mt-2", "Parsing PDFs\u2026")
          )
        })

        pdf_files <- list.files(pdf_dir, pattern = "\\.pdf$",
                                ignore.case = TRUE, full.names = TRUE)

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
