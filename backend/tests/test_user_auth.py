"""Sign-in gate: profile routes must fail closed and never trust an unverified token.

Credentials live in Firebase; this service only verifies ID tokens. If the
service account is missing the server cannot verify anything, so it must refuse
requests rather than let them through.

Run from backend/:  ./venv/bin/python tests/test_user_auth.py
"""

import os
import sys
import tempfile

_BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ROOT = os.path.dirname(_BACKEND)
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db.name}"
os.environ["ADMIN_API_KEY"] = "test-admin-key"
os.environ["ENABLE_SCHEDULER"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
import security  # noqa: E402
from db.database import SessionLocal  # noqa: E402
from db.models import User  # noqa: E402
from security import AuthedUser, require_fresh_user, require_user  # noqa: E402

main.prepare_schema()  # lifespan is not run by a bare TestClient

client = TestClient(main.app)

_PROFILE_ROUTES = [("get", "/api/v1/users/me"), ("put", "/api/v1/users/me"),
                   ("delete", "/api/v1/users/me")]


def test_missing_token_is_rejected():
    for method, path in _PROFILE_ROUTES:
        call = getattr(client, method)
        r = call(path, json={}) if method == "put" else call(path)
        assert r.status_code == 401, f"{method} {path} -> {r.status_code}"
    print("✓ every profile route rejects a missing token (401)")


def test_malformed_authorization_header_is_rejected():
    for header in ["", "Bearer", "Bearer ", "Basic abc", "token abc"]:
        r = client.get("/api/v1/users/me", headers={"Authorization": header})
        assert r.status_code in (401, 503), f"{header!r} -> {r.status_code}"
    print("✓ malformed Authorization headers are refused")


def test_fails_closed_without_service_account():
    """No credentials => cannot verify => refuse. Never fall open."""
    from firebase_app import get_app

    assert get_app() is None, "test environment unexpectedly has Firebase creds"
    r = client.get("/api/v1/users/me", headers={"Authorization": "Bearer anything"})
    assert r.status_code == 503, f"expected 503, got {r.status_code}"
    assert r.status_code != 200, "unverified token must never be accepted"
    print("✓ unverifiable token is refused (503), not trusted")


def _as_user(uid: str, email: str = "a@b.co"):
    """Impersonate a verified caller by overriding the dependencies."""
    caller = AuthedUser(uid=uid, email=email, email_verified=True, name="Tester")
    main.app.dependency_overrides[require_user] = lambda: caller
    main.app.dependency_overrides[require_fresh_user] = lambda: caller


def test_profile_round_trip_is_scoped_to_the_caller():
    try:
        _as_user("uid-alice", "alice@example.com")
        created = client.get("/api/v1/users/me")
        assert created.status_code == 200, created.text
        assert created.json()["firebaseUid"] == "uid-alice"

        saved = client.put("/api/v1/users/me", json={
            "name": "Alice", "zodiacSign": "Leo",
            "birthDate": "1990-08-05", "tradition": "vedic",
        })
        assert saved.status_code == 200, saved.text
        assert saved.json()["zodiacSign"] == "Leo"

        # A different account must not see Alice's profile.
        _as_user("uid-bob", "bob@example.com")
        bob = client.get("/api/v1/users/me")
        assert bob.status_code == 200
        assert bob.json()["firebaseUid"] == "uid-bob"
        assert bob.json()["zodiacSign"] is None, "profile leaked across accounts"
        print("✓ profile is created, updated and scoped per account")
    finally:
        main.app.dependency_overrides.clear()


def test_invalid_update_is_rejected():
    try:
        _as_user("uid-carol")
        r = client.put("/api/v1/users/me", json={"birthDate": "not-a-date"})
        assert r.status_code == 422, f"expected validation error, got {r.status_code}"
        r = client.put("/api/v1/users/me", json={"tradition": "klingon"})
        assert r.status_code == 422, f"expected validation error, got {r.status_code}"
        # 'both' was retired as a reading style; it must no longer be accepted.
        r = client.put("/api/v1/users/me", json={"tradition": "both"})
        assert r.status_code == 422, f"'both' should be rejected, got {r.status_code}"
        for valid in ("western", "vedic"):
            r = client.put("/api/v1/users/me", json={"tradition": valid})
            assert r.status_code == 200, f"{valid} rejected: {r.status_code}"
        print("✓ malformed profile fields are rejected at the boundary")
    finally:
        main.app.dependency_overrides.clear()


def test_null_clears_a_field():
    """An explicit null must clear the value — it is how a user withdraws a
    birth detail. `exclude_none` once made that indistinguishable from omitted."""
    try:
        _as_user("uid-erin")
        client.put("/api/v1/users/me", json={"birthTime": "06:30", "birthPlace": "Pune"})
        cleared = client.put("/api/v1/users/me", json={"birthTime": None})
        assert cleared.status_code == 200, cleared.text
        assert cleared.json()["birthTime"] is None, "null did not clear the field"
        assert cleared.json()["birthPlace"] == "Pune", "omitted field was not preserved"
        print("✓ an explicit null clears a profile field; omitted fields are untouched")
    finally:
        main.app.dependency_overrides.clear()


def test_delete_removes_the_profile_row():
    import api.users as users_api

    original = users_api._remove_firebase_credential
    try:
        _as_user("uid-dave")
        assert client.get("/api/v1/users/me").status_code == 200

        users_api._remove_firebase_credential = lambda uid: True
        r = client.delete("/api/v1/users/me")
        assert r.status_code == 200, r.text
        assert r.json()["credentialRemoved"] is True

        session = SessionLocal()
        try:
            remaining = session.query(User).filter(
                User.firebase_uid == "uid-dave"
            ).count()
        finally:
            session.close()
        assert remaining == 0, "profile row survived account deletion"
        print("✓ account deletion removes the stored profile")
    finally:
        users_api._remove_firebase_credential = original
        main.app.dependency_overrides.clear()


def test_delete_keeps_everything_when_the_credential_cannot_be_removed():
    """Deleting the profile but leaving the login alive is the worst outcome:
    the data is gone and the account still works. Nothing may be committed
    until the credential is actually removed."""
    import api.users as users_api

    original = users_api._remove_firebase_credential
    try:
        _as_user("uid-frank")
        assert client.get("/api/v1/users/me").status_code == 200

        users_api._remove_firebase_credential = lambda uid: False
        r = client.delete("/api/v1/users/me")
        assert r.status_code == 502, f"expected 502, got {r.status_code}"

        session = SessionLocal()
        try:
            remaining = session.query(User).filter(
                User.firebase_uid == "uid-frank"
            ).count()
        finally:
            session.close()
        assert remaining == 1, "profile was destroyed even though the login survived"
        print("✓ a failed credential delete leaves the account completely intact")
    finally:
        users_api._remove_firebase_credential = original
        main.app.dependency_overrides.clear()


def test_content_routes_stay_public():
    assert client.get("/api/v1/horoscope/today?zodiac_sign=Leo").status_code == 200
    assert client.get("/api/v1/stories").status_code == 200
    print("✓ generic content routes remain reachable without signing in")


def test_personalized_reading_requires_sign_in():
    """A birth triple is a guaranteed cache miss, i.e. one geocode plus one LLM
    call chosen by the caller — that must not be available anonymously."""
    r = client.get("/api/v1/horoscope/today",
                   params={"zodiac_sign": "Leo", "birthDate": "1990-08-05"})
    assert r.status_code == 401, f"personalized reading was served anonymously: {r.status_code}"
    assert client.get("/api/v1/horoscope/forecast",
                      params={"birthDate": "1990-08-05"}).status_code == 401
    assert client.post("/api/v1/chart/birth",
                       json={"birthDate": "1990-08-05"}).status_code == 401
    assert client.get("/api/v1/vedic/home-summary").status_code == 401
    print("✓ personalized/expensive routes require sign-in")


if __name__ == "__main__":
    print("User auth")
    try:
        test_missing_token_is_rejected()
        test_malformed_authorization_header_is_rejected()
        test_fails_closed_without_service_account()
        test_profile_round_trip_is_scoped_to_the_caller()
        test_invalid_update_is_rejected()
        test_null_clears_a_field()
        test_delete_removes_the_profile_row()
        test_delete_keeps_everything_when_the_credential_cannot_be_removed()
        test_content_routes_stay_public()
        test_personalized_reading_requires_sign_in()
        print("All passed.")
    finally:
        os.unlink(_tmp_db.name)
