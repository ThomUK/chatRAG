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
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
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


#' Build a placeholder main tabbed UI (populated by later slices)
#'
#' @noRd
main_tabbed_ui <- function() {
  bslib::navset_tab(
    id = "main_tabs",
    bslib::nav_panel(
      "Source Material",
      tags$p(class = "text-muted mt-4", "Source Material tab — coming soon.")
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
