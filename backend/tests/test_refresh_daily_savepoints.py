"""Verify the /admin/refresh-daily insert loops isolate a bad row with a SAVEPOINT
so one failure can't roll back the whole batch (defect #12).

The session here is configured EXACTLY like the app's SessionLocal
(``autoflush=False``) — the fix relies on ``begin_nested()`` flushing on block exit
even with autoflush off, so we prove that against the real models/constraints.

Runnable standalone (``python tests/test_refresh_daily_savepoints.py`` from ``backend/``).
No app import, no network, no LLM — just the ORM models + SQLite.
"""
import os
import sys

_BACKEND = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ROOT = os.path.abspath(os.path.join(_BACKEND, ".."))  # repo root, for `shared`
sys.path.insert(0, _ROOT)
sys.path.insert(0, _BACKEND)

from sqlalchemy import create_engine                       # noqa: E402
from sqlalchemy.orm import sessionmaker                     # noqa: E402
from sqlalchemy.pool import StaticPool                      # noqa: E402
from db.models import Base, Horoscope, Story, FortunePool   # noqa: E402

_SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
          "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]


def _fresh_session():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    # Match the app's SessionLocal exactly.
    return sessionmaker(bind=engine, autoflush=False, autocommit=False)


def _insert_with_savepoints(Session, rows, make):
    """Mirror the endpoint's fixed loop: per-row SAVEPOINT, one commit after."""
    db = Session()
    good = bad = 0
    for r in rows:
        try:
            with db.begin_nested():
                db.add(make(r))
            good += 1
        except Exception:
            bad += 1
    db.commit()
    return good, bad


def _mk_horoscope(sign):
    return Horoscope(date="2026-08-20", zodiac_sign=sign, system="western",
                     general="g", love="l", career="c", health="h",
                     overall_score=70, lucky_number="7", lucky_color="Gold", mood="Bright")


def _mk_story(title):
    return Story(title=title, summary="s", content="c", category="News",
                 read_time="3 min", author="CosmicGuide")


def _mk_fortune(item):
    return FortunePool(date="2026-08-20", zodiac_sign=item[0], topic=item[1], fortunes=item[2])


# ── one bad row must NOT sink the batch ───────────────────────────────────────

def test_horoscope_duplicate_is_isolated():
    Session = _fresh_session()
    rows = _SIGNS + ["Aries"]                     # duplicate → violates uq_horoscope_day
    good, bad = _insert_with_savepoints(Session, rows, _mk_horoscope)
    assert (good, bad) == (12, 1), (good, bad)
    assert Session().query(Horoscope).count() == 12   # the 12 good rows survived


def test_story_not_null_title_is_isolated():
    Session = _fresh_session()
    rows = ["A", "B", None, "D", "E"]             # None title → NOT NULL violation
    good, bad = _insert_with_savepoints(Session, rows, _mk_story)
    assert (good, bad) == (4, 1), (good, bad)
    assert Session().query(Story).count() == 4


def test_fortune_duplicate_is_isolated():
    Session = _fresh_session()
    rows = [
        ("Aries", "Love", ["a", "b", "c"]),
        ("Aries", "Love", ["x", "y", "z"]),       # duplicate (date, sign, topic) → uq_fortune_pool
        ("Taurus", "Love", ["d", "e", "f"]),
    ]
    good, bad = _insert_with_savepoints(Session, rows, _mk_fortune)
    assert (good, bad) == (2, 1), (good, bad)
    assert Session().query(FortunePool).count() == 2


# ── contrast: the OLD pattern (add-all, single trailing commit) lost everything ──

def test_old_single_commit_pattern_loses_all():
    Session = _fresh_session()
    db = Session()
    for sign in _SIGNS + ["Aries"]:
        db.add(_mk_horoscope(sign))               # no per-row savepoint
    raised = False
    try:
        db.commit()                               # whole batch flushes here
    except Exception:
        raised = True
        db.rollback()
    assert raised, "the duplicate must fail the batch commit"
    assert Session().query(Horoscope).count() == 0, "old pattern loses every row"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name} passed")
    print("All refresh-daily savepoint tests passed.")
