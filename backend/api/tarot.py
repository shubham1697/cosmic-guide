from fastapi import APIRouter
from schemas import TarotCardResponse
from services.tarot_service import draw_tarot_card

router = APIRouter(prefix="/tarot", tags=["Tarot"])


@router.get("/draw", response_model=TarotCardResponse)
def draw_card():
    return draw_tarot_card()
