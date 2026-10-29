"""Rate limiter behaviour: window accounting, bucket isolation, proxy trust."""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import rate_limit
from rate_limit import FixedWindowLimiter, WINDOW_SECONDS, client_identity, _bucket_for
from config import settings


class _FakeClient:
    def __init__(self, host):
        self.host = host


class _FakeRequest:
    def __init__(self, host="1.2.3.4", headers=None):
        self.client = _FakeClient(host) if host else None
        self.headers = headers or {}


def test_allows_up_to_limit_then_blocks():
    limiter = FixedWindowLimiter()
    now = 1_000_000.0
    for i in range(5):
        allowed, _ = limiter.hit("default", "ip", 5, now)
        assert allowed, f"request {i + 1} of 5 should be allowed"

    allowed, retry_after = limiter.hit("default", "ip", 5, now)
    assert not allowed, "the 6th request must be rejected"
    assert 1 <= retry_after <= WINDOW_SECONDS
    print("PASS: allows up to the limit, then blocks")


def test_window_resets():
    limiter = FixedWindowLimiter()
    now = 1_000_000.0
    for _ in range(5):
        limiter.hit("default", "ip", 5, now)
    assert not limiter.hit("default", "ip", 5, now)[0]

    allowed, _ = limiter.hit("default", "ip", 5, now + WINDOW_SECONDS)
    assert allowed, "a new window must start with a fresh count"
    print("PASS: counter resets on the next window")


def test_buckets_and_clients_are_independent():
    limiter = FixedWindowLimiter()
    now = 1_000_000.0
    for _ in range(5):
        limiter.hit("llm", "ip-a", 5, now)
    assert not limiter.hit("llm", "ip-a", 5, now)[0]

    assert limiter.hit("default", "ip-a", 5, now)[0], "other bucket must be unaffected"
    assert limiter.hit("llm", "ip-b", 5, now)[0], "other client must be unaffected"
    print("PASS: buckets and clients are isolated")


def test_llm_routes_get_the_tighter_bucket():
    bucket, limit = _bucket_for(f"{settings.API_PREFIX}/horoscope/today")
    assert bucket == "llm", bucket
    assert limit == settings.RATE_LIMIT_LLM

    bucket, limit = _bucket_for(f"{settings.API_PREFIX}/stories")
    assert bucket == "default", bucket
    assert limit == settings.RATE_LIMIT_DEFAULT
    print("PASS: LLM-capable routes use the tighter bucket")


def test_forwarded_for_ignored_unless_proxy_trusted():
    request = _FakeRequest(host="9.9.9.9", headers={"x-forwarded-for": "6.6.6.6"})

    original = settings.TRUST_PROXY_HEADERS
    try:
        settings.TRUST_PROXY_HEADERS = False
        assert client_identity(request) == "9.9.9.9", "spoofed header must be ignored"

        settings.TRUST_PROXY_HEADERS = True
        assert client_identity(request) == "6.6.6.6", "proxy header must win when trusted"
    finally:
        settings.TRUST_PROXY_HEADERS = original
    print("PASS: X-Forwarded-For honoured only when explicitly trusted")


def test_pruning_keeps_table_bounded():
    limiter = FixedWindowLimiter()
    now = 1_000_000.0
    for i in range(50):
        limiter.hit("default", f"ip-{i}", 100, now)
    assert len(limiter._hits) == 50

    limiter._prune(now + WINDOW_SECONDS)
    assert len(limiter._hits) == 0, "expired windows must be dropped"
    print("PASS: expired entries are pruned")


def test_saturation_tightens_instead_of_failing_open():
    """More live clients than we can track is exactly the distributed flood the
    limiter exists for. It used to clear the whole table there, handing every
    attacker a fresh budget."""
    limiter = FixedWindowLimiter()
    now = 1_000_000.0

    # Flood with distinct clients, all inside the same window.
    for i in range(rate_limit._MAX_TRACKED_KEYS + 500):
        limiter.hit("default", f"ip-{i}", 100, now)

    assert len(limiter._hits) <= rate_limit._MAX_TRACKED_KEYS, "table is unbounded"
    assert limiter._saturated_until > now, "saturation was not recorded"

    # A client that was already at its budget must stay blocked, not be reset.
    for _ in range(rate_limit._SATURATION_LIMIT):
        limiter.hit("default", "victim", 100, now)
    allowed, _ = limiter.hit("default", "victim", 100, now)
    assert not allowed, "limiter failed open under saturation"
    print("PASS: saturation evicts LRU and clamps the budget (no fail-open)")


if __name__ == "__main__":
    test_allows_up_to_limit_then_blocks()
    test_window_resets()
    test_buckets_and_clients_are_independent()
    test_llm_routes_get_the_tighter_bucket()
    test_forwarded_for_ignored_unless_proxy_trusted()
    test_pruning_keeps_table_bounded()
    test_saturation_tightens_instead_of_failing_open()
    print("\nAll rate limit tests passed.")
