"""Verify unique constraints + dedupe migration on the cache tables (defect #8).

Runnable standalone (``python tests/test_cache_unique_indexes.py`` from ``backend/``) or via pytest.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

from sqlalchemy import create_engine, text                # noqa: E402
from sqlalchemy.exc import IntegrityError                 # noqa: E402
from sqlalchemy.orm import sessionmaker                    # noqa: E402
from sqlalchemy.pool import StaticPool                     # noqa: E402

from db.database import Base                               # noqa: E402
from db.models import Horoscope, PeriodicHoroscope, FortunePool  # noqa: E402
from shared.db_migrations import ensure_cache_unique_indexes     # noqa: E402


def _engine():
    return create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)


def _dup_raises(session, make_row):
    session.add(make_row("a"))
    session.commit()                       # first row OK
    session.add(make_row("b"))
    try:
        session.commit()
        return False
    except IntegrityError:
        session.rollback()
        return True


def test_fresh_schema_blocks_duplicate_cache_rows():
    eng = _engine()
    Base.metadata.create_all(eng)          # constraints declared on the models
    s = sessionmaker(bind=eng)()
    try:
        assert _dup_raises(s, lambda g: Horoscope(
            date="2026-08-20", zodiac_sign="Aries", system="western", general=g))
        assert _dup_raises(s, lambda g: FortunePool(
            date="2026-08-20", zodiac_sign="Aries", topic="Love", fortunes=[g]))
        assert _dup_raises(s, lambda g: PeriodicHoroscope(
            period="weekly", period_key="2026-W34", system="western", zodiac_sign="Aries", general=g))
    finally:
        s.close()


def test_migration_dedupes_legacy_and_enforces():
    eng = _engine()
    with eng.begin() as c:   # legacy tables WITHOUT the unique constraint, with duplicates
        c.execute(text("CREATE TABLE horoscopes (id INTEGER PRIMARY KEY, date TEXT, zodiac_sign TEXT, system TEXT, general TEXT)"))
        c.execute(text("CREATE TABLE fortune_pool (id INTEGER PRIMARY KEY, date TEXT, zodiac_sign TEXT, topic TEXT, fortunes TEXT)"))
        c.execute(text("CREATE TABLE periodic_horoscopes (id INTEGER PRIMARY KEY, period TEXT, period_key TEXT, system TEXT, zodiac_sign TEXT, general TEXT)"))
        for _ in range(3):
            c.execute(text("INSERT INTO horoscopes (date,zodiac_sign,system,general) VALUES ('d','Aries','western','g')"))
            c.execute(text("INSERT INTO fortune_pool (date,zodiac_sign,topic,fortunes) VALUES ('d','Aries','Love','[]')"))
            c.execute(text("INSERT INTO periodic_horoscopes (period,period_key,system,zodiac_sign,general) VALUES ('weekly','2026-W34','western','Aries','g')"))

    ensure_cache_unique_indexes(eng, None)

    with eng.connect() as c:
        assert c.execute(text("SELECT COUNT(*) FROM horoscopes")).scalar() == 1
        assert c.execute(text("SELECT COUNT(*) FROM fortune_pool")).scalar() == 1
        assert c.execute(text("SELECT COUNT(*) FROM periodic_horoscopes")).scalar() == 1

    raised = False   # unique index now blocks a duplicate
    try:
        with eng.begin() as c:
            c.execute(text("INSERT INTO horoscopes (date,zodiac_sign,system,general) VALUES ('d','Aries','western','x')"))
    except IntegrityError:
        raised = True
    assert raised

    ensure_cache_unique_indexes(eng, None)   # idempotent
    with eng.connect() as c:
        assert c.execute(text("SELECT COUNT(*) FROM horoscopes")).scalar() == 1


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All cache unique-index tests passed.")
