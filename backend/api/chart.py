from fastapi import APIRouter, Depends
from schemas import BirthChartRequest, BirthChartResponse, TransitsResponse
from security import require_user
from services.birth_chart_service import calculate_birth_chart, calculate_current_transits

router = APIRouter(prefix="/chart", tags=["Birth Chart"])


# /birth and /vedic geocode and cast a full chart from the caller's birth
# details, so they require sign-in; /transits is the same sky for everyone.
@router.post("/birth", response_model=BirthChartResponse, dependencies=[Depends(require_user)])
def get_birth_chart(request: BirthChartRequest):
    """Calculate a full birth chart using Swiss Ephemeris."""
    chart = calculate_birth_chart(
        birth_date=request.birth_date,
        birth_time=request.birth_time,
        birth_place=request.birth_place,
    )
    return chart


@router.post("/vedic", response_model=BirthChartResponse, dependencies=[Depends(require_user)])
def get_vedic_chart(request: BirthChartRequest):
    """Calculate a sidereal Vedic (Jyotish) birth chart.

    Uses the Lahiri ayanamsa, the nine grahas (including Rahu/Ketu),
    and whole-sign houses — the basis of the North/South Indian kundli.
    """
    chart = calculate_birth_chart(
        birth_date=request.birth_date,
        birth_time=request.birth_time,
        birth_place=request.birth_place,
        sidereal=True,
    )
    return chart


@router.get("/transits", response_model=TransitsResponse)
def get_current_transits():
    """Get current planetary positions (today's transits)."""
    transits = calculate_current_transits()
    return {"transits": transits}
