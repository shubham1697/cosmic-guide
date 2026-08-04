"""Push notification service (Firebase Cloud Messaging).

Design goals:
- **Safe without credentials.** If ``FCM_CREDENTIALS_PATH`` is unset or the file
  is missing, the service logs a warning and every send becomes a no-op. This
  lets the API and endpoints run in local dev / CI with no Firebase project.
- **Self-pruning.** When FCM reports a token as unregistered (app uninstalled,
  token rotated), the caller is told to delete that row.
"""

from __future__ import annotations

import os
from datetime import date
from typing import Any, Optional

from config import settings
from logger import get_logger

logger = get_logger(__name__)

# Lazily-imported firebase symbols (import is cheap, init is what we gate).
try:  # pragma: no cover - import guard
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FIREBASE_IMPORTED = True
except Exception as exc:  # pragma: no cover
    firebase_admin = None  # type: ignore
    credentials = None  # type: ignore
    messaging = None  # type: ignore
    _FIREBASE_IMPORTED = False
    logger.warning("firebase-admin not importable (%s); push sends disabled.", exc)

_initialized = False
_enabled = False


def _ensure_init() -> bool:
    """Initialize the Firebase app once. Returns True when sending is possible."""
    global _initialized, _enabled
    if _initialized:
        return _enabled
    _initialized = True

    if not _FIREBASE_IMPORTED:
        _enabled = False
        return False

    path = settings.FCM_CREDENTIALS_PATH
    if not path or not os.path.isfile(path):
        logger.warning(
            "FCM disabled: no service-account file at FCM_CREDENTIALS_PATH=%r. "
            "Notification endpoints work but sends are no-ops until configured.",
            path,
        )
        _enabled = False
        return False

    try:
        cred = credentials.Certificate(path)
        firebase_admin.initialize_app(cred)
        _enabled = True
        logger.info("FCM initialized from %s", path)
    except Exception as exc:  # pragma: no cover - depends on external creds
        logger.error("FCM init failed (%s); sends disabled.", exc)
        _enabled = False
    return _enabled


def is_enabled() -> bool:
    """Whether push sending is currently possible (creds present + valid)."""
    return _ensure_init()


def send_to_token(
    token: str,
    title: str,
    body: str,
    data: Optional[dict[str, Any]] = None,
) -> tuple[bool, bool]:
    """Send one notification.

    Returns ``(sent, should_prune)`` where ``should_prune`` is True when the
    token is dead and the caller should delete it.
    """
    if not _ensure_init():
        return (False, False)

    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(aps=messaging.Aps(sound="default")),
            ),
        )
        messaging.send(message)
        return (True, False)
    except messaging.UnregisteredError:
        logger.info("FCM token unregistered; will prune: %s…", token[:12])
        return (False, True)
    except Exception as exc:  # pragma: no cover - depends on external service
        logger.warning("FCM send failed (%s) for token %s…", exc, token[:12])
        return (False, False)


def _daily_message(zodiac_sign: Optional[str]) -> tuple[str, str]:
    """Build the (title, body) for the daily horoscope reminder."""
    sign = (zodiac_sign or "").strip()
    title = "✨ Your daily horoscope is ready"
    if sign:
        body = f"{sign}, the stars have something to say today. Tap to read your reading. 🔮"
    else:
        body = "The stars have something to say today. Tap to read your reading. 🔮"
    return (title, body)


def send_daily_horoscope_reminders(db) -> dict:
    """Send the daily reminder to every opted-in device.

    Idempotent per day: a token whose ``last_notified_date`` is today is skipped,
    so re-running the job (retries, manual trigger) will not double-notify.
    """
    from db.models import DeviceToken

    today = date.today().isoformat()
    tokens = (
        db.query(DeviceToken)
        .filter(DeviceToken.daily_horoscope_enabled.is_(True))
        .all()
    )

    sent = failed = pruned = skipped = 0
    for dt in tokens:
        if dt.last_notified_date == today:
            skipped += 1
            continue

        title, body = _daily_message(dt.zodiac_sign)
        ok, prune = send_to_token(
            dt.token,
            title,
            body,
            data={"type": "daily_horoscope", "route": "/horoscope"},
        )
        if ok:
            dt.last_notified_date = today
            sent += 1
        elif prune:
            db.delete(dt)
            pruned += 1
        else:
            failed += 1

    db.commit()
    logger.info(
        "daily horoscope reminders: sent=%d failed=%d pruned=%d skipped=%d",
        sent, failed, pruned, skipped,
    )
    return {"sent": sent, "failed": failed, "pruned": pruned, "skipped": skipped}
