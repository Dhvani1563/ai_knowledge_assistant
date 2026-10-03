"""Step 3: text -> vectors, locally, for free.

Model: BAAI/bge-small-en-v1.5 (384 dims, ~130 MB, strong retrieval quality
for its size, runs fine on CPU). Upgrade path: bge-base-en-v1.5 (768 dims)
or bge-m3 (multilingual) — change EMBEDDING_MODEL + VECTOR_DIMENSION and
re-ingest, because vectors from different models are not comparable.

bge is *asymmetric*: search queries get an instruction prefix, passages do
not. Skipping the prefix measurably hurts retrieval.
"""
from functools import lru_cache

from sentence_transformers import SentenceTransformer

from ..core.config import settings

QUERY_PREFIX = "Represent this sentence for searching relevant passages: "


@lru_cache(maxsize=1)
def get_model() -> SentenceTransformer:
    return SentenceTransformer(settings.embedding_model)


def embed_passages(texts: list[str]) -> list[list[float]]:
    if not texts:
        return []
    vectors = get_model().encode(texts, normalize_embeddings=True, batch_size=32, show_progress_bar=False)
    return vectors.tolist()


def embed_query(query: str) -> list[float]:
    vector = get_model().encode(QUERY_PREFIX + query, normalize_embeddings=True)
    return vector.tolist()
