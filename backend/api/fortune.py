from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from schemas import FortuneRequest, FortuneResponse
from services.fortune_service import generate_fortune
from db.database import get_db

router = APIRouter(prefix="/fortune", tags=["Fortune"])


@router.post("/generate", response_model=FortuneResponse)
def create_fortune(request: FortuneRequest, db: Session = Depends(get_db)):
    fortune_text = generate_fortune(request.zodiac_sign, request.topic, request.mood, db=db)
    return FortuneResponse(
        zodiac_sign=request.zodiac_sign,
        topic=request.topic,
        mood=request.mood,
        fortune_text=fortune_text,
    )
