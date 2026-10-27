from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...core.database import get_db
from ...models.security import AuditLog
from ...models.user import User

router = APIRouter(prefix="/security", tags=["security"])


class AuditEntryOut(BaseModel):
    id: UUID
    action: str
    resource_type: Optional[str] = None
    resource_id: Optional[str] = None
    detail: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("/activity", response_model=list[AuditEntryOut])
def my_security_activity(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The signed-in user's OWN recent security events: logins (including
    failed attempts against their account), uploads, shares, denied accesses.
    Nobody can read anyone else's trail through this endpoint."""
    return (
        db.query(AuditLog)
        .filter(AuditLog.user_id == current_user.id)
        .order_by(AuditLog.created_at.desc())
        .limit(limit)
        .all()
    )
