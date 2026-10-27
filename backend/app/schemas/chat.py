from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional
from ..models.chat import MessageSender, QuestionType


class SourceReferenceOut(BaseModel):
    document_id: str
    document_name: str
    page_number: int
    excerpt: str
    relevance_score: float


class SendMessageRequest(BaseModel):
    session_id: Optional[UUID] = None  # omit to create a new session
    # Length limits stop prompt-stuffing and runaway AI costs
    text: str = Field(min_length=1, max_length=2000)
    # optional scope; empty = search every document the user may access
    document_ids: list[UUID] = Field(default_factory=list, max_length=50)


class ChatMessageOut(BaseModel):
    id: UUID
    sender: MessageSender
    text: str
    question_type: Optional[QuestionType] = None
    sources: list[SourceReferenceOut] = []
    created_at: datetime

    class Config:
        from_attributes = True


class ChatSessionOut(BaseModel):
    id: UUID
    title: str
    document_ids: list[UUID] = []
    created_at: datetime
    updated_at: datetime
    messages: list[ChatMessageOut] = []

    class Config:
        from_attributes = True


class ChatSessionSummary(BaseModel):
    id: UUID
    title: str
    updated_at: datetime
    last_message_preview: str


class SendMessageResponse(BaseModel):
    session: ChatSessionOut
    reply: ChatMessageOut
