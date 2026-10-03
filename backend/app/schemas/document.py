from pydantic import BaseModel
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

    class Config:
        from_attributes = True


class DocumentListResponse(BaseModel):
    documents: list[DocumentOut]
    total_chunks: int
