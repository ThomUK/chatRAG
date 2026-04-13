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
      });
      // Trigger next document processing tick from server
      Shiny.addCustomMessageHandler('trigger_next_doc', function(msg) {
        setTimeout(function() {
          Shiny.setInputValue('process_next_doc', Math.random(), {priority: 'event'});
        }, msg.delay || 50);
      });
      // Force-close any open modal using the Bootstrap 5 API
      Shiny.addCustomMessageHandler('force_close_modal', function(msg) {
        document.querySelectorAll('.modal.show').forEach(function(el) {
          var m = bootstrap.Modal.getInstance(el);
          if (m) { m.hide(); } else { el.classList.remove('show'); }
        });
        document.querySelectorAll('.modal-backdrop').forEach(function(el) { el.remove(); });
        document.body.classList.remove('modal-open');
        document.body.style.removeProperty('overflow');
        document.body.style.removeProperty('padding-right');
      });
      // Update build-progress modal content in place (no close/reopen flicker)
      Shiny.addCustomMessageHandler('update_build_modal', function(msg) {
        var s = document.getElementById('build-modal-step');
        var c = document.getElementById('build-modal-count');
        var p = document.getElementById('build-modal-progress');
        if (s) s.textContent = msg.step;
        if (c) c.textContent = msg.count_line;
        if (p) p.style.width = msg.pct + '%';
      });
      // Focus chat input on load (once the Chat tab and textarea are rendered)
      $(document).on('shiny:idle', function handler() {
        var el = document.getElementById('chat_input');
        if (el) { el.focus(); $(document).off('shiny:idle', handler); }
      });
      // Submit chat on Enter (Shift+Enter inserts a newline)
      $(document).on('keydown', '#chat_input', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          document.getElementById('chat_submit').click();
        }
      });
      // Scroll so the last user query is at the top of the chat window.
      // setTimeout defers until after Shiny flushes the new bubbles to the DOM.
      // If the content isn't tall enough to reach that position, the browser
      // clamps scrollTop to the maximum, naturally landing at the bottom.
      Shiny.addCustomMessageHandler('scroll_to_last_query', function(msg) {
        setTimeout(function() {
          var bubbles = document.querySelectorAll('.chat-bubble-user');
          if (!bubbles.length) return;
          var last    = bubbles[bubbles.length - 1];
          var wrapper = document.getElementById('chat-messages-wrapper');
          if (!wrapper) { last.scrollIntoView({ behavior: 'smooth', block: 'start' }); return; }
          var targetTop = last.getBoundingClientRect().top
                        - wrapper.getBoundingClientRect().top
                        + wrapper.scrollTop;
          wrapper.scrollTo({ top: targetTop, behavior: 'smooth' });
        }, 100);
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
          prerequisite_row("nomic-embed-text model", checks$nomic_model),
          prerequisite_row("PDFs present", checks$pdfs),
          prerequisite_row("documents.csv valid", checks$documents_csv),
          if (!isTRUE(checks$documents_csv$ok)) {
            actionButton(
              inputId = "open_csv_excel",
              label   = "Open documents.csv in Excel",
              class   = "btn btn-sm btn-outline-secondary mb-3"
            )
          }
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


#' Build the knowledge base build progress modal
#'
#' @param n        Total number of documents to embed.
#' @param current  Number of documents embedded so far (0 = not yet started).
#' @param saving   If TRUE show "Saving..." state instead of embedding state.
#' @param filename Filename of the document currently being embedded (optional).
#' @param debug    If TRUE show a Cancel button to dismiss the modal (for debugging).
#'
#' @noRd
build_kb_modal_ui <- function(n, current, saving = FALSE, filename = NULL, debug = TRUE) {
  pct <- if (n > 0L) round(current / n * 100L) else 0L

  # current  = number of documents fully embedded so far
  # active   = document number currently being processed (current + 1)
  active <- current + 1L

  step <- if (saving) {
    "Saving knowledge base\u2026"
  } else if (current == 0L && is.null(filename)) {
    "Preparing\u2026"
  } else {
    paste0("Embedding document ", active, " of ", n, "\u2026")
  }

  count_line <- if (saving) {
    "Almost done\u2026"
  } else if (!is.null(filename) && nchar(filename) > 0L) {
    paste0(current, " of ", n, " embedded \u2014 processing: ", filename)
  } else {
    paste0(
      current, " of ", n, " document", if (n == 1L) "" else "s", " embedded"
    )
  }

  modalDialog(
    title     = "Building Knowledge Base",
    size      = "m",
    easyClose = FALSE,
    footer    = if (debug) {
      tags$button(
        type            = "button",
        class           = "btn btn-sm btn-outline-secondary",
        `data-dismiss`  = "modal",
        `data-bs-dismiss` = "modal",
        onclick         = "Shiny.setInputValue('cancel_build', Math.random(), {priority: 'event'})",
        "Cancel (Debug)"
      )
    } else {
      NULL
    },

    tags$div(
      class = "text-center py-3",

      tags$div(
        class = "spinner-border text-primary mb-4",
        style = "width: 3rem; height: 3rem;",
        role  = "status"
      ),

      tags$p(id = "build-modal-step", class = "fw-semibold mb-1", step),

      tags$p(id = "build-modal-count", class = "text-muted small mb-3", count_line),

      tags$div(
        class = "progress mx-auto",
        style = "max-width: 320px;",
        tags$div(
          id    = "build-modal-progress",
          class = "progress-bar bg-primary",
          style = paste0("width: ", pct, "%"),
          role  = "progressbar"
        )
      ),

      tags$p(
        class = "text-muted small mt-3 mb-0",
        "Please do not close the app."
      )
    )
  )
}


#' Build the main tabbed UI
#'
#' @noRd
main_tabbed_ui <- function() {
  bslib::navset_tab(
    id       = "main_tabs",
    selected = "Chat",
    bslib::nav_panel(
      "Source Material",
      source_material_tab_ui()
    ),
    bslib::nav_panel(
      title = uiOutput("chat_tab_label", inline = TRUE),
      value = "Chat",
      chat_tab_ui()
    ),
    bslib::nav_panel(
      "Connect Your Own",
      connect_your_own_tab_ui()
    ),
    bslib::nav_panel(
      "Config",
      config_tab_ui()
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


#' Build the Chat tab content
#'
#' Two-column layout: chat conversation on the left, context window panel
#' on the right.
#'
#' @noRd
chat_tab_ui <- function() {
  fluidRow(
    # ── Left column: chat interface ───────────────────────────────────────────
    column(
      width = 8,
      tags$div(
        class = "chat-container mt-4",

        # Conversation output area
        tags$div(
          id    = "chat-messages-wrapper",
          class = "chat-messages-wrapper mb-3",
          uiOutput("chat_messages")
        ),

        # "Thinking..." spinner (hidden by default)
        uiOutput("chat_thinking"),

        # Input row
        tags$div(
          class = "d-flex gap-2 mt-2",
          textAreaInput(
            inputId     = "chat_input",
            label       = NULL,
            placeholder = "Ask a question about the loaded documents\u2026",
            rows        = 2,
            width       = "100%"
          ),
          tags$div(
            class = "d-flex flex-column justify-content-end",
            actionButton(
              inputId = "chat_submit",
              label   = "Send",
              class   = "btn btn-primary"
            )
          )
        )
      )
    ),

    # ── Right column: context window panel ───────────────────────────────────
    column(
      width = 4,
      tags$div(
        class = "context-panel-wrapper mt-4",
        uiOutput("context_window_panel")
      )
    )
  )
}


#' Build the Edit Metadata modal dialog
#'
#' Pre-fills a form with existing metadata for the selected document so the
#' user can correct title, organisation, date, or URL.
#'
#' @param title        Current document title.
#' @param organisation Current organisation.
#' @param date         Current date string (YYYY-MM-DD).
#' @param url          Current public URL.
#' @param filename     PDF filename (used as the hidden row key).
#'
#' @noRd
edit_metadata_modal_ui <- function(title, organisation, date, url, filename) {
  modalDialog(
    title     = "Edit Document Metadata",
    size      = "m",
    easyClose = FALSE,

    tags$input(type = "hidden", id = "edit_filename", value = filename),
    textInput(
      inputId = "edit_title",
      label   = "Title",
      value   = title
    ),
    textInput(
      inputId = "edit_org",
      label   = "Organisation",
      value   = organisation
    ),
    textInput(
      inputId = "edit_date",
      label   = "Date (YYYY-MM-DD)",
      value   = date
    ),
    textInput(
      inputId = "edit_url",
      label   = "Public URL",
      value   = url
    ),

    uiOutput("edit_progress"),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(
        inputId = "submit_edit",
        label   = "Save Changes",
        class   = "btn btn-primary"
      )
    )
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


#' Render the combinations radio group with disabled radios for not-built rows
#'
#' Returns a Shiny radio-group tag compatible with Shiny's input binding
#' (id = `"config_selected_slug"`). Radio inputs for not-built combinations
#' carry the `disabled` attribute; the active slug is pre-selected.
#'
#' @param all_combs   Output of `all_embedding_combinations()` — all 8 rows.
#' @param built_combs Subset of `all_combs` that have `.rds` files on disk.
#' @param active_slug Currently active slug string (e.g. `"sentence_1500"`),
#'   or `NULL`.
#'
#' @return A `shiny.tag` suitable for use in `renderUI`.
#' @noRd
config_combinations_table_ui <- function(all_combs, built_combs, active_slug) {
  all_slugs   <- embedding_slug(all_combs$strategy, all_combs$size)
  built_slugs <- if (nrow(built_combs) > 0L) {
    embedding_slug(built_combs$strategy, built_combs$size)
  } else {
    character(0)
  }

  # Determine which slug should be pre-selected
  selected <- if (!is.null(active_slug) && active_slug %in% all_slugs) {
    active_slug
  } else if (length(built_slugs) > 0L) {
    built_slugs[1L]
  } else {
    character(0)
  }

  option_items <- lapply(seq_along(all_slugs), function(i) {
    sl        <- all_slugs[i]
    is_built  <- sl %in% built_slugs
    is_active <- identical(sl, active_slug)

    label_text <- paste0(
      all_combs$strategy[i], " / ", all_combs$size[i], " chars",
      if (is_built) " \u2713" else " \u2013 not built",
      if (is_active) " [active]" else ""
    )

    input_tag <- if (is_built) {
      if (identical(sl, selected)) {
        tags$input(type = "radio", name = "config_selected_slug",
                   value = sl, checked = "checked")
      } else {
        tags$input(type = "radio", name = "config_selected_slug", value = sl)
      }
    } else {
      tags$input(type = "radio", name = "config_selected_slug",
                 value = sl, disabled = "disabled")
    }

    tags$div(
      class = "radio",
      tags$label(input_tag, tags$span(label_text))
    )
  })

  tags$div(
    id    = "config_selected_slug",
    class = "form-group shiny-input-radiogroup",
    tags$div(
      class = "shiny-options-group",
      tagList(option_items)
    ),
    tags$p(
      class = "text-muted small mt-1",
      "Only built combinations can be activated. \u2713 = built on disk."
    )
  )
}


#' Build the Config tab content
#'
#' Shows a table of all 8 strategy × size combinations with build status and
#' radio-button selection, plus a build section and an Activate button.
#'
#' @noRd
config_tab_ui <- function() {
  tagList(
    tags$div(
      class = "mt-4",

      tags$h5("Embedding Configuration", class = "fw-semibold mb-1"),
      tags$p(
        class = "text-muted small mb-4",
        "Build and activate different embedding strategies.",
        "The active knowledge base is used for all chat queries.",
        "Switch configurations live to compare retrieval quality."
      ),

      # ── Combination status table ───────────────────────────────────────────
      tags$h6("Available Combinations", class = "fw-semibold mb-2"),
      uiOutput("config_combinations_table"),

      tags$div(
        class = "mt-3 mb-4",
        actionButton(
          inputId = "config_activate",
          label   = "Activate Selected",
          class   = "btn btn-primary btn-sm"
        )
      ),

      tags$hr(),

      # ── Build section ──────────────────────────────────────────────────────
      tags$h6("Build a New Combination", class = "fw-semibold mb-2"),
      tags$div(
        class = "d-flex gap-2 align-items-end mb-3",
        tags$div(
          selectInput(
            inputId  = "config_build_strategy",
            label    = "Strategy",
            choices  = c("sentence", "char"),
            selected = "sentence",
            width    = "150px"
          )
        ),
        tags$div(
          selectInput(
            inputId  = "config_build_size",
            label    = "Chunk Size",
            choices  = c("500", "1000", "1500", "2000"),
            selected = "1500",
            width    = "130px"
          )
        ),
        tags$div(
          class = "mb-3",
          actionButton(
            inputId = "config_build",
            label   = "Build",
            class   = "btn btn-outline-primary btn-sm"
          )
        )
      ),

      uiOutput("config_build_status")
    )
  )
}
