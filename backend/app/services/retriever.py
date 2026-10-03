"""Step 5: the retriever — question in, best evidence out.

Kept separate from vector_store so retrieval *policy* (thresholds, dedupe,
ordering) can evolve without touching database code. Natural next
upgrades: hybrid search (BM25 + dense), a cross-encoder reranker such as
bge-reranker-base, and MMR for diversity.
"""
from uuid import UUID

from ..core.config import settings
from .embedder import embed_query
from .vector_store import RetrievedChunk, search


def retrieve(
    question: str, owner_id: UUID, top_k: int, document_ids: list[UUID] | None = None,
) -> list[RetrievedChunk]:
    hits = search(embed_query(question), owner_id, top_k=top_k, document_ids=document_ids)

    # 1) drop weak matches — better to say "not found" than to feed noise to the LLM
    hits = [h for h in hits if h.score >= settings.min_relevance]

    # 2) drop near-duplicates (overlapping chunks that say the same thing)
    unique, seen = [], set()
    for hit in hits:
        key = hit.text[:120].lower()
        if key not in seen:
            seen.add(key)
            unique.append(hit)
    return unique
