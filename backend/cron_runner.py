#!/usr/bin/env python3
"""
Scheduler that runs the daily content population automatically.

Run this as a long-lived process on the machine with the content database:
    python cron_runner.py

It will:
  - Run populate_daily.py at the configured time (DAILY_REFRESH_TIME, default 00:05)
  - Also run immediately on startup if today's content is missing
  - Retry up to 3 times on failure with exponential backoff
  - Log everything for monitoring

For a simpler setup, use a system crontab instead:
    # crontab -e
    5 0 * * * cd /path/to/backend && /path/to/python populate_daily.py >> /var/log/cosmicguide_cron.log 2>&1
"""

import time
import subprocess
import sys
import os
from datetime import datetime, date, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import settings
from logger import configure_logging, get_logger

configure_logging()
logger = get_logger("cron_runner")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PYTHON = sys.executable
POPULATE_SCRIPT = os.path.join(SCRIPT_DIR, "populate_daily.py")
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 60  # seconds


def run_populate(for_date: date = None, seed: bool = False) -> bool:
    """Run the population script. Returns True on success."""
    cmd = [PYTHON, POPULATE_SCRIPT]
    if for_date:
        cmd += ["--date", for_date.isoformat()]
    if seed:
        cmd += ["--seed-oneshot"]

    logger.info("Running: %s", " ".join(cmd))

    try:
        result = subprocess.run(
            cmd, cwd=SCRIPT_DIR, capture_output=True, text=True, timeout=600,
        )
        if result.returncode == 0:
            logger.info("Population completed successfully")
            if result.stdout:
                logger.debug("stdout: %s", result.stdout[-500:])
            return True
        else:
            logger.error("Population failed (exit %d)\nstderr: %s",
                         result.returncode, result.stderr[-500:])
            return False
    except subprocess.TimeoutExpired:
        logger.error("Population timed out after 600s")
        return False
    except Exception as exc:
        logger.error("Failed to run population script: %s", exc)
        return False


def run_with_retry(for_date: date = None, seed: bool = False) -> bool:
    """Run population with exponential backoff retries."""
    for attempt in range(1, MAX_RETRIES + 1):
        logger.info("Attempt %d/%d for %s", attempt, MAX_RETRIES,
                     for_date.isoformat() if for_date else "today")
        if run_populate(for_date, seed):
            return True
        if attempt < MAX_RETRIES:
            wait = RETRY_BACKOFF_BASE * (2 ** (attempt - 1))
            logger.info("Retrying in %ds ...", wait)
            time.sleep(wait)
    logger.error("All %d attempts failed for %s", MAX_RETRIES,
                 for_date.isoformat() if for_date else "today")
    return False


def seconds_until(hour: int, minute: int) -> float:
    """Seconds from now until the next occurrence of HH:MM."""
    now = datetime.now()
    target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= now:
        target += timedelta(days=1)
    return (target - now).total_seconds()


def check_and_populate_today():
    """Run population if today's content is missing."""
    logger.info("Checking if today's content needs population ...")
    from db.content_db import get_content_session, create_content_tables
    from services.content_db_service import get_content_status

    create_content_tables()
    db = get_content_session()
    try:
        status = get_content_status(db, date.today())
        if status["fully_populated"]:
            logger.info("Today's content is fully populated — skipping")
            return True
        else:
            logger.info("Today's content incomplete: %s", status)
            # First run includes one-shot seeding
            needs_seed = (status["compatibility_pairs"]["count"] < 78
                          or status["tarot_cards"]["count"] < 78)
            return run_with_retry(seed=needs_seed)
    finally:
        db.close()


def main():
    # Parse schedule time
    try:
        hour, minute = map(int, settings.DAILY_REFRESH_TIME.split(":"))
    except (ValueError, AttributeError):
        hour, minute = 0, 5

    logger.info("=" * 60)
    logger.info("CosmicGuide Content Scheduler")
    logger.info("Scheduled time: %02d:%02d daily", hour, minute)
    logger.info("=" * 60)

    # On startup, check if today's content is ready
    check_and_populate_today()

    # Main scheduling loop
    while True:
        wait = seconds_until(hour, minute)
        logger.info("Next run in %.0f seconds (%s)", wait,
                     (datetime.now() + timedelta(seconds=wait)).strftime("%Y-%m-%d %H:%M"))
        time.sleep(wait)

        logger.info("⏰ Scheduled run starting for %s", date.today().isoformat())
        run_with_retry()

        # Sleep a bit to avoid double-triggering
        time.sleep(120)


if __name__ == "__main__":
    main()
