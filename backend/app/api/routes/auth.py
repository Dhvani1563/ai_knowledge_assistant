from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...core.config import settings
from ...core.database import get_db
from ...core.rate_limit import client_ip, limit_by_ip, rate_limiter
from ...core.security import hash_password, verify_password, create_access_token
from ...models.document import Document
from ...models.user import User
from ...schemas.auth import (
    SignupRequest, LoginRequest, GoogleAuthRequest, FacebookAuthRequest, PhoneAuthRequest,
    AuthResponse, UserOut,
)
from ...services.audit import log_event
from ...services.oauth_service import (
    verify_google_token, verify_facebook_token, verify_firebase_phone_token, OAuthError,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# Every sign-in route is rate limited per IP address (stops password guessing and signup spam).
_ip_limit = [Depends(limit_by_ip("auth", settings.rate_limit_auth_per_minute))]

# After this many failed passwords for one email from one IP, login is paused for a while.
_MAX_FAILED_LOGINS = 5
_LOCKOUT_SECONDS = 900

# Checking a password against a fake hash when the email is unknown makes
# "no such account" take as long as "wrong password", so response time
# cannot be used to discover which emails are registered.
_DUMMY_HASH = hash_password("not-a-real-password")


def _find_by_email(db: Session, email: str) -> User | None:
    return db.query(User).filter(func.lower(User.email) == email.lower()).first()


def _token_response(db: Session, user: User) -> AuthResponse:
    return AuthResponse(access_token=create_access_token(subject=str(user.id)), user=_to_user_out(db, user))


@router.post("/signup", response_model=AuthResponse, dependencies=_ip_limit)
def signup(payload: SignupRequest, request: Request, db: Session = Depends(get_db)):
    email = payload.email.lower()
    if _find_by_email(db, email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with this email already exists.")

    user = User(
        name=payload.name.strip() or email.split("@")[0],
        email=email,
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with this email already exists.")
    db.refresh(user)

    log_event("signup", user_id=user.id, detail="email", request=request)
    return _token_response(db, user)


@router.post("/login", response_model=AuthResponse, dependencies=_ip_limit)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    email = payload.email.lower()
    fail_key = f"loginfail:{email}:{client_ip(request)}"

    if rate_limiter.is_blocked(fail_key, _MAX_FAILED_LOGINS, _LOCKOUT_SECONDS):
        log_event("login_locked", detail="too many failed attempts", request=request)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed attempts. Please wait a few minutes and try again.",
        )

    user = _find_by_email(db, email)

    if user and not user.hashed_password:
        # Account exists but signs in with Google/Facebook/phone — no password to check.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"This account signs in with {user.oauth_provider or 'a social provider'}. Use that button instead.",
        )

    password_ok = verify_password(payload.password, user.hashed_password if user else _DUMMY_HASH)
    if not user or not password_ok:
        rate_limiter.record(fail_key, _LOCKOUT_SECONDS)
        log_event("login_failed", user_id=user.id if user else None, detail="wrong email or password", request=request)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password.")

    rate_limiter.clear(fail_key)
    log_event("login_success", user_id=user.id, detail="email", request=request)
    return _token_response(db, user)


@router.post("/google", response_model=AuthResponse, dependencies=_ip_limit)
def google_login(payload: GoogleAuthRequest, request: Request, db: Session = Depends(get_db)):
    try:
        info = verify_google_token(payload.id_token)
    except OAuthError as exc:
        log_event("login_failed", detail="google token rejected", request=request)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))
    user = _upsert_oauth_user(db, request, provider="google", info=info)
    log_event("login_success", user_id=user.id, detail="google", request=request)
    return _token_response(db, user)


@router.post("/facebook", response_model=AuthResponse, dependencies=_ip_limit)
def facebook_login(payload: FacebookAuthRequest, request: Request, db: Session = Depends(get_db)):
    try:
        info = verify_facebook_token(payload.access_token)
    except OAuthError as exc:
        log_event("login_failed", detail="facebook token rejected", request=request)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))
    user = _upsert_oauth_user(db, request, provider="facebook", info=info)
    log_event("login_success", user_id=user.id, detail="facebook", request=request)
    return _token_response(db, user)


@router.post("/phone", response_model=AuthResponse, dependencies=_ip_limit)
def phone_login(payload: PhoneAuthRequest, request: Request, db: Session = Depends(get_db)):
    try:
        info = verify_firebase_phone_token(payload.id_token)
    except OAuthError as exc:
        log_event("login_failed", detail="phone token rejected", request=request)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))
    user = _upsert_oauth_user(db, request, provider="phone", info=info)
    log_event("login_success", user_id=user.id, detail="phone", request=request)
    return _token_response(db, user)


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _to_user_out(db, current_user)


def _upsert_oauth_user(db: Session, request: Request, provider: str, info: dict) -> User:
    """Find or create the account for a verified social/phone login.

    Account-takeover protection: we only use the provider's email when the
    provider says it is VERIFIED. Otherwise an attacker could register a
    Facebook account with YOUR email address and be merged into YOUR account.

    Pre-hijacking protection: if a verified email matches an account that
    has a password (email signups are not email-verified), the password is
    removed when the accounts are linked. Otherwise someone who signed up
    with your email first would keep a working password to your account.
    """
    email = info["email"].lower() if info.get("email") and info.get("email_verified") else None
    phone = info.get("phone")

    user = (
        db.query(User)
        .filter(User.oauth_provider == provider, User.oauth_id == info["provider_id"])
        .first()
    )
    linked_by = None
    if user is None and email:
        user = _find_by_email(db, email)
        linked_by = "email" if user else None
    if user is None and phone:
        user = db.query(User).filter(User.phone == phone).first()
        linked_by = "phone" if user else None

    if user is None:
        user = User(
            name=info["name"],
            email=email,
            phone=phone,
            hashed_password=None,
            oauth_provider=provider,
            oauth_id=info["provider_id"],
            avatar_url=info.get("avatar_url"),
        )
        db.add(user)
        action = "signup"
    else:
        if linked_by == "email" and user.hashed_password:
            user.hashed_password = None
            log_event("password_cleared_on_link", user_id=user.id, detail=f"linked {provider} by verified email", request=request)
        user.oauth_provider = user.oauth_provider or provider
        user.oauth_id = user.oauth_id or info["provider_id"]
        user.avatar_url = info.get("avatar_url") or user.avatar_url
        user.phone = user.phone or phone
        action = "account_linked" if linked_by else None

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This account could not be created because it conflicts with an existing one.")
    db.refresh(user)
    if action:
        log_event(action, user_id=user.id, detail=provider, request=request)
    return user


def _to_user_out(db: Session, user: User) -> UserOut:
    doc_count = db.query(Document).filter(Document.owner_id == user.id).count()
    return UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        phone=user.phone,
        avatar_url=user.avatar_url,
        oauth_provider=user.oauth_provider,
        created_at=user.created_at,
        document_count=doc_count,
        query_count=0,
    )
