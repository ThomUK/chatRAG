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
#' @param min_similarity  Minimum cosine similarity threshold; chunks below this
#'   score are excluded before ranking.
#' @param use_mmr         If `TRUE` (default), applies Maximal Marginal
#'   Relevance re-ranking to balance relevance with diversity.
#' @param lambda          MMR trade-off parameter in \[0, 1\].  `1` = pure
#'   relevance (same as non-MMR); `0` = pure diversity.  Default `0.5`.
#'
#' @return A tibble with columns `chunk_text`, `doc_title`, `doc_org`,
#'   `doc_date`, `doc_url`, and `similarity_score`, in MMR selection order
#'   (or descending similarity when `use_mmr = FALSE`).
#' @noRd
retrieve_chunks <- function(query_embedding, knowledge_base, top_n = 5,
                            min_similarity = 0.5, use_mmr = TRUE, lambda = 0.5) {
  scores <- vapply(
    knowledge_base$embedding,
    function(emb) cosine_similarity(query_embedding, emb),
    numeric(1L)
  )

  knowledge_base$similarity_score <- scores
  candidates <- knowledge_base[order(scores, decreasing = TRUE), ]
  candidates <- candidates[candidates$similarity_score >= min_similarity, ]

  if (!use_mmr || nrow(candidates) == 0) {
    result <- candidates[seq_len(min(top_n, nrow(candidates))), ]
  } else {
    # Greedy MMR selection: balance relevance vs. diversity from already-selected chunks.
    n_pick          <- min(top_n, nrow(candidates))
    candidate_idx   <- seq_len(nrow(candidates))
    selected_idx    <- integer(0)

    for (i in seq_len(n_pick)) {
      if (length(selected_idx) == 0L) {
        # First pick: highest query similarity (candidates already sorted desc)
        best_local <- 1L
      } else {
        sel_embeddings <- lapply(selected_idx, function(j) candidates$embedding[[j]])

        mmr_scores <- vapply(seq_along(candidate_idx), function(k) {
          j           <- candidate_idx[k]
          max_sim_sel <- max(vapply(sel_embeddings,
                                   function(e) cosine_similarity(candidates$embedding[[j]], e),
                                   numeric(1L)))
          lambda * candidates$similarity_score[j] - (1 - lambda) * max_sim_sel
        }, numeric(1L))

        best_local <- which.max(mmr_scores)
      }

      selected_idx  <- c(selected_idx, candidate_idx[best_local])
      candidate_idx <- candidate_idx[-best_local]
    }

    result <- candidates[selected_idx, ]
  }

  result[, c("chunk_text", "doc_title", "doc_org", "doc_date", "doc_url", "similarity_score")]
}
