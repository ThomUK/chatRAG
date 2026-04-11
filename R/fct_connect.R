# fct_connect.R
# Business logic and static UI for the Connect Your Own tab.

# ── Helpers ────────────────────────────────────────────────────────────────────

#' Return the display label for a provider key
#'
#' @param provider One of `"claude"`, `"openai"`, or `"azure"`.
#' @return A single character string.
#' @noRd
provider_label <- function(provider) {
  switch(
    provider,
    claude = "Claude (Anthropic)",
    openai = "OpenAI",
    azure  = "Azure OpenAI",
    stop("Unknown provider: '", provider, "'. Must be one of: claude, openai, azure.")
  )
}


#' Build the connection status UI element
#'
#' @param result  Return value of [test_connection()]: a list with `success`
#'   (logical) and optionally `message` (character).
#' @param provider  One of `"claude"`, `"openai"`, or `"azure"`.
#'
#' @return A shiny tag.
#' @noRd
connection_status_ui <- function(result, provider) {
  if (isTRUE(result$success)) {
    tags$div(
      class = "alert alert-success mt-3 mb-0",
      paste0("Connected \u2014 ", provider_label(provider), " API responding")
    )
  } else {
    tags$div(
      class = "alert alert-danger mt-3 mb-0",
      paste0("Connection failed: ", result$message)
    )
  }
}


# ── Static UI ──────────────────────────────────────────────────────────────────

#' Build the Connect Your Own tab content
#'
#' Renders a card containing:
#' - Provider dropdown (Claude, OpenAI, Azure OpenAI)
#' - API key text input (password type)
#' - Conditionally shown Azure endpoint + deployment inputs
#' - Test Connection button
#' - Status output area
#' - Privacy / transparency paragraph
#'
#' @noRd
connect_your_own_tab_ui <- function() {
  tagList(
    tags$div(
      class = "row justify-content-center mt-4",
      tags$div(
        class = "col-12 col-md-8 col-lg-6",

        bslib::card(
          bslib::card_header(
            tags$h5(class = "mb-0", "Connect Your Own API Key")
          ),
          bslib::card_body(

            tags$p(
              class = "text-muted mb-4",
              "Use your organisation's existing LLM subscription to power this demo.",
              "Enter your credentials below and test the connection."
            ),

            # ── Provider selection ──────────────────────────────────────────
            selectInput(
              inputId  = "connect_provider",
              label    = "LLM Provider",
              choices  = c(
                "Claude (Anthropic)" = "claude",
                "OpenAI"             = "openai",
                "Azure OpenAI"       = "azure"
              ),
              selected = "claude",
              width    = "100%"
            ),

            # ── API key ─────────────────────────────────────────────────────
            tags$div(
              class = "mb-3",
              tags$label(
                class = "form-label",
                `for` = "connect_api_key",
                "API Key"
              ),
              tags$input(
                type        = "password",
                id          = "connect_api_key",
                class       = "form-control",
                placeholder = "Paste your API key here\u2026",
                autocomplete = "off"
              )
            ),

            # ── Azure-only fields (shown/hidden via shinyjs) ─────────────────
            tags$div(
              id = "connect_azure_fields",
              tags$div(
                class = "mb-3",
                tags$label(
                  class = "form-label",
                  `for` = "connect_azure_endpoint",
                  "Azure Endpoint URL"
                ),
                tags$input(
                  type        = "text",
                  id          = "connect_azure_endpoint",
                  class       = "form-control",
                  placeholder = "https://your-resource.openai.azure.com/"
                )
              ),
              tags$div(
                class = "mb-3",
                tags$label(
                  class = "form-label",
                  `for` = "connect_azure_deployment",
                  "Deployment Name"
                ),
                tags$input(
                  type        = "text",
                  id          = "connect_azure_deployment",
                  class       = "form-control",
                  placeholder = "e.g. gpt-4o"
                )
              )
            ),

            # ── Test Connection button ───────────────────────────────────────
            actionButton(
              inputId = "connect_test",
              label   = "Test Connection",
              class   = "btn btn-primary w-100 mb-3"
            ),

            # ── Status output ────────────────────────────────────────────────
            uiOutput("connect_status"),

            tags$hr(),

            # ── Privacy paragraph ────────────────────────────────────────────
            tags$h6("What is and isn\u2019t shared", class = "fw-bold mb-2"),
            tags$p(
              class = "text-muted small",
              tags$strong("Sent to the API:"),
              " your question and the retrieved document chunks that best match it.",
              " These are sent to the LLM provider to generate an answer."
            ),
            tags$p(
              class = "text-muted small mb-0",
              tags$strong("Stays local:"),
              " your PDFs, the vector embeddings, and the chat UI all run entirely",
              " on this machine and are never transmitted to any external service."
            )
          )
        )
      )
    )
  )
}
