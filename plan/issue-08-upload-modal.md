# Issue #8: Slice 7 — Upload Modal

**GitHub:** ThomUK/chatRAG#8
**Type:** AFK
**Blocked by:** #3 (fct_embeddings), #7 (App Shell)

## Parent PRD

#1

## What to build

Wire the "Add to Knowledge Base" button on the Source Material tab to a modal dialog that allows a new PDF to be ingested into the live knowledge base. This is the live demo moment — the audience watches a document get added and can immediately ask questions about it.

## Acceptance criteria

- [ ] Clicking "Add to Knowledge Base" opens a modal dialog
- [ ] Modal contains: a PDF file upload field, and form fields for Title, Organisation, Date, and Public URL
- [ ] Submitting the form with a valid PDF and complete metadata triggers the embedding pipeline
- [ ] A progress bar with status labels is shown within the modal during processing: "Parsing PDF...", "Creating embeddings...", "Updating knowledge base..."
- [ ] On success, a confirmation message shows the number of chunks added (e.g. "Knowledge base updated — 47 chunks added")
- [ ] Modal closes automatically on success
- [ ] The Source Material table updates reactively to include the new document without a page reload
- [ ] A subtle visual pulse appears on the Source Material tab label when the knowledge base is updated
- [ ] The in-memory knowledge base (reactive value) is updated immediately — the Chat tab has access to the new document without restarting the app
- [ ] The new document's metadata is appended to `documents.csv`

## Blocked by

- Blocked by #3 (fct_embeddings — modal invokes the embedding pipeline)
- Blocked by #7 (App Shell — modal is triggered from the Source Material tab)

## User stories addressed

- User story 13
- User story 14
- User story 15
- User story 16
- User story 17
- User story 18
- User story 19
- User story 20
- User story 21
