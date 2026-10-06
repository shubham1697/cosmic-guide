"""Verify the in-memory caches are bounded (LRU eviction) and that
clear_horoscope_cache() flushes all four caches (defect #10).

Runnable standalone (``python tests/test_bounded_cache.py`` from ``backend/``).
No DB / network / LLM needed — exercises the cache objects directly.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.horoscope_service as hs   # noqa: E402


# ── 10A: /admin/clear-cache must flush ALL four caches ────────────────────────

def test_clear_flushes_all_four_caches():
    hs._horoscope_cache[("Aries", "western", "2026-08-20")] = {"x": 1}
    hs._periodic_cache[("Aries", "western", "weekly", "2026-W34")] = {"x": 1}
    hs._personalized_cache[("Aries", "western", "2026-08-20", "abc123")] = {"x": 1}
    hs._forecast_cache[("abc123", "western", "2026-08-20")] = [{"x": 1}]

    hs.clear_horoscope_cache()

    assert len(hs._horoscope_cache) == 0
    assert len(hs._periodic_cache) == 0
    assert len(hs._personalized_cache) == 0, "clear-cache must flush _personalized_cache"
    assert len(hs._forecast_cache) == 0, "clear-cache must flush _forecast_cache"


# ── 10B: caches are bounded ───────────────────────────────────────────────────

def test_bounded_cache_caps_at_maxsize():
    c = hs._BoundedCache(3)
    for i in range(5):                     # insert 0..4 into a size-3 cache
        c[i] = i
    assert len(c) == 3, len(c)
    assert set(c.keys()) == {2, 3, 4}, "only the 3 most-recent inserts survive"


def test_bounded_cache_lru_eviction_order():
    c = hs._BoundedCache(2)
    c["a"] = 1
    c["b"] = 2
    _ = c["a"]                             # read a -> now most-recently-used
    c["c"] = 3                             # inserting c evicts the LRU (b)
    assert "b" not in c, "least-recently-used key must be evicted"
    assert set(c.keys()) == {"a", "c"}


def test_bounded_cache_get_default_and_recency():
    c = hs._BoundedCache(2)
    assert c.get(("missing",), "fallback") == "fallback"   # missing -> default
    c["a"] = 1
    c["b"] = 2
    assert c.get("a") == 1                 # read via get -> a becomes MRU
    c["d"] = 4                             # evicts LRU (b), not a
    assert "b" not in c and set(c.keys()) == {"a", "d"}


def test_module_caches_are_bounded_instances():
    for name in ("_horoscope_cache", "_periodic_cache", "_personalized_cache", "_forecast_cache"):
        cache = getattr(hs, name)
        assert isinstance(cache, hs._BoundedCache), name
        assert cache._maxsize > 0, name


def test_personalized_cache_does_not_grow_unbounded():
    hs._personalized_cache.clear()
    cap = hs._personalized_cache._maxsize
    for i in range(cap + 500):             # 500 more distinct users than the cap
        hs._personalized_cache[("Aries", "western", "2026-08-20", f"user{i:06d}")] = {"x": i}
    assert len(hs._personalized_cache) == cap, "personalized cache must stay capped"
    hs._personalized_cache.clear()


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All bounded-cache tests passed.")
