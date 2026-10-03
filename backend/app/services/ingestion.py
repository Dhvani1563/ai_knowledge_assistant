"""Ingestion pipeline: file -> text -> chunks -> embeddings -> Qdrant.

Runs as a FastAPI BackgroundTask. It opens its OWN database session,
because the request-scoped session is closed once the HTTP response is
sent. `stage` is written to Postgres at each step so the Flutter app can
show real progress while polling GET /documents/{id}.
"""
import logging
from uuid import UUID

from ..core.database import SessionLocal
from ..models.document import Document, DocumentStatus
from . import vector_store
from .chunker import chunk_pages
from .document_loader import load_document
from .embedder import embed_passages

logger = logging.getLogger(__name__)


def _set_stage(db, document: Document, stage: str) -> None:
    document.stage = stage
    db.commit()


def process_document(document_id: UUID) -> None:
    db = SessionLocal()
    try:
        document = db.query(Document).filter(Document.id == document_id).first()
        if document is None:
            return
        try:
            document.status = DocumentStatus.processing
            _set_stage(db, document, "Extracting text")
            pages = load_document(document.file_path, document.file_type)

            _set_stage(db, document, "Splitting into chunks")
            chunks = chunk_pages(pages)
            if not chunks:
                raise ValueError("The document produced no usable text chunks.")

            _set_stage(db, document, f"Creating embeddings ({len(chunks)} chunks)")
            vectors = embed_passages([c.text for c in chunks])

            _set_stage(db, document, "Indexing in vector database")
            vector_store.upsert_chunks(document.owner_id, document.id, document.name, chunks, vectors)

            document.page_count = len(pages)
            document.chunk_count = len(chunks)
            document.status = DocumentStatus.ready
            document.stage = "Ready"
            document.error_message = None
            db.commit()
        except Exception as exc:  # noqa: BLE001
            logger.exception("Ingestion failed for %s", document_id)
            try:
                vector_store.delete_document(document_id)  # never leave half-indexed docs
            except Exception:  # noqa: BLE001
                pass
            document.status = DocumentStatus.failed
            document.stage = "Failed"
            document.error_message = str(exc)[:500]
            db.commit()
    finally:
        db.close()
