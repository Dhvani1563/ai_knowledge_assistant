"""Step 4: Qdrant — the vector database.

Why Qdrant here: payload filtering is first-class. Every search is scoped
with a `must owner_id == user` filter (privacy: users can only ever
retrieve their own chunks) and optionally `document_id in [...]`.
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
                for field in ("owner_id", "document_id"):
                    _client.create_payload_index(
                        COLLECTION, field_name=field, field_schema=models.PayloadSchemaType.KEYWORD
                    )
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
) -> None:
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
            },
        )
        for chunk, vector in zip(chunks, vectors)
    ]
    for start in range(0, len(points), 64):
        _client.upsert(collection_name=COLLECTION, points=points[start:start + 64])


def search(
    query_vector: list[float], owner_id: UUID, top_k: int,
    document_ids: list[UUID] | None = None,
) -> list[RetrievedChunk]:
    must = [models.FieldCondition(key="owner_id", match=models.MatchValue(value=str(owner_id)))]
    if document_ids:
        must.append(models.FieldCondition(
            key="document_id", match=models.MatchAny(any=[str(d) for d in document_ids])
        ))
    result = _client.query_points(
        collection_name=COLLECTION,
        query=query_vector,
        query_filter=models.Filter(must=must),
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
    ]


def delete_document(document_id: UUID) -> None:
    _client.delete(
        collection_name=COLLECTION,
        points_selector=models.FilterSelector(filter=models.Filter(must=[
            models.FieldCondition(key="document_id", match=models.MatchValue(value=str(document_id)))
        ])),
    )
