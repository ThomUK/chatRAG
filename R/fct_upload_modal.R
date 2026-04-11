#' Validate upload form inputs
#'
#' @param file   The file input list from Shiny (`input$upload_pdf`), or NULL.
#' @param title  Document title string.
#' @param org    Organisation string.
#' @param date   Date string.
#' @param url    Public URL string.
#'
#' @return A list with `ok` (logical) and `message` (character).
#' @noRd
validate_upload_inputs <- function(file, title, org, date, url) {
  if (is.null(file)) {
    return(list(ok = FALSE, message = "Please select a PDF file to upload."))
  }

  filename <- if (!is.null(file$name)) file$name else basename(file$datapath)
  if (!grepl("\\.pdf$", filename, ignore.case = TRUE)) {
    return(list(ok = FALSE, message = "Only PDF files are supported. Please select a PDF."))
  }

  if (nchar(trimws(title)) == 0L) {
    return(list(ok = FALSE, message = "Title is required."))
  }

  if (nchar(trimws(org)) == 0L) {
    return(list(ok = FALSE, message = "Organisation is required."))
  }

  if (nchar(trimws(date)) == 0L) {
    return(list(ok = FALSE, message = "Date is required."))
  }

  if (nchar(trimws(url)) == 0L) {
    return(list(ok = FALSE, message = "URL is required."))
  }

  list(ok = TRUE, message = "")
}


#' Append a new document's metadata to documents.csv
#'
#' @param csv_path Path to the documents.csv file.
#' @param new_row  A named list with fields: title, organisation, date, url,
#'   filename.
#'
#' @return Invisibly returns `csv_path`.
#' @importFrom readr read_csv write_csv cols col_character
#' @noRd
append_document_to_csv <- function(csv_path, new_row) {
  existing <- readr::read_csv(
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

  new_df <- data.frame(
    title        = as.character(new_row$title),
    organisation = as.character(new_row$organisation),
    date         = as.character(new_row$date),
    url          = as.character(new_row$url),
    filename     = as.character(new_row$filename),
    stringsAsFactors = FALSE
  )

  updated <- dplyr::bind_rows(existing, new_df)
  readr::write_csv(updated, csv_path)
  invisible(csv_path)
}
