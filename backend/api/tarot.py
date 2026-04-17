from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from schemas import TarotCardResponse
from services.tarot_service import draw_tarot_card
from db.database import get_db

router = APIRouter(prefix="/tarot", tags=["Tarot"])


@router.get("/draw", response_model=TarotCardResponse)
def draw_card(db: Session = Depends(get_db)):
    return draw_tarot_card(db=db)
