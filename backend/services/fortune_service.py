"""Fortune generation templates and logic."""

import random

from logger import get_logger
from data.fortune_options import FORTUNE_TOPICS  # re-exported for API use
from data.mock.fortune_data import FORTUNE_TEMPLATES

logger = get_logger(__name__)


def generate_fortune(zodiac_sign: str, topic: str, mood: str, db=None) -> str:
    """
    Generate a fortune for the given sign, topic, and mood.

    Resolution order:
    1. Pre-generated daily pool in DB (today's row).
    2. Random fortune from any available DB row for sign+topic.
    3. If no DB data exists, return service unavailable.
    """
    canonical_topic = (topic or "").strip().title()
    canonical_sign = (zodiac_sign or "").strip().title()
    if canonical_topic not in FORTUNE_TOPICS:
        canonical_topic = "Spiritual"

    logger.debug(
        "generate_fortune  sign=%s  topic=%s  mood=%s",
        canonical_sign,
        canonical_topic,
        mood,
    )

    def _pick_from_fortunes(values) -> str | None:
        if not values:
            return None
        cleaned = [str(v).strip() for v in values if str(v).strip()]
        return random.choice(cleaned) if cleaned else None

    def _pick_mock_fortune(topic_name: str) -> str:
        values = FORTUNE_TEMPLATES.get(topic_name) or FORTUNE_TEMPLATES.get("Spiritual", [])
        cleaned = [str(v).strip() for v in values if str(v).strip()]
        if cleaned:
            return random.choice(cleaned)
        return "The stars encourage patience today. Trust your path and move forward with calm confidence."

    # ── 1. DB pool ────────────────────────────────────────────────────────────
    if db is not None:
        try:
            from datetime import date as _date
            from db.models import FortunePool
            today_str = _date.today().isoformat()

            # 1a) Exact hit for today's pool.
            pool_row = (
                db.query(FortunePool)
                .filter(
                    FortunePool.date == today_str,
                    FortunePool.zodiac_sign == canonical_sign,
                    FortunePool.topic == canonical_topic,
                )
                .first()
            )

            chosen = _pick_from_fortunes(pool_row.fortunes if pool_row else None)
            if chosen:
                logger.info("generate_fortune  source=db  sign=%s  topic=%s  scope=today", canonical_sign, canonical_topic)
                return chosen

            # 1b) Fallback: choose randomly from all available rows for sign+topic.
            all_rows = (
                db.query(FortunePool)
                .filter(
                    FortunePool.zodiac_sign == canonical_sign,
                    FortunePool.topic == canonical_topic,
                )
                .all()
            )
            combined_fortunes = []
            for row in all_rows:
                if row.fortunes:
                    combined_fortunes.extend([str(v).strip() for v in row.fortunes if str(v).strip()])

            chosen = _pick_from_fortunes(combined_fortunes)
            if chosen:
                logger.info("generate_fortune  source=db  sign=%s  topic=%s  scope=history  rows=%d", canonical_sign, canonical_topic, len(all_rows))
                return chosen

            logger.warning(
                "generate_fortune  POOL MISS  sign=%s  topic=%s  date=%s",
                canonical_sign,
                canonical_topic,
                today_str,
            )
        except Exception as exc:
            logger.warning("generate_fortune  DB pool query failed (%s)", exc)
            logger.warning("generate_fortune  source=mock  sign=%s  topic=%s  reason=db_fetch_failed", canonical_sign, canonical_topic)
            return _pick_mock_fortune(canonical_topic)

    logger.warning("generate_fortune  source=mock  sign=%s  topic=%s  reason=pool_empty", canonical_sign, canonical_topic)
    return _pick_mock_fortune(canonical_topic)
