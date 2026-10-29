"""The stories API must be read-only: no LLM call, no generation route.

`GET /stories` used to call `seed_stories_db()` synchronously when the DB was
empty, so on a fresh production database every app launch would block for
minutes and spend LLM budget anonymously. Generation now belongs to the batch
populator (`./populate.sh -s`) and the API only reads.

Run from backend/:  ./venv/bin/python tests/test_stories_no_public_llm.py
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db.name}"
os.environ["ADMIN_API_KEY"] = "test-admin-key"
os.environ["ENABLE_SCHEDULER"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
import services.story_service as story_service  # noqa: E402

main.prepare_schema()  # lifespan is not run by a bare TestClient

client = TestClient(main.app)


class _SeedSpy:
    called = 0

    def __call__(self, *args, **kwargs):
        _SeedSpy.called += 1
        return 0


def test_public_read_never_generates():
    spy = _SeedSpy()
    _SeedSpy.called = 0
    original = story_service.seed_stories_db
    story_service.seed_stories_db = spy
    try:
        r = client.get("/api/v1/stories")
    finally:
        story_service.seed_stories_db = original

    assert r.status_code == 200, r.status_code
    assert _SeedSpy.called == 0, "public GET /stories triggered LLM generation"
    assert len(r.json()["stories"]) > 0, "empty DB should still serve the bundled set"
    print(f"  GET /stories on empty DB -> 200, {len(r.json()['stories'])} bundled stories, 0 LLM calls")


def test_no_generation_route_is_exposed():
    """Guards against re-adding an endpoint that runs the LLM in the API process."""
    offenders = [
        r.path for r in main.app.routes
        if "stories" in getattr(r, "path", "") and "generate" in getattr(r, "path", "")
    ]
    assert not offenders, f"stories generation route is exposed: {offenders}"
    assert client.post("/api/v1/stories/generate").status_code in (404, 405)
    print("  no /stories/generate route on the API")


def test_story_routes_are_read_only():
    story_routes = [
        r for r in main.app.routes
        if "stories" in getattr(r, "path", "") and hasattr(r, "methods")
    ]
    for route in story_routes:
        assert set(route.methods) <= {"GET", "HEAD", "OPTIONS"}, (
            f"{route.path} exposes {sorted(route.methods)}"
        )
    print(f"  {len(story_routes)} story route(s), all read-only")


if __name__ == "__main__":
    print("Stories: read-only API, no public LLM trigger")
    try:
        test_public_read_never_generates()
        test_no_generation_route_is_exposed()
        test_story_routes_are_read_only()
        print("All passed.")
    finally:
        os.unlink(_tmp_db.name)
