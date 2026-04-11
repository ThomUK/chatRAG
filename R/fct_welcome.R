# External-package / filesystem wrappers (mockable in tests) ------------------

#' @noRd
.list_pdf_files <- function(pdf_dir) {
  list.files(pdf_dir, pattern = "\\.pdf$", ignore.case = TRUE, recursive = TRUE)
}

#' @noRd
.read_documents_csv <- function(csv_path) {
  readr::read_csv(csv_path, show_col_types = FALSE)
}

#' @noRd
.check_file_exists <- function(path) {
  file.exists(path)
}


# Public API -------------------------------------------------------------------

#' Check whether the local Ollama server is running
#'
#' @return A named list: `ok` (logical) and `message` (character).
#' @noRd
check_ollama_status <- function() {
  running <- check_ollama_running()
  list(
    ok = running,
    message = if (running) {
      "Ollama is running"
    } else {
      "Ollama is not running. Start it with: ollama serve"
    }
  )
}


#' Check whether at least one PDF exists in the PDFs directory
#'
#' @param pdf_dir Path to the directory containing PDFs.
#'
#' @return A named list: `ok` (logical) and `message` (character).
#' @noRd
check_pdfs_status <- function(
  pdf_dir = app_sys("app/data/pdfs")
) {
  files <- .list_pdf_files(pdf_dir)
  ok <- length(files) > 0
  list(
    ok = ok,
    message = if (ok) {
      paste0(length(files), " PDF(s) found in the PDFs folder")
    } else {
      "No PDFs found. Add PDF files to inst/app/data/pdfs/ and restart. Add subdirectories to organise your files if needed."
    }
  )
}


#' Check whether documents.csv exists and has the required columns
#'
#' @param csv_path Path to `documents.csv`.
#'
#' @return A named list: `ok` (logical) and `message` (character).
#' @noRd
check_documents_csv_status <- function(
  csv_path = app_sys("app/data/documents.csv")
) {
  if (!.check_file_exists(csv_path)) {
    return(list(
      ok = FALSE,
      message = "documents.csv not found. Create it at inst/app/data/documents.csv."
    ))
  }

  required_cols <- c("title", "organisation", "date", "url", "filename")

  tryCatch(
    {
      df <- .read_documents_csv(csv_path)
      missing <- setdiff(required_cols, names(df))
      if (length(missing) > 0) {
        return(list(
          ok = FALSE,
          message = paste0(
            "documents.csv is missing columns: ",
            paste(missing, collapse = ", ")
          )
        ))
      }
      list(
        ok = TRUE,
        message = paste0("documents.csv found with ", nrow(df), " document(s)")
      )
    },
    error = function(e) {
      list(
        ok = FALSE,
        message = paste0(
          "documents.csv could not be parsed: ",
          conditionMessage(e)
        )
      )
    }
  )
}


#' Run all three prerequisite checks
#'
#' @param pdf_dir  Path to the directory containing PDFs.
#' @param csv_path Path to `documents.csv`.
#'
#' @return A named list with elements `ollama`, `pdfs`, and `documents_csv`,
#'   each a list with `ok` and `message`.
#' @noRd
run_prerequisite_checks <- function(
  pdf_dir = app_sys("app/data/pdfs"),
  csv_path = app_sys("app/data/documents.csv")
) {
  list(
    ollama = check_ollama_status(),
    pdfs = check_pdfs_status(pdf_dir),
    documents_csv = check_documents_csv_status(csv_path)
  )
}


#' Test whether all prerequisite checks pass
#'
#' @param checks Output of `run_prerequisite_checks()`.
#'
#' @return `TRUE` if every check has `ok == TRUE`, otherwise `FALSE`.
#' @noRd
all_checks_pass <- function(checks) {
  all(vapply(checks, function(c) isTRUE(c$ok), logical(1)))
}


#' Test whether the embeddings RDS file exists
#'
#' @param rds_path Path to the embeddings `.rds` file.
#'
#' @return `TRUE` if the file exists, `FALSE` otherwise.
#' @noRd
embeddings_file_exists <- function(
  rds_path = app_sys("app/data/embeddings.rds")
) {
  .check_file_exists(rds_path)
}
