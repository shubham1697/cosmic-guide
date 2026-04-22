"""Horoscope data and retrieval."""

from datetime import date

from logger import get_logger

logger = get_logger(__name__)

# In-memory cache: { (zodiac_sign, "YYYY-MM-DD"): dict }
# Ensures all requests in the same process return the same daily result.
_horoscope_cache: dict = {}


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
        logger.debug("get_horoscope  CACHE HIT (memory)  sign=%s", zodiac_sign)
        return _horoscope_cache[cache_key]

    # ── 2. DB cache ──────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import Horoscope
            cached = (
                db.query(Horoscope)
                .filter(Horoscope.zodiac_sign == zodiac_sign, Horoscope.date == today_str)
                .first()
            )
            if cached:
                logger.info("get_horoscope  DB HIT  sign=%s", zodiac_sign)
                result = {
                    "sign": zodiac_sign,
                    "date": today_str,
                    "general": cached.general,
                    "love": cached.love,
                    "career": cached.career,
                    "health": cached.health,
                    "overall_score": cached.overall_score,
                    "lucky_number": cached.lucky_number,
                    "lucky_color": cached.lucky_color,
                    "mood": cached.mood,
                }
                _horoscope_cache[cache_key] = result
                return result
            else:
                logger.debug("get_horoscope  DB MISS  sign=%s", zodiac_sign)
        except Exception as exc:
            logger.warning("get_horoscope  DB query failed (%s) \u2014 skipping to AI", exc)

    # ── 3. AI generation ─────────────────────────────────────────────────────
    try:
        from services.ai_service import generate_daily_horoscope
        logger.debug("get_horoscope  calling AI  sign=%s", zodiac_sign)
        ai_data = generate_daily_horoscope(zodiac_sign, today)
        if ai_data:
            logger.info(
                "get_horoscope  AI OK  sign=%s  score=%d  mood=%s",
                zodiac_sign, ai_data["overall_score"], ai_data["mood"],
            )
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

    # AI unavailable and no cached data — surface the error
    from fastapi import HTTPException
    raise HTTPException(
        status_code=503,
        detail="Horoscope service temporarily unavailable. Please try again shortly.",
    )
