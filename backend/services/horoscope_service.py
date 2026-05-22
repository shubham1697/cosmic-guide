"""Horoscope data and retrieval."""

from datetime import date
import time

from logger import get_logger
from logging_utils import log_db_query
from data.mock.horoscope_data import HOROSCOPE_DATA, DEFAULT_HOROSCOPE

logger = get_logger(__name__)

# In-memory cache: { (zodiac_sign, "YYYY-MM-DD"): dict }
# Ensures all requests in the same process return the same daily result.
_horoscope_cache: dict = {}


def _mock_horoscope(zodiac_sign: str, today_str: str) -> dict:
    template = HOROSCOPE_DATA.get(zodiac_sign, DEFAULT_HOROSCOPE)
    return {
        "sign": zodiac_sign,
        "date": today_str,
        "general": str(template.get("general", "")),
        "love": str(template.get("love", "")),
        "career": str(template.get("career", "")),
        "health": str(template.get("health", "")),
        "overall_score": int(template.get("overall_score", 75)),
        "lucky_number": str(template.get("lucky_number", "9")),
        "lucky_color": str(template.get("lucky_color", "Purple")),
        "mood": str(template.get("mood", "Intuitive")),
    }


def get_horoscope(zodiac_sign: str, db=None) -> dict:
    """
    Get today's horoscope for a zodiac sign.

    Resolution order:
    1. In-memory process cache (same result for all requests today).
    2. Today's cached row in the database (if db session provided).
    3. AI-generated content (if GEMINI_API_KEY is configured).
    4. Static template fallback.
    """
    from datetime import date as _date
    today = _date.today()
    today_str = today.isoformat()

    logger.debug("get_horoscope  sign=%s  date=%s", zodiac_sign, today_str)

    # ── 1. In-memory cache ───────────────────────────────────────────────────
    cache_key = (zodiac_sign, today_str)
    if cache_key in _horoscope_cache:
        logger.info("get_horoscope  source=memory  sign=%s  date=%s", zodiac_sign, today_str)
        return _horoscope_cache[cache_key]

    # ── 2. DB cache ──────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import Horoscope
            t0 = time.perf_counter()
            cached = (
                db.query(Horoscope)
                .filter(Horoscope.zodiac_sign == zodiac_sign, Horoscope.date == today_str)
                .first()
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            
            if cached:
                log_db_query("SELECT", "horoscope", f"where sign={zodiac_sign} date={today_str}", rows_affected=1, elapsed_ms=elapsed_ms)
                logger.info("get_horoscope  source=db  sign=%s  date=%s", zodiac_sign, today_str)
                result = {
                    "sign": zodiac_sign,
                    "date": today_str,
                    "general": cached.general,
                    "love": cached.love,
                    "career": cached.career,
                    "health": cached.health,
                    "overall_score": cached.overall_score,
                    "lucky_number": str(cached.lucky_number),
                    "lucky_color": cached.lucky_color,
                    "mood": cached.mood,
                }
                _horoscope_cache[cache_key] = result
                return result
            else:
                log_db_query("SELECT", "horoscope", f"where sign={zodiac_sign} date={today_str}", rows_affected=0, elapsed_ms=elapsed_ms)
                logger.debug("get_horoscope  DB MISS  sign=%s", zodiac_sign)
        except Exception as exc:
            logger.warning("get_horoscope  DB query failed (%s)", exc)
            log_db_query("SELECT", "horoscope", f"where sign={zodiac_sign} date={today_str}", error=exc, elapsed_ms=0)
            logger.warning("get_horoscope  source=mock  sign=%s  date=%s  reason=db_fetch_failed", zodiac_sign, today_str)
            return _mock_horoscope(zodiac_sign, today_str)

    # ── 3. AI generation ─────────────────────────────────────────────────────
    try:
        from services.ai_service import generate_daily_horoscope
        logger.debug("get_horoscope  calling AI  sign=%s", zodiac_sign)
        ai_data = generate_daily_horoscope(zodiac_sign, today)
        if ai_data:
            logger.info("get_horoscope  source=llm  sign=%s  date=%s", zodiac_sign, today_str)
            # Persist in DB for subsequent requests today
            if db is not None:
                try:
                    from db.models import Horoscope
                    row = Horoscope(
                        date=today_str,
                        zodiac_sign=zodiac_sign,
                        general=ai_data["general"],
                        love=ai_data["love"],
                        career=ai_data["career"],
                        health=ai_data["health"],
                        overall_score=ai_data["overall_score"],
                        lucky_number=ai_data["lucky_number"],
                        lucky_color=ai_data["lucky_color"],
                        mood=ai_data["mood"],
                    )
                    db.add(row)
                    db.commit()
                    logger.debug("get_horoscope  persisted to DB  sign=%s", zodiac_sign)
                except Exception as exc:
                    logger.warning("get_horoscope  DB persist failed (%s)", exc)
                    db.rollback()
            result = {
                "sign": zodiac_sign,
                "date": today_str,
                **{k: v for k, v in ai_data.items() if k != "zodiac_sign"},
            }
            _horoscope_cache[cache_key] = result
            return result
        else:
            logger.warning("get_horoscope  AI returned None  sign=%s", zodiac_sign)
    except Exception as exc:
        logger.warning("get_horoscope  AI exception (%s)  sign=%s", exc, zodiac_sign)

    logger.warning("get_horoscope  source=mock  sign=%s  date=%s  reason=ai_unavailable", zodiac_sign, today_str)
    return _mock_horoscope(zodiac_sign, today_str)


def clear_horoscope_cache():
    """Clear the in-memory horoscope cache (call after DB repopulation)."""
    _horoscope_cache.clear()
    logger.info("Horoscope in-memory cache cleared")
