from fastapi import APIRouter, Query

from schemas import VedicHomeSummaryResponse
from services.vedic_service import get_vedic_home_summary

router = APIRouter(prefix="/vedic", tags=["Vedic"])


@router.get("/home-summary", response_model=VedicHomeSummaryResponse)
def vedic_home_summary(
    target_date: str | None = Query(default=None, alias="targetDate"),
    birth_date: str | None = Query(default=None, alias="birthDate"),
    birth_time: str | None = Query(default=None, alias="birthTime"),
    birth_place: str | None = Query(default=None, alias="birthPlace"),
):
    return get_vedic_home_summary(
        target_date=target_date,
        birth_date=birth_date,
        birth_time=birth_time,
        birth_place=birth_place,
    )
