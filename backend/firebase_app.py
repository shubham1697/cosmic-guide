"""Single Firebase Admin app shared by sign-in verification and push sending.

Both features authenticate with the same service account, and
``firebase_admin.initialize_app`` may only be called once per process, so the
app is created here and reused.

Without credentials this stays unavailable and callers fail **closed**: sign-in
verification rejects every token rather than letting requests through.
"""

import os
import threading

from config import settings
from logger import get_logger

logger = get_logger(__name__)

try:  # pragma: no cover - import guard
    import firebase_admin
    from firebase_admin import credentials
    _IMPORTED = True
except Exception as exc:  # pragma: no cover
    firebase_admin = None  # type: ignore
    credentials = None  # type: ignore
    _IMPORTED = False
    logger.warning("firebase-admin not importable (%s); Firebase features disabled.", exc)

_lock = threading.Lock()
_initialized = False
_app = None


def get_app():
    """Return the shared Firebase app, or None when credentials are absent."""
    global _initialized, _app
    if _initialized:
        return _app

    with _lock:
        if _initialized:
            return _app
        _initialized = True

        if not _IMPORTED:
            return None

        path = settings.FCM_CREDENTIALS_PATH
        if not path or not os.path.isfile(path):
            logger.warning(
                "Firebase disabled: no service-account file at FCM_CREDENTIALS_PATH=%r. "
                "Sign-in verification will reject all tokens and push sends are no-ops.",
                path,
            )
            return None

        try:
            _app = firebase_admin.initialize_app(credentials.Certificate(path))
            logger.info("Firebase initialized from %s", path)
        except ValueError:
            _app = firebase_admin.get_app()  # already initialised in this process
        except Exception as exc:  # pragma: no cover - depends on external creds
            logger.error("Firebase init failed (%s).", exc)
            _app = None
        return _app


def is_available() -> bool:
    return get_app() is not None
