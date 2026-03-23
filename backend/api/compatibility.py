from fastapi import APIRouter, HTTPException
from schemas import CompatibilityRequest, CompatibilityResponse
from services.compatibility_service import get_compatibility
from services.zodiac_service import ZODIAC_SIGNS

router = APIRouter(prefix="/compatibility", tags=["Compatibility"])


@router.post("/check", response_model=CompatibilityResponse)
def check_compatibility(request: CompatibilityRequest):
    if request.sign1 not in ZODIAC_SIGNS or request.sign2 not in ZODIAC_SIGNS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    return get_compatibility(request.sign1, request.sign2)
