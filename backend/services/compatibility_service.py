"""Zodiac compatibility calculation."""

from logger import get_logger
from logging_utils import service_call, log_db_query, log_external_api_call
from data.zodiac_data import ZODIAC_ELEMENTS
from data.compatibility_data import ELEMENT_COMPATIBILITY, SIGN_PAIR_SCORES
from data.mock.compatibility_templates import COMPATIBILITY_TEMPLATES
import time

logger = get_logger(__name__)


def canonical_pair(sign1: str, sign2: str) -> tuple:
    """Canonical (alphabetical) ordering of a sign pair — the single ordering used
    by every compatibility read and write path so a pair maps to exactly one row."""
    return (sign1, sign2) if sign1 <= sign2 else (sign2, sign1)


# Backwards-compatible internal alias.
_canonical = canonical_pair


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


def _mock_compatibility(sign1: str, sign2: str, score: int, elem1: str, elem2: str) -> dict:
    tier = "high" if score >= 80 else "medium" if score >= 60 else "low"
    template = COMPATIBILITY_TEMPLATES[tier]
    return {
        "sign1": str(sign1),
        "sign2": str(sign2),
        "score": int(score),
        "description": template["description"].format(sign1=sign1, sign2=sign2, elem1=elem1, elem2=elem2),
        "love_advice": template["love_advice"],
        "strengths_together": template["strengths_together"],
        "challenges": template["challenges"],
    }


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

    def _safe_str(value, default: str = "") -> str:
        return default if value is None else str(value)

    logger.debug(
        "get_compatibility  %s(%s) x %s(%s)  score=%d",
        sign1, elem1, sign2, elem2, score,
    )
    s_a, s_b = _canonical(sign1, sign2)

    # ── 1. DB cache ───────────────────────────────────────────────────────────
    if db is not None:
        try:
            from db.models import Compatibility
            s_a, s_b = _canonical(sign1, sign2)
            t0 = time.perf_counter()
            cached = (
                db.query(Compatibility)
                .filter(Compatibility.sign1 == s_a, Compatibility.sign2 == s_b)
                .first()
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000
            
            if cached:
                log_db_query("SELECT", "compatibility", f"where sign1={s_a} AND sign2={s_b}", rows_affected=1, elapsed_ms=elapsed_ms)
                logger.info("get_compatibility  source=db  %s x %s", sign1, sign2)
                return {
                    "sign1": _safe_str(sign1),
                    "sign2": _safe_str(sign2),
                    "score": int(cached.score or score),
                    "description":        _safe_str(cached.description),
                    "love_advice":        _safe_str(cached.love_advice),
                    "strengths_together": _safe_str(cached.strengths),
                    "challenges":         _safe_str(cached.challenges),
                }
            else:
                log_db_query("SELECT", "compatibility", f"where sign1={s_a} AND sign2={s_b}", rows_affected=0, elapsed_ms=elapsed_ms)
                logger.debug("get_compatibility  DB MISS  %s x %s", sign1, sign2)
        except Exception as exc:
            logger.warning("get_compatibility  DB query failed (%s) — falling through to AI", exc)
            log_db_query("SELECT", "compatibility", f"where sign1={s_a} AND sign2={s_b}", error=exc, elapsed_ms=0)
            # A DB read failure is treated like a cache miss: fall through to the AI
            # step so a healthy LLM still serves fresh content; mock is the final fallback.

    # ── 2. AI-generated descriptions ────────────────────────────────────────────
    try:
        from services.ai_service import generate_compatibility
        ai_data = generate_compatibility(sign1, sign2, score)
        if ai_data:
            logger.info("get_compatibility  source=llm  %s x %s", sign1, sign2)
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
                    t0 = time.perf_counter()
                    db.commit()
                    elapsed_ms = (time.perf_counter() - t0) * 1000
                    log_db_query("INSERT", "compatibility", f"sign1={s_a} sign2={s_b}", rows_affected=1, elapsed_ms=elapsed_ms)
                    logger.debug("get_compatibility  persisted to DB  %s x %s", s_a, s_b)
                except Exception as exc:
                    logger.warning("get_compatibility  DB persist failed (%s)", exc)
                    log_db_query("INSERT", "compatibility", error=exc, elapsed_ms=0)
                    db.rollback()
            return {
                "sign1": _safe_str(sign1),
                "sign2": _safe_str(sign2),
                "score": int(score),
                "description":        _safe_str(ai_data.get("description")),
                "love_advice":        _safe_str(ai_data.get("love_advice")),
                "strengths_together": _safe_str(ai_data.get("strengths_together")),
                "challenges":         _safe_str(ai_data.get("challenges")),
            }
        logger.warning("get_compatibility  AI returned None  %s x %s", sign1, sign2)
    except Exception as exc:
        logger.warning(
            "get_compatibility  AI exception (%s)  %s x %s — falling back to mock",
            exc, sign1, sign2,
        )

    logger.warning("get_compatibility  source=mock  %s x %s  reason=ai_unavailable", sign1, sign2)
    return _mock_compatibility(sign1, sign2, score, elem1, elem2)
