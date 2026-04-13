#' Load the documents catalogue from CSV
#'
#' @param csv_path Path to documents.csv (default: inst/app/data/documents.csv).
#' @return A tibble with columns: title, organisation, date, url, filename.
#' @importFrom readr read_csv cols col_character
#' @noRd
load_documents_csv <- function(csv_path = app_sys("app/data/documents.csv")) {
  readr::read_csv(
    csv_path,
    col_types = readr::cols(
      title        = readr::col_character(),
      organisation = readr::col_character(),
      date         = readr::col_character(),
      url          = readr::col_character(),
      filename     = readr::col_character()
    ),
    show_col_types = FALSE
  )
}


#' Prepare documents data for display in the Source Material DT table
#'
#' Renames columns to display labels, builds an HTML anchor for the Source
#' column, an Edit button in the Actions column, and drops internal-only
#' columns (url, filename).
#'
#' @param documents A data frame as returned by `load_documents_csv()`.
#' @return A data frame with columns: Title, Organisation, Date, Source, Actions.
#' @noRd
prepare_source_table <- function(documents) {
  if (nrow(documents) == 0L) {
    return(data.frame(
      Title        = character(0),
      Organisation = character(0),
      Date         = character(0),
      Source       = character(0),
      Actions      = character(0),
      stringsAsFactors = FALSE
    ))
  }

  source_links <- sprintf(
    '<a href="%s" target="_blank" rel="noopener noreferrer">View source</a>',
    documents$url
  )

  edit_buttons <- sprintf(
    '<button class="btn btn-outline-secondary btn-sm me-1" onclick="Shiny.setInputValue(\'edit_row_idx\', %d, {priority: \'event\'})">Edit</button>',
    seq_len(nrow(documents))
  )

  remove_buttons <- sprintf(
    '<button class="btn btn-outline-danger btn-sm" onclick="Shiny.setInputValue(\'remove_row_idx\', %d, {priority: \'event\'})">&#x2715;</button>',
    seq_len(nrow(documents))
  )

  data.frame(
    Title        = documents$title,
    Organisation = documents$organisation,
    Date         = documents$date,
    Source       = source_links,
    Actions      = paste0(edit_buttons, remove_buttons),
    stringsAsFactors = FALSE
  )
}


#' Update a document row in documents.csv by filename
#'
#' @param csv_path        Path to documents.csv.
#' @param filename        Basename of the PDF file (used as the row key).
#' @param new_title       Replacement title string.
#' @param new_organisation Replacement organisation string.
#' @param new_date        Replacement date string (YYYY-MM-DD).
#' @param new_url         Replacement public URL string.
#'
#' @return Invisibly returns `csv_path`.
#' @importFrom readr read_csv write_csv cols col_character
#' @noRd
update_document_in_csv <- function(csv_path, filename,
                                   new_title, new_organisation,
                                   new_date, new_url) {
  docs <- readr::read_csv(
    csv_path,
    col_types = readr::cols(
      title        = readr::col_character(),
      organisation = readr::col_character(),
      date         = readr::col_character(),
      url          = readr::col_character(),
      filename     = readr::col_character()
    ),
    show_col_types = FALSE
  )

  idx <- which(docs$filename == filename)
  if (length(idx) == 0L) {
    stop("Document not found in documents.csv: ", filename)
  }

  docs$title[idx]        <- new_title
  docs$organisation[idx] <- new_organisation
  docs$date[idx]         <- new_date
  docs$url[idx]          <- new_url

  readr::write_csv(docs, csv_path)
  invisible(csv_path)
}


#' Update chunk metadata in a knowledge base for a specific document
#'
#' Finds all chunks matching the old metadata fields and replaces them with
#' the new values.  Chunks for other documents are left unchanged.
#'
#' @param kb        A tibble / data frame (the knowledge base) with columns
#'   `doc_title`, `doc_org`, `doc_date`, `doc_url`.
#' @param old_title,old_org,old_date,old_url  Original metadata to match on.
#' @param new_title,new_org,new_date,new_url  Replacement metadata.
#'
#' @return The updated knowledge base (same structure as `kb`).
#' @noRd
update_kb_metadata <- function(kb,
                               old_title, old_org, old_date, old_url,
                               new_title, new_org, new_date, new_url) {
  matching <- kb$doc_title == old_title &
              kb$doc_org   == old_org   &
              kb$doc_date  == old_date  &
              kb$doc_url   == old_url

  kb$doc_title[matching] <- new_title
  kb$doc_org[matching]   <- new_org
  kb$doc_date[matching]  <- new_date
  kb$doc_url[matching]   <- new_url

  kb
}


#' Remove a document row from documents.csv by filename
#'
#' @param csv_path Path to documents.csv.
#' @param filename Basename of the PDF file (used as the row key).
#'
#' @return Invisibly returns `csv_path`.
#' @importFrom readr read_csv write_csv cols col_character
#' @noRd
remove_document_from_csv <- function(csv_path, filename) {
  docs <- readr::read_csv(
    csv_path,
    col_types = readr::cols(
      title        = readr::col_character(),
      organisation = readr::col_character(),
      date         = readr::col_character(),
      url          = readr::col_character(),
      filename     = readr::col_character()
    ),
    show_col_types = FALSE
  )

  idx <- which(docs$filename == filename)
  if (length(idx) == 0L) {
    stop("Document not found in documents.csv: ", filename)
  }

  updated <- docs[-idx, ]
  readr::write_csv(updated, csv_path)
  invisible(csv_path)
}


#' Remove all knowledge-base chunks belonging to a document
#'
#' Matches on all four metadata fields to avoid accidentally removing chunks
#' from a different document that happens to share a title.
#'
#' @param kb        A tibble / data frame (the knowledge base) with columns
#'   `doc_title`, `doc_org`, `doc_date`, `doc_url`.
#' @param doc_title,doc_org,doc_date,doc_url  Metadata values identifying the
#'   document whose chunks should be removed.
#'
#' @return The updated knowledge base (same structure as `kb`, fewer rows).
#' @noRd
remove_source_material <- function(kb, doc_title, doc_org, doc_date, doc_url) {
  keep <- !(kb$doc_title == doc_title &
            kb$doc_org   == doc_org   &
            kb$doc_date  == doc_date  &
            kb$doc_url   == doc_url)
  kb[keep, ]
}


#' Archive a PDF by moving it to a 'removed' subfolder
#'
#' @param pdf_dir  Directory that contains the PDF file.
#' @param filename Basename of the file to archive.
#'
#' @return Invisibly returns the destination path.
#' @noRd
archive_pdf_file <- function(pdf_dir, filename) {
  src  <- file.path(pdf_dir, filename)
  if (!file.exists(src)) {
    stop("PDF file not found: ", src)
  }

  removed_dir <- file.path(pdf_dir, "removed")
  if (!dir.exists(removed_dir)) {
    dir.create(removed_dir, recursive = TRUE)
  }

  dest <- file.path(removed_dir, filename)
  file.rename(src, dest)
  invisible(dest)
}
