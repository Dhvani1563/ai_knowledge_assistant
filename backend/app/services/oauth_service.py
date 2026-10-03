import httpx
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from ..core.config import settings


class OAuthError(Exception):
    """Raised whenever a provider token fails verification — never trust a
    token the client hands you without checking it against the provider."""


def verify_google_token(id_token_str: str) -> dict:
    """Verifies a Google ID token's signature, expiry, and audience.

    Critically, this checks the token was issued *for this app*
    (GOOGLE_CLIENT_ID) and signed by Google — the frontend cannot forge
    this, which is exactly why we verify server-side instead of trusting
    whatever profile info the client claims.
    """
    try:
        payload = google_id_token.verify_oauth2_token(
            id_token_str, google_requests.Request(), settings.google_client_id
        )
    except ValueError as exc:
        raise OAuthError(f"Invalid Google token: {exc}") from exc

    if payload.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise OAuthError("Token was not issued by Google.")

    return {
        "provider_id": payload["sub"],
        "email": payload.get("email"),
        "name": payload.get("name") or (payload.get("email", "").split("@")[0]),
        "avatar_url": payload.get("picture"),
    }


def verify_facebook_token(access_token: str) -> dict:
    """Validates a Facebook access token via the debug_token endpoint using
    the app's own secret (proves the token was issued for OUR app, not
    copy-pasted from somewhere else), then fetches the profile.
    """
    app_token = f"{settings.facebook_app_id}|{settings.facebook_app_secret}"

    with httpx.Client(timeout=10) as client:
        debug = client.get(
            "https://graph.facebook.com/debug_token",
            params={"input_token": access_token, "access_token": app_token},
        ).json()

        data = debug.get("data", {})
        if not data.get("is_valid") or data.get("app_id") != settings.facebook_app_id:
            raise OAuthError("Invalid or expired Facebook token.")

        profile = client.get(
            "https://graph.facebook.com/me",
            params={"fields": "id,name,email,picture", "access_token": access_token},
        ).json()

    if "error" in profile:
        raise OAuthError(profile["error"].get("message", "Could not fetch Facebook profile."))

    picture = (profile.get("picture") or {}).get("data", {}).get("url")

    return {
        "provider_id": profile["id"],
        # Facebook omits email if the user never verified one on their FB
        # account — handle None downstream rather than assuming it exists.
        "email": profile.get("email"),
        "name": profile.get("name", "Facebook User"),
        "avatar_url": picture,
    }
