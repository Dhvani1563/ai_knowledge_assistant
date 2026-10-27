"""Ingestion pipeline: file -> text -> chunks -> security scan -> embeddings -> Qdrant.

Runs as a FastAPI BackgroundTask with its OWN database session (the request's
session is closed once the HTTP response is sent). `stage` is written to
Postgres at each step so the app can show real progress.

Security steps added here:
  * encrypted uploads are decrypted into a temporary file that is deleted
    immediately after parsing
  * invisible characters are stripped from every chunk
  * chunks that read like hidden instructions to an AI are FLAGGED and
    quarantined (stored, but never returned by search)
"""
import logging
from uuid import UUID

from ..core.database import SessionLocal
from ..models.document import Document, DocumentStatus
from . import vector_store
from .audit import log_event
from .chunker import chunk_pages
from .document_loader import load_document
from .embedder import embed_passages
from .file_security import decrypted_copy
from .prompt_safety import scan_text, strip_invisible

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
            if document.is_encrypted:
                with decrypted_copy(document.file_path, document.file_type) as plain_path:
                    pages = load_document(plain_path, document.file_type)
            else:
                pages = load_document(document.file_path, document.file_type)

            _set_stage(db, document, "Splitting into chunks")
            chunks = chunk_pages(pages)
            if not chunks:
                raise ValueError("The document produced no usable text chunks.")

            _set_stage(db, document, "Scanning for hidden instructions")
            flags: list[bool] = []
            for chunk in chunks:
                chunk.text = strip_invisible(chunk.text)
                flags.append(bool(scan_text(chunk.text)))
            flagged = sum(flags)

            _set_stage(db, document, f"Creating embeddings ({len(chunks)} chunks)")
            vectors = embed_passages([c.text for c in chunks])

            _set_stage(db, document, "Indexing in vector database")
            vector_store.upsert_chunks(document.owner_id, document.id, document.name, chunks, vectors, flags)

            document.page_count = len(pages)
            document.chunk_count = len(chunks)
            document.flagged_chunks = flagged
            document.status = DocumentStatus.ready
            document.stage = "Ready" if not flagged else f"Ready ({flagged} suspicious passages quarantined)"
            document.error_message = None
            db.commit()

            if flagged:
                log_event(
                    "document_flagged", user_id=document.owner_id, resource_type="document",
                    resource_id=document.id, detail=f"{flagged} passage(s) quarantined as possible prompt injection",
                )
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
