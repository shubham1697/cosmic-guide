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


def _verify_bearer(authorization: str | None, *, check_revoked: bool) -> AuthedUser:
    """Resolve the caller behind an ``Authorization: Bearer <firebase-id-token>``.

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
        claims = fb_auth.verify_id_token(token, app=app, check_revoked=check_revoked)
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


def require_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> AuthedUser:
    """Resolve the signed-in caller. Signature verification only (no round trip)."""
    return _verify_bearer(authorization, check_revoked=False)


def require_fresh_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> AuthedUser:
    """Like :func:`require_user`, but also rejects a *revoked* session.

    An ID token stays signature-valid for up to an hour after the user changes
    their password or signs a device out, which is far too long a window for
    the routes that modify or destroy an account. Costs one Firebase lookup, so
    it is reserved for those routes.
    """
    return _verify_bearer(authorization, check_revoked=True)


def optional_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> AuthedUser | None:
    """Resolve the caller when a token is presented, ``None`` when none is.

    A *present but invalid* token is still rejected — only the complete absence
    of the header counts as anonymous.
    """
    if not authorization:
        return None
    return _verify_bearer(authorization, check_revoked=False)
