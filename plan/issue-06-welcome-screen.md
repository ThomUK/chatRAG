# Issue #6: Slice 5 — Welcome / Setup Screen

**GitHub:** ThomUK/chatRAG#6
**Type:** AFK
**Blocked by:** #3 (fct_embeddings)

## Parent PRD

#1

## What to build

Implement the welcome screen that is displayed when no `embeddings.rds` exists. This screen guides a developer or presenter through the prerequisites and triggers the initial knowledge base build. It is the first thing a new user sees and must be clear, reassuring, and self-sufficient.

## Acceptance criteria

- [ ] Welcome screen is shown automatically when `inst/app/data/embeddings.rds` does not exist at startup
- [ ] Three prerequisite checks are displayed with plain-English status indicators: Ollama running (HTTP ping to localhost:11434), PDFs folder contains at least one PDF, documents.csv is present and parseable
- [ ] Each failing check shows a plain-English instruction explaining how to resolve it
- [ ] "Build Knowledge Base" button is disabled until all three checks pass
- [ ] Clicking "Build Knowledge Base" shows a progress bar with status labels: "Parsing PDF...", "Creating embeddings...", "Updating knowledge base..."
- [ ] On successful build, the app transitions automatically into the main tabbed UI without a page refresh
- [ ] The welcome screen design is consistent with the app's light, minimal aesthetic

## Blocked by

- Blocked by #3 (fct_embeddings — the build button invokes the embedding pipeline)

## User stories addressed

- User story 1
- User story 2
- User story 3
- User story 4
- User story 5
- User story 6
- User story 7
