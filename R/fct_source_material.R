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
#' column, and drops internal-only columns (url, filename).
#'
#' @param documents A data frame as returned by `load_documents_csv()`.
#' @return A data frame with columns: Title, Organisation, Date, Source.
#' @noRd
prepare_source_table <- function(documents) {
  if (nrow(documents) == 0L) {
    return(data.frame(
      Title        = character(0),
      Organisation = character(0),
      Date         = character(0),
      Source       = character(0),
      stringsAsFactors = FALSE
    ))
  }

  source_links <- sprintf(
    '<a href="%s" target="_blank" rel="noopener noreferrer">View source</a>',
    documents$url
  )

  data.frame(
    Title        = documents$title,
    Organisation = documents$organisation,
    Date         = documents$date,
    Source       = source_links,
    stringsAsFactors = FALSE
  )
}
