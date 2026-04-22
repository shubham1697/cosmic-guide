"""Fortune generation templates and logic."""

import random

from logger import get_logger
from data.fortune_options import FORTUNE_TOPICS  # re-exported for API use

logger = get_logger(__name__)


def generate_fortune(zodiac_sign: str, topic: str, mood: str, db=None) -> str:
    """
    Generate a fortune for the given sign, topic, and mood.

    Resolution order:
    1. Pre-generated daily pool in SQLite (pick one of 3 variants at random).
    2. Real-time AI generation (if pool miss and API key configured).
    3. Static template fallback.
    """
    logger.debug("generate_fortune  sign=%s  topic=%s  mood=%s", zodiac_sign, topic, mood)

    # ── 1. DB pool ────────────────────────────────────────────────────────────
    if db is not None:
        try:
            from datetime import date as _date
            from db.models import FortunePool
            today_str = _date.today().isoformat()
            pool_row = (
                db.query(FortunePool)
                .filter(
                    FortunePool.date == today_str,
                    FortunePool.zodiac_sign == zodiac_sign,
                    FortunePool.topic == topic,
                )
                .first()
            )
            if pool_row and pool_row.fortunes:
                chosen = random.choice(pool_row.fortunes)
                logger.info("generate_fortune  POOL HIT  sign=%s  topic=%s", zodiac_sign, topic)
                return chosen
            else:
                logger.debug("generate_fortune  POOL MISS  sign=%s  topic=%s", zodiac_sign, topic)
        except Exception as exc:
            logger.warning("generate_fortune  DB pool query failed (%s)", exc)

    # ── 2. Real-time AI ───────────────────────────────────────────────────────
    try:
        from services.ai_service import generate_fortune as ai_fortune
        result = ai_fortune(zodiac_sign, topic, mood)
        if result:
            logger.info("generate_fortune  AI OK  sign=%s  topic=%s", zodiac_sign, topic)
            return result
        logger.warning("generate_fortune  AI returned empty  sign=%s  topic=%s", zodiac_sign, topic)
    except Exception as exc:
        logger.warning("generate_fortune  AI exception (%s)  sign=%s — raising 503", exc, zodiac_sign)

    # AI unavailable and no pool — surface the error
    from fastapi import HTTPException
    raise HTTPException(
        status_code=503,
        detail="Fortune service temporarily unavailable. Please try again shortly.",
    )
