"""Zodiac compatibility calculation."""

from logger import get_logger
from data.zodiac_data import ZODIAC_ELEMENTS
from data.compatibility_data import ELEMENT_COMPATIBILITY, SIGN_PAIR_SCORES

logger = get_logger(__name__)


def _canonical(sign1: str, sign2: str) -> tuple:
    """Return a canonical (alphabetical) ordering of two sign names for DB lookup."""
    return (sign1, sign2) if sign1 <= sign2 else (sign2, sign1)


def get_pair_score(sign1: str, sign2: str) -> int:
    """Return the sign-specific compatibility score for two signs."""
    canon = _canonical(sign1, sign2)
    if canon in SIGN_PAIR_SCORES:
        return SIGN_PAIR_SCORES[canon]
    # Fallback to element-based score (shouldn't be reached for valid signs)
    elem1 = ZODIAC_ELEMENTS.get(sign1, "Fire")
    elem2 = ZODIAC_ELEMENTS.get(sign2, "Fire")
    key = (elem1, elem2) if (elem1, elem2) in ELEMENT_COMPATIBILITY else (elem2, elem1)
    return ELEMENT_COMPATIBILITY.get(key, 70)


def get_compatibility(sign1: str, sign2: str, db=None) -> dict:
    """
    Calculate compatibility between two zodiac signs.

    Resolution order:
    1. DB cache — look up pre-generated result.
    2. Real-time AI generation (single pair).
    3. Static template fallback.
    """
    elem1 = ZODIAC_ELEMENTS.get(sign1, "Fire")
    elem2 = ZODIAC_ELEMENTS.get(sign2, "Fire")
    score = get_pair_score(sign1, sign2)

    logger.debug(
        "get_compatibility  %s(%s) x %s(%s)  score=%d",
        sign1, elem1, sign2, elem2, score,
    )

    # ── 1. DB cache ───────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import Compatibility
            s_a, s_b = _canonical(sign1, sign2)
            cached = (
                db.query(Compatibility)
                .filter(Compatibility.sign1 == s_a, Compatibility.sign2 == s_b)
                .first()
            )
            if cached:
                logger.info("get_compatibility  DB HIT  %s x %s", sign1, sign2)
                return {
                    "sign1": sign1,
                    "sign2": sign2,
                    "score": cached.score,
                    "description":        cached.description,
                    "love_advice":        cached.love_advice,
                    "strengths_together": cached.strengths,
                    "challenges":         cached.challenges,
                }
            else:
                logger.debug("get_compatibility  DB MISS  %s x %s", sign1, sign2)
        except Exception as exc:
            logger.warning("get_compatibility  DB query failed (%s)", exc)

    # ── 2. AI-generated descriptions ────────────────────────────────────────────
    try:
        from services.ai_service import generate_compatibility
        ai_data = generate_compatibility(sign1, sign2, score)
        if ai_data:
            logger.info("get_compatibility  AI OK  %s x %s  score=%d", sign1, sign2, score)
            # Persist so future requests are free
            if db is not None:
                try:
                    from db.models import Compatibility
                    s_a, s_b = _canonical(sign1, sign2)
                    row = Compatibility(
                        sign1=s_a, sign2=s_b, score=score,
                        description=ai_data["description"],
                        love_advice=ai_data["love_advice"],
                        strengths=ai_data["strengths_together"],
                        challenges=ai_data["challenges"],
                    )
                    db.add(row)
                    db.commit()
                    logger.debug("get_compatibility  persisted to DB  %s x %s", s_a, s_b)
                except Exception as exc:
                    logger.warning("get_compatibility  DB persist failed (%s)", exc)
                    db.rollback()
            return {
                "sign1": sign1, "sign2": sign2, "score": score,
                "description":        ai_data["description"],
                "love_advice":        ai_data["love_advice"],
                "strengths_together": ai_data["strengths_together"],
                "challenges":         ai_data["challenges"],
            }
        logger.warning("get_compatibility  AI returned None  %s x %s", sign1, sign2)
    except Exception as exc:
        logger.warning(
            "get_compatibility  AI exception (%s)  %s x %s — raising 503",
            exc, sign1, sign2,
        )

    # AI unavailable and no cached data — surface the error
    from fastapi import HTTPException
    raise HTTPException(
        status_code=503,
        detail="Compatibility service temporarily unavailable. Please try again shortly.",
    )
