# Issue #2: Slice 1 — Project Foundation

**GitHub:** ThomUK/chatRAG#2
**Type:** AFK
**Blocked by:** None — can start immediately

## Parent PRD

#1

## What to build

Establish the complete project scaffold so all subsequent slices can build on a clean, consistent foundation. This covers dependency declaration, secrets management, directory structure, and gitignore hygiene — nothing more.

## Acceptance criteria

- [ ] All required packages declared in DESCRIPTION Imports: golem, shiny, bslib, pdftools, ollamar, httr2, DT, dplyr, readr, stringr, config
- [ ] `inst/app/data/pdfs/` directory exists (with a .gitkeep so it is tracked)
- [ ] `inst/app/data/documents.csv` placeholder exists with correct columns: title, organisation, date, url, filename
- [ ] `inst/app/data/embeddings.rds` is gitignored
- [ ] `inst/app/data/pdfs/` is gitignored
- [ ] `.Renviron` is gitignored
- [ ] `.Renviron.example` is committed with placeholder values and explanatory comments for all required env vars (ANTHROPIC_API_KEY, OPENAI_API_KEY, AZURE_OPENAI_KEY, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT)
- [ ] `inst/golem-config.yml` references all API key env vars via `!expr Sys.getenv(...)`
- [ ] `R/app_config.R` exposes a `get_golem_config()` based helper for retrieving the default API key at startup

## Blocked by

None — can start immediately.

## User stories addressed

- User story 8
- User story 9
