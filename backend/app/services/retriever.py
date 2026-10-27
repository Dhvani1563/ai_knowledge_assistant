"""Step 5: the retriever — question in, best permitted evidence out.

`document_ids` is the caller's permitted set, decided by access_control
BEFORE this runs. Retrieval policy (thresholds, de-duplication) lives here
so it can evolve without touching database code.
"""
from uuid import UUID

from ..core.config import settings
from .embedder import embed_query
from .vector_store import RetrievedChunk, search


def retrieve(question: str, document_ids: list[UUID], top_k: int) -> list[RetrievedChunk]:
    if not document_ids:
        return []
    hits = search(embed_query(question), document_ids, top_k=top_k)

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
