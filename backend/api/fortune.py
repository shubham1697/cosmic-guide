from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from schemas import FortuneRequest, FortuneResponse
from services.fortune_service import generate_fortune
from services.zodiac_service import ZODIAC_SIGNS
from db.database import get_db
from logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/fortune", tags=["Fortune"])


@router.post("/generate", response_model=FortuneResponse)
def create_fortune(request: FortuneRequest, db: Session = Depends(get_db)):
    logger.info("→ POST /fortune/generate | sign=%s topic=%s mood=%s", request.zodiac_sign, request.topic, request.mood)
    
    if request.zodiac_sign not in ZODIAC_SIGNS:
        logger.warning("← POST /fortune/generate | status=400 | invalid sign")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid zodiac sign. Must be one of: {', '.join(ZODIAC_SIGNS)}",
        )

    fortune_text = generate_fortune(request.zodiac_sign, request.topic, request.mood, db=db)
    
    logger.info("← POST /fortune/generate | status=200 | text_len=%d", len(fortune_text or ""))
    return FortuneResponse(
        zodiac_sign=request.zodiac_sign,
        topic=request.topic,
        mood=request.mood,
        fortune_text=fortune_text,
    )
