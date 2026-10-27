"""Security audit trail: who did what, when, from where.

Entries are written with their OWN database session, so a problem in the
request that triggered the log (or a rollback) can never erase the record,
and a logging failure can never break the request.
Never pass passwords, tokens or document text as `detail`.
"""
import logging
from uuid import UUID

from fastapi import Request

from ..core.database import SessionLocal
from ..core.rate_limit import client_ip
from ..models.security import AuditLog

logger = logging.getLogger(__name__)


def log_event(
    action: str,
    user_id: UUID | None = None,
    resource_type: str | None = None,
    resource_id: object | None = None,
    detail: str | None = None,
    request: Request | None = None,
) -> None:
    try:
        with SessionLocal() as session:
            session.add(AuditLog(
                user_id=user_id,
                action=action,
                resource_type=resource_type,
                resource_id=str(resource_id) if resource_id is not None else None,
                detail=(detail or "")[:300] or None,
                ip_address=client_ip(request) if request is not None else None,
            ))
            session.commit()
    except Exception:  # noqa: BLE001
        logger.exception("Could not write audit log entry %r", action)
