from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from schemas import CompatibilityRequest, CompatibilityResponse
from services.compatibility_service import get_compatibility
from services.zodiac_service import ZODIAC_SIGNS
from db.database import get_db
from logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/compatibility", tags=["Compatibility"])


@router.post("/check", response_model=CompatibilityResponse)
def check_compatibility(request: CompatibilityRequest, db: Session = Depends(get_db)):
    logger.info("→ POST /compatibility/check | sign1=%s sign2=%s", request.sign1, request.sign2)
    
    if request.sign1 not in ZODIAC_SIGNS or request.sign2 not in ZODIAC_SIGNS:
        logger.warning("← POST /compatibility/check | status=400 | invalid signs")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )
    
    result = get_compatibility(request.sign1, request.sign2, db=db)
    logger.info("← POST /compatibility/check | status=200 | score=%d", result.get("score", 0))
    return result
