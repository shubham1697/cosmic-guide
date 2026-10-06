"""Ashta Koota table + scoring correctness tests (guards the 2026-08-10 fixes).

Runnable directly (``python tests/test_kundli_tables.py`` from ``backend/``) or
via pytest. Table-level checks are dependency-free; the service-logic checks
need pyswisseph (imported transitively by kundli_service) and self-skip if absent.
"""
import os
import sys
from collections import Counter

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for the `shared` package
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

from data.kundli_tables import (  # noqa: E402
    VARNA_RASHI, VASHYA_SIGN, YONI_ANIMAL, YONI_MORTAL_ENEMIES,
    GANA, NADI, RASHI_LORD, yoni_points, graha_maitri_points,
)


def test_nadi_blocks_forward_reverse_forward():
    block1, block2, block3 = NADI[0:9], NADI[9:18], NADI[18:27]
    assert block1 == [0, 1, 2, 2, 1, 0, 0, 1, 2]
    assert block2 == block1[::-1]            # middle block is the REVERSE, not a copy
    assert block3 == block1
    assert Counter(NADI) == {0: 9, 1: 9, 2: 9}


def test_gana_rohini_is_manushya():
    assert len(GANA) == 27
    assert GANA[3] == 1                       # Rohini = Manushya (was 0/Deva)
    assert Counter(GANA) == {0: 9, 1: 9, 2: 9}


def test_varna_is_rashi_indexed_and_balanced():
    assert len(VARNA_RASHI) == 12             # rashi property, not 27 nakshatras
    assert Counter(VARNA_RASHI) == {0: 3, 1: 3, 2: 3, 3: 3}


def test_vashya_leo_is_vanachara():
    assert len(VASHYA_SIGN) == 12
    assert VASHYA_SIGN[4] == 3                 # Leo = Vanachara (was 0/Chatushpada)


def test_yoni_animal_pairs():
    counts = Counter(YONI_ANIMAL)
    assert len(YONI_ANIMAL) == 27
    assert counts[12] == 1                     # Mongoose (Uttara Ashadha) has no pair
    assert all(counts[a] == 2 for a in range(14) if a != 12)


def test_yoni_points_tiers():
    assert len(YONI_MORTAL_ENEMIES) == 7
    assert yoni_points(5, 5) == 4              # same animal
    assert yoni_points(5, 6) == 0              # Cat-Rat mortal enemies
    assert yoni_points(0, 8) == 0              # Horse-Buffalo mortal enemies
    assert yoni_points(0, 1) == 2              # otherwise neutral


def test_graha_maitri_full_range():
    # Every value 0..5 must be reachable (the old table could only return 3-5).
    got = {graha_maitri_points(a, b) for a in RASHI_LORD for b in RASHI_LORD}
    assert {0, 1, 2, 3, 4, 5} <= got
    assert graha_maitri_points(0, 0) == 5      # a planet befriends itself
    assert graha_maitri_points(0, 4) == 5      # Sun-Mars mutual friends
    assert graha_maitri_points(0, 6) == 0      # Sun-Venus mutual enemies
    assert graha_maitri_points(1, 3) == 2      # Moon(friend) + Mercury(enemy): classic asymmetry
    assert graha_maitri_points(0, 3) == 4      # Sun(neutral of Mercury) + Mercury(friend of Sun)


def _run_service_logic_tests():
    """Koota scoring via kundli_service (needs pyswisseph); self-skips if unavailable."""
    try:
        from services.kundli_service import (
            _varna_score, _nadi_score, _gana_score, _yoni_score, _graha_maitri_score,
        )
    except Exception as exc:  # pragma: no cover
        print(f"  SKIP service-logic tests (import failed: {exc})")
        return
    assert _varna_score(3, 2) == 1             # Cancer(Brahmin) boy vs Gemini(Shudra) girl
    assert _varna_score(2, 3) == 0             # inverse direction loses the point
    assert _nadi_score(9, 9) == 0              # same Nadi = dosha
    assert _nadi_score(0, 9) == 8              # Ashwini vs Magha now differ (was wrongly equal)
    assert _gana_score(3, 3) == 6              # Rohini-Rohini (Manushya) still 6
    assert _yoni_score(0, 23) == 4             # Ashwini & Shatabhisha = Horse
    assert _graha_maitri_score(4, 9) in range(6)
    print("  service-logic tests passed")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    _run_service_logic_tests()
    print("All Ashta Koota tests passed.")
