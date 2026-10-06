"""Verify _call_ollama passes its timeout argument through to urlopen (defect #13).

Runnable standalone (``python tests/test_ollama_timeout.py`` from ``backend/``).
Stubs urlopen so no network request is made.
"""
import os
import sys
import urllib.request

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import services.story_service as ss   # noqa: E402


class _FakeResp:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return b'{"message": {"content": "ok"}}'


def _capture_urlopen():
    """Patch urlopen to record the timeout it receives; returns (restore, captured)."""
    captured = {}
    original = urllib.request.urlopen

    def fake(req, timeout=None):
        captured["timeout"] = timeout
        return _FakeResp()

    urllib.request.urlopen = fake
    return (lambda: setattr(urllib.request, "urlopen", original)), captured


def test_explicit_timeout_is_forwarded():
    restore, captured = _capture_urlopen()
    try:
        ss._call_ollama("prompt", timeout=5)
    finally:
        restore()
    assert captured["timeout"] == 5, captured


def test_default_timeout_is_forwarded():
    restore, captured = _capture_urlopen()
    try:
        ss._call_ollama("prompt")
    finally:
        restore()
    assert captured["timeout"] == 600, captured        # the declared default, not 3600


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All _call_ollama timeout tests passed.")
