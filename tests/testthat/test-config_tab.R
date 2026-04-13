# test-config_tab.R
# TDD tests for Issue #18 + #19: Config tab — build + activate embedding combinations
# Covers: config_tab_ui() structure, file-naming, overwrite safety,
# main_tabbed_ui() Config panel presence, format_kb_badge(), and
# config_combinations_table_ui() with disabled/enabled radios.

# ── Helpers ────────────────────────────────────────────────────────────────────

as_html <- function(tag) as.character(tag)

# Source required files directly (avoids devtools::load_all which needs all
# optional Imports like golem, DT, ollamar to be installed)
local({
  pkg_root <- tryCatch(
    rprojroot::find_package_root_file(),
    error = function(e) getwd()
  )
  for (f in c("R/fct_embedding_config.R", "R/fct_embeddings.R",
               "R/fct_source_material.R", "R/fct_chat.R",
               "R/fct_connect.R", "R/fct_upload_modal.R",
               "R/fct_welcome.R", "R/app_ui.R")) {
    source(file.path(pkg_root, f), local = FALSE)
  }
})

# ── config_tab_ui() structure ──────────────────────────────────────────────────

test_that("config_tab_ui returns a shiny tag object", {
  result <- config_tab_ui()
  expect_s3_class(result, "shiny.tag.list")
})

test_that("config_tab_ui includes config_combinations_table uiOutput", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_combinations_table", html))
})

test_that("config_tab_ui includes config_build_status uiOutput", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_build_status", html))
})

test_that("config_tab_ui includes strategy selectInput with id config_build_strategy", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_build_strategy", html))
})

test_that("config_tab_ui strategy select defaults to 'sentence'", {
  html <- as_html(config_tab_ui())
  # The selected option should have 'selected' attribute and value 'sentence'
  expect_true(grepl('value="sentence"\\s+selected', html) ||
                grepl('selected.*value="sentence"', html) ||
                grepl('selected="selected"[^>]*>\\s*sentence', html) ||
                # selectInput renders selected as the first option OR via selected attr
                grepl("sentence.*selected|selected.*sentence", html))
})

test_that("config_tab_ui includes chunk size selectInput with id config_build_size", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_build_size", html))
})

test_that("config_tab_ui chunk size select defaults to '1500'", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("1500.*selected|selected.*1500", html))
})

test_that("config_tab_ui includes Build button with id config_build", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_build", html))
})

test_that("config_tab_ui includes Activate button with id config_activate", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("config_activate", html))
})

test_that("config_tab_ui chunk size choices include all four sizes", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("500", html))
  expect_true(grepl("1000", html))
  expect_true(grepl("1500", html))
  expect_true(grepl("2000", html))
})

test_that("config_tab_ui strategy choices include both sentence and char", {
  html <- as_html(config_tab_ui())
  expect_true(grepl("sentence", html))
  expect_true(grepl("char", html))
})

# ── main_tabbed_ui() contains Config tab ──────────────────────────────────────
# These tests require DT (for source_material_tab_ui); skip gracefully if absent.

test_that("main_tabbed_ui includes a Config nav panel", {
  skip_if_not_installed("DT")
  html <- as_html(main_tabbed_ui())
  expect_true(grepl("Config", html))
})

test_that("main_tabbed_ui Config panel includes config_combinations_table", {
  skip_if_not_installed("DT")
  html <- as_html(main_tabbed_ui())
  expect_true(grepl("config_combinations_table", html))
})

# ── File-naming: build writes to correctly named .rds ─────────────────────────

test_that("embedding_slug gives 'sentence_1500' for sentence / 1500", {
  expect_equal(embedding_slug("sentence", 1500L), "sentence_1500")
})

test_that("embedding_slug gives 'char_500' for char / 500", {
  expect_equal(embedding_slug("char", 500L), "char_500")
})

test_that("embedding_slug gives 'char_1000' for char / 1000", {
  expect_equal(embedding_slug("char", 1000L), "char_1000")
})

test_that("embedding_slug gives 'sentence_2000' for sentence / 2000", {
  expect_equal(embedding_slug("sentence", 2000L), "sentence_2000")
})

test_that("embedding_file_path returns path ending in embeddings_<slug>.rds", {
  dir  <- tempdir()
  path <- embedding_file_path(dir, "sentence", 1500L)
  expect_true(grepl("embeddings_sentence_1500\\.rds$", path))
})

test_that("embedding_file_path uses the supplied data_dir as the base directory", {
  dir  <- tempdir()
  path <- embedding_file_path(dir, "char", 1000L)
  expect_true(startsWith(path, dir))
})

# ── Overwrite safety: building an existing combination must not error ──────────

test_that("save_knowledge_base overwrites an existing file without error", {
  tmp  <- tempfile(fileext = ".rds")
  kb1  <- tibble::tibble(chunk = "first", embedding = list(c(0.1, 0.2)))
  save_knowledge_base(kb1, tmp)
  expect_true(file.exists(tmp))

  kb2  <- tibble::tibble(chunk = "second", embedding = list(c(0.3, 0.4)))
  expect_no_error(save_knowledge_base(kb2, tmp))

  loaded <- readRDS(tmp)
  expect_equal(loaded$chunk, "second")
})

test_that("save_knowledge_base returns the path invisibly", {
  tmp <- tempfile(fileext = ".rds")
  kb  <- tibble::tibble(chunk = "x", embedding = list(c(1, 2)))
  result <- withVisible(save_knowledge_base(kb, tmp))
  expect_false(result$visible)
  expect_equal(result$value, tmp)
})

# ── built_combinations sees newly created .rds files ──────────────────────────

test_that("built_combinations reflects a just-written embeddings file", {
  dir  <- withr::local_tempdir()
  kb   <- tibble::tibble(chunk = "x", doc_title = "T", embedding = list(c(1)))
  path <- embedding_file_path(dir, "char", 500L)
  saveRDS(kb, path)

  result <- built_combinations(dir)
  expect_equal(nrow(result), 1L)
  expect_equal(result$strategy, "char")
  expect_equal(result$size,     500L)
})

test_that("built_combinations treats overwritten file as one built entry", {
  dir  <- withr::local_tempdir()
  kb1  <- tibble::tibble(chunk = "v1", doc_title = "T", embedding = list(c(1)))
  kb2  <- tibble::tibble(chunk = "v2", doc_title = "T", embedding = list(c(2)))
  path <- embedding_file_path(dir, "sentence", 1500L)
  saveRDS(kb1, path)
  saveRDS(kb2, path)  # overwrite

  result <- built_combinations(dir)
  expect_equal(nrow(result), 1L)
})

# ── format_kb_badge() ─────────────────────────────────────────────────────────
# Issue #19: Chat tab badge must show "KB: sentence · 1500" format

test_that("format_kb_badge formats sentence_1500 as 'sentence · 1500'", {
  expect_equal(format_kb_badge("sentence_1500"), "sentence \u00b7 1500")
})

test_that("format_kb_badge formats char_500 as 'char · 500'", {
  expect_equal(format_kb_badge("char_500"), "char \u00b7 500")
})

test_that("format_kb_badge formats sentence_2000 as 'sentence · 2000'", {
  expect_equal(format_kb_badge("sentence_2000"), "sentence \u00b7 2000")
})

test_that("format_kb_badge formats char_1000 as 'char · 1000'", {
  expect_equal(format_kb_badge("char_1000"), "char \u00b7 1000")
})

test_that("format_kb_badge returns NULL for NULL input", {
  expect_null(format_kb_badge(NULL))
})

# ── config_combinations_table_ui() ───────────────────────────────────────────
# Issue #19: combinations table must disable radios for not-built rows and
# pre-select the currently active slug.

test_that("config_combinations_table_ui returns a shiny tag", {
  all_combs   <- all_embedding_combinations()
  built_combs <- all_combs[1L, ]
  result <- config_combinations_table_ui(all_combs, built_combs, "char_500")
  expect_true(inherits(result, c("shiny.tag", "shiny.tag.list")))
})

test_that("config_combinations_table_ui includes config_selected_slug input group id", {
  all_combs   <- all_embedding_combinations()
  built_combs <- all_combs[1L, ]
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, "char_500"))
  expect_true(grepl("config_selected_slug", html))
})

test_that("config_combinations_table_ui marks not-built combinations as disabled", {
  all_combs   <- all_embedding_combinations()
  # Only char_500 built; char_1000 is not
  built_combs <- all_combs[all_combs$strategy == "char" & all_combs$size == 500L, ]
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, "char_500"))
  # At least one radio must carry disabled attribute (char_1000, char_1500, etc.)
  expect_true(grepl("disabled", html))
})

test_that("config_combinations_table_ui does not disable the built combination", {
  all_combs   <- all_embedding_combinations()
  built_combs <- all_combs[all_combs$strategy == "char" & all_combs$size == 500L, ]
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, "char_500"))
  # char_500 value must appear without disabled on the same input tag
  expect_false(grepl('value="char_500"[^>]*disabled', html))
})

test_that("config_combinations_table_ui pre-selects the active slug", {
  all_combs   <- all_embedding_combinations()
  # Both char sizes built so char_1000 is a valid selection
  built_combs <- all_combs[all_combs$strategy == "char", ]
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, "char_1000"))
  # The char_1000 input must carry checked
  expect_true(grepl('value="char_1000"[^>]*checked|checked[^>]*value="char_1000"', html))
})

test_that("config_combinations_table_ui selects first built slug when active_slug is NULL", {
  all_combs   <- all_embedding_combinations()
  built_combs <- all_combs[all_combs$strategy == "sentence" & all_combs$size == 1500L, ]
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, NULL))
  # sentence_1500 is the only built slug — must be checked
  expect_true(grepl('value="sentence_1500"[^>]*checked|checked[^>]*value="sentence_1500"', html))
})

test_that("config_combinations_table_ui has no checked radio when nothing is built and slug is NULL", {
  all_combs   <- all_embedding_combinations()
  built_combs <- all_combs[0L, ]  # empty — nothing built
  html <- as_html(config_combinations_table_ui(all_combs, built_combs, NULL))
  expect_false(grepl("checked", html))
})
