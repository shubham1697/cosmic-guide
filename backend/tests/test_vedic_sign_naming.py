"""Verify /vedic and /chart name the same sidereal sign identically (defect #18).

Both must use the app's canonical English sign label so the Vedic-home screen and
the chart/profile screens never show "Mesha" vs "Aries" for the same planet.

Runnable standalone (``python tests/test_vedic_sign_naming.py`` from ``backend/``).
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.vedic_service as vs            # noqa: E402
import services.birth_chart_service as bcs     # noqa: E402
from data.zodiac_data import ZODIAC_SIGNS      # noqa: E402


def test_vedic_and_chart_sign_names_agree():
    lon = 0.0
    while lon < 360.0:
        assert vs._sign_name_from_longitude(lon) == bcs._sign_from_longitude(lon), lon
        lon += 0.37


def test_vedic_sign_is_english_canonical():
    # Every sign the Vedic summary can emit is one of the canonical English names.
    for deg in range(0, 360, 5):
        assert vs._sign_name_from_longitude(float(deg)) in ZODIAC_SIGNS
    assert vs._sign_name_from_longitude(45.0) == "Taurus"   # not "Vrishabha"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All vedic sign-naming tests passed.")
