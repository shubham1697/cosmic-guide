from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from db.database import get_db
from schemas import DATE_PATTERN, TIME_PATTERN, HoroscopeResponse, ForecastResponse
from services.horoscope_service import get_horoscope, get_periodic_horoscope, get_forecast
from services.zodiac_service import ZODIAC_SIGNS
from logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/horoscope", tags=["Horoscope"])


@router.get("/today", response_model=HoroscopeResponse)
def today_horoscope(
    zodiac_sign: str = Query(..., description="Zodiac sign name"),
    system: str = Query(
        "western",
        description="Reading tradition: 'western' (tropical Sun) or 'vedic' (sidereal Moon rashi)",
        pattern="^(western|vedic)$",
    ),
    birth_date: str | None = Query(
        default=None, alias="birthDate", pattern=DATE_PATTERN,
        description="YYYY-MM-DD. When provided, returns a personalized transit-to-natal reading.",
    ),
    birth_time: str | None = Query(
        default=None, alias="birthTime", pattern=TIME_PATTERN,
        description="HH:MM (24h). Sharpens the personalized reading (enables houses & rising).",
    ),
    birth_place: str | None = Query(
        default=None, alias="birthPlace", max_length=200,
        description="City/place name for the personalized reading.",
    ),
    db: Session = Depends(get_db),
):
    logger.info("→ GET /horoscope/today | sign=%s | system=%s | personal=%s", zodiac_sign, system, bool(birth_date))
    
    if zodiac_sign not in ZODIAC_SIGNS:
        logger.warning("← GET /horoscope/today | status=400 | invalid sign")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    result = get_horoscope(
        zodiac_sign, system=system, db=db,
        birth_date=birth_date, birth_time=birth_time, birth_place=birth_place,
    )
    logger.info(
        "← GET /horoscope/today | status=200 | system=%s | personal=%s | mood=%s",
        system, result.get("personalized", False), result.get("mood", "unknown"),
    )
    return result


@router.get("/forecast", response_model=ForecastResponse)
def horoscope_forecast(
    birth_date: str = Query(
        ..., alias="birthDate", pattern=DATE_PATTERN,
        description="YYYY-MM-DD — required; the forecast is personal to this chart.",
    ),
    birth_time: str | None = Query(default=None, alias="birthTime", pattern=TIME_PATTERN,
                                   description="HH:MM (24h)"),
    birth_place: str | None = Query(default=None, alias="birthPlace", max_length=200,
                                    description="City/place name"),
    system: str = Query("western", pattern="^(western|vedic)$"),
    days: int = Query(30, ge=3, le=30, description="Forecast window length (days)"),
):
    """A personalized day-by-day energy forecast (deterministic transit-to-natal
    scores) plus the best day in the window. No LLM involved.
    """
    logger.info("→ GET /horoscope/forecast | system=%s | days=%s | personal=%s", system, days, bool(birth_date))
    points, best = get_forecast(birth_date, birth_time, birth_place, system=system, days=days)
    logger.info("← GET /horoscope/forecast | status=200 | points=%d", len(points))
    return {"forecast": points, "best_day": best}


def _periodic_reading(zodiac_sign: str, period: str, system: str, db: Session) -> dict:
    if zodiac_sign not in ZODIAC_SIGNS:
        logger.warning("← GET /horoscope/%s | status=400 | invalid sign", period)
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    return get_periodic_horoscope(zodiac_sign, period, system=system, db=db)


@router.get("/weekly", response_model=HoroscopeResponse)
def weekly_horoscope(
    zodiac_sign: str = Query(..., description="Zodiac sign name"),
    system: str = Query(
        "western",
        description="Reading tradition: 'western' (tropical Sun) or 'vedic' (sidereal Moon rashi)",
        pattern="^(western|vedic)$",
    ),
    db: Session = Depends(get_db),
):
    logger.info("→ GET /horoscope/weekly | sign=%s | system=%s", zodiac_sign, system)
    result = _periodic_reading(zodiac_sign, "weekly", system, db)
    logger.info("← GET /horoscope/weekly | status=200 | system=%s | mood=%s", system, result.get("mood", "unknown"))
    return result


@router.get("/monthly", response_model=HoroscopeResponse)
def monthly_horoscope(
    zodiac_sign: str = Query(..., description="Zodiac sign name"),
    system: str = Query(
        "western",
        description="Reading tradition: 'western' (tropical Sun) or 'vedic' (sidereal Moon rashi)",
        pattern="^(western|vedic)$",
    ),
    db: Session = Depends(get_db),
):
    logger.info("→ GET /horoscope/monthly | sign=%s | system=%s", zodiac_sign, system)
    result = _periodic_reading(zodiac_sign, "monthly", system, db)
    logger.info("← GET /horoscope/monthly | status=200 | system=%s | mood=%s", system, result.get("mood", "unknown"))
    return result
