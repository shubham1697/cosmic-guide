"""Verify ensure_compatibility_canonical repairs ordering, dedupes, and enforces uniqueness.

Standalone (``python tests/test_compatibility_migration.py`` from ``backend/``) or via
pytest. Uses an in-memory SQLite DB with a StaticPool so every operation shares one DB.
"""
import os
import sys

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)

from sqlalchemy import create_engine, text          # noqa: E402
from sqlalchemy.exc import IntegrityError           # noqa: E402
from sqlalchemy.pool import StaticPool              # noqa: E402

from shared.db_migrations import ensure_compatibility_canonical  # noqa: E402


def _legacy_engine():
    """A pre-fix `compatibility` table (no unique constraint) with mixed-order rows."""
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    with engine.begin() as conn:
        conn.execute(text(
            "CREATE TABLE compatibility ("
            " id INTEGER PRIMARY KEY, sign1 VARCHAR(20), sign2 VARCHAR(20), score INTEGER,"
            " description TEXT, love_advice TEXT, strengths TEXT, challenges TEXT)"
        ))
        rows = [
            ("Taurus", "Sagittarius", 60, "short"),                                   # astrological seeder row
            ("Sagittarius", "Taurus", 60, "a much longer, richer description kept"),  # alphabetical live duplicate
            ("Virgo", "Leo", 55, "leo-virgo"),                                        # non-canonical single
            ("Aries", "Aries", 70, "same sign"),                                      # already canonical
            ("Aquarius", "Aries", 80, "aqua-aries"),                                  # already canonical
        ]
        for i, (a, b, sc, d) in enumerate(rows, start=1):
            conn.execute(
                text("INSERT INTO compatibility (id, sign1, sign2, score, description) "
                     "VALUES (:id,:a,:b,:sc,:d)"),
                {"id": i, "a": a, "b": b, "sc": sc, "d": d},
            )
    return engine


def test_migration_canonicalizes_dedupes_and_enforces_unique():
    engine = _legacy_engine()
    ensure_compatibility_canonical(engine, logger=None)

    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT sign1, sign2, description FROM compatibility ORDER BY sign1, sign2")
        ).fetchall()

    assert all(r.sign1 <= r.sign2 for r in rows), rows            # 1. every row canonical
    ts = [r for r in rows if (r.sign1, r.sign2) == ("Sagittarius", "Taurus")]
    assert len(ts) == 1 and "richer" in ts[0].description, ts     # 2. duplicate collapsed, richer kept
    assert any((r.sign1, r.sign2) == ("Leo", "Virgo") for r in rows)  # 3. non-canonical swapped
    assert len(rows) == 4, rows                                   # 4. 5 rows - 1 duplicate

    # 5. unique index now blocks a duplicate pair
    raised = False
    try:
        with engine.begin() as conn:
            conn.execute(text("INSERT INTO compatibility (sign1, sign2, score) VALUES ('Aries','Aries',1)"))
    except IntegrityError:
        raised = True
    assert raised, "expected UNIQUE violation on duplicate (Aries, Aries)"

    # 6. idempotent — a second run neither errors nor changes the row count
    ensure_compatibility_canonical(engine, logger=None)
    with engine.connect() as conn:
        assert conn.execute(text("SELECT COUNT(*) FROM compatibility")).scalar() == 4


if __name__ == "__main__":
    test_migration_canonicalizes_dedupes_and_enforces_unique()
    print("compatibility migration test passed.")
