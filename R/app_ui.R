#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # Your application UI logic
    bslib::page_fluid(
      shinyjs::useShinyjs(),
      tags$div(
        class = "mobile-warning",
        "\u26a0\ufe0f This app is best viewed on a larger screen (1024px or wider)."
      ),
      uiOutput("main_content")
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "chatRAG"
    ),
    tags$link(
      rel  = "preconnect",
      href = "https://fonts.googleapis.com"
    ),
    tags$link(
      rel         = "preconnect",
      href        = "https://fonts.gstatic.com",
      crossorigin = NA
    ),
    tags$link(
      rel  = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
    ),
    # Custom message handler: pulse the Source Material tab label
    tags$script(HTML(
      "Shiny.addCustomMessageHandler('pulse_source_tab', function(msg) {
        var tabs = document.querySelectorAll('#main_tabs .nav-link');
        for (var i = 0; i < tabs.length; i++) {
          if (tabs[i].textContent.trim() === 'Source Material') {
            tabs[i].classList.add('tab-pulse');
            setTimeout(function(el) { el.classList.remove('tab-pulse'); }, 2000, tabs[i]);
            break;
          }
        }
      });"
    ))
  )

}


# ── Welcome screen UI helpers ─────────────────────────────────────────────────

#' Render a single prerequisite check row
#'
#' @param label     Display name of the check.
#' @param check     A list with `ok` (logical) and `message` (character).
#'
#' @noRd
prerequisite_row <- function(label, check) {
  icon_el <- if (isTRUE(check$ok)) {
    tags$span(
      class = "text-success fw-semibold",
      "\u2713 ", label
    )
  } else {
    tags$span(
      class = "text-danger fw-semibold",
      "\u2717 ", label
    )
  }
  tagList(
    tags$div(
      class = "d-flex align-items-start gap-2 mb-2",
      icon_el,
    ),
    tags$div(
      class = if (isTRUE(check$ok)) "text-muted small mb-3" else "text-danger small mb-3",
      check$message
    )
  )
}


#' Build the welcome / setup screen UI
#'
#' @param checks   Output of `run_prerequisite_checks()`, or `NULL` while
#'   checks are still loading.
#'
#' @noRd
welcome_screen_ui <- function(checks = NULL) {
  all_pass <- !is.null(checks) && all_checks_pass(checks)

  bslib::card(
    class = "mx-auto mt-5",
    style = "max-width: 560px;",
    bslib::card_header(
      tags$h4(class = "mb-0", "chatRAG — Setup")
    ),
    bslib::card_body(
      tags$p(
        class = "text-muted mb-4",
        "No knowledge base found. Complete the steps below to build one before using the app."
      ),

      tags$h6("Prerequisites", class = "fw-bold mb-3"),

      if (is.null(checks)) {
        tags$p(class = "text-muted", "Checking prerequisites\u2026")
      } else {
        tagList(
          prerequisite_row("Ollama running", checks$ollama),
          prerequisite_row("PDFs present", checks$pdfs),
          prerequisite_row("documents.csv valid", checks$documents_csv)
        )
      },

      tags$hr(),

      actionButton(
        inputId  = "build_kb",
        label    = "Build Knowledge Base",
        class    = "btn btn-primary w-100",
        disabled = if (all_pass) NULL else NA
      ),

      uiOutput("build_progress")
    )
  )
}


#' Build the main tabbed UI
#'
#' @noRd
main_tabbed_ui <- function() {
  bslib::navset_tab(
    id = "main_tabs",
    bslib::nav_panel(
      "Source Material",
      source_material_tab_ui()
    ),
    bslib::nav_panel(
      "Chat",
      tags$p(class = "text-muted mt-4", "Chat tab — coming soon.")
    ),
    bslib::nav_panel(
      "Connect Your Own",
      tags$p(class = "text-muted mt-4", "Connect Your Own tab — coming soon.")
    )
  )
}


#' Build the Source Material tab content
#'
#' @noRd
source_material_tab_ui <- function() {
  tagList(
    tags$div(
      class = "d-flex justify-content-between align-items-center mt-4 mb-3",
      tags$p(
        class = "text-muted mb-0",
        style = "max-width: 700px;",
        "Every answer this assistant gives is grounded in real documents \u2014 the board papers and reports listed below.",
        "Nothing is invented or assumed. You can read the original source behind any answer by clicking the document link directly."
      ),
      actionButton(
        inputId = "open_upload_modal",
        label   = "Add to Knowledge Base",
        class   = "btn btn-outline-primary btn-sm"
      )
    ),
    DT::DTOutput("source_table")
  )
}


#' Build the Upload Modal dialog
#'
#' Returns a `modalDialog()` containing a PDF file input and metadata fields
#' for Title, Organisation, Date, and Public URL.
#'
#' @noRd
upload_modal_ui <- function() {
  modalDialog(
    title = "Add Document to Knowledge Base",
    size  = "m",
    easyClose = FALSE,

    # File upload + form fields
    fileInput(
      inputId  = "upload_pdf",
      label    = "PDF File",
      accept   = ".pdf",
      multiple = FALSE
    ),
    textInput(
      inputId     = "upload_title",
      label       = "Title",
      placeholder = "e.g. Annual Report 2024"
    ),
    textInput(
      inputId     = "upload_org",
      label       = "Organisation",
      placeholder = "e.g. NHS England"
    ),
    textInput(
      inputId     = "upload_date",
      label       = "Date (YYYY-MM-DD)",
      placeholder = "e.g. 2024-03-31"
    ),
    textInput(
      inputId     = "upload_url",
      label       = "Public URL",
      placeholder = "https://..."
    ),

    # Progress / status area
    uiOutput("upload_progress"),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(
        inputId = "submit_upload",
        label   = "Upload & Embed",
        class   = "btn btn-primary"
      )
    )
  )
}
