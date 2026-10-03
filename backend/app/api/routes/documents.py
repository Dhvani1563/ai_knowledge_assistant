import os
import uuid
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, BackgroundTasks, status
from sqlalchemy.orm import Session
from ..deps import get_current_user
from ...core.database import get_db
from ...core.config import settings
from ...models.user import User
from ...models.document import Document, DocumentStatus
from ...schemas.document import DocumentOut, DocumentListResponse
from ...services.ingestion import process_document
from ...services import vector_store

router = APIRouter(prefix="/documents", tags=["documents"])

ALLOWED_EXTENSIONS = {"pdf", "docx", "txt", "md"}
MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024


@router.post("/upload", response_model=DocumentOut, status_code=status.HTTP_201_CREATED)
def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    extension = (file.filename.rsplit(".", 1)[-1] if "." in file.filename else "").lower()
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: .{extension}")

    os.makedirs(settings.upload_dir, exist_ok=True)
    stored_name = f"{uuid.uuid4()}.{extension}"
    file_path = os.path.join(settings.upload_dir, stored_name)

    size_bytes = 0
    with open(file_path, "wb") as out:
        while chunk := file.file.read(1024 * 1024):
            size_bytes += len(chunk)
            if size_bytes > MAX_FILE_SIZE_BYTES:
                out.close()
                os.remove(file_path)
                raise HTTPException(status_code=400, detail="File exceeds the 25 MB limit.")
            out.write(chunk)

    document = Document(
        owner_id=current_user.id,
        name=file.filename,
        file_type=extension,
        file_path=file_path,
        size_bytes=size_bytes,
        status=DocumentStatus.uploading,
    )
    db.add(document)
    db.commit()
    db.refresh(document)

    # Runs after the response is sent — the client polls GET /documents (or
    # GET /documents/{id}) to watch status move to "ready".
    background_tasks.add_task(process_document, document.id)

    return document


@router.get("", response_model=DocumentListResponse)
def list_documents(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    documents = (
        db.query(Document)
        .filter(Document.owner_id == current_user.id)
        .order_by(Document.uploaded_at.desc())
        .all()
    )
    total_chunks = sum(d.chunk_count for d in documents)
    return DocumentListResponse(documents=documents, total_chunks=total_chunks)


@router.get("/{document_id}", response_model=DocumentOut)
def get_document(document_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    document = (
        db.query(Document)
        .filter(Document.id == document_id, Document.owner_id == current_user.id)
        .first()
    )
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found.")
    return document


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(document_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    document = (
        db.query(Document)
        .filter(Document.id == document_id, Document.owner_id == current_user.id)
        .first()
    )
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found.")

    try:
        vector_store.delete_document(document.id)  # remove this document's vectors from Qdrant
    except Exception:  # noqa: BLE001
        pass

    if os.path.exists(document.file_path):
        try:
            os.remove(document.file_path)
        except OSError:
            pass  # non-fatal — the DB record  is the source of truth

    db.delete(document)
    db.commit()
