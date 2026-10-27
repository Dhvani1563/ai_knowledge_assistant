from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...core.config import settings
from ...core.database import get_db
from ...core.rate_limit import rate_limiter
from ...models.chat import ChatSession, ChatMessage, MessageSender, QuestionType
from ...models.user import User
from ...schemas.chat import (
    SendMessageRequest, SendMessageResponse, ChatSessionOut, ChatSessionSummary,
)
from ...services.access_control import permitted_document_ids
from ...services.audit import log_event
from ...services.llm_service import LLMError
from ...services.rag_pipeline import answer_question

router = APIRouter(prefix="/chat", tags=["chat"])


def _own_session(db: Session, session_id: UUID, user: User) -> ChatSession:
    """A chat belongs to exactly one user; anyone else gets 'not found'."""
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.owner_id == user.id)
        .first()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="Conversation not found.")
    return session


@router.get("/sessions", response_model=list[ChatSessionSummary])
def list_sessions(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sessions = (
        db.query(ChatSession)
        .filter(ChatSession.owner_id == current_user.id)
        .order_by(ChatSession.updated_at.desc())
        .all()
    )
    summaries = []
    for s in sessions:
        last = s.messages[-1].text if s.messages else "No messages yet"
        summaries.append(ChatSessionSummary(
            id=s.id, title=s.title, updated_at=s.updated_at,
            last_message_preview=(last[:64] + "…") if len(last) > 64 else last,
        ))
    return summaries


@router.get("/sessions/{session_id}", response_model=ChatSessionOut)
def get_session(session_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _own_session(db, session_id, current_user)


@router.delete("/sessions/{session_id}", status_code=204)
def delete_session(session_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    session = _own_session(db, session_id, current_user)
    db.delete(session)
    db.commit()


@router.post("/message", response_model=SendMessageResponse)
def send_message(
    payload: SendMessageRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(f"chat:{current_user.id}", settings.rate_limit_chat_per_minute)

    # 1. AUTHORIZATION FIRST: work out which documents this user may search.
    #    Anything the client asks for beyond that is silently dropped.
    requested = list(payload.document_ids)
    scope: list[UUID] | None = None
    if requested:
        scope = permitted_document_ids(db, current_user.id, requested)
        if not scope:
            raise HTTPException(status_code=404, detail="None of the selected documents are available to you.")

    # 2. Reuse an existing chat, or start a new one on the first message
    if payload.session_id:
        session = _own_session(db, payload.session_id, current_user)
    else:
        title = payload.text[:40] + ("…" if len(payload.text) > 40 else "")
        session = ChatSession(owner_id=current_user.id, title=title, document_ids=scope or [])
        db.add(session)
        db.commit()
        db.refresh(session)

    if scope is None:
        saved = list(session.document_ids or [])
        scope = permitted_document_ids(db, current_user.id, saved) if saved else []
        if not scope:  # nothing saved, or the saved documents are no longer accessible
            scope = permitted_document_ids(db, current_user.id)

    # last few turns give the model context for follow-up questions
    history = [(m.sender.value, m.text) for m in session.messages[-6:]]

    user_message = ChatMessage(session_id=session.id, sender=MessageSender.user, text=payload.text)
    db.add(user_message)
    db.commit()

    # 3. classify -> retrieve (permitted documents only) -> generate -> sanitize
    try:
        result = answer_question(permitted_ids=scope, question=payload.text, history=history)
    except LLMError as exc:
        raise HTTPException(status_code=502, detail=f"The AI model is unavailable right now. {exc}")

    assistant_message = ChatMessage(
        session_id=session.id,
        sender=MessageSender.assistant,
        text=result.answer,
        question_type=QuestionType(result.question_type),
        sources=result.sources,
    )
    db.add(assistant_message)
    db.commit()
    db.refresh(session)
    db.refresh(assistant_message)

    # Log that a question was asked, never what it said.
    log_event(
        "chat_query", user_id=current_user.id, resource_type="chat", resource_id=session.id,
        detail=f"type={result.question_type}; documents_searched={len(scope)}; sources={len(result.sources)}",
        request=request,
    )
    return SendMessageResponse(session=session, reply=assistant_message)
