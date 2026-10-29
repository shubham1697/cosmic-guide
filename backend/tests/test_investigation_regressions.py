"""Regressions from the 2026-08-21 investigation.

1. A blank birth time must be treated as *absent*: the chart is cast at the
   12:00 default, so the ascendant is an estimate and must say so. It used to
   report has_accurate_houses=True / is_estimated=False for birth_time="".

2. The Vedic birth-time timezone fallback must match calculate_birth_chart.
   vedic_service._birth_jd defaulted to Asia/Kolkata while calculate_birth_chart
   defaults to UTC, so a chart whose place could not be geocoded produced a
   Dasha derived from a different nakshatra than the Kundli shown next to it.

3. The AI JSON parsers must never raise: `null` / a bare number used to escape
   as a TypeError past the JSONDecodeError-only guard.

4. One unusable overall_score must not discard an entire 12-sign batch.

Run:  ./venv/bin/python tests/test_investigation_regressions.py   (from backend/)
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import swisseph as swe  # noqa: E402

import services.ai_service as ai  # noqa: E402
import services.birth_chart_service as bcs  # noqa: E402
import services.vedic_service as vs  # noqa: E402

_FIXED_COORDS = (51.5074, -0.1278)


def _stub_geocode(result):
    """Patch geocoding in BOTH modules (vedic_service imports it by name)."""
    bcs._geocode_cache.clear()
    bcs.geocode_place = lambda place: result
    vs.geocode_place = lambda place: result


# ── 1. blank birth time is not an accurate birth time ────────────────────────

def test_blank_birth_time_is_estimated():
    _stub_geocode(_FIXED_COORDS)

    blank = bcs.calculate_birth_chart("1990-08-05", "", "London")
    missing = bcs.calculate_birth_chart("1990-08-05", None, "London")
    real = bcs.calculate_birth_chart("1990-08-05", "14:30", "London")

    assert blank["has_accurate_houses"] is False, "blank birth time claimed accurate houses"
    assert blank["big3"]["rising"]["is_estimated"] is True, "blank birth time claimed an exact rising sign"
    # A blank time must behave exactly like a missing one.
    assert blank["big3"]["rising"]["sign"] == missing["big3"]["rising"]["sign"]
    assert blank["has_accurate_houses"] == missing["has_accurate_houses"]
    # A real time is still honoured.
    assert real["has_accurate_houses"] is True
    assert real["big3"]["rising"]["is_estimated"] is False
    print("✓ birth_time='' is reported as an estimated ascendant, exactly like None")


def test_whitespace_birth_place_still_estimates():
    """No geocode → no houses, whatever the birth time says."""
    _stub_geocode(None)
    chart = bcs.calculate_birth_chart("1990-08-05", "14:30", "Nowheresville")
    assert chart["has_accurate_houses"] is False
    assert chart["big3"]["rising"]["is_estimated"] is True
    print("✓ un-geocodable place still yields an estimated ascendant")


# ── 2. Vedic dasha and kundli agree on the birth moment ──────────────────────

def _sidereal_moon_from_chart(birth_date, birth_time, birth_place):
    chart = bcs.calculate_birth_chart(
        birth_date=birth_date, birth_time=birth_time,
        birth_place=birth_place, sidereal=True,
    )
    return next(p["longitude"] for p in chart["planets"] if p["name"] == "Moon")


def test_dasha_and_kundli_use_the_same_birth_moment():
    # The regression only shows up when the place cannot be geocoded, which is
    # where the two fallbacks used to disagree (UTC vs Asia/Kolkata).
    _stub_geocode(None)
    birth = ("1990-08-05", "23:30", "Nowheresville")

    moon_chart = _sidereal_moon_from_chart(*birth)
    moon_dasha = vs._sidereal_longitude(vs._birth_jd(*birth), swe.MOON)

    delta = abs(moon_chart - moon_dasha)
    # calculate_birth_chart rounds longitudes to 4dp; anything beyond that means
    # the two paths disagree about the birth instant.
    assert delta < 1e-3, f"birth Moon differs by {delta:.6f}° between the chart and dasha paths"

    nak_chart = bcs._nakshatra_from_longitude(moon_chart)
    nak_dasha = vs._nakshatra_from_longitude(moon_dasha)
    assert nak_chart["name"] == nak_dasha["name"], (
        f"kundli shows nakshatra {nak_chart['name']} but the dasha is built "
        f"from {nak_dasha['name']}"
    )
    assert nak_chart["lord"] == nak_dasha["lord"], "mahadasha lord disagrees with the displayed kundli"
    print(f"✓ un-geocodable place: chart and dasha agree "
          f"(nakshatra {nak_chart['name']}, lord {nak_chart['lord']})")


def test_geocodable_place_unchanged():
    _stub_geocode(_FIXED_COORDS)
    birth = ("1990-08-05", "23:30", "London")
    delta = abs(_sidereal_moon_from_chart(*birth)
                - vs._sidereal_longitude(vs._birth_jd(*birth), swe.MOON))
    assert delta < 1e-3, f"geocodable place regressed: {delta:.6f}°"
    # The daily Panchang default (no birth place at all) is deliberately kept.
    assert vs._timezone_name(None) == "Asia/Kolkata"
    assert vs._timezone_name(None, default="UTC") == "UTC"
    print("✓ geocodable place still agrees; the Panchang India default is preserved")


# ── 3. the AI JSON parsers never raise ───────────────────────────────────────

def test_parsers_never_raise():
    for raw in ("null", "5", "3.5", '"oops"', "true", "{}", "[]", "not json"):
        assert ai._parse_json_array(raw) in (None, []), f"_parse_json_array({raw!r}) misbehaved"
        assert ai._parse_json(raw) in (None, {}), f"_parse_json({raw!r}) misbehaved"
    # Valid shapes still work.
    assert ai._parse_json_array('[1,2]') == [1, 2]
    assert ai._parse_json_array('{"stories":[1]}') == [1]
    assert ai._parse_json_array('{"stories":"nope"}') is None
    assert ai._parse_json('{"a":1}') == {"a": 1}
    assert ai._parse_json('[1,2]') is None, "_parse_json must reject a list (callers call .get on it)"
    print("✓ _parse_json / _parse_json_array return None instead of raising on junk")


# ── 4. one bad score does not discard the whole batch ────────────────────────

def test_bad_score_does_not_kill_the_batch():
    original = ai._call_ai
    signs = ["Aries", "Taurus", "Gemini"]
    try:
        ai._call_ai = lambda *a, **k: json.dumps({
            s: {
                "general": "g", "love": "l", "career": "c", "health": "h",
                "overall_score": ("N/A" if s == "Aries" else 80),
                "lucky_number": "7", "lucky_color": "Violet", "mood": "Calm",
            } for s in signs
        })
        result = ai.generate_all_horoscopes()
        assert result is not None, "one unusable score discarded the entire batch"
        assert sorted(result) == sorted(signs), f"lost signs: {sorted(result)}"
        assert result["Aries"]["overall_score"] == 75, "bad score not defaulted"
        assert result["Taurus"]["overall_score"] == 80, "good score not preserved"

        ai._call_ai = lambda *a, **k: json.dumps({
            "general": "g", "love": "l", "career": "c", "health": "h",
            "overall_score": "85%", "lucky_number": "7",
            "lucky_color": "Violet", "mood": "Calm",
        })
        single = ai.generate_daily_horoscope("Leo")
        assert single is not None and single["overall_score"] == 85, single
    finally:
        ai._call_ai = original
    print("✓ an unusable overall_score is defaulted; the rest of the batch survives")


# ── 5. an unusable birth time is absent, not noon-with-exact-houses ──────────

def test_parse_birth_time_rejects_junk():
    assert bcs.parse_birth_time("14:30") == (14, 30)
    assert bcs.parse_birth_time("00:00") == (0, 0)
    assert bcs.parse_birth_time("23:59") == (23, 59)
    for bad in (None, "", "abc", "25:99", "-5:00", "12", "12:60", "24:00", "  "):
        assert bcs.parse_birth_time(bad) is None, f"parse_birth_time({bad!r}) should be None"
    print("✓ parse_birth_time accepts real HH:MM and rejects blank/junk/out-of-range")


def test_unusable_birth_time_never_claims_exact_houses():
    _stub_geocode(_FIXED_COORDS)
    for bad in ("", "abc", "25:99"):
        chart = bcs.calculate_birth_chart("1990-08-05", bad, "London")
        assert chart["has_accurate_houses"] is False, f"birth_time={bad!r} claimed exact houses"
        assert chart["big3"]["rising"]["is_estimated"] is True, f"birth_time={bad!r} claimed an exact rising"
        # The echoed time must not pretend the junk value was used.
        assert chart["birth_info"]["time"] == "12:00 (default)", chart["birth_info"]["time"]
    print("✓ blank/junk/out-of-range birth times all report an estimated ascendant")


# ── 6. malformed input is a 4xx, never a 500 ─────────────────────────────────

def test_malformed_input_is_4xx_not_500():
    import os
    import tempfile

    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    os.environ["DATABASE_URL"] = f"sqlite:///{tmp.name}"
    os.environ["ENABLE_SCHEDULER"] = "false"
    try:
        from fastapi.testclient import TestClient

        import main
        from security import AuthedUser, require_user

        main.prepare_schema()  # lifespan is not run by a bare TestClient
        # These routes require sign-in; the case under test is input validation.
        main.app.dependency_overrides[require_user] = lambda: AuthedUser(
            uid="uid-test", email="t@example.com", email_verified=True, name="Test"
        )

        bcs.geocode_place = lambda p: _FIXED_COORDS
        vs.geocode_place = lambda p: _FIXED_COORDS
        client = TestClient(main.app, raise_server_exceptions=False)

        cases = [
            ("/api/v1/vedic/home-summary", {"birthDate": "garbage"}),
            ("/api/v1/vedic/home-summary", {"birthDate": "1990-13-45"}),   # regex-valid, not a real date
            ("/api/v1/vedic/home-summary", {"targetDate": "nope"}),
            ("/api/v1/vedic/home-summary", {"birthDate": "1990-08-05", "birthTime": "abc"}),
        ]
        for path, params in cases:
            r = client.get(path, params=params)
            assert 400 <= r.status_code < 500, f"GET {path} {params} -> {r.status_code} (expected 4xx)"

        for bad_time in ("25:99", "abc", "-5:00"):
            r = client.post("/api/v1/chart/birth", json={
                "birthDate": "1990-08-05", "birthTime": bad_time, "birthPlace": "London"})
            assert r.status_code == 422, f"chart/birth birthTime={bad_time!r} -> {r.status_code}"

        r = client.post("/api/v1/kundli/match", json={
            "person1": {"name": "A", "birthDate": "1990-08-05", "birthTime": "99:99", "birthPlace": "London"},
            "person2": {"name": "B", "birthDate": "1992-03-11", "birthTime": "10:00", "birthPlace": "London"}})
        assert r.status_code == 422, f"kundli bad birthTime -> {r.status_code}"

        # A well-formed request still works.
        r = client.post("/api/v1/chart/birth", json={
            "birthDate": "1990-08-05", "birthTime": "14:30", "birthPlace": "London"})
        assert r.status_code == 200 and r.json()["hasAccurateHouses"] is True
        print("✓ malformed dates/times return 4xx (were 500); valid input unaffected")
    finally:
        import main as _main
        _main.app.dependency_overrides.clear()
        os.unlink(tmp.name)


if __name__ == "__main__":
    test_blank_birth_time_is_estimated()
    test_whitespace_birth_place_still_estimates()
    test_dasha_and_kundli_use_the_same_birth_moment()
    test_geocodable_place_unchanged()
    test_parsers_never_raise()
    test_bad_score_does_not_kill_the_batch()
    test_parse_birth_time_rejects_junk()
    test_unusable_birth_time_never_claims_exact_houses()
    test_malformed_input_is_4xx_not_500()
    print("\nAll investigation regression tests passed.")
