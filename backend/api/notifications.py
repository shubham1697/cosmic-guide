"""Push notification endpoints — device registration & preferences."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import DeviceToken
from logger import get_logger
from schemas import (
    DeviceTokenRegister,
    NotificationPreferences,
    TestPushRequest,
    TokenRef,
)
from services import notification_service

logger = get_logger(__name__)
router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.post("/register")
def register_device(payload: DeviceTokenRegister, db: Session = Depends(get_db)):
    """Upsert an FCM device token (called by the app after it obtains a token)."""
    logger.info("→ POST /notifications/register platform=%s sign=%s",
                payload.platform, payload.zodiac_sign)
    now = datetime.now(timezone.utc)
    existing = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()

    if existing:
        existing.platform = payload.platform
        existing.zodiac_sign = payload.zodiac_sign
        existing.tradition = payload.tradition
        existing.birth_date = payload.birth_date
        existing.birth_time = payload.birth_time
        existing.birth_place = payload.birth_place
        if payload.daily_horoscope_enabled is not None:
            existing.daily_horoscope_enabled = payload.daily_horoscope_enabled
        existing.updated_at = now
        created = False
    else:
        db.add(DeviceToken(
            token=payload.token,
            platform=payload.platform,
            zodiac_sign=payload.zodiac_sign,
            tradition=payload.tradition,
            birth_date=payload.birth_date,
            birth_time=payload.birth_time,
            birth_place=payload.birth_place,
            daily_horoscope_enabled=(
                True if payload.daily_horoscope_enabled is None
                else payload.daily_horoscope_enabled
            ),
            created_at=now,
            updated_at=now,
        ))
        created = True

    db.commit()
    logger.info("← POST /notifications/register created=%s", created)
    return {"status": "ok", "created": created}


@router.post("/unregister")
def unregister_device(payload: TokenRef, db: Session = Depends(get_db)):
    """Remove a device token (e.g. on logout)."""
    logger.info("→ POST /notifications/unregister")
    deleted = (
        db.query(DeviceToken)
        .filter(DeviceToken.token == payload.token)
        .delete(synchronize_session=False)
    )
    db.commit()
    logger.info("← POST /notifications/unregister deleted=%d", deleted)
    return {"status": "ok", "deleted": deleted}


@router.put("/preferences")
def update_preferences(payload: NotificationPreferences, db: Session = Depends(get_db)):
    """Toggle the daily horoscope reminder for a device."""
    logger.info("→ PUT /notifications/preferences enabled=%s", payload.daily_horoscope_enabled)
    device = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if device is None:
        logger.info("← PUT /notifications/preferences token not found")
        return {"status": "not_found"}
    device.daily_horoscope_enabled = payload.daily_horoscope_enabled
    device.updated_at = datetime.now(timezone.utc)
    db.commit()
    logger.info("← PUT /notifications/preferences ok")
    return {"status": "ok"}


@router.post("/test")
def send_test(payload: TestPushRequest):
    """Send a one-off test push to a token (dev aid)."""
    logger.info("→ POST /notifications/test")
    sent, _prune = notification_service.send_to_token(
        payload.token,
        payload.title or "🔔 CosmicGuide test",
        payload.body or "If you can read this, notifications work!",
        data={"type": "test"},
    )
    logger.info("← POST /notifications/test sent=%s enabled=%s",
                sent, notification_service.is_enabled())
    return {"sent": sent, "fcm_enabled": notification_service.is_enabled()}


@router.post("/run-daily")
def run_daily(db: Session = Depends(get_db)):
    """Manually trigger the daily reminder job now (dev / ops aid)."""
    logger.info("→ POST /notifications/run-daily")
    result = notification_service.send_daily_horoscope_reminders(db)
    logger.info("← POST /notifications/run-daily %s", result)
    return result
