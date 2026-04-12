# fct_embedding_config.R
# Owns all embedding-config-layer concerns: canonical combination list,
# slug / file-path derivation, active-slug persistence, migration, and
# built-status enumeration.

# ── Constants ─────────────────────────────────────────────────────────────────

.EMBEDDING_STRATEGIES <- c("char", "sentence")
.EMBEDDING_SIZES      <- c(500L, 1000L, 1500L, 2000L)


# ── Public API ─────────────────────────────────────────────────────────────────

#' Return all 8 supported strategy × size combinations
#'
#' @return A tibble with columns `strategy` (character) and `size` (integer).
#' @noRd
all_embedding_combinations <- function() {
  tibble::tibble(
    strategy = rep(.EMBEDDING_STRATEGIES, each = length(.EMBEDDING_SIZES)),
    size     = rep(.EMBEDDING_SIZES,      times = length(.EMBEDDING_STRATEGIES))
  )
}


#' Derive the slug for a strategy / size combination
#'
#' @param strategy `"char"` or `"sentence"`.
#' @param size     Target chunk size in characters (integer).
#'
#' @return A character string, e.g. `"sentence_1500"`.
#' @noRd
embedding_slug <- function(strategy, size) {
  paste0(strategy, "_", as.integer(size))
}


#' Derive the knowledge base file path for a strategy / size combination
#'
#' @param data_dir  Path to the app data directory.
#' @param strategy  `"char"` or `"sentence"`.
#' @param size      Target chunk size in characters (integer).
#'
#' @return Absolute path to the `.rds` file.
#' @noRd
embedding_file_path <- function(data_dir, strategy, size) {
  file.path(data_dir, paste0("embeddings_", embedding_slug(strategy, size), ".rds"))
}


#' Read the active embedding slug from disk
#'
#' @param data_dir Path to the app data directory.
#'
#' @return The slug string (e.g. `"sentence_1500"`), or `NULL` if the file does
#'   not exist.
#' @noRd
read_active_slug <- function(data_dir) {
  path <- file.path(data_dir, "active_embedding.txt")
  if (!file.exists(path)) return(NULL)
  trimws(readLines(path, warn = FALSE)[[1L]])
}


#' Write the active embedding slug to disk
#'
#' @param data_dir Path to the app data directory.
#' @param slug     Slug string to write (e.g. `"sentence_1500"`).
#'
#' @return Invisibly returns `slug`.
#' @noRd
write_active_slug <- function(data_dir, slug) {
  path <- file.path(data_dir, "active_embedding.txt")
  writeLines(as.character(slug), path)
  invisible(slug)
}


#' Migrate a legacy embeddings.rds to the new naming convention
#'
#' On first startup after the upgrade: if `embeddings.rds` exists and
#' `embeddings_char_500.rds` does not, renames the former to the latter and
#' writes `"char_500"` to `active_embedding.txt`.
#' Is a no-op when the target file already exists, or when neither file exists.
#'
#' @param data_dir Path to the app data directory.
#'
#' @return Invisibly returns `TRUE` if migration occurred, `FALSE` otherwise.
#' @noRd
migrate_legacy_embedding <- function(data_dir) {
  legacy_path  <- file.path(data_dir, "embeddings.rds")
  char500_path <- file.path(data_dir, "embeddings_char_500.rds")

  if (file.exists(char500_path)) return(invisible(FALSE))
  if (!file.exists(legacy_path)) return(invisible(FALSE))

  file.rename(legacy_path, char500_path)
  write_active_slug(data_dir, "char_500")
  invisible(TRUE)
}


#' Enumerate which of the 8 combinations have been built on disk
#'
#' @param data_dir Path to the app data directory.
#'
#' @return A subset of [all_embedding_combinations()] containing only the rows
#'   whose `.rds` file exists.
#' @noRd
built_combinations <- function(data_dir) {
  all_combs <- all_embedding_combinations()
  built <- vapply(seq_len(nrow(all_combs)), function(i) {
    file.exists(embedding_file_path(data_dir, all_combs$strategy[i], all_combs$size[i]))
  }, logical(1L))
  all_combs[built, ]
}
