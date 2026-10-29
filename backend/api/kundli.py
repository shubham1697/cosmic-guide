from fastapi import APIRouter, Depends
from schemas import KundliRequest, KundliResponse
from security import require_user
from services.kundli_service import calculate_kundli

# Sign-in required: every match geocodes two places and runs two ephemeris
# charts, and the request body carries a second person's full birth details.
router = APIRouter(prefix="/kundli", tags=["Kundli"], dependencies=[Depends(require_user)])


@router.post("/match", response_model=KundliResponse)
def match_kundli(request: KundliRequest):
    return calculate_kundli(
        request.person1.model_dump(),
        request.person2.model_dump(),
    )
