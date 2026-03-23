from fastapi import APIRouter
from schemas import FortuneRequest, FortuneResponse
from services.fortune_service import generate_fortune

router = APIRouter(prefix="/fortune", tags=["Fortune"])


@router.post("/generate", response_model=FortuneResponse)
def create_fortune(request: FortuneRequest):
    fortune_text = generate_fortune(request.zodiac_sign, request.topic, request.mood)
    return FortuneResponse(
        zodiac_sign=request.zodiac_sign,
        topic=request.topic,
        mood=request.mood,
        fortune_text=fortune_text,
    )
