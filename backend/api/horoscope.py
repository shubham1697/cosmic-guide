from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from db.database import get_db
from schemas import HoroscopeResponse
from services.horoscope_service import get_horoscope, get_periodic_horoscope
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
    db: Session = Depends(get_db),
):
    logger.info("→ GET /horoscope/today | sign=%s | system=%s", zodiac_sign, system)
    
    if zodiac_sign not in ZODIAC_SIGNS:
        logger.warning("← GET /horoscope/today | status=400 | invalid sign")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    result = get_horoscope(zodiac_sign, system=system, db=db)
    logger.info("← GET /horoscope/today | status=200 | system=%s | mood=%s", system, result.get("mood", "unknown"))
    return result


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
