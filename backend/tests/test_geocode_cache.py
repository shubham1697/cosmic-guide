"""Verify geocode_place caches successes and throttles/retries correctly (defect #6).

Runnable standalone (``python tests/test_geocode_cache.py`` from ``backend/``) or via pytest.
Stubs the network geocode callable so no Nominatim request is made.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.birth_chart_service as bcs   # noqa: E402


class _FakeLoc:
    latitude = 19.076
    longitude = 72.8777


def _stub(net):
    def fn(place, timeout=None):
        net.append(place)
        return _FakeLoc()
    return fn


def test_cache_collapses_repeat_and_casevariant_lookups():
    net = []
    bcs._geocode_fn = _stub(net)          # bypass RateLimiter/Nominatim
    bcs._geocode_cache.clear()
    a = bcs.geocode_place("Mumbai, India")
    b = bcs.geocode_place("mumbai, india")     # case-insensitive → cache hit
    c = bcs.geocode_place("  Mumbai, India ")  # whitespace-insensitive → cache hit
    assert a == b == c == (19.076, 72.8777)
    assert len(net) == 1, net                  # one network call for three lookups


def test_failures_are_not_cached():
    net = []
    def fn(place, timeout=None):
        net.append(place)
        return None                            # geocode miss
    bcs._geocode_fn = fn
    bcs._geocode_cache.clear()
    assert bcs.geocode_place("Nowhere") is None
    assert bcs.geocode_place("Nowhere") is None
    assert len(net) == 2                        # retried, not pinned as None


def test_vedic_summary_makes_one_network_geocode():
    import services.vedic_service as vs
    net = []
    bcs._geocode_fn = _stub(net)
    bcs._geocode_cache.clear()
    kw = dict(target_date="2026-08-20", birth_date="1990-05-15",
              birth_time="06:30", birth_place="Mumbai, India")
    vs.get_vedic_home_summary(**kw)
    assert len(net) == 1, f"first request should geocode once, got {len(net)}"
    before = len(net)
    vs.get_vedic_home_summary(**kw)
    assert len(net) == before, "second identical request should be fully cached"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All geocode cache tests passed.")
