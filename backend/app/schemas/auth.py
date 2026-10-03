from pydantic import BaseModel, EmailStr, Field
from uuid import UUID
from datetime import datetime
from typing import Optional


class SignupRequest(BaseModel):
    name: str = Field(min_length=1)
    email: EmailStr
    password: str = Field(min_length=6)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str  # from google_sign_in's GoogleSignInAuthentication.idToken


class FacebookAuthRequest(BaseModel):
    access_token: str  # from flutter_facebook_auth's LoginResult.accessToken


class UserOut(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    avatar_url: Optional[str] = None
    oauth_provider: Optional[str] = None
    created_at: datetime
    document_count: int = 0
    query_count: int = 0

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
