"""Access-control dependencies shared by the operator-only and signed-in endpoints."""

import secrets

from fastapi import Header, HTTPException

from config import settings
from logger import get_logger

logger = get_logger(__name__)


def require_admin(x_admin_key: str | None = Header(default=None, alias="X-Admin-Key")) -> None:
    """Gate operator-only routes behind ``ADMIN_API_KEY``.

    These routes spend real money (batch LLM generation), mutate or delete
    cached content, and can push a notification to every registered device, so
    they stay closed unless an operator key is configured *and* presented.
    """
    expected = settings.ADMIN_API_KEY
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="Admin API is disabled. Set ADMIN_API_KEY to enable it.",
        )
    if not x_admin_key or not secrets.compare_digest(x_admin_key, expected):
        raise HTTPException(status_code=401, detail="Invalid or missing X-Admin-Key header.")


class AuthedUser:
    """The verified caller behind a Firebase ID token."""

    __slots__ = ("uid", "email", "email_verified", "name")

    def __init__(self, uid: str, email: str | None, email_verified: bool, name: str | None):
        self.uid = uid
        self.email = email
        self.email_verified = email_verified
        self.name = name


def require_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> AuthedUser:
    """Resolve the caller from an ``Authorization: Bearer <firebase-id-token>``.

    Fails closed: if the service account is missing the token cannot be
    verified, so the request is refused rather than trusted.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token.")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token.")

    from firebase_app import get_app

    app = get_app()
    if app is None:
        logger.error("Sign-in verification unavailable: Firebase credentials are not configured.")
        raise HTTPException(
            status_code=503,
            detail="Authentication is not configured on the server.",
        )

    from firebase_admin import auth as fb_auth

    try:
        claims = fb_auth.verify_id_token(token, app=app)
    except Exception as exc:
        # Covers expired, revoked, malformed and wrong-project tokens alike.
        logger.info("Rejected ID token: %s", type(exc).__name__)
        raise HTTPException(status_code=401, detail="Invalid or expired token.") from exc

    uid = claims.get("uid") or claims.get("sub")
    if not uid:
        raise HTTPException(status_code=401, detail="Token has no subject.")

    return AuthedUser(
        uid=uid,
        email=claims.get("email"),
        email_verified=bool(claims.get("email_verified")),
        name=claims.get("name"),
    )
