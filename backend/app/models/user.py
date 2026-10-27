import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..core.database import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("oauth_provider", "oauth_id", name="uq_oauth_provider_id"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    # Nullable: a phone-only account (Firebase OTP) has no email at all.
    # Postgres allows multiple NULLs in a UNIQUE column, so this doesn't
    # weaken uniqueness for accounts that DO have an email.
    email = Column(String, unique=True, nullable=True, index=True)
    # Nullable now: an account created via Google/Facebook has no password —
    # they authenticate with a provider token instead. See auth.py's
    # login() for the guard that handles this at sign-in time.
    hashed_password = Column(String, nullable=True)
    oauth_provider = Column(String, nullable=True)  # "google" | "facebook" | "phone" | None
    oauth_id = Column(String, nullable=True)
    avatar_url = Column(String, nullable=True)
    phone = Column(String, nullable=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    documents = relationship("Document", back_populates="owner", cascade="all, delete-orphan")
    chat_sessions = relationship("ChatSession", back_populates="owner", cascade="all, delete-orphan")

