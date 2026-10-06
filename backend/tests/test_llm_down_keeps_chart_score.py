"""Regression: an LLM outage must not discard the chart-derived score.

`describe_day` is pure ephemeris maths, so when the AI step fails the generic
text should still carry the real score / band / "why" instead of the static
template's placeholder number.

Run from backend/:  ./venv/bin/python tests/test_llm_down_keeps_chart_score.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import services.horoscope_service as hs

BIRTH = dict(birth_date="1990-08-05", birth_time="14:30", birth_place="Mumbai, India")

_FAKE_CONTEXT = {
    "big3": {"sun_sign": "Leo", "moon_sign": "Capricorn", "rising_sign": "Sagittarius"},
    "moon_nakshatra": None,
    "transits": [],
    "transit_aspects": [
        {"transit_planet": "Saturn", "natal_planet": "Sun", "aspect": "Square",
         "orb": 0.5, "transit_retrograde": False},
        {"transit_planet": "Mars", "natal_planet": "Moon", "aspect": "Opposition",
         "orb": 1.2, "transit_retrograde": False},
    ],
}


def _reset_caches():
    hs._horoscope_cache.clear()
    hs._personalized_cache.clear()


def _patch(monkey_context=True, ai_returns=None, ai_raises=False):
    """Stub the chart context and the AI call; returns the originals."""
    original_ctx = hs._build_personalized_context
    original_ai_mod = sys.modules.get("services.ai_service")

    if monkey_context:
        hs._build_personalized_context = lambda *a, **k: _FAKE_CONTEXT

    import services.ai_service as ai

    original_gen = ai.generate_daily_horoscope

    def _fake_gen(*args, **kwargs):
        if ai_raises:
            raise RuntimeError("ollama connection refused")
        return ai_returns

    ai.generate_daily_horoscope = _fake_gen
    return original_ctx, ai, original_gen, original_ai_mod


def _restore(original_ctx, ai, original_gen):
    hs._build_personalized_context = original_ctx
    ai.generate_daily_horoscope = original_gen


def test_ai_exception_keeps_chart_score():
    _reset_caches()
    orig = _patch(ai_raises=True)
    try:
        result = hs.get_horoscope("Leo", system="western", db=None, **BIRTH)
    finally:
        _restore(orig[0], orig[1], orig[2])

    expected = hs._mock_horoscope("Leo", result["date"])
    assert result["band"], "band missing on LLM-down reading"
    assert result["mood_summary"], "mood_summary missing on LLM-down reading"
    assert result["general"] == expected["general"], "text should be the generic template"
    assert result["overall_score"] != expected["overall_score"], (
        "score should come from the chart, not the template placeholder"
    )
    assert result.get("personalized") is not True, "generic text must not claim to be personalized"
    print(f"  ai exception    -> score={result['overall_score']} band={result['band']} (template was {expected['overall_score']})")


def test_ai_returns_none_keeps_chart_score():
    _reset_caches()
    orig = _patch(ai_returns=None)
    try:
        result = hs.get_horoscope("Leo", system="western", db=None, **BIRTH)
    finally:
        _restore(orig[0], orig[1], orig[2])

    template = hs._mock_horoscope("Leo", result["date"])
    assert result["band"], "band missing when AI returned None"
    assert result["mood_summary"], "mood_summary missing when AI returned None"
    assert result["overall_score"] != template["overall_score"], (
        "score should come from the chart, not the template placeholder"
    )
    print(f"  ai returned None-> score={result['overall_score']} band={result['band']}")


def test_shared_cache_not_polluted():
    """The chart overlay is per-user; the shared per-sign cache must stay generic."""
    _reset_caches()
    orig = _patch(ai_raises=True)
    try:
        personal_view = hs.get_horoscope("Leo", system="western", db=None, **BIRTH)
    finally:
        _restore(orig[0], orig[1], orig[2])

    cache_key = ("Leo", "western", personal_view["date"])
    cached = hs._horoscope_cache.get(cache_key)
    if cached is not None:
        assert "band" not in cached, "chart overlay leaked into the shared per-sign cache"
        assert cached["overall_score"] != personal_view["overall_score"]
    print("  shared cache stays generic")


def test_no_birth_data_is_unchanged():
    _reset_caches()
    orig = _patch(monkey_context=False, ai_raises=True)
    try:
        result = hs.get_horoscope("Leo", system="western", db=None)
    finally:
        _restore(orig[0], orig[1], orig[2])

    assert result.get("band") is None, "a sign-only reading has no chart to score"
    assert result["overall_score"] == hs._mock_horoscope("Leo", result["date"])["overall_score"]
    print("  no birth data   -> bare template reading, unchanged")


def test_context_failure_falls_back_cleanly():
    """No chart (bad place, geocoder down) => no score, no crash."""
    _reset_caches()

    def _boom(*a, **k):
        raise RuntimeError("geocode failed")

    orig = _patch(monkey_context=False, ai_raises=True)
    original_ctx = hs._build_personalized_context
    hs._build_personalized_context = _boom
    try:
        result = hs.get_horoscope("Leo", system="western", db=None, **BIRTH)
    finally:
        hs._build_personalized_context = original_ctx
        _restore(orig[0], orig[1], orig[2])

    assert result.get("band") is None
    assert result["general"], "still returns a readable horoscope"
    print("  context failure -> clean generic fallback")


if __name__ == "__main__":
    print("LLM-down chart score retention")
    test_ai_exception_keeps_chart_score()
    test_ai_returns_none_keeps_chart_score()
    test_shared_cache_not_polluted()
    test_no_birth_data_is_unchanged()
    test_context_failure_falls_back_cleanly()
    print("All passed.")
