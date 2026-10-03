import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Enum, Float, Integer, ARRAY
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import enum
from ..core.database import Base


class MessageSender(str, enum.Enum):
    user = "user"
    assistant = "assistant"


class QuestionType(str, enum.Enum):
    factual = "factual"
    summarization = "summarization"
    comparison = "comparison"
    retrieval = "retrieval"


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    title = Column(String, default="New conversation")
    document_ids = Column(ARRAY(UUID(as_uuid=True)), default=list)  # scope, empty = all docs
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    owner = relationship("User", back_populates="chat_sessions")
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan", order_by="ChatMessage.created_at")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("chat_sessions.id"), nullable=False)
    sender = Column(Enum(MessageSender), nullable=False)
    text = Column(Text, nullable=False)
    question_type = Column(Enum(QuestionType), nullable=True)  # set on assistant messages only
    sources = Column(JSONB, default=list)  # [{document_id, document_name, page_number, excerpt, relevance_score}]
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    session = relationship("ChatSession", back_populates="messages")
