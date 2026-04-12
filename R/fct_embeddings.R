# External-package wrappers (mockable in tests) --------------------------------

#' @noRd
.call_pdf_text <- function(pdf_path) {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop(
      "Package 'pdftools' is required to parse PDFs. ",
      "Install it with: install.packages('pdftools')",
      call. = FALSE
    )
  }
  pdftools::pdf_text(pdf_path)
}

#' @noRd
.call_ollama_embed_one <- function(chunk) {
  response <- ollamar::embed("nomic-embed-text", chunk)

  # Extract a single embedding vector regardless of ollamar version/return shape
  emb <- if (is.data.frame(response) && !is.null(response$embeddings)) {
    response$embeddings[[1L]]
  } else if (is.matrix(response)) {
    response[1L, ]
  } else if (is.list(response) && !is.null(response$embeddings)) {
    response$embeddings[[1L]]
  } else if (is.numeric(response)) {
    response
  } else {
    stop(
      "Unexpected response from ollamar::embed(). ",
      "Got class: ", paste(class(response), collapse = ", "),
      call. = FALSE
    )
  }

  as.numeric(emb)
}

#' @noRd
.call_ollama_embed <- function(chunks) {
  lapply(chunks, .call_ollama_embed_one)
}

#' @noRd
.call_ollama_ping <- function() {
  resp <- httr2::request("http://localhost:11434") |>
    httr2::req_perform()
  httr2::resp_status(resp)
}


# Public API -------------------------------------------------------------------

#' Split text into overlapping character chunks
#'
#' @param text      A single character string.
#' @param chunk_size Maximum number of characters per chunk.
#' @param overlap   Number of characters to repeat at the start of each
#'   successive chunk.
#'
#' @return A character vector of chunks, or `character(0)` for empty/NULL input.
#' @noRd
chunk_text <- function(text, chunk_size = 500, overlap = 50) {
  if (is.null(text) || length(text) == 0 || nchar(text) == 0) {
    return(character(0))
  }

  text_length <- nchar(text)
  if (text_length <= chunk_size) {
    return(text)
  }

  step   <- chunk_size - overlap
  starts <- seq(1, text_length, by = step)

  chunks <- character(length(starts))
  for (i in seq_along(starts)) {
    end        <- min(starts[i] + chunk_size - 1L, text_length)
    chunks[i]  <- substr(text, starts[i], end)
  }
  chunks
}


#' Extract plain text from a PDF
#'
#' @param pdf_path Path to the PDF file.
#'
#' @return A single character string containing all page text concatenated.
#' @noRd
parse_pdf <- function(pdf_path) {
  pages <- .call_pdf_text(pdf_path)
  paste(pages, collapse = " ")
}


#' Embed text chunks using Ollama nomic-embed-text
#'
#' @param chunks       Character vector of text chunks.
#' @param doc_metadata Named list with fields `doc_title`, `doc_org`,
#'   `doc_date`, and `doc_url`.
#'
#' @return A tibble with columns: chunk_text, embedding, doc_title, doc_org,
#'   doc_date, doc_url.
#' @noRd
embed_chunks <- function(chunks, doc_metadata) {
  embeddings <- .call_ollama_embed(chunks)

  tibble::tibble(
    chunk_text = chunks,
    embedding  = embeddings,
    doc_title  = doc_metadata$doc_title,
    doc_org    = doc_metadata$doc_org,
    doc_date   = doc_metadata$doc_date,
    doc_url    = doc_metadata$doc_url
  )
}


#' Build a knowledge base from a set of PDFs and a metadata CSV
#'
#' Reads the documents CSV, then for each PDF path parses the PDF, chunks the
#' text, and embeds the chunks.  The filename column in the CSV is used to join
#' PDF paths to document metadata.
#'
#' @param pdf_paths          Character vector of paths to PDF files.
#' @param documents_csv_path Path to the documents metadata CSV.
#' @param chunk_size         Passed to [chunk_text()].
#' @param overlap            Passed to [chunk_text()].
#'
#' @return A tibble (knowledge base) with columns: chunk_text, embedding,
#'   doc_title, doc_org, doc_date, doc_url.
#' @noRd
build_knowledge_base <- function(pdf_paths,
                                 documents_csv_path,
                                 chunk_size = 500,
                                 overlap    = 50) {
  docs <- readr::read_csv(documents_csv_path, show_col_types = FALSE)

  results <- lapply(pdf_paths, function(pdf_path) {
    filename <- basename(pdf_path)
    meta_row <- docs[docs$filename == filename, ]

    doc_metadata <- list(
      doc_title = meta_row$title,
      doc_org   = meta_row$organisation,
      doc_date  = as.character(meta_row$date),
      doc_url   = meta_row$url
    )

    text   <- parse_pdf(pdf_path)
    chunks <- chunk_text(text, chunk_size = chunk_size, overlap = overlap)
    embed_chunks(chunks, doc_metadata)
  })

  dplyr::bind_rows(results)
}


#' Append a single document to an existing knowledge base
#'
#' @param existing_kb  An existing knowledge base tibble (from
#'   [build_knowledge_base()] or [load_knowledge_base()]).
#' @param pdf_path     Path to the new PDF file.
#' @param doc_metadata Named list with fields `doc_title`, `doc_org`,
#'   `doc_date`, and `doc_url`.
#' @param chunk_size   Passed to [chunk_text()].
#' @param overlap      Passed to [chunk_text()].
#'
#' @return An updated knowledge base tibble.
#' @noRd
append_to_knowledge_base <- function(existing_kb,
                                     pdf_path,
                                     doc_metadata,
                                     chunk_size = 500,
                                     overlap    = 50) {
  text   <- parse_pdf(pdf_path)
  chunks <- chunk_text(text, chunk_size = chunk_size, overlap = overlap)
  new_rows <- embed_chunks(chunks, doc_metadata)
  dplyr::bind_rows(existing_kb, new_rows)
}


#' Save a knowledge base to an RDS file
#'
#' @param kb   Knowledge base tibble.
#' @param path File path for the `.rds` file.
#'
#' @return Invisibly returns `path`.
#' @noRd
save_knowledge_base <- function(kb, path) {
  saveRDS(kb, file = path)
  invisible(path)
}


#' Load a knowledge base from an RDS file
#'
#' @param path Path to the `.rds` file.
#'
#' @return The knowledge base tibble.
#' @noRd
load_knowledge_base <- function(path) {
  readRDS(path)
}


#' Check whether the local Ollama server is running
#'
#' @return `TRUE` if Ollama responds on port 11434, `FALSE` otherwise.
#' @noRd
check_ollama_running <- function() {
  tryCatch(
    {
      status <- .call_ollama_ping()
      status >= 200L && status < 300L
    },
    error = function(e) FALSE
  )
}
