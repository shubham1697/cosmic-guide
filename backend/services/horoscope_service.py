"""Horoscope data and retrieval."""

from datetime import date, timedelta
import time

from logger import get_logger
from logging_utils import log_db_query
from data.mock.horoscope_data import HOROSCOPE_DATA, DEFAULT_HOROSCOPE

logger = get_logger(__name__)

# In-memory cache: { (zodiac_sign, system, "YYYY-MM-DD"): dict }
# Ensures all requests in the same process return the same daily result.
_horoscope_cache: dict = {}

# In-memory cache for weekly/monthly readings:
#   { (zodiac_sign, system, period, period_key): dict }
_periodic_cache: dict = {}


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


def get_horoscope(zodiac_sign: str, system: str = "western", db=None) -> dict:
    """
    Get today's horoscope for a zodiac sign.

    `system` selects the tradition:
      - "western" → tropical Sun-sign reading (DB-cached, AI, template).
      - "vedic"   → sidereal reading framed on the Moon rashi (Janma Rashi);
                    in-memory cache + AI, then the shared template. Vedic
                    readings are not persisted to the DB.

    Resolution order:
    1. In-memory process cache (same result for all requests today).
    2. Today's cached row in the database (western only, if db provided).
    3. AI-generated content (if an AI provider is configured).
    4. Static template fallback.
    """
    from datetime import date as _date
    today = _date.today()
    today_str = today.isoformat()

    system = system if system in ("western", "vedic") else "western"
    logger.debug("get_horoscope  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)

    # ── 1. In-memory cache ───────────────────────────────────────────────────
    cache_key = (zodiac_sign, system, today_str)
    if cache_key in _horoscope_cache:
        logger.info("get_horoscope  source=memory  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)
        return _horoscope_cache[cache_key]

    # ── 2. DB cache ──────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import Horoscope
            t0 = time.perf_counter()
            cached = (
                db.query(Horoscope)
                .filter(
                    Horoscope.zodiac_sign == zodiac_sign,
                    Horoscope.date == today_str,
                    Horoscope.system == system,
                )
                .first()
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            
            if cached:
                log_db_query("SELECT", "horoscope", f"where sign={zodiac_sign} date={today_str} system={system}", rows_affected=1, elapsed_ms=elapsed_ms)
                logger.info("get_horoscope  source=db  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)
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
        logger.debug("get_horoscope  calling AI  sign=%s  system=%s", zodiac_sign, system)
        ai_data = generate_daily_horoscope(zodiac_sign, today, system=system)
        if ai_data:
            logger.info("get_horoscope  source=llm  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)
            # Persist in DB for subsequent requests today (western + vedic,
            # disambiguated by the `system` column).
            if db is not None:
                try:
                    from db.models import Horoscope
                    row = Horoscope(
                        date=today_str,
                        zodiac_sign=zodiac_sign,
                        system=system,
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
                    logger.debug("get_horoscope  persisted to DB  sign=%s  system=%s", zodiac_sign, system)
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

    logger.warning("get_horoscope  source=mock  sign=%s  system=%s  date=%s  reason=ai_unavailable", zodiac_sign, system, today_str)
    return _mock_horoscope(zodiac_sign, today_str)


def _period_bounds(period: str, today: date):
    """Return (period_key, start_date, end_date) for the current week or month."""
    if period == "monthly":
        start = today.replace(day=1)
        if start.month == 12:
            nxt = start.replace(year=start.year + 1, month=1)
        else:
            nxt = start.replace(month=start.month + 1)
        end = nxt - timedelta(days=1)
        return f"{today.year}-{today.month:02d}", start, end
    # weekly — Monday–Sunday of the current ISO week
    iso_year, iso_week, _ = today.isocalendar()
    start = today - timedelta(days=today.weekday())
    end = start + timedelta(days=6)
    return f"{iso_year}-W{iso_week:02d}", start, end


def _periodic_to_dict(row, period_key: str) -> dict:
    return {
        "sign": row.zodiac_sign,
        "date": period_key,
        "general": row.general,
        "love": row.love,
        "career": row.career,
        "health": row.health,
        "overall_score": row.overall_score,
        "lucky_number": str(row.lucky_number),
        "lucky_color": row.lucky_color,
        "mood": row.mood,
    }


def get_periodic_horoscope(zodiac_sign: str, period: str,
                           system: str = "western", db=None) -> dict:
    """
    Get the weekly or monthly horoscope for a sign.

    Resolution mirrors the daily reading: in-memory cache → DB cache
    (``periodic_horoscopes``) → AI generation (persisted) → static template.
    Both western and vedic readings are cached, disambiguated by ``system``.
    """
    from datetime import date as _date
    today = _date.today()
    period = period if period in ("weekly", "monthly") else "weekly"
    system = system if system in ("western", "vedic") else "western"
    period_key, start, end = _period_bounds(period, today)

    logger.debug("get_periodic_horoscope  sign=%s  period=%s  system=%s  key=%s",
                 zodiac_sign, period, system, period_key)

    # ── 1. In-memory cache ───────────────────────────────────────────────────
    cache_key = (zodiac_sign, system, period, period_key)
    if cache_key in _periodic_cache:
        logger.info("get_periodic_horoscope  source=memory  sign=%s  period=%s  key=%s",
                    zodiac_sign, period, period_key)
        return _periodic_cache[cache_key]

    # ── 2. DB cache ──────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import PeriodicHoroscope
            t0 = time.perf_counter()
            cached = (
                db.query(PeriodicHoroscope)
                .filter(
                    PeriodicHoroscope.period == period,
                    PeriodicHoroscope.period_key == period_key,
                    PeriodicHoroscope.system == system,
                    PeriodicHoroscope.zodiac_sign == zodiac_sign,
                )
                .first()
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            if cached:
                log_db_query("SELECT", "periodic_horoscope",
                             f"sign={zodiac_sign} period={period} key={period_key} system={system}",
                             rows_affected=1, elapsed_ms=elapsed_ms)
                logger.info("get_periodic_horoscope  source=db  sign=%s  period=%s  key=%s",
                            zodiac_sign, period, period_key)
                result = _periodic_to_dict(cached, period_key)
                _periodic_cache[cache_key] = result
                return result
            log_db_query("SELECT", "periodic_horoscope",
                         f"sign={zodiac_sign} period={period} key={period_key} system={system}",
                         rows_affected=0, elapsed_ms=elapsed_ms)
        except Exception as exc:
            logger.warning("get_periodic_horoscope  DB query failed (%s)", exc)

    # ── 3. AI generation ─────────────────────────────────────────────────────
    try:
        from services.ai_service import generate_periodic_horoscope
        ai_data = generate_periodic_horoscope(zodiac_sign, period, start, end, system=system)
        if ai_data:
            logger.info("get_periodic_horoscope  source=llm  sign=%s  period=%s  key=%s",
                        zodiac_sign, period, period_key)
            if db is not None:
                try:
                    from db.models import PeriodicHoroscope
                    row = PeriodicHoroscope(
                        period=period,
                        period_key=period_key,
                        system=system,
                        zodiac_sign=zodiac_sign,
                        general=ai_data["general"],
                        love=ai_data["love"],
                        career=ai_data["career"],
                        health=ai_data["health"],
                        overall_score=ai_data["overall_score"],
                        lucky_number=str(ai_data["lucky_number"]),
                        lucky_color=ai_data["lucky_color"],
                        mood=ai_data["mood"],
                    )
                    db.add(row)
                    db.commit()
                    logger.debug("get_periodic_horoscope  persisted  sign=%s  period=%s",
                                 zodiac_sign, period)
                except Exception as exc:
                    logger.warning("get_periodic_horoscope  DB persist failed (%s)", exc)
                    db.rollback()
            result = {
                "sign": zodiac_sign,
                "date": period_key,
                **{k: v for k, v in ai_data.items() if k != "zodiac_sign"},
            }
            _periodic_cache[cache_key] = result
            return result
        logger.warning("get_periodic_horoscope  AI returned None  sign=%s  period=%s",
                       zodiac_sign, period)
    except Exception as exc:
        logger.warning("get_periodic_horoscope  AI exception (%s)  sign=%s", exc, zodiac_sign)

    # ── 4. Template fallback ─────────────────────────────────────────────────
    logger.warning("get_periodic_horoscope  source=mock  sign=%s  period=%s  key=%s  reason=ai_unavailable",
                   zodiac_sign, period, period_key)
    return _mock_horoscope(zodiac_sign, period_key)


def clear_horoscope_cache():
    """Clear the in-memory horoscope caches (call after DB repopulation)."""
    _horoscope_cache.clear()
    _periodic_cache.clear()
    logger.info("Horoscope in-memory caches cleared")
