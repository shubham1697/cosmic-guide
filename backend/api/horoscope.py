from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from db.database import get_db
from schemas import HoroscopeResponse
from services.horoscope_service import get_horoscope
from services.zodiac_service import ZODIAC_SIGNS
from logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/horoscope", tags=["Horoscope"])


@router.get("/today", response_model=HoroscopeResponse)
def today_horoscope(
    zodiac_sign: str = Query(..., description="Zodiac sign name"),
    db: Session = Depends(get_db),
):
    logger.info("→ GET /horoscope/today | sign=%s", zodiac_sign)
    
    if zodiac_sign not in ZODIAC_SIGNS:
        logger.warning("← GET /horoscope/today | status=400 | invalid sign")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    result = get_horoscope(zodiac_sign, db=db)
    logger.info("← GET /horoscope/today | status=200 | mood=%s", result.get("mood", "unknown"))
    return result
