from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import datetime
from typing import Optional
from ..models.document import DocumentStatus


class DocumentOut(BaseModel):
    id: UUID
    name: str
    file_type: str
    size_bytes: int
    category: Optional[str] = None
    status: DocumentStatus
    stage: Optional[str] = None
    page_count: int
    chunk_count: int
    error_message: Optional[str] = None
    uploaded_at: datetime
    # Security info
    is_encrypted: bool = False
    flagged_chunks: int = 0
    access_role: str = "owner"          # "owner" or "viewer" (shared with you)
    shared_by: Optional[str] = None     # owner's name, when access_role == "viewer"

    class Config:
        from_attributes = True


class DocumentListResponse(BaseModel):
    documents: list[DocumentOut]
    total_chunks: int


class ShareRequest(BaseModel):
    email: EmailStr


class ShareOut(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    email: Optional[str] = None
    role: str
    created_at: datetime
