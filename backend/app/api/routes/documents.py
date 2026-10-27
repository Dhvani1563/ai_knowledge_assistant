import logging
import os
import uuid
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...core.config import settings
from ...core.database import get_db
from ...core.rate_limit import rate_limiter
from ...models.document import Document, DocumentStatus
from ...models.security import DocumentShare
from ...models.user import User
from ...schemas.document import DocumentListResponse, DocumentOut, ShareOut, ShareRequest
from ...services import vector_store
from ...services.access_control import require_document, scrub_document_from_history
from ...services.audit import log_event
from ...services.file_security import (
    UploadRejected, encrypt_file, restrict_permissions, sanitize_display_name,
    validate_head, validate_saved_file,
)
from ...services.ingestion import process_document

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/documents", tags=["documents"])

ALLOWED_EXTENSIONS = {"pdf", "docx", "txt", "md"}


def _to_out(document: Document, role: str, shared_by: str | None = None) -> DocumentOut:
    out = DocumentOut.model_validate(document)
    out.access_role = role
    out.shared_by = shared_by
    return out


def _share_out(share: DocumentShare, user: User) -> ShareOut:
    return ShareOut(
        id=share.id, user_id=user.id, name=user.name, email=user.email,
        role=share.role, created_at=share.created_at,
    )


def _remove_file(path: str) -> None:
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


@router.post("/upload", response_model=DocumentOut, status_code=status.HTTP_201_CREATED)
def upload_document(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(f"upload:{current_user.id}", settings.rate_limit_upload_per_minute)

    display_name = sanitize_display_name(file.filename)
    extension = display_name.rsplit(".", 1)[-1].lower() if "." in display_name else ""
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: .{extension or '?'}")

    # Check what the file REALLY is from its first bytes, before saving anything.
    head = file.file.read(8192)
    file.file.seek(0)
    try:
        validate_head(extension, head)
    except UploadRejected as exc:
        log_event("upload_rejected", user_id=current_user.id, detail=str(exc), request=request)
        raise HTTPException(status_code=400, detail=str(exc))

    os.makedirs(settings.upload_dir, exist_ok=True)
    path = os.path.join(settings.upload_dir, f"{uuid.uuid4()}.{extension}")  # random name: no path tricks possible
    max_bytes = settings.max_upload_mb * 1024 * 1024
    size = 0
    try:
        with open(path, "wb") as out:
            while chunk := file.file.read(1024 * 1024):
                size += len(chunk)
                if size > max_bytes:
                    raise UploadRejected(f"File exceeds the {settings.max_upload_mb} MB limit.")
                out.write(chunk)
        validate_saved_file(path, extension)
        restrict_permissions(path)
        encrypted = encrypt_file(path)  # no-op unless FILE_ENCRYPTION_KEY is set
    except UploadRejected as exc:
        _remove_file(path)
        log_event("upload_rejected", user_id=current_user.id, detail=str(exc), request=request)
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        _remove_file(path)
        raise

    document = Document(
        owner_id=current_user.id,
        name=display_name,
        file_type=extension,
        file_path=path,
        size_bytes=size,
        status=DocumentStatus.uploading,
        is_encrypted=encrypted,
    )
    db.add(document)
    db.commit()
    db.refresh(document)

    background_tasks.add_task(process_document, document.id)
    log_event(
        "document_upload", user_id=current_user.id, resource_type="document", resource_id=document.id,
        detail=f"{extension}, {size} bytes, encrypted={encrypted}", request=request,
    )
    return _to_out(document, "owner")


@router.get("", response_model=DocumentListResponse)
def list_documents(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owned = db.query(Document).filter(Document.owner_id == current_user.id).all()
    shared = (
        db.query(Document, User.name)
        .select_from(Document)
        .join(DocumentShare, DocumentShare.document_id == Document.id)
        .join(User, User.id == Document.owner_id)
        .filter(DocumentShare.user_id == current_user.id)
        .all()
    )
    items = [(d, "owner", None) for d in owned] + [(d, "viewer", owner_name) for d, owner_name in shared]
    items.sort(key=lambda item: item[0].uploaded_at, reverse=True)
    return DocumentListResponse(
        documents=[_to_out(d, role, by) for d, role, by in items],
        total_chunks=sum(d.chunk_count or 0 for d, _, _ in items),
    )


@router.get("/{document_id}", response_model=DocumentOut)
def get_document(document_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    document, role = require_document(db, current_user.id, document_id)
    shared_by = None
    if role != "owner":
        owner = db.query(User).filter(User.id == document.owner_id).first()
        shared_by = owner.name if owner else None
    return _to_out(document, role, shared_by)


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(
    document_id: UUID, request: Request,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    document, _ = require_document(db, current_user.id, document_id, owner_only=True)
    file_path = document.file_path

    try:
        vector_store.delete_document(document.id)           # 1. remove its passages from the vector database
    except Exception:  # noqa: BLE001
        # Safe to continue: search only ever looks inside documents the
        # DATABASE says a user may access, so leftover vectors of a deleted
        # document can never be returned to anyone.
        logger.warning("Could not remove vectors for %s; they are unreachable anyway.", document.id)
    scrub_document_from_history(db, document.id)             # 2. saved chat excerpts of it are removed for everyone
    db.delete(document)                                      # 3. metadata and share rows go
    db.commit()
    _remove_file(file_path)                                  # 4. the stored file goes
    log_event("document_delete", user_id=current_user.id, resource_type="document", resource_id=document_id, request=request)


# ── Sharing ───────────────────────────────────────────────────────────────

@router.get("/{document_id}/shares", response_model=list[ShareOut])
def list_shares(document_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    document, _ = require_document(db, current_user.id, document_id, owner_only=True)
    rows = (
        db.query(DocumentShare, User)
        .select_from(DocumentShare)
        .join(User, User.id == DocumentShare.user_id)
        .filter(DocumentShare.document_id == document.id)
        .order_by(DocumentShare.created_at)
        .all()
    )
    return [_share_out(share, user) for share, user in rows]


@router.post("/{document_id}/shares", response_model=ShareOut, status_code=status.HTTP_201_CREATED)
def share_document(
    document_id: UUID, payload: ShareRequest, request: Request,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    rate_limiter.check(f"share:{current_user.id}", settings.rate_limit_share_per_minute)
    document, _ = require_document(db, current_user.id, document_id, owner_only=True)

    target = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if target is None:
        raise HTTPException(status_code=404, detail="We couldn't find an Archive user with that email.")
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail="You already own this document.")

    share = (
        db.query(DocumentShare)
        .filter(DocumentShare.document_id == document.id, DocumentShare.user_id == target.id)
        .first()
    )
    if share is None:
        share = DocumentShare(document_id=document.id, user_id=target.id, role="viewer", granted_by=current_user.id)
        db.add(share)
        db.commit()
        db.refresh(share)
        log_event(
            "document_share", user_id=current_user.id, resource_type="document", resource_id=document.id,
            detail=f"granted viewer access to user {target.id}", request=request,
        )
    return _share_out(share, target)


@router.delete("/{document_id}/shares/{share_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_share(
    document_id: UUID, share_id: UUID, request: Request,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    document, _ = require_document(db, current_user.id, document_id, owner_only=True)
    share = (
        db.query(DocumentShare)
        .filter(DocumentShare.id == share_id, DocumentShare.document_id == document.id)
        .first()
    )
    if share is None:
        raise HTTPException(status_code=404, detail="Share not found.")

    grantee_id = share.user_id
    scrub_document_from_history(db, document.id, user_id=grantee_id)  # remove saved excerpts from THEIR chats
    db.delete(share)
    db.commit()  # from this moment permitted_document_ids() no longer includes the document for them
    log_event(
        "document_unshare", user_id=current_user.id, resource_type="document", resource_id=document.id,
        detail=f"revoked access from user {grantee_id}", request=request,
    )
