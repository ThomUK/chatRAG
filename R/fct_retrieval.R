# fct_retrieval.R
# Retrieval layer: embed a query, score the knowledge base by cosine
# similarity, and return the top-N most relevant chunks.

# Public API -------------------------------------------------------------------

#' Compute cosine similarity between two numeric vectors
#'
#' @param vec_a A numeric vector.
#' @param vec_b A numeric vector of the same length as `vec_a`.
#'
#' @return A single numeric value in \[-1, 1\].  Identical vectors return 1;
#'   orthogonal vectors return 0.
#' @noRd
cosine_similarity <- function(vec_a, vec_b) {
  dot  <- sum(vec_a * vec_b)
  norm <- sqrt(sum(vec_a^2)) * sqrt(sum(vec_b^2))
  dot / norm
}


#' Embed a natural-language query using Ollama nomic-embed-text
#'
#' @param query_text A single character string.
#'
#' @return A numeric vector (the query embedding).
#' @noRd
embed_query <- function(query_text) {
  embeddings <- .call_ollama_embed(query_text)
  embeddings[[1L]]
}


#' Retrieve the top-N most relevant chunks from a knowledge base
#'
#' @param query_embedding A numeric vector (from [embed_query()]).
#' @param knowledge_base  A tibble produced by [build_knowledge_base()] or
#'   [load_knowledge_base()], with at minimum columns `embedding`,
#'   `chunk_text`, `doc_title`, `doc_org`, `doc_date`, and `doc_url`.
#' @param top_n           Maximum number of chunks to return.  If the knowledge
#'   base contains fewer chunks than `top_n`, all chunks are returned.
#'
#' @return A tibble with columns `chunk_text`, `doc_title`, `doc_org`,
#'   `doc_date`, `doc_url`, and `similarity_score`, ordered from highest to
#'   lowest similarity.
#' @noRd
retrieve_chunks <- function(query_embedding, knowledge_base, top_n = 5, min_similarity = 0.5) {
  scores <- vapply(
    knowledge_base$embedding,
    function(emb) cosine_similarity(query_embedding, emb),
    numeric(1L)
  )

  knowledge_base$similarity_score <- scores
  result <- knowledge_base[order(scores, decreasing = TRUE), ]
  result <- result[result$similarity_score >= min_similarity, ]
  result <- result[seq_len(min(top_n, nrow(result))), ]

  result[, c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")]
}
