# Tests for fct_embedding_config.R
# Using red-green-refactor TDD approach.
# All file I/O uses tempdir() for isolation.

# ── all_embedding_combinations ────────────────────────────────────────────────

test_that("all_embedding_combinations returns 8 rows", {
  result <- all_embedding_combinations()
  expect_equal(nrow(result), 8L)
})

test_that("all_embedding_combinations always returns all 8 rows regardless of disk state", {
  result <- all_embedding_combinations()
  expect_equal(nrow(result), 8L)
  expect_true(all(c("strategy", "size") %in% names(result)))
})

test_that("all_embedding_combinations includes both strategies", {
  result <- all_embedding_combinations()
  expect_true("char" %in% result$strategy)
  expect_true("sentence" %in% result$strategy)
})

test_that("all_embedding_combinations includes all four sizes", {
  result <- all_embedding_combinations()
  expect_true(all(c(500L, 1000L, 1500L, 2000L) %in% result$size))
})


# ── embedding_slug ────────────────────────────────────────────────────────────

test_that("embedding_slug returns correct slug for char/500", {
  expect_equal(embedding_slug("char", 500L), "char_500")
})

test_that("embedding_slug returns correct slug for sentence/1500", {
  expect_equal(embedding_slug("sentence", 1500L), "sentence_1500")
})

test_that("embedding_slug returns correct slug for all 8 combinations", {
  combos <- all_embedding_combinations()
  for (i in seq_len(nrow(combos))) {
    slug <- embedding_slug(combos$strategy[i], combos$size[i])
    expect_match(slug, paste0(combos$strategy[i], "_", combos$size[i]))
  }
})


# ── embedding_file_path ───────────────────────────────────────────────────────

test_that("embedding_file_path returns path inside data_dir", {
  path <- embedding_file_path("/some/dir", "char", 500L)
  expect_true(startsWith(path, "/some/dir"))
})

test_that("embedding_file_path filename contains strategy and size", {
  path <- embedding_file_path("/data", "sentence", 1500L)
  expect_match(basename(path), "sentence_1500")
})

test_that("embedding_file_path ends with .rds", {
  path <- embedding_file_path("/data", "char", 1000L)
  expect_match(path, "\\.rds$")
})


# ── read_active_slug / write_active_slug ──────────────────────────────────────

test_that("read_active_slug returns NULL when file does not exist", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  result <- read_active_slug(data_dir)
  expect_null(result)
})

test_that("write_active_slug creates the file if it does not exist", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  write_active_slug(data_dir, "sentence_1500")
  expect_true(file.exists(file.path(data_dir, "active_embedding.txt")))
})

test_that("read_active_slug returns the slug written by write_active_slug", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  write_active_slug(data_dir, "char_500")
  result <- read_active_slug(data_dir)
  expect_equal(result, "char_500")
})

test_that("write_active_slug overwrites an existing file", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  write_active_slug(data_dir, "char_500")
  write_active_slug(data_dir, "sentence_1500")
  expect_equal(read_active_slug(data_dir), "sentence_1500")
})


# ── migrate_legacy_embedding ──────────────────────────────────────────────────

test_that("migrate_legacy_embedding renames embeddings.rds to embeddings_char_500.rds", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  saveRDS(list(), file.path(data_dir, "embeddings.rds"))
  migrate_legacy_embedding(data_dir)

  expect_false(file.exists(file.path(data_dir, "embeddings.rds")))
  expect_true(file.exists(file.path(data_dir, "embeddings_char_500.rds")))
})

test_that("migrate_legacy_embedding writes char_500 to active_embedding.txt", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  saveRDS(list(), file.path(data_dir, "embeddings.rds"))
  migrate_legacy_embedding(data_dir)

  expect_equal(read_active_slug(data_dir), "char_500")
})

test_that("migrate_legacy_embedding is a no-op when embeddings_char_500.rds already exists", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  # Both files exist — char_500 already present, should not overwrite
  saveRDS("already", file.path(data_dir, "embeddings_char_500.rds"))
  saveRDS("legacy",  file.path(data_dir, "embeddings.rds"))

  migrate_legacy_embedding(data_dir)

  # Legacy file should still exist (no-op)
  expect_true(file.exists(file.path(data_dir, "embeddings.rds")))
})

test_that("migrate_legacy_embedding is a no-op when neither file exists", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  expect_silent(migrate_legacy_embedding(data_dir))
  expect_false(file.exists(file.path(data_dir, "active_embedding.txt")))
})


# ── built_combinations ────────────────────────────────────────────────────────

test_that("built_combinations returns empty result when no files exist", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  result <- built_combinations(data_dir)
  expect_equal(nrow(result), 0L)
})

test_that("built_combinations returns only combinations whose .rds file exists", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  # Create two of the 8 possible files
  saveRDS(list(), file.path(data_dir, "embeddings_char_500.rds"))
  saveRDS(list(), file.path(data_dir, "embeddings_sentence_1500.rds"))

  result <- built_combinations(data_dir)
  expect_equal(nrow(result), 2L)
  expect_true(any(result$strategy == "char"     & result$size == 500L))
  expect_true(any(result$strategy == "sentence" & result$size == 1500L))
})

test_that("built_combinations result contains strategy and size columns", {
  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  saveRDS(list(), file.path(data_dir, "embeddings_char_1000.rds"))

  result <- built_combinations(data_dir)
  expect_true(all(c("strategy", "size") %in% names(result)))
})
