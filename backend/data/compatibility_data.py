"""Compatibility score lookup tables."""

# Element-based compatibility scores (used as fallback only)
ELEMENT_COMPATIBILITY = {
    ("Fire", "Fire"): 80, ("Fire", "Air"): 85, ("Fire", "Earth"): 55, ("Fire", "Water"): 50,
    ("Air", "Air"): 75, ("Air", "Earth"): 60, ("Air", "Water"): 65,
    ("Earth", "Earth"): 90, ("Earth", "Water"): 85,
    ("Water", "Water"): 80,
}

# Sign-specific compatibility scores for all 78 canonical pairs.
# Keys are always (alphabetically_first_sign, alphabetically_second_sign).
SIGN_PAIR_SCORES = {
    # ── Aquarius ──────────────────────────────────────────────────────────────
    ("Aquarius", "Aquarius"): 68,
    ("Aquarius", "Aries"):    80,
    ("Aquarius", "Cancer"):   55,
    ("Aquarius", "Capricorn"):57,
    ("Aquarius", "Gemini"):   82,
    ("Aquarius", "Leo"):      80,
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
    ("Aries", "Libra"):       80,
    ("Aries", "Pisces"):      55,
    ("Aries", "Sagittarius"): 88,
    ("Aries", "Scorpio"):     47,
    ("Aries", "Taurus"):      52,
    ("Aries", "Virgo"):       58,
    # ── Cancer ────────────────────────────────────────────────────────────────
    ("Cancer", "Cancer"):     72,
    ("Cancer", "Capricorn"):  82,
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
    ("Gemini", "Sagittarius"):82,
    ("Gemini", "Scorpio"):    60,
    ("Gemini", "Taurus"):     62,
    ("Gemini", "Virgo"):      57,
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
    ("Pisces", "Virgo"):      80,
    # ── Sagittarius ───────────────────────────────────────────────────────────
    ("Sagittarius", "Sagittarius"): 72,
    ("Sagittarius", "Scorpio"):     50,
    ("Sagittarius", "Taurus"):      58,
    ("Sagittarius", "Virgo"):       52,
    # ── Scorpio ───────────────────────────────────────────────────────────────
    ("Scorpio", "Scorpio"):   70,
    ("Scorpio", "Taurus"):    82,
    ("Scorpio", "Virgo"):     88,
    # ── Taurus ────────────────────────────────────────────────────────────────
    ("Taurus", "Taurus"):     80,
    ("Taurus", "Virgo"):      92,
    # ── Virgo ─────────────────────────────────────────────────────────────────
    ("Virgo", "Virgo"):       75,
}
