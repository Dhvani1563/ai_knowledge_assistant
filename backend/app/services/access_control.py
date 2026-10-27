"""AUTHORIZATION: deciding what an already-identified user may touch.

Authentication (auth.py) answers "who are you?". This file answers "are you
allowed to do that to THIS document?". The rules, in one place:

  owner   created the document: read, ask questions, share, unshare, delete
  viewer  was granted access by the owner: read + ask questions only
  nobody else: the document does not exist as far as they can tell (we
           answer 404, never 403, so strangers cannot probe for document IDs)

The most important function is permitted_document_ids(): the chat pipeline
asks it "which documents may this user search?" BEFORE any retrieval, and
the vector database is then told to search ONLY those documents. Permissions
are enforced before retrieval, not by hiding results afterwards.
"""
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ..models.chat import ChatMessage, ChatSession
from ..models.document import Document, DocumentStatus
from ..models.security import DocumentShare
from .audit import log_event


def require_document(
    db: Session, user_id: UUID, document_id: UUID, owner_only: bool = False,
) -> tuple[Document, str]:
    """Returns (document, role) or raises. Role is "owner" or "viewer"."""
    document = db.query(Document).filter(Document.id == document_id).first()
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found.")

    if document.owner_id == user_id:
        return document, "owner"

    share = (
        db.query(DocumentShare)
        .filter(DocumentShare.document_id == document.id, DocumentShare.user_id == user_id)
        .first()
    )
    if share is None:
        log_event("access_denied", user_id=user_id, resource_type="document", resource_id=document_id)
        raise HTTPException(status_code=404, detail="Document not found.")  # same answer as "doesn't exist"

    if owner_only:
        raise HTTPException(status_code=403, detail="Only the owner of this document can do that.")
    return document, share.role


def permitted_document_ids(
    db: Session, user_id: UUID, requested: list[UUID] | None = None,
) -> list[UUID]:
    """IDs of READY documents this user may search: their own + shared with them.

    If `requested` is given, only the permitted subset of it is returned, so a
    client can never widen its own access by sending extra document IDs.
    """
    owned = [
        row[0] for row in
        db.query(Document.id)
        .filter(Document.owner_id == user_id, Document.status == DocumentStatus.ready)
        .all()
    ]
    shared = [
        row[0] for row in
        db.query(Document.id)
        .join(DocumentShare, DocumentShare.document_id == Document.id)
        .filter(DocumentShare.user_id == user_id, Document.status == DocumentStatus.ready)
        .all()
    ]
    allowed = list(dict.fromkeys(owned + shared))  # de-duplicated, order kept

    if requested:
        wanted = set(requested)
        result = [doc_id for doc_id in allowed if doc_id in wanted]
        if len(result) < len(wanted):
            log_event(
                "access_denied", user_id=user_id, resource_type="document",
                detail=f"asked to search {len(wanted)} documents, permitted {len(result)}",
            )
        return result
    return allowed


def scrub_document_from_history(db: Session, document_id: UUID, user_id: UUID | None = None) -> int:
    """Remove a document's excerpts from saved chat history.

    Chat messages store the source passages they cited. When a document is
    deleted, or access to it is revoked, those saved excerpts would otherwise
    keep showing text the person is no longer allowed to see.
      user_id given -> only that person's chats (used when revoking one share)
      user_id None  -> everyone's chats (used when the document is deleted)
    Caller must commit. Returns how many messages were changed.

    Honest limit: the *wording of past answers* may still reflect what the
    person read; software cannot make someone un-read something.
    """
    marker = [{"document_id": str(document_id)}]
    query = db.query(ChatMessage).filter(ChatMessage.sources.contains(marker))
    if user_id is not None:
        query = (
            query.join(ChatSession, ChatSession.id == ChatMessage.session_id)
            .filter(ChatSession.owner_id == user_id)
        )
    changed = 0
    for message in query.all():
        current = message.sources or []
        kept = [s for s in current if s.get("document_id") != str(document_id)]
        if len(kept) != len(current):
            message.sources = kept  # assign a NEW list so SQLAlchemy notices the change
            changed += 1
    return changed
