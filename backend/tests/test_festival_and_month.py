"""Verify the Vedic calendar helpers (defects #16, #17).

#17 — _next_festival must never return a PAST festival; once FESTIVAL_DATES is
     exhausted it returns None (so the UI degrades instead of showing a stale date).
#16 — _hindu_month_name returns a valid month for every day, including the
     Jan 1–13 wrap-around (documents that the "load-bearing init" is correct).

Runnable standalone (``python tests/test_festival_and_month.py`` from ``backend/``).
"""
import os
import sys
from datetime import date

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.vedic_service as vs                          # noqa: E402
from data.vedic_reference import FESTIVAL_DATES, HINDU_MONTH_WINDOWS  # noqa: E402


# ── #17 ───────────────────────────────────────────────────────────────────────

def test_next_festival_returns_upcoming():
    f = vs._next_festival(date(2026, 8, 20))
    assert f is not None and f["name"] == "Janmashtami" and f["date"] == "2026-09-04"


def test_next_festival_boundary_is_inclusive():
    # A festival dated exactly today counts as "next".
    first = FESTIVAL_DATES[0]
    f = vs._next_festival(date.fromisoformat(first["date"]))
    assert f is not None and f["name"] == first["name"]


def test_next_festival_none_when_exhausted():
    last = date.fromisoformat(FESTIVAL_DATES[-1]["date"])
    day_after = date(last.year + 1, 1, 1)
    assert vs._next_festival(day_after) is None, "must not return a past festival"


# ── #16 ───────────────────────────────────────────────────────────────────────

def test_hindu_month_valid_for_every_day():
    names = {n for _, n in HINDU_MONTH_WINDOWS}
    for m in range(1, 13):
        for d in range(1, 32):
            try:
                dt = date(2028, m, d)   # leap year → include Feb 29
            except ValueError:
                continue
            assert vs._hindu_month_name(dt) in names, dt


def test_hindu_month_wraparound_boundary():
    # Before the first window (Pausha starts Jan 14) → previous month wraps in.
    assert vs._hindu_month_name(date(2026, 1, 13)) == "Margashirsha"
    assert vs._hindu_month_name(date(2026, 1, 14)) == "Pausha"
    assert vs._hindu_month_name(date(2026, 12, 16)) == "Margashirsha"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All festival/month tests passed.")
