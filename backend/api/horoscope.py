from fastapi import APIRouter, Query
from schemas import HoroscopeResponse
from services.horoscope_service import get_horoscope
from services.zodiac_service import ZODIAC_SIGNS

router = APIRouter(prefix="/horoscope", tags=["Horoscope"])


@router.get("/today", response_model=HoroscopeResponse)
def today_horoscope(zodiac_sign: str = Query(..., description="Zodiac sign name")):
    if zodiac_sign not in ZODIAC_SIGNS:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}")
    return get_horoscope(zodiac_sign)
