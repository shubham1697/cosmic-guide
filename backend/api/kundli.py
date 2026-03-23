from fastapi import APIRouter
from schemas import KundliRequest, KundliResponse
from services.kundli_service import calculate_kundli

router = APIRouter(prefix="/kundli", tags=["Kundli"])


@router.post("/match", response_model=KundliResponse)
def match_kundli(request: KundliRequest):
    return calculate_kundli(
        request.person1.model_dump(),
        request.person2.model_dump(),
    )
