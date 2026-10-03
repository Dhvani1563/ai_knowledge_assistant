from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..deps import get_current_user
from ...core.database import get_db
from ...models.user import User
from ...models.chat import ChatSession, ChatMessage, MessageSender, QuestionType
from ...schemas.chat import (
    SendMessageRequest, SendMessageResponse, ChatSessionOut, ChatSessionSummary,
)
from ...services.rag_pipeline import answer_question
from ...services.llm_service import LLMError

router = APIRouter(prefix="/chat", tags=["chat"])


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
def get_session(session_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.owner_id == current_user.id)
        .first()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="Conversation not found.")
    return session


@router.delete("/sessions/{session_id}", status_code=204)
def delete_session(session_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.owner_id == current_user.id)
        .first()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="Conversation not found.")
    db.delete(session)
    db.commit()


@router.post("/message", response_model=SendMessageResponse)
def send_message(
    payload: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Reuse an existing session, or start a new one on the first message
    if payload.session_id:
        session = (
            db.query(ChatSession)
            .filter(ChatSession.id == payload.session_id, ChatSession.owner_id == current_user.id)
            .first()
        )
        if session is None:
            raise HTTPException(status_code=404, detail="Conversation not found.")
    else:
        title = payload.text[:40] + ("…" if len(payload.text) > 40 else "")
        session = ChatSession(owner_id=current_user.id, title=title, document_ids=payload.document_ids)
        db.add(session)
        db.commit()
        db.refresh(session)

    # last few turns give the model context for follow-up questions
    history = [(m.sender.value, m.text) for m in session.messages[-6:]]

    user_message = ChatMessage(session_id=session.id, sender=MessageSender.user, text=payload.text)
    db.add(user_message)
    db.commit()

    # classify -> retrieve (Qdrant) -> generate (LLM); see services/rag_pipeline.py
    try:
        result = answer_question(
            owner_id=current_user.id,
            question=payload.text,
            document_ids=payload.document_ids or session.document_ids or None,
            history=history,
        )
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

    return SendMessageResponse(session=session, reply=assistant_message)
