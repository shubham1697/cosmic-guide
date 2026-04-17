"""Zodiac compatibility calculation."""

from logger import get_logger
from services.zodiac_service import ZODIAC_ELEMENTS

logger = get_logger(__name__)

# Element-based compatibility scores (used as fallback only)
ELEMENT_COMPATIBILITY = {
    ("Fire", "Fire"): 80, ("Fire", "Air"): 85, ("Fire", "Earth"): 55, ("Fire", "Water"): 50,
    ("Air", "Air"): 75, ("Air", "Earth"): 60, ("Air", "Water"): 65,
    ("Earth", "Earth"): 90, ("Earth", "Water"): 85,
    ("Water", "Water"): 80,
}

# Sign-specific compatibility scores for all 78 canonical pairs.
# Keys are always (alphabetically_first_sign, alphabetically_second_sign).
# Derived from element base + modality interaction + traditional astrology.
SIGN_PAIR_SCORES = {
    # ── Aquarius ──────────────────────────────────────────────────────────────
    ("Aquarius", "Aquarius"): 68,
    ("Aquarius", "Aries"):    80,
    ("Aquarius", "Cancer"):   55,
    ("Aquarius", "Capricorn"):57,
    ("Aquarius", "Gemini"):   82,
    ("Aquarius", "Leo"):      80,   # opposites
    ("Aquarius", "Libra"):    82,
    ("Aquarius", "Pisces"):   65,
    ("Aquarius", "Sagittarius"): 88,
    ("Aquarius", "Scorpio"):  58,
    ("Aquarius", "Taurus"):   55,
    ("Aquarius", "Virgo"):    60,
    # ── Aries ─────────────────────────────────────────────────────────────────
    ("Aries", "Aries"):       70,
    ("Aries", "Cancer"):      47,
    ("Aries", "Capricorn"):   50,
    ("Aries", "Gemini"):      88,
    ("Aries", "Leo"):         85,
    ("Aries", "Libra"):       80,   # opposites
    ("Aries", "Pisces"):      55,
    ("Aries", "Sagittarius"): 88,
    ("Aries", "Scorpio"):     47,
    ("Aries", "Taurus"):      52,
    ("Aries", "Virgo"):       58,
    # ── Cancer ────────────────────────────────────────────────────────────────
    ("Cancer", "Cancer"):     72,
    ("Cancer", "Capricorn"):  82,   # opposites
    ("Cancer", "Gemini"):     62,
    ("Cancer", "Leo"):        47,
    ("Cancer", "Libra"):      60,
    ("Cancer", "Pisces"):     88,
    ("Cancer", "Sagittarius"):53,
    ("Cancer", "Scorpio"):    87,
    ("Cancer", "Taurus"):     83,
    ("Cancer", "Virgo"):      88,
    # ── Capricorn ─────────────────────────────────────────────────────────────
    ("Capricorn", "Capricorn"):78,
    ("Capricorn", "Gemini"):  58,
    ("Capricorn", "Leo"):     52,
    ("Capricorn", "Libra"):   57,
    ("Capricorn", "Pisces"):  88,
    ("Capricorn", "Sagittarius"): 58,
    ("Capricorn", "Scorpio"): 83,
    ("Capricorn", "Taurus"):  87,
    ("Capricorn", "Virgo"):   92,
    # ── Gemini ────────────────────────────────────────────────────────────────
    ("Gemini", "Gemini"):     68,
    ("Gemini", "Leo"):        88,
    ("Gemini", "Libra"):      82,
    ("Gemini", "Pisces"):     60,
    ("Gemini", "Sagittarius"):82,   # opposites
    ("Gemini", "Scorpio"):    60,
    ("Gemini", "Taurus"):     62,
    ("Gemini", "Virgo"):      57,   # opposites
    # ── Leo ───────────────────────────────────────────────────────────────────
    ("Leo", "Leo"):           72,
    ("Leo", "Libra"):         85,
    ("Leo", "Pisces"):        52,
    ("Leo", "Sagittarius"):   85,
    ("Leo", "Scorpio"):       47,
    ("Leo", "Taurus"):        50,
    ("Leo", "Virgo"):         57,
    # ── Libra ─────────────────────────────────────────────────────────────────
    ("Libra", "Libra"):       68,
    ("Libra", "Pisces"):      70,
    ("Libra", "Sagittarius"): 88,
    ("Libra", "Scorpio"):     60,
    ("Libra", "Taurus"):      57,
    ("Libra", "Virgo"):       62,
    # ── Pisces ────────────────────────────────────────────────────────────────
    ("Pisces", "Pisces"):     72,
    ("Pisces", "Sagittarius"):47,
    ("Pisces", "Scorpio"):    85,
    ("Pisces", "Taurus"):     88,
    ("Pisces", "Virgo"):      80,   # opposites
    # ── Sagittarius ───────────────────────────────────────────────────────────
    ("Sagittarius", "Sagittarius"): 72,
    ("Sagittarius", "Scorpio"):     50,
    ("Sagittarius", "Taurus"):      58,
    ("Sagittarius", "Virgo"):       52,
    # ── Scorpio ───────────────────────────────────────────────────────────────
    ("Scorpio", "Scorpio"):   70,
    ("Scorpio", "Taurus"):    82,   # opposites
    ("Scorpio", "Virgo"):     88,
    # ── Taurus ────────────────────────────────────────────────────────────────
    ("Taurus", "Taurus"):     80,
    ("Taurus", "Virgo"):      92,
    # ── Virgo ─────────────────────────────────────────────────────────────────
    ("Virgo", "Virgo"):       75,
}


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
            "get_compatibility  AI exception (%s)  %s x %s — using static template",
            exc, sign1, sign2,
        )

    # ── 3. Static template fallback ─────────────────────────────────────────────
    logger.debug("get_compatibility  STATIC FALLBACK  %s x %s  score=%d", sign1, sign2, score)
    if score >= 80:
        description = f"{sign1} and {sign2} share a natural harmony. Their {elem1} and {elem2} energies complement each other beautifully, creating a bond that feels effortless and deeply fulfilling."
        love_advice = "Nurture this connection with open communication and shared adventures. Your energies amplify each other."
        strengths_together = "Deep understanding, natural chemistry, shared values, and the ability to grow together through life's challenges."
        challenges = "You may become too comfortable — keep the spark alive by trying new things together and maintaining individual identities."
    elif score >= 60:
        description = f"{sign1} and {sign2} bring different strengths to the table. The interplay between {elem1} and {elem2} creates a dynamic, growth-oriented partnership."
        love_advice = "Embrace your differences as opportunities to learn and grow. Patience and understanding are your greatest allies."
        strengths_together = "Complementary skills, mutual respect, growth through differences, and the ability to balance each other out."
        challenges = "Communication styles may differ — practice active listening and express needs clearly to bridge any gaps."
    else:
        description = f"{sign1} and {sign2} face an uphill journey together. The tension between {elem1} and {elem2} requires conscious effort, but the rewards of overcoming challenges can be profound."
        love_advice = "Success requires mutual respect and willingness to compromise. Focus on shared goals rather than differences."
        strengths_together = "When it works, the contrast creates passion and excitement. You challenge each other to grow in ways comfortable partners rarely do."
        challenges = "Fundamental differences in approach and temperament require patience. Regular honest conversations prevent misunderstandings."

    return {
        "sign1": sign1, "sign2": sign2, "score": score,
        "description": description, "love_advice": love_advice,
        "strengths_together": strengths_together, "challenges": challenges,
    }
