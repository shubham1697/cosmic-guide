from datetime import date

from fastapi import APIRouter, HTTPException, Query

from schemas import DATE_PATTERN, TIME_PATTERN, VedicHomeSummaryResponse
from services.vedic_service import get_vedic_home_summary

router = APIRouter(prefix="/vedic", tags=["Vedic"])


def _validate_date(value: str | None, field: str) -> None:
    """The regex accepts 1990-13-45; only fromisoformat rejects it."""
    if value is None:
        return
    try:
        date.fromisoformat(value)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"{field} must be a real YYYY-MM-DD date")


@router.get("/home-summary", response_model=VedicHomeSummaryResponse)
def vedic_home_summary(
    target_date: str | None = Query(default=None, alias="targetDate", pattern=DATE_PATTERN),
    birth_date: str | None = Query(default=None, alias="birthDate", pattern=DATE_PATTERN),
    birth_time: str | None = Query(default=None, alias="birthTime", pattern=TIME_PATTERN),
    birth_place: str | None = Query(default=None, alias="birthPlace", max_length=200),
):
    _validate_date(target_date, "targetDate")
    _validate_date(birth_date, "birthDate")
    return get_vedic_home_summary(
        target_date=target_date,
        birth_date=birth_date,
        birth_time=birth_time,
        birth_place=birth_place,
    )
