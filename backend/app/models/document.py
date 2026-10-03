import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Enum, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..core.database import Base


class DocumentStatus(str, enum.Enum):
    uploading = "uploading"
    processing = "processing"
    ready = "ready"
    failed = "failed"


class Document(Base):
    """Document *metadata* lives in PostgreSQL. The chunk text + embedding
    vectors live in Qdrant (see services/vector_store.py), keyed by
    document_id in each point's payload."""
    __tablename__ = "documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    file_type = Column(String, nullable=False)  # pdf, docx, txt, md
    file_path = Column(String, nullable=False)
    size_bytes = Column(Integer, default=0)
    category = Column(String, nullable=True)
    status = Column(Enum(DocumentStatus), default=DocumentStatus.uploading, nullable=False)
    stage = Column(String, nullable=True)  # human-readable pipeline step for the UI
    page_count = Column(Integer, default=0)
    chunk_count = Column(Integer, default=0)
    error_message = Column(Text, nullable=True)
    uploaded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    owner = relationship("User", back_populates="documents")
