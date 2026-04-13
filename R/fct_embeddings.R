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


# Sentence splitting -----------------------------------------------------------

#' Split text into sentences, correctly handling common abbreviations
#'
#' Uses an abbreviation-masking strategy so that titles (Dr., Mr., Mrs., etc.),
#' acronyms (U.S.A., N.A.T.O.), and Latin abbreviations (e.g., i.e., etc.) do
#' not create spurious sentence boundaries.
#'
#' @param text A single character string.
#' @return A character vector of sentences.
#' @noRd
.split_sentences <- function(text) {
  ph <- "\x01"  # SOH: non-printable placeholder, unlikely in real text

  # 1. Protect single uppercase letters followed by a period (initials, acronyms)
  #    Matches each letter-period pair inside acronyms like U.S.A., N.A.T.O.
  #    The period must NOT be followed by a non-period, non-alpha character at
  #    end of acronym — so we protect all single-uppercase + period occurrences.
  text <- gsub("\\b([A-Z])\\.", paste0("\\1", ph), text, perl = TRUE)

  # 2. Protect common English title abbreviations (case-sensitive list)
  titles <- c("Mr", "Mrs", "Ms", "Dr", "Prof", "Sr", "Jr", "Rev",
               "Lt", "Sgt", "Capt", "Maj", "Col", "Gen", "Cdr",
               "Pres", "Gov", "Sen", "Rep", "Dept", "Corp", "Inc", "Ltd",
               "Ave", "Blvd", "St", "Rd", "Mt")
  for (ab in titles) {
    text <- gsub(paste0("\\b", ab, "\\."), paste0(ab, ph), text, perl = TRUE)
  }

  # 3. Protect common lowercase abbreviations (e.g., i.e., etc., viz., cf.)
  lower_abbrevs <- c("e\\.g", "i\\.e", "c\\.f", "viz", "etc", "approx",
                     "est", "vol", "no", "pp", "fig", "cf")
  for (ab in lower_abbrevs) {
    text <- gsub(paste0("\\b", ab, "\\."), paste0(sub("\\\\.", ".", ab), ph),
                 text, perl = TRUE)
  }

  # 4. Split on sentence-ending punctuation followed by whitespace + uppercase
  #    (requiring uppercase after the break avoids spurious splits on decimal
  #    numbers and other non-boundary periods)
  sentences <- strsplit(text, "(?<=[.!?])\\s+(?=[A-Z\"])", perl = TRUE)[[1L]]

  # 5. Restore placeholders
  gsub(ph, ".", sentences, fixed = TRUE)
}


# Public API -------------------------------------------------------------------

#' Split text into sentence-aware overlapping chunks
#'
#' Accumulates complete sentences until the target character length is reached
#' (soft cap — a single sentence longer than `chunk_size` is kept whole).
#' The last sentence of each chunk is carried into the next chunk as overlap.
#'
#' @param text       A single character string.
#' @param chunk_size Target maximum number of characters per chunk (soft cap).
#'
#' @return A character vector of chunks, or `character(0)` for empty/NULL input.
#' @noRd
chunk_text_sentence <- function(text, chunk_size = 1500) {
  if (is.null(text) || length(text) == 0L || nchar(text) == 0L) {
    return(character(0))
  }

  sentences <- .split_sentences(text)
  sentences <- sentences[nchar(trimws(sentences)) > 0L]

  if (length(sentences) == 0L) return(character(0))
  if (length(sentences) == 1L) return(text)

  chunks <- character(0)
  n      <- length(sentences)
  i      <- 1L

  while (i <= n) {
    j           <- i
    current_len <- nchar(sentences[j])

    # Greedily add more sentences while under chunk_size.
    # Always add at least two sentences when possible (j > i guard ensures we
    # never break before adding the second sentence, giving guaranteed progress).
    while (j < n) {
      next_len <- nchar(sentences[j + 1L])
      if (current_len + 1L + next_len > chunk_size && j > i) break
      j           <- j + 1L
      current_len <- current_len + 1L + nchar(sentences[j])
    }

    chunks <- c(chunks, paste(sentences[i:j], collapse = " "))

    if (j >= n) break
    # Overlap: next chunk starts at the last sentence of the current chunk
    i <- j
  }

  chunks
}


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
#' @return A single character string with pages separated by
#'   `\n\n--- PAGE BREAK ---\n\n`, preserving page boundaries so that
#'   chunks do not cross topic boundaries at page turns.
#' @noRd
parse_pdf <- function(pdf_path) {
  pages <- .call_pdf_text(pdf_path)
  paste(pages, collapse = "\n\n--- PAGE BREAK ---\n\n")
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
#' @param strategy           Chunking strategy: `"sentence"` (default) or
#'   `"char"`.
#' @param chunk_size         Target chunk size in characters.  Defaults to
#'   `1500` for sentence strategy, `500` for character strategy.
#' @param overlap            Overlap in characters (only used when `strategy =
#'   "char"`).
#'
#' @return A tibble (knowledge base) with columns: chunk_text, embedding,
#'   doc_title, doc_org, doc_date, doc_url.
#' @noRd
build_knowledge_base <- function(pdf_paths,
                                 documents_csv_path,
                                 strategy   = "sentence",
                                 chunk_size = if (strategy == "sentence") 1500L else 500L,
                                 overlap    = 50L) {
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

    text <- parse_pdf(pdf_path)
    chunks <- if (strategy == "sentence") {
      chunk_text_sentence(text, chunk_size = chunk_size)
    } else {
      chunk_text(text, chunk_size = chunk_size, overlap = overlap)
    }
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
#' @param strategy     Chunking strategy: `"sentence"` (default) or `"char"`.
#' @param chunk_size   Target chunk size in characters.
#' @param overlap      Overlap in characters (only used when `strategy =
#'   "char"`).
#'
#' @return An updated knowledge base tibble.
#' @noRd
append_to_knowledge_base <- function(existing_kb,
                                     pdf_path,
                                     doc_metadata,
                                     strategy   = "sentence",
                                     chunk_size = if (strategy == "sentence") 1500L else 500L,
                                     overlap    = 50L) {
  text <- parse_pdf(pdf_path)
  chunks <- if (strategy == "sentence") {
    chunk_text_sentence(text, chunk_size = chunk_size)
  } else {
    chunk_text(text, chunk_size = chunk_size, overlap = overlap)
  }
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


# ── Interim embedding cache ────────────────────────────────────────────────────

#' Derive the interim cache path for a single PDF
#'
#' @param cache_dir  Directory used for interim `.rds` files.
#' @param pdf_filename  Basename of the source PDF (e.g. `"report.pdf"`).
#'
#' @return Absolute path to the interim `.rds` file.
#' @noRd
interim_cache_path <- function(cache_dir, pdf_filename) {
  stem <- tools::file_path_sans_ext(basename(pdf_filename))
  file.path(cache_dir, paste0(stem, ".rds"))
}


#' Save one document's embedding result to the interim cache
#'
#' Creates `cache_dir` if it does not yet exist.
#'
#' @param result      Tibble returned by [embed_chunks()].
#' @param cache_dir   Directory for interim `.rds` files.
#' @param pdf_filename Basename of the source PDF.
#'
#' @return Invisibly returns the path written.
#' @noRd
save_interim_embedding <- function(result, cache_dir, pdf_filename) {
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  path <- interim_cache_path(cache_dir, pdf_filename)
  saveRDS(result, file = path)
  invisible(path)
}


#' Load a previously cached embedding result for one PDF
#'
#' @param cache_dir   Directory for interim `.rds` files.
#' @param pdf_filename Basename of the source PDF.
#'
#' @return The cached tibble, or `NULL` if no cache file exists.
#' @noRd
load_interim_embedding <- function(cache_dir, pdf_filename) {
  path <- interim_cache_path(cache_dir, pdf_filename)
  if (file.exists(path)) readRDS(path) else NULL
}


#' Delete all `.rds` files in the interim cache directory
#'
#' @param cache_dir Directory to clear.
#'
#' @return Invisibly returns the paths removed.
#' @noRd
clear_interim_cache <- function(cache_dir) {
  files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) > 0L) file.remove(files)
  invisible(files)
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
