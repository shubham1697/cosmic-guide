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

# In-memory cache for PERSONALIZED daily readings (natal chart + transits):
#   { (zodiac_sign, system, "YYYY-MM-DD", birth_hash): dict }
# Kept separate from the shared per-sign caches so one person's chart-specific
# reading is never served to (or persisted for) everyone with that sign.
_personalized_cache: dict = {}


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


def _build_personalized_context(birth_date: str, birth_time, birth_place, system: str) -> dict:
    """Assemble the natal chart, today's transits, and the transit-to-natal
    aspects that a personalized reading is grounded in. Western readings use the
    tropical zodiac; vedic readings use the sidereal (Lahiri) zodiac throughout.
    """
    from services.birth_chart_service import (
        calculate_birth_chart,
        calculate_current_transits,
        calculate_transit_aspects_to_natal,
    )

    sidereal = system == "vedic"
    natal = calculate_birth_chart(
        birth_date=birth_date,
        birth_time=birth_time,
        birth_place=birth_place,
        sidereal=sidereal,
    )
    # Sample at noon UTC so today's score is stable through the day and matches
    # the forecast's point for today (which is also sampled at noon).
    from datetime import date as _date, datetime as _dt, timezone as _tz
    _t = _date.today()
    transits = calculate_current_transits(
        sidereal=sidereal, when=_dt(_t.year, _t.month, _t.day, 12, 0, tzinfo=_tz.utc)
    )
    transit_aspects = calculate_transit_aspects_to_natal(natal["planets"], transits)
    return {
        "big3": natal.get("big3", {}),
        "moon_nakshatra": natal.get("moon_nakshatra"),
        "transits": transits,
        "transit_aspects": transit_aspects,
    }


def _get_personalized_horoscope(zodiac_sign: str, system: str, today, today_str: str,
                                birth_date: str, birth_time, birth_place):
    """Return a genuinely personal daily reading (natal chart + live transits),
    or None if it can't be produced so the caller falls back to the generic one.

    Cached per (sign, system, date, birth_hash) in ``_personalized_cache`` and
    never written to the shared per-sign DB cache.
    """
    import hashlib

    key_src = f"{birth_date}|{birth_time or ''}|{birth_place or ''}"
    birth_hash = hashlib.sha256(key_src.encode()).hexdigest()[:12]
    cache_key = (zodiac_sign, system, today_str, birth_hash)
    if cache_key in _personalized_cache:
        logger.info("get_horoscope  source=memory(personal)  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)
        return _personalized_cache[cache_key]

    try:
        context = _build_personalized_context(birth_date, birth_time, birth_place, system)
    except Exception as exc:
        logger.warning("get_horoscope  personalization context failed (%s)  sign=%s", exc, zodiac_sign)
        return None

    try:
        from services.ai_service import generate_daily_horoscope
        ai_data = generate_daily_horoscope(zodiac_sign, today, system=system, astro_context=context)
    except Exception as exc:
        logger.warning("get_horoscope  personalized AI exception (%s)  sign=%s", exc, zodiac_sign)
        return None

    if not ai_data:
        return None

    # Ground the headline score, its band label, and a one-line "why" in the
    # real chart rather than the LLM's guess.
    from services.birth_chart_service import describe_day
    day = describe_day(context.get("transit_aspects", []))
    if day is not None:
        ai_data["overall_score"] = day["score"]
        ai_data["band"] = day["band"]
        ai_data["mood_summary"] = day["summary"]

    logger.info("get_horoscope  source=llm(personal)  sign=%s  system=%s  date=%s  score=%s  band=%s",
                zodiac_sign, system, today_str, ai_data.get("overall_score"), ai_data.get("band"))
    result = {
        "sign": zodiac_sign,
        "date": today_str,
        **{k: v for k, v in ai_data.items() if k != "zodiac_sign"},
        "personalized": True,
    }
    _personalized_cache[cache_key] = result
    return result


# In-memory cache for the personalized energy forecast (full 30-day series):
#   { (birth_hash, system, "YYYY-MM-DD"): list[dict] }
_forecast_cache: dict = {}
_FORECAST_MAX_DAYS = 30


def get_forecast(birth_date: str, birth_time=None, birth_place=None,
                 system: str = "western", days: int = 30):
    """A personalized day-by-day energy forecast: the deterministic transit-to-
    natal score for each of the next ``days`` days (capped at 30), plus the best
    day in that window. Pure astronomy — no LLM. Returns ``(points, best_day)``.

    The full 30-day series is computed once per chart per day and then sliced,
    so the natal chart (and its geocoding) is only calculated once.
    """
    import hashlib
    from datetime import date as _date, datetime as _dt, timedelta, timezone as _tz

    sidereal = system == "vedic"
    days = max(1, min(days, _FORECAST_MAX_DAYS))
    today = _date.today()

    key_src = f"{birth_date}|{birth_time or ''}|{birth_place or ''}"
    birth_hash = hashlib.sha256(key_src.encode()).hexdigest()[:12]
    cache_key = (birth_hash, system, today.isoformat())

    series = _forecast_cache.get(cache_key)
    if series is None:
        try:
            from services.birth_chart_service import (
                calculate_birth_chart,
                calculate_current_transits,
                calculate_transit_aspects_to_natal,
                score_transit_aspects,
                band_for_score,
            )
            natal = calculate_birth_chart(
                birth_date=birth_date, birth_time=birth_time,
                birth_place=birth_place, sidereal=sidereal,
            )
            series = []
            for i in range(_FORECAST_MAX_DAYS):
                d = today + timedelta(days=i)
                when = _dt(d.year, d.month, d.day, 12, 0, tzinfo=_tz.utc)
                transits = calculate_current_transits(sidereal=sidereal, when=when)
                aspects = calculate_transit_aspects_to_natal(natal["planets"], transits)
                score = score_transit_aspects(aspects)
                if score is None:
                    continue
                series.append({
                    "date": d.isoformat(),
                    "score": score,
                    "band": band_for_score(score),
                })
        except Exception as exc:
            logger.warning("get_forecast  failed (%s)  system=%s", exc, system)
            return [], None
        _forecast_cache[cache_key] = series
        logger.info("get_forecast  computed  system=%s  points=%d", system, len(series))

    points = series[:days]
    best_day = max(points, key=lambda p: p["score"]) if points else None
    return points, best_day


def get_horoscope(zodiac_sign: str, system: str = "western", db=None,
                  birth_date: str | None = None, birth_time: str | None = None,
                  birth_place: str | None = None) -> dict:
    """
    Get today's horoscope for a zodiac sign.

    `system` selects the tradition:
      - "western" → tropical Sun-sign reading (DB-cached, AI, template).
      - "vedic"   → sidereal reading framed on the Moon rashi (Janma Rashi);
                    in-memory cache + AI, then the shared template. Vedic
                    readings are not persisted to the DB.

    When `birth_date` is provided, a genuinely PERSONAL reading is attempted
    first — grounded in the reader's real natal chart and today's transits to
    it. It has its own in-memory cache and is never written to the shared
    per-sign DB cache. If the AI is unavailable the code falls through to the
    generic per-sign resolution below.

    Resolution order:
    0. Personalized transit-to-natal reading (only when birth_date is given).
    1. In-memory process cache (same result for all requests today).
    2. Today's cached row in the database (if db provided).
    3. AI-generated content (if an AI provider is configured).
    4. Static template fallback.
    """
    from datetime import date as _date
    today = _date.today()
    today_str = today.isoformat()

    system = system if system in ("western", "vedic") else "western"
    logger.debug("get_horoscope  sign=%s  system=%s  date=%s", zodiac_sign, system, today_str)

    # Personalized reading (real natal chart + today's transits) comes first so
    # a chart-specific request never reads or writes the shared per-sign cache.
    if birth_date:
        personal = _get_personalized_horoscope(
            zodiac_sign, system, today, today_str,
            birth_date, birth_time, birth_place,
        )
        if personal is not None:
            return personal
        logger.info(
            "get_horoscope  personalization unavailable — using generic  sign=%s  system=%s",
            zodiac_sign, system,
        )

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
