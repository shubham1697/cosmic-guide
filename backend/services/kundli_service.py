"""
Kundli (Ashta Koota Gun Milan) matching — real Nakshatra-based calculation.

Uses Swiss Ephemeris via birth_chart_service to get the Moon's true
ecliptic longitude for each person, then derives Nakshatras and computes
all eight Koota scores according to traditional Vedic rules.
"""

from logger import get_logger
from services.birth_chart_service import calculate_birth_chart
from data.astro_constants import NAKSHATRAS
from data.kundli_tables import (
    VARNA, VASHYA_SIGN, YONI_ANIMAL, YONI_COMPAT,
    GANA, NADI, RASHI_LORD, GRAHA_FRIENDSHIP,
)

logger = get_logger(__name__)


def _nak_index_from_moon(moon_lon: float) -> int:
    """Nakshatra index (0-26) from Moon longitude."""
    return int(moon_lon / (360 / 27)) % 27


def _rashi_from_moon(moon_lon: float) -> int:
    """Rashi index (0-11) from Moon longitude."""
    return int(moon_lon / 30) % 12


# ── Koota scoring functions ──────────────────────────────────────────────────

def _varna_score(nak1: int, nak2: int) -> int:
    """Varna Koota (max 1). Boy's varna >= Girl's varna."""
    v1, v2 = VARNA[nak1], VARNA[nak2]
    return 1 if v1 >= v2 else 0


def _vashya_score(rashi1: int, rashi2: int) -> int:
    """Vashya Koota (max 2)."""
    v1, v2 = VASHYA_SIGN[rashi1], VASHYA_SIGN[rashi2]
    if v1 == v2:
        return 2
    # Mutual vashya pairs
    mutual = {(0,1),(1,0),(2,0),(0,2)}
    if (v1,v2) in mutual:
        return 1
    return 0


def _tara_score(nak1: int, nak2: int) -> int:
    """Tara Koota (max 3). Based on Nakshatra distance."""
    diff = (nak2 - nak1) % 27
    tara = diff % 9
    # 0-indexed tara positions:
    # 0=Janma, 1=Sampat, 2=Vipat, 3=Kshema, 4=Pratyari,
    # 5=Sadhana, 6=Naidhana, 7=Mitra, 8=Parama Mitra
    # Inauspicious: 2(Vipat), 4(Pratyari), 6(Naidhana)
    if tara in (2, 4, 6):
        return 0
    return 3


def _yoni_score(nak1: int, nak2: int) -> int:
    """Yoni Koota (max 4). Animal compatibility."""
    y1, y2 = YONI_ANIMAL[nak1], YONI_ANIMAL[nak2]
    if y1 == y2:
        return 4
    # Friendly / neutral / enemy pairs (simplified)
    diff = abs(y1 - y2)
    if diff <= 2:
        return 3
    elif diff <= 5:
        return 2
    elif diff <= 8:
        return 1
    return 0


def _graha_maitri_score(rashi1: int, rashi2: int) -> int:
    """Graha Maitri Koota (max 5). Lord friendship."""
    lord1 = RASHI_LORD[rashi1]
    lord2 = RASHI_LORD[rashi2]
    score = GRAHA_FRIENDSHIP.get((lord1, lord2), 3)
    return score


def _gana_score(nak1: int, nak2: int) -> int:
    """Gana Koota (max 6). Temperament match."""
    g1, g2 = GANA[nak1], GANA[nak2]
    if g1 == g2:
        return 6
    if {g1, g2} == {0, 1}:
        return 5
    if {g1, g2} == {1, 2}:
        return 3
    return 0  # Deva-Rakshasa


def _bhakoot_score(rashi1: int, rashi2: int) -> int:
    """Bhakoot Koota (max 7). Rashi relationship."""
    diff = (rashi2 - rashi1) % 12
    # Inauspicious house pairs (0-based diff where diff=0 means same sign):
    # 2/12 → 2nd house: diff=1, 12th house: diff=11
    # 5/9  → 5th house: diff=4, 9th house: diff=8
    # 6/8  → 6th house: diff=5, 8th house: diff=7
    if diff in {1, 11, 4, 8, 5, 7}:
        return 0
    return 7


def _nadi_score(nak1: int, nak2: int) -> int:
    """Nadi Koota (max 8). Health & genes — same Nadi is dosha."""
    n1, n2 = NADI[nak1], NADI[nak2]
    return 0 if n1 == n2 else 8


# ── Manglik Dosha check ──────────────────────────────────────────────────────

def _check_manglik(chart: dict) -> bool:
    """Check if Mars is in houses 1, 2, 4, 7, 8, or 12 (Manglik Dosha)."""
    if not chart.get("houses"):
        return False  # can't determine without houses

    mars = next((p for p in chart["planets"] if p["name"] == "Mars"), None)
    if not mars:
        return False

    mars_lon = mars["longitude"]
    asc_lon = chart["ascendant"]["longitude"]

    # Determine which house Mars occupies
    cusps = [h["cusp_longitude"] for h in chart["houses"]]
    house = 1
    for i in range(12):
        next_cusp = cusps[(i + 1) % 12]
        if cusps[i] <= next_cusp:
            if cusps[i] <= mars_lon < next_cusp:
                house = i + 1
                break
        else:  # wraps around 360°
            if mars_lon >= cusps[i] or mars_lon < next_cusp:
                house = i + 1
                break

    return house in (1, 2, 4, 7, 8, 12)


# ── Main entry point ─────────────────────────────────────────────────────────

def calculate_kundli(person1: dict, person2: dict) -> dict:
    """
    Calculate Kundli matching using real Swiss Ephemeris calculations.

    Computes Moon positions for both persons via birth_chart_service,
    then applies all 8 Ashta Koota rules based on actual Nakshatras.
    """
    logger.info(
        "calculate_kundli  person1=%s  person2=%s",
        person1.get("name", "?"), person2.get("name", "?"),
    )

    # Calculate birth charts for both persons
    chart1 = calculate_birth_chart(
        birth_date=person1["birth_date"],
        birth_time=person1.get("birth_time"),
        birth_place=person1.get("birth_place"),
    )
    chart2 = calculate_birth_chart(
        birth_date=person2["birth_date"],
        birth_time=person2.get("birth_time"),
        birth_place=person2.get("birth_place"),
    )

    # Get Moon longitudes
    moon1 = next(p for p in chart1["planets"] if p["name"] == "Moon")
    moon2 = next(p for p in chart2["planets"] if p["name"] == "Moon")

    moon_lon1 = moon1["longitude"]
    moon_lon2 = moon2["longitude"]

    nak1 = _nak_index_from_moon(moon_lon1)
    nak2 = _nak_index_from_moon(moon_lon2)
    rashi1 = _rashi_from_moon(moon_lon1)
    rashi2 = _rashi_from_moon(moon_lon2)

    # Calculate all 8 Koota scores
    koota_scores = {
        "Varna":        _varna_score(nak1, nak2),
        "Vashya":       _vashya_score(rashi1, rashi2),
        "Tara":         _tara_score(nak1, nak2),
        "Yoni":         _yoni_score(nak1, nak2),
        "Graha Maitri": _graha_maitri_score(rashi1, rashi2),
        "Gana":         _gana_score(nak1, nak2),
        "Bhakoot":      _bhakoot_score(rashi1, rashi2),
        "Nadi":         _nadi_score(nak1, nak2),
    }
    total = sum(koota_scores.values())
    max_score = 36

    if total >= 24:
        compatibility = "Excellent"
    elif total >= 18:
        compatibility = "Good"
    elif total >= 12:
        compatibility = "Average"
    else:
        compatibility = "Below Average"

    # Manglik dosha
    manglik1 = _check_manglik(chart1)
    manglik2 = _check_manglik(chart2)
    has_manglik = manglik1 or manglik2

    # Build detailed analysis
    nak1_name = NAKSHATRAS[nak1]
    nak2_name = NAKSHATRAS[nak2]

    analysis_parts = [
        f"The Ashta Koota analysis for {person1['name']} (Moon in {moon1['sign']}, "
        f"Nakshatra: {nak1_name}) and {person2['name']} (Moon in {moon2['sign']}, "
        f"Nakshatra: {nak2_name}) reveals a total score of {total} out of {max_score} points.",
        f"This indicates {compatibility.lower()} compatibility.",
    ]

    # Highlight strongest and weakest kootas
    max_possible = {"Varna": 1, "Vashya": 2, "Tara": 3, "Yoni": 4,
                    "Graha Maitri": 5, "Gana": 6, "Bhakoot": 7, "Nadi": 8}
    strong = [k for k, v in koota_scores.items() if v == max_possible[k]]
    weak = [k for k, v in koota_scores.items() if v == 0]

    if strong:
        analysis_parts.append(f"Strongest alignment: {', '.join(strong)}.")
    if weak:
        analysis_parts.append(
            f"Areas needing attention: {', '.join(weak)}. "
            "These can be harmonised with mutual understanding and effort."
        )
    if has_manglik:
        who = []
        if manglik1:
            who.append(person1["name"])
        if manglik2:
            who.append(person2["name"])
        analysis_parts.append(
            f"Manglik Dosha detected for {' and '.join(who)}. "
            "Traditional remedies may be considered."
        )

    analysis = " ".join(analysis_parts)

    logger.info(
        "Kundli result: total=%d/%d compat=%s manglik=%s nak1=%s nak2=%s",
        total, max_score, compatibility, has_manglik, nak1_name, nak2_name,
    )

    return {
        "total_score": total,
        "max_score": max_score,
        "koota_scores": koota_scores,
        "compatibility": compatibility,
        "analysis": analysis,
        "has_manglik_dosha": has_manglik,
    }
