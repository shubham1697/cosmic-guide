"""Verify Vimshottari antardasha starts at the mahadasha lord (defect #3).

Runnable standalone (``python tests/test_dasha_antardasha.py`` from ``backend/``) or via
pytest. Patches only ``_mahadasha_timeline`` so the real ``_current_dasha`` sub-period
logic runs without an ephemeris or geocoding.
"""
import os
import sys
from datetime import date, timedelta

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.vedic_service as vs                                  # noqa: E402
from data.vedic_reference import DASHA_SEQUENCE, DASHA_YEARS         # noqa: E402


def _rotated(lord):
    i = DASHA_SEQUENCE.index(lord)
    n = len(DASHA_SEQUENCE)
    return [DASHA_SEQUENCE[(i + k) % n] for k in range(n)]


def _antardasha_at(maha_lord, offset_days):
    ms = date(2020, 1, 1)
    me = ms + timedelta(days=int(DASHA_YEARS[maha_lord] * 365.25))
    orig = vs._mahadasha_timeline
    vs._mahadasha_timeline = lambda *a, **k: [{"lord": maha_lord, "start": ms.isoformat(), "end": me.isoformat()}]
    try:
        return vs._current_dasha("1990-01-01", "12:00", "Delhi", ms + timedelta(days=offset_days))["antardasha"]
    finally:
        vs._mahadasha_timeline = orig


def test_first_antardasha_is_maha_lord():
    for lord in DASHA_SEQUENCE:
        assert _antardasha_at(lord, 5) == lord, f"{lord} maha: first antardasha should be {lord}"


def test_antardasha_sequence_matches_rotation():
    for maha_lord in DASHA_SEQUENCE:
        ms = date(2020, 1, 1)
        maha_days = max(1, int(DASHA_YEARS[maha_lord] * 365.25))
        cursor = 0
        for expected in _rotated(maha_lord):                        # standard order, maha-lord first
            sub_days = max(1, int(maha_days * (DASHA_YEARS[expected] / 120.0)))
            mid = cursor + sub_days // 2                            # sample the middle of each sub-period
            got = _antardasha_at(maha_lord, mid)
            assert got == expected, f"{maha_lord} maha @day {mid}: got {got}, expected {expected}"
            cursor += sub_days


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All antardasha tests passed.")
