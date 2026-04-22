"""Tarot card data and drawing logic."""

import random

from data.tarot_data import TAROT_CARDS


from logger import get_logger


logger = get_logger(__name__)

# In-memory name→card lookup for fast seeding checks
_CARD_BY_NAME = {c["name"]: c for c in TAROT_CARDS}


def seed_tarot_db(db) -> int:
    """
    Seed the tarot_cards DB table from the static TAROT_CARDS list if empty.
    Returns the number of rows inserted (0 if already seeded).
    """
    from db.models import TarotCard
    existing = db.query(TarotCard).count()
    if existing >= len(TAROT_CARDS):
        logger.debug("seed_tarot_db  already seeded  count=%d", existing)
        return 0

    inserted = 0
    for card in TAROT_CARDS:
        try:
            row = TarotCard(
                name=card["name"],
                number=card["number"],
                meaning=card["meaning"],
                upright_interpretation=card["upright"],
                reversed_interpretation=card["reversed"],
            )
            db.add(row)
            inserted += 1
        except Exception as exc:
            logger.warning("seed_tarot_db  skip '%s': %s", card["name"], exc)
    db.commit()
    logger.info("seed_tarot_db  seeded %d cards", inserted)
    return inserted


def draw_tarot_card(db=None) -> dict:
    """
    Draw a random tarot card.

    Resolution order:
    1. DB table (seeded with static or AI-upgraded interpretations).
    2. In-memory static list (fallback if DB unavailable).
    """
    import random as _random
    is_reversed = _random.random() < 0.3  # 30% reversed

    if db is not None:
        try:
            from db.models import TarotCard
            # Auto-seed on first use
            count = db.query(TarotCard).count()
            if count == 0:
                seed_tarot_db(db)

            total = db.query(TarotCard).count()
            if total > 0:
                offset = _random.randint(0, total - 1)
                card_row = db.query(TarotCard).offset(offset).first()
                if card_row:
                    interpretation = (
                        card_row.reversed_interpretation if is_reversed
                        else card_row.upright_interpretation
                    )
                    logger.info(
                        "draw_tarot_card  DB  card='%s'  reversed=%s",
                        card_row.name, is_reversed,
                    )
                    return {
                        "name": card_row.name,
                        "number": card_row.number,
                        "meaning": card_row.meaning,
                        "interpretation": interpretation,
                        "is_reversed": is_reversed,
                    }
        except Exception as exc:
            logger.warning("draw_tarot_card  DB error (%s)", exc)

    # DB unavailable — surface the error
    from fastapi import HTTPException
    raise HTTPException(
        status_code=503,
        detail="Tarot service temporarily unavailable. Please try again shortly.",
    )

