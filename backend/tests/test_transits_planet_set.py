"""Verify calculate_current_transits returns the Vedic planet set for sidereal callers (defect #5b).

Runnable standalone (``python tests/test_transits_planet_set.py`` from ``backend/``) or via
pytest. No DB/geocoding needed — transits use the current instant.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

from services.birth_chart_service import calculate_current_transits   # noqa: E402
from data.astro_constants import PLANET_IDS, VEDIC_GRAHAS             # noqa: E402


def test_sidereal_transits_are_vedic_grahas_plus_nodes():
    names = [p["name"] for p in calculate_current_transits(sidereal=True)]
    assert names == list(VEDIC_GRAHAS) + ["Rahu", "Ketu"], names       # 7 grahas + nodes, in order
    assert not ({"Uranus", "Neptune", "Pluto"} & set(names))           # outer planets excluded


def test_western_transits_unchanged():
    names = [p["name"] for p in calculate_current_transits(sidereal=False)]
    assert names == list(PLANET_IDS.keys()), names                     # all 10, order preserved
    assert not ({"Rahu", "Ketu"} & set(names))                         # no nodes in the Western set


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All transit planet-set tests passed.")
