
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `{chatRAG}`

<!-- badges: start -->

<!-- badges: end -->

{chatRAG} is a demo Retrieval Augmented Generation (RAG) Shiny app. It
is not intended for production use (although it may be suitable as a
starting point). Its intended purpose is as a demonstrator to help make
RAG more approachable and understandable as a technology to those who
may commission and use RAG projects built by analysts and developers.

## Installation

You can install the development version of `{chatRAG}` like so:

``` r
#install.packages("pak")
pak::pkg_install("ThomUK/chatRAG")
```

## Run

You can launch the application by running:

``` r
chatRAG::run_app()
```

## About

You are reading the doc about version : 0.0.0.9000

This README has been compiled on the

``` r
Sys.time()
#> [1] "2026-04-11 19:53:27 BST"
```

Here are the tests results and package coverage:

``` r
devtools::check(quiet = TRUE)
#> ══ Documenting ═════════════════════════════════════════════════════════════════
#> ℹ Installed roxygen2 version (7.3.3) doesn't match required (7.1.1)
#> ✖ `check()` will not re-document this package
#> ── R CMD check results ───────────────────────────────── chatRAG 0.0.0.9000 ────
#> Duration: 56.5s
#> 
#> 0 errors ✔ | 0 warnings ✔ | 0 notes ✔
```

``` r
covr::package_coverage()
#> chatRAG Coverage: 0.00%
#> R/app_config.R: 0.00%
#> R/app_ui.R: 0.00%
#> R/run_app.R: 0.00%
```
