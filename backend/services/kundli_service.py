"""Kundli (Gun Milan) matching calculation."""

from logger import get_logger

logger = get_logger(__name__)


def calculate_kundli(person1: dict, person2: dict) -> dict:
    """Calculate Kundli matching (mock implementation — returns element-based results)."""
    logger.info(
        "calculate_kundli  person1=%s  person2=%s  [NOTE: mock implementation]",
        person1.get("name", "?"), person2.get("name", "?"),
    )
    koota_scores = {
        "Varna": 1,
        "Vashya": 1,
        "Tara": 3,
        "Yoni": 3,
        "Graha Maitri": 4,
        "Gana": 5,
        "Bhakoot": 5,
        "Nadi": 4,
    }
    total = sum(koota_scores.values())
    max_score = 36

    if total >= 24:
        compatibility = "Good"
    elif total >= 18:
        compatibility = "Average"
    else:
        compatibility = "Below Average"

    analysis = (
        f"The Ashta Koota analysis for {person1['name']} and {person2['name']} "
        f"reveals a total score of {total} out of {max_score} points. "
        f"This indicates a {compatibility.lower()} level of compatibility. "
        "The strongest alignment is seen in Tara and Gana, suggesting good "
        "destiny compatibility and temperamental harmony. Consider consulting "
        "a Vedic astrologer for a detailed birth chart analysis."
    )

    logger.debug(
        "calculate_kundli  total=%d/%d  compatibility=%s",
        total, max_score, compatibility,
    )
    return {
        "total_score": total,
        "max_score": max_score,
        "koota_scores": koota_scores,
        "compatibility": compatibility,
        "analysis": analysis,
        "has_manglik_dosha": False,
    }
