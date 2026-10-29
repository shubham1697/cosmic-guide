"""Operator-only routes must not be open to the internet.

/admin/* spends LLM budget, flushes caches and rewrites cached content;
/notifications/run-daily broadcasts to every registered device and
/notifications/test pushes caller-supplied text to a device. All of them were
reachable with no credential at all. They are now gated on ADMIN_API_KEY:

  - key unset  -> 503 (disabled, not open)
  - key set    -> 401 without / with a wrong X-Admin-Key, 2xx with the right one

Run:  ./venv/bin/python tests/test_admin_auth.py     (from backend/)
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Point the app at a throwaway SQLite file and keep the scheduler off BEFORE
# importing main.
_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db.name}"
os.environ["ENABLE_SCHEDULER"] = "false"
os.environ["ADMIN_API_KEY"] = ""

from fastapi.testclient import TestClient  # noqa: E402

import config  # noqa: E402
import main  # noqa: E402

# Schema work lives in the lifespan now, which a bare TestClient does not run.
main.prepare_schema()

client = TestClient(main.app)

ADMIN_ROUTES = [
    ("GET", "/admin/content-status"),
    ("POST", "/admin/clear-cache"),
    ("POST", "/admin/refresh-daily"),
    ("POST", "/admin/seed-oneshot"),
    ("POST", "/api/v1/notifications/run-daily"),
]
TEST_PUSH = ("POST", "/api/v1/notifications/test")


def _call(method, path, key=None):
    headers = {"X-Admin-Key": key} if key is not None else {}
    body = {"token": "x" * 12} if path.endswith("/test") else None
    return client.request(method, path, headers=headers, json=body)


def test_disabled_when_no_key():
    config.settings.ADMIN_API_KEY = ""
    for method, path in ADMIN_ROUTES + [TEST_PUSH]:
        r = _call(method, path)
        assert r.status_code == 503, f"{method} {path} -> {r.status_code} (expected 503)"
        assert "ADMIN_API_KEY" in r.json()["detail"]
    print(f"✓ no key configured → all {len(ADMIN_ROUTES) + 1} operator routes 503 (not open)")


def test_rejects_missing_and_wrong_key():
    config.settings.ADMIN_API_KEY = "s3cret-operator-key"
    for method, path in ADMIN_ROUTES + [TEST_PUSH]:
        assert _call(method, path).status_code == 401, f"{method} {path} allowed a missing key"
        assert _call(method, path, key="wrong").status_code == 401, f"{method} {path} allowed a wrong key"
        assert _call(method, path, key="").status_code == 401, f"{method} {path} allowed an empty key"
    print(f"✓ key configured → missing/wrong/empty X-Admin-Key rejected with 401 on all "
          f"{len(ADMIN_ROUTES) + 1} routes")


def test_accepts_correct_key():
    config.settings.ADMIN_API_KEY = "s3cret-operator-key"
    r = _call("GET", "/admin/content-status", key="s3cret-operator-key")
    assert r.status_code == 200, f"correct key rejected: {r.status_code} {r.text}"
    assert "horoscopes" in r.json()

    r = _call("POST", "/admin/clear-cache", key="s3cret-operator-key")
    assert r.status_code == 200, f"correct key rejected: {r.status_code} {r.text}"
    print("✓ correct X-Admin-Key still reaches the handler (200)")


def test_public_routes_unaffected():
    config.settings.ADMIN_API_KEY = ""
    assert client.get("/health").status_code == 200
    assert client.get("/").status_code == 200
    print("✓ /health and / remain public")


def test_device_registration_requires_sign_in():
    """Device tokens are tied to an account now, so deletion can remove them."""
    config.settings.ADMIN_API_KEY = ""
    r = client.post("/api/v1/notifications/register",
                    json={"token": "t" * 20, "platform": "android"})
    assert r.status_code == 401, f"register should require a user token: {r.status_code}"
    print("✓ device registration requires a signed-in user")


def test_preferences_requires_sign_in():
    """Knowing a device token must not be enough to silence its reminders."""
    config.settings.ADMIN_API_KEY = ""
    r = client.put("/api/v1/notifications/preferences",
                   json={"token": "t" * 20, "dailyHoroscopeEnabled": False})
    assert r.status_code == 401, f"preferences should require a user token: {r.status_code}"
    print("✓ notification preferences require a signed-in user")


def test_unregister_is_not_a_token_oracle():
    """Unregister stays open (sign-out can outlive the session) but must not
    reveal whether the token was registered."""
    config.settings.ADMIN_API_KEY = ""
    unknown = client.post("/api/v1/notifications/unregister", json={"token": "u" * 20})
    assert unknown.status_code == 200, unknown.text
    assert unknown.json() == {"status": "ok"}, unknown.json()
    print("✓ /unregister returns a constant reply (no existence oracle)")


if __name__ == "__main__":
    try:
        test_disabled_when_no_key()
        test_rejects_missing_and_wrong_key()
        test_accepts_correct_key()
        test_public_routes_unaffected()
        test_device_registration_requires_sign_in()
        test_preferences_requires_sign_in()
        test_unregister_is_not_a_token_oracle()
        print("\nAll admin-auth tests passed.")
    finally:
        os.unlink(_tmp_db.name)
