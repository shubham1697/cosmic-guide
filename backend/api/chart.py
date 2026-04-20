from fastapi import APIRouter
from schemas import BirthChartRequest, BirthChartResponse, TransitsResponse
from services.birth_chart_service import calculate_birth_chart, calculate_current_transits

router = APIRouter(prefix="/chart", tags=["Birth Chart"])


@router.post("/birth", response_model=BirthChartResponse)
def get_birth_chart(request: BirthChartRequest):
    """Calculate a full birth chart using Swiss Ephemeris."""
    chart = calculate_birth_chart(
        birth_date=request.birth_date,
        birth_time=request.birth_time,
        birth_place=request.birth_place,
    )
    return chart


@router.get("/transits", response_model=TransitsResponse)
def get_current_transits():
    """Get current planetary positions (today's transits)."""
    transits = calculate_current_transits()
    return {"transits": transits}
