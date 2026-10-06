"""Verify the audit stdout mirror is opt-out via AUDIT_LOG_STDOUT (defect #25).

The audit trail is always persisted to the rotated file; mirroring it to stdout
(which duplicates it in `docker logs`) can be turned off.

Runnable standalone (``python tests/test_audit_stdout_toggle.py`` from ``backend/``).
"""
import os
import sys
import logging

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import audit   # noqa: E402


def _fresh_audit_logger():
    """Rebuild the audit logger from scratch (reset the module singleton)."""
    audit._configured = False
    lg = logging.getLogger("cosmicguide.audit")
    for h in list(lg.handlers):
        lg.removeHandler(h)
    return audit._get_audit_logger()


def _stdout_stream_handlers(lg):
    # FileHandler subclasses StreamHandler, so exclude file handlers.
    return [h for h in lg.handlers
            if isinstance(h, logging.StreamHandler) and not isinstance(h, logging.FileHandler)]


def test_stdout_mirror_on_by_default():
    os.environ.pop("AUDIT_LOG_STDOUT", None)
    lg = _fresh_audit_logger()
    assert _stdout_stream_handlers(lg), "audit should mirror to stdout by default"


def test_stdout_mirror_can_be_disabled():
    os.environ["AUDIT_LOG_STDOUT"] = "false"
    try:
        lg = _fresh_audit_logger()
        assert _stdout_stream_handlers(lg) == [], "AUDIT_LOG_STDOUT=false must drop the stdout mirror"
        # …but the durable file handler is still present.
        assert any(isinstance(h, logging.FileHandler) for h in lg.handlers)
    finally:
        os.environ.pop("AUDIT_LOG_STDOUT", None)
        _fresh_audit_logger()   # restore default state for any later import


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All audit stdout-toggle tests passed.")
