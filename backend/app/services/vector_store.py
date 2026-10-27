"""Step 4: Qdrant — the vector database.

SECURITY MODEL: a search is only ever allowed to look inside an explicit
list of document IDs, and that list is computed on the server from the
database (see access_control.permitted_document_ids) — never taken from the
client. Chunks flagged as suspicious are excluded with a `must_not` filter.
"""
import time
import uuid
from dataclasses import dataclass
from uuid import UUID

from qdrant_client import QdrantClient, models

from ..core.config import settings
from .chunker import Chunk

_client = QdrantClient(
    url=settings.qdrant_url,
    api_key=settings.qdrant_api_key or None,  # Qdrant Cloud needs this; local Qdrant ignores it
    timeout=30,
)
COLLECTION = settings.qdrant_collection


@dataclass
class RetrievedChunk:
    document_id: str
    document_name: str
    page_number: int
    chunk_index: int
    text: str
    score: float  # cosine similarity, 0..1


def _ensure_payload_indexes() -> None:
    """Filtering is faster (and works on strict Qdrant Cloud settings) with
    payload indexes. Safe to call repeatedly; failures just mean "already there"."""
    wanted = [("owner_id", "KEYWORD"), ("document_id", "KEYWORD"), ("flagged", "BOOL")]
    for field, schema_name in wanted:
        try:
            schema = getattr(models.PayloadSchemaType, schema_name)
            _client.create_payload_index(COLLECTION, field_name=field, field_schema=schema)
        except Exception:  # noqa: BLE001
            pass


def ensure_collection(retries: int = 15) -> None:
    """Called at API startup. Retries because Qdrant may still be booting."""
    for attempt in range(retries):
        try:
            if not _client.collection_exists(COLLECTION):
                _client.create_collection(
                    collection_name=COLLECTION,
                    vectors_config=models.VectorParams(
                        size=settings.vector_dimension, distance=models.Distance.COSINE
                    ),
                )
            _ensure_payload_indexes()
            return
        except Exception:  # noqa: BLE001
            if attempt == retries - 1:
                raise
            time.sleep(2)


def is_healthy() -> bool:
    try:
        _client.get_collections()
        return True
    except Exception:  # noqa: BLE001
        return False


def upsert_chunks(
    owner_id: UUID, document_id: UUID, document_name: str,
    chunks: list[Chunk], vectors: list[list[float]],
    flags: list[bool] | None = None,
) -> None:
    flags = flags or [False] * len(chunks)
    points = [
        models.PointStruct(
            id=str(uuid.uuid4()),
            vector=vector,
            payload={
                "owner_id": str(owner_id),
                "document_id": str(document_id),
                "document_name": document_name,
                "page_number": chunk.page_number,
                "chunk_index": chunk.index,
                "text": chunk.text,
                "flagged": bool(flagged),  # True = looks like a hidden instruction
            },
        )
        for chunk, vector, flagged in zip(chunks, vectors, flags)
    ]
    for start in range(0, len(points), 64):
        _client.upsert(collection_name=COLLECTION, points=points[start:start + 64])


def search(query_vector: list[float], document_ids: list[UUID], top_k: int) -> list[RetrievedChunk]:
    """Nearest chunks, restricted to `document_ids` (the caller's permitted set)."""
    if not document_ids:
        return []  # never run an unfiltered search

    allowed = {str(d) for d in document_ids}
    must = [models.FieldCondition(key="document_id", match=models.MatchAny(any=sorted(allowed)))]
    must_not = None
    if settings.quarantine_suspicious_chunks:
        must_not = [models.FieldCondition(key="flagged", match=models.MatchValue(value=True))]

    result = _client.query_points(
        collection_name=COLLECTION,
        query=query_vector,
        query_filter=models.Filter(must=must, must_not=must_not),
        limit=top_k,
        with_payload=True,
    )
    return [
        RetrievedChunk(
            document_id=p.payload["document_id"],
            document_name=p.payload["document_name"],
            page_number=p.payload["page_number"],
            chunk_index=p.payload["chunk_index"],
            text=p.payload["text"],
            score=float(p.score),
        )
        for p in result.points
        if p.payload["document_id"] in allowed  # belt and braces: re-check every hit
    ]


def delete_document(document_id: UUID) -> None:
    _client.delete(
        collection_name=COLLECTION,
        points_selector=models.FilterSelector(filter=models.Filter(must=[
            models.FieldCondition(key="document_id", match=models.MatchValue(value=str(document_id)))
        ])),
    )
