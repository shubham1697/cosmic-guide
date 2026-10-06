"""Verify the horoscopes.lucky_number Integer→String fix (defect #2).

Runnable standalone (``python tests/test_lucky_number_migration.py`` from ``backend/``)
or via pytest. The Postgres branch isolates itself in a throwaway database and
self-skips when no Postgres is reachable.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

import sqlalchemy as sa                                          # noqa: E402
from sqlalchemy.pool import StaticPool                           # noqa: E402

from shared.db_migrations import ensure_horoscope_lucky_number_string  # noqa: E402

_PG_URL = os.environ.get(
    "TEST_PG_URL", "postgresql+psycopg2://cosmicguide:cosmicguide@localhost:5432/cosmicguide"
)


def test_fresh_schema_lucky_number_is_string():
    """create_all() from the ORM model must build lucky_number as VARCHAR, not INTEGER."""
    from db.database import Base
    import db.models  # noqa: F401 — registers Horoscope on Base.metadata

    eng = sa.create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    col = next(c for c in sa.inspect(eng).get_columns("horoscopes") if c["name"] == "lucky_number")
    assert "CHAR" in str(col["type"]).upper(), col["type"]


def test_sqlite_migration_noop_and_idempotent():
    """On SQLite the migration is a safe no-op; affinity already stores strings."""
    eng = sa.create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with eng.begin() as conn:
        conn.execute(sa.text("CREATE TABLE horoscopes (id INTEGER PRIMARY KEY, lucky_number INTEGER)"))
        conn.execute(sa.text("INSERT INTO horoscopes (id, lucky_number) VALUES (1, 7)"))

    ensure_horoscope_lucky_number_string(eng, None)
    ensure_horoscope_lucky_number_string(eng, None)  # idempotent

    with eng.begin() as conn:
        conn.execute(sa.text("INSERT INTO horoscopes (id, lucky_number) VALUES (2, '7, 14')"))
    with eng.connect() as conn:
        vals = [str(r[0]) for r in conn.execute(sa.text("SELECT lucky_number FROM horoscopes ORDER BY id"))]
    assert vals == ["7", "7, 14"], vals


def test_postgres_migration_alters_type():
    """On Postgres the Integer column rejects '7, 14'; after the migration it persists."""
    try:
        admin = sa.create_engine(_PG_URL, isolation_level="AUTOCOMMIT")
        with admin.connect() as c:
            c.execute(sa.text("DROP DATABASE IF EXISTS lucky_probe_test"))
            c.execute(sa.text("CREATE DATABASE lucky_probe_test"))
    except Exception as exc:  # pragma: no cover
        print(f"  SKIP postgres branch ({str(exc).splitlines()[0]})")
        return

    test_url = _PG_URL.rsplit("/", 1)[0] + "/lucky_probe_test"
    eng = sa.create_engine(test_url)
    try:
        with eng.begin() as conn:
            conn.execute(sa.text("CREATE TABLE horoscopes (id SERIAL PRIMARY KEY, lucky_number INTEGER)"))
            conn.execute(sa.text("INSERT INTO horoscopes (lucky_number) VALUES (7)"))

        # Integer column rejects a non-integer string BEFORE the migration.
        rejected = False
        try:
            with eng.begin() as conn:
                conn.execute(sa.text("INSERT INTO horoscopes (lucky_number) VALUES (:v)"), {"v": "7, 14"})
        except sa.exc.DataError:
            rejected = True
        assert rejected, "Integer column should reject '7, 14' before the migration"

        ensure_horoscope_lucky_number_string(eng, None)

        col = next(c for c in sa.inspect(eng).get_columns("horoscopes") if c["name"] == "lucky_number")
        assert "CHAR" in str(col["type"]).upper(), col["type"]           # now VARCHAR
        with eng.begin() as conn:                                        # string now persists
            conn.execute(sa.text("INSERT INTO horoscopes (lucky_number) VALUES (:v)"), {"v": "7, 14"})
        with eng.connect() as conn:
            vals = [r[0] for r in conn.execute(sa.text("SELECT lucky_number FROM horoscopes ORDER BY id"))]
        assert vals == ["7", "7, 14"], vals                              # legacy 7 preserved as "7"
        print("  postgres branch passed")
    finally:
        eng.dispose()
        try:
            admin = sa.create_engine(_PG_URL, isolation_level="AUTOCOMMIT")
            with admin.connect() as c:
                c.execute(sa.text("DROP DATABASE IF EXISTS lucky_probe_test"))
        except Exception:
            pass


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All lucky_number migration tests passed.")
