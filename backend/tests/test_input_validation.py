"""Verify input-validation fixes (defects #26, #27, and DEFECTS.md #6).

#26 — birth_date gets a YYYY-MM-DD pattern on BirthDetails (Kundli) and on
      /horoscope/today's birthDate, matching /forecast and BirthChartRequest.
#27 — /fortune/generate rejects an unknown zodiac sign with 400.
#6  — /admin/content-status returns 400 (not 500) on a malformed target_date.

Runs against a throwaway SQLite DB so no Postgres/LLM is needed. Standalone:
``python tests/test_input_validation.py`` from ``backend/``.
"""
import os
import sys
import tempfile

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

# Point the app at a throwaway SQLite file BEFORE importing it (load_dotenv does
# not override an already-set env var), and keep the scheduler off.
_DB_FD, _DB_PATH = tempfile.mkstemp(suffix=".db")
os.close(_DB_FD)
os.environ["DATABASE_URL"] = f"sqlite:///{_DB_PATH}"
os.environ["ENABLE_SCHEDULER"] = "false"
# /admin/* is gated on ADMIN_API_KEY; set one so these cases still reach the
# date parsing they are meant to cover (auth itself is covered by test_admin_auth).
os.environ["ADMIN_API_KEY"] = "test-admin-key"

from fastapi.testclient import TestClient   # noqa: E402
import pydantic                             # noqa: E402
import main                                 # noqa: E402
from schemas import BirthDetails            # noqa: E402
from security import AuthedUser, require_user   # noqa: E402

main.prepare_schema()                       # lifespan is not run by a bare TestClient
# The chart/kundli/vedic routes require sign-in; these cases are about input
# validation, so stand in a verified caller rather than a real Firebase token.
main.app.dependency_overrides[require_user] = lambda: AuthedUser(
    uid="uid-test", email="t@example.com", email_verified=True, name="Test"
)

client = TestClient(main.app)               # no context-manager → startup/scheduler not fired
_API = "/api/v1"
_ADMIN_HEADERS = {"X-Admin-Key": os.environ["ADMIN_API_KEY"]}


# ── #26: BirthDetails birth_date pattern (Pydantic level) ─────────────────────

def test_birthdetails_rejects_bad_date():
    try:
        BirthDetails(name="A", birth_date="not-a-date")
        raise AssertionError("expected ValidationError for bad birth_date")
    except pydantic.ValidationError:
        pass


def test_birthdetails_accepts_good_date():
    b = BirthDetails(name="A", birth_date="1990-05-01")
    assert b.birth_date == "1990-05-01"


# ── #26: /horoscope/today birthDate pattern (endpoint level) ──────────────────

def test_today_rejects_bad_birthdate():
    r = client.get(f"{_API}/horoscope/today", params={"zodiac_sign": "Aries", "birthDate": "garbage"})
    assert r.status_code == 422, r.text


# ── #27: /fortune/generate validates the sign ─────────────────────────────────

def test_fortune_rejects_invalid_sign():
    r = client.post(f"{_API}/fortune/generate",
                    json={"zodiacSign": "Nonsense", "topic": "Love", "mood": "Happy"})
    assert r.status_code == 400, r.text


def test_fortune_accepts_valid_sign():
    r = client.post(f"{_API}/fortune/generate",
                    json={"zodiacSign": "Aries", "topic": "Love", "mood": "Happy"})
    assert r.status_code == 200, r.text


# ── DEFECTS.md #6: /admin/content-status is 400 (not 500) on a bad date ────────

def test_content_status_bad_date_is_400():
    r = client.get("/admin/content-status", params={"target_date": "garbage"},
                   headers=_ADMIN_HEADERS)
    assert r.status_code == 400, r.text


def test_content_status_good_date_ok():
    r = client.get("/admin/content-status", params={"target_date": "2026-08-20"},
                   headers=_ADMIN_HEADERS)
    assert r.status_code == 200, r.text


if __name__ == "__main__":
    failures = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            try:
                fn()
                print(f"  {name} passed")
            except Exception as exc:  # noqa: BLE001
                failures += 1
                print(f"  {name} FAILED: {exc}")
    os.unlink(_DB_PATH)
    if failures:
        sys.exit(1)
    print("All input-validation tests passed.")
