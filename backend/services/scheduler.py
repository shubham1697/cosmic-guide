"""In-process job scheduler (APScheduler).

Runs a daily job that sends horoscope reminders. Kept intentionally small:
- One background scheduler per process, started at app startup.
- Guarded against double-start (uvicorn --reload re-imports safely).
- The daily send is itself idempotent (see notification_service), so even if
  more than one worker runs this, ``last_notified_date`` prevents duplicates.

Note: ``DAILY_REMINDER_HOUR`` is interpreted in the *container's* local timezone
(UTC by default in Docker). Per-user timezones are a future enhancement.
"""

from __future__ import annotations

from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler

from config import settings
from logger import get_logger

logger = get_logger(__name__)

_scheduler: Optional[BackgroundScheduler] = None


def _run_daily_reminders() -> None:
    """Job entrypoint: open a session, send reminders, always close."""
    from db.database import SessionLocal
    from services.notification_service import send_daily_horoscope_reminders

    db = SessionLocal()
    try:
        send_daily_horoscope_reminders(db)
    except Exception as exc:  # pragma: no cover - defensive
        logger.error("daily reminder job failed: %s", exc, exc_info=True)
    finally:
        db.close()


def start_scheduler() -> None:
    """Start the background scheduler and register the daily reminder job."""
    global _scheduler
    if _scheduler is not None:
        return
    if not settings.ENABLE_SCHEDULER:
        logger.info("Scheduler disabled (ENABLE_SCHEDULER=false).")
        return

    scheduler = BackgroundScheduler()
    scheduler.add_job(
        _run_daily_reminders,
        trigger="cron",
        hour=settings.DAILY_REMINDER_HOUR,
        minute=0,
        id="daily_horoscope_reminder",
        replace_existing=True,
        coalesce=True,
        misfire_grace_time=3600,
    )
    scheduler.start()
    _scheduler = scheduler
    logger.info(
        "Scheduler started; daily horoscope reminder at %02d:00 (server tz).",
        settings.DAILY_REMINDER_HOUR,
    )


def shutdown_scheduler() -> None:
    """Stop the scheduler if running (called on app shutdown)."""
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("Scheduler stopped.")
