"""Verify a DB read failure falls through to the AI step instead of short-circuiting
to the static mock (defect #9). A transient DB hiccup must not skip a healthy LLM.

Runnable standalone (``python tests/test_db_failure_falls_through.py`` from ``backend/``).
Stubs the AI callables so no LLM/network request is made.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.ai_service as ai                 # noqa: E402
import services.horoscope_service as hs          # noqa: E402
import services.compatibility_service as cs      # noqa: E402


class _FailingDB:
    """A down DB: reads and writes raise; rollback is safe (like a real Session)."""

    def query(self, *a, **k):
        raise RuntimeError("transient DB hiccup")

    def add(self, *a, **k):
        pass

    def commit(self, *a, **k):
        raise RuntimeError("DB down")

    def rollback(self, *a, **k):
        pass


class _MissDB:
    """A healthy DB that returns no cached row (clean cache miss)."""

    def query(self, *a, **k):
        return self

    def filter(self, *a, **k):
        return self

    def first(self):
        return None

    def add(self, *a, **k):
        pass

    def commit(self, *a, **k):
        pass

    def rollback(self, *a, **k):
        pass


def _patch(module, name, fn):
    """Set module.name = fn, returning a restore() callable."""
    original = getattr(module, name)
    setattr(module, name, fn)
    return lambda: setattr(module, name, original)


# ── horoscope ────────────────────────────────────────────────────────────────

def test_horoscope_db_failure_falls_through_to_ai():
    hs._horoscope_cache.clear()
    called = {"ai": False}

    def fake_ai(*a, **k):
        called["ai"] = True
        return {
            "general": "REAL-LLM-CONTENT", "love": "l", "career": "c", "health": "h",
            "overall_score": 80, "lucky_number": "7", "lucky_color": "Gold", "mood": "Bright",
        }

    restore = _patch(ai, "generate_daily_horoscope", fake_ai)
    try:
        res = hs.get_horoscope("Aries", system="western", db=_FailingDB())
    finally:
        restore()

    assert called["ai"] is True, "healthy LLM must be called after a DB read failure"
    assert res["general"] == "REAL-LLM-CONTENT", "LLM content must be served, not mock"


def test_horoscope_db_failure_still_mocks_when_ai_down():
    hs._horoscope_cache.clear()

    def dead_ai(*a, **k):
        raise RuntimeError("LLM down")

    restore = _patch(ai, "generate_daily_horoscope", dead_ai)
    try:
        res = hs.get_horoscope("Aries", system="western", db=_FailingDB())
    finally:
        restore()

    # DB down AND AI down → mock is the final fallback (no crash, valid payload).
    assert res["sign"] == "Aries"
    assert res["general"]


def test_horoscope_db_miss_unchanged():
    hs._horoscope_cache.clear()
    called = {"ai": False}

    def fake_ai(*a, **k):
        called["ai"] = True
        return {
            "general": "MISS-LLM", "love": "l", "career": "c", "health": "h",
            "overall_score": 70, "lucky_number": "3", "lucky_color": "Blue", "mood": "Calm",
        }

    restore = _patch(ai, "generate_daily_horoscope", fake_ai)
    try:
        res = hs.get_horoscope("Leo", system="western", db=_MissDB())
    finally:
        restore()

    assert called["ai"] is True, "a clean DB miss must reach the AI step (unchanged)"
    assert res["general"] == "MISS-LLM"


# ── compatibility ────────────────────────────────────────────────────────────

def test_compatibility_db_failure_falls_through_to_ai():
    called = {"ai": False}

    def fake_ai(sign1, sign2, score, *a, **k):
        called["ai"] = True
        return {
            "description": "REAL-LLM-DESC", "love_advice": "la",
            "strengths_together": "st", "challenges": "ch",
        }

    restore = _patch(ai, "generate_compatibility", fake_ai)
    try:
        res = cs.get_compatibility("Aries", "Leo", db=_FailingDB())
    finally:
        restore()

    assert called["ai"] is True, "healthy LLM must be called after a DB read failure"
    assert res["description"] == "REAL-LLM-DESC", "LLM content must be served, not mock"


def test_compatibility_db_failure_still_mocks_when_ai_down():
    def dead_ai(*a, **k):
        raise RuntimeError("LLM down")

    restore = _patch(ai, "generate_compatibility", dead_ai)
    try:
        res = cs.get_compatibility("Aries", "Leo", db=_FailingDB())
    finally:
        restore()

    # DB down AND AI down → mock is the final fallback (no crash, valid payload).
    assert res["sign1"] == "Aries" and res["sign2"] == "Leo"
    assert res["description"]


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All DB-failure fall-through tests passed.")
