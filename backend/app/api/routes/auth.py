from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..deps import get_current_user
from ...core.database import get_db
from ...core.security import hash_password, verify_password, create_access_token
from ...models.user import User
from ...models.document import Document
from ...schemas.auth import (
    SignupRequest, LoginRequest, GoogleAuthRequest, FacebookAuthRequest,
    AuthResponse, UserOut,
)
from ...services.oauth_service import verify_google_token, verify_facebook_token, OAuthError

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=AuthResponse)
def signup(payload: SignupRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with this email already exists.")

    user = User(name=payload.name, email=payload.email, hashed_password=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(subject=str(user.id))
    return AuthResponse(access_token=token, user=_to_user_out(db, user))


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()

    if user and not user.hashed_password:
        # Account exists but was created via Google/Facebook — there's no
        # password to check against.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"This account signs in with {user.oauth_provider or 'a social provider'}. Use that button instead.",
        )

    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password.")

    token = create_access_token(subject=str(user.id))
    return AuthResponse(access_token=token, user=_to_user_out(db, user))


@router.post("/google", response_model=AuthResponse)
def google_login(payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        info = verify_google_token(payload.id_token)
    except OAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    user = _upsert_oauth_user(db, provider="google", info=info)
    token = create_access_token(subject=str(user.id))
    return AuthResponse(access_token=token, user=_to_user_out(db, user))


@router.post("/facebook", response_model=AuthResponse)
def facebook_login(payload: FacebookAuthRequest, db: Session = Depends(get_db)):
    try:
        info = verify_facebook_token(payload.access_token)
    except OAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    user = _upsert_oauth_user(db, provider="facebook", info=info)
    token = create_access_token(subject=str(user.id))
    return AuthResponse(access_token=token, user=_to_user_out(db, user))


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _to_user_out(db, current_user)


def _upsert_oauth_user(db: Session, provider: str, info: dict) -> User:
    """Finds an existing user for this provider+id, or links/creates one.

    If someone already has an email/password account and later signs in
    with Google using the same email, we link the provider to that
    existing account rather than creating a duplicate — same person, one
    row, so their documents and chat history stay attached to one account
    either way they log in.
    """
    user = (
        db.query(User)
        .filter(User.oauth_provider == provider, User.oauth_id == info["provider_id"])
        .first()
    )

    if user is None and info.get("email"):
        user = db.query(User).filter(User.email == info["email"]).first()

    if user is None:
        if not info.get("email"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Your {provider} account has no email to sign up with.",
            )
        user = User(
            name=info["name"],
            email=info["email"],
            hashed_password=None,
            oauth_provider=provider,
            oauth_id=info["provider_id"],
            avatar_url=info.get("avatar_url"),
        )
        db.add(user)
    else:
        user.oauth_provider = user.oauth_provider or provider
        user.oauth_id = user.oauth_id or info["provider_id"]
        user.avatar_url = info.get("avatar_url") or user.avatar_url

    db.commit()
    db.refresh(user)
    return user


def _to_user_out(db: Session, user: User) -> UserOut:
    doc_count = db.query(Document).filter(Document.owner_id == user.id).count()
    return UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        avatar_url=user.avatar_url,
        oauth_provider=user.oauth_provider,
        created_at=user.created_at,
        document_count=doc_count,
        query_count=0,
    )
