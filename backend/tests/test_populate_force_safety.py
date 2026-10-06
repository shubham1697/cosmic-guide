"""`populate.sh --force` must never destroy content it cannot replace.

populate_horoscopes / populate_periodic used to delete the existing row and only
then call the LLM:

    if sign in existing and force:
        delete_horoscope(db, sign, target_date)   # committed
    raw = _llm_generate(...)                      # may fail / return nothing
    if not raw: continue                          # -> the sign is now gone

That is the same delete-before-regenerate shape that was already fixed once in
/stories/generate. Generation now happens first and the old row is only removed
once a replacement is in hand.

Run:  ./venv/bin/python tests/test_populate_force_safety.py   (from backend/)
"""

import os
import sys

_BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ROOT = os.path.dirname(_BACKEND)
sys.path.insert(0, _ROOT)

os.environ.setdefault("DATABASE_URL", "sqlite://")

from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

import database.populate_db as pdb  # noqa: E402
from database.models import Base, Horoscope, PeriodicHoroscope, Story  # noqa: E402

_SIGN = "Aries"
_DATE = None  # set in _session()


def _session():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False},
                           poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _seed_daily(db, target_date):
    db.add(Horoscope(
        date=target_date.isoformat(), zodiac_sign=_SIGN, system="western",
        general="ORIGINAL", love="l", career="c", health="h",
        overall_score=80, lucky_number="7", lucky_color="Gold", mood="Bright",
    ))
    db.commit()


def test_force_keeps_existing_when_llm_is_down():
    from datetime import date

    db = _session()
    today = date.today()
    _seed_daily(db, today)

    original = pdb._llm_generate
    try:
        pdb._llm_generate = lambda *a, **k: None        # LLM down / empty response
        pdb.populate_horoscopes(db, today, force=True)
    finally:
        pdb._llm_generate = original

    rows = db.query(Horoscope).filter(Horoscope.zodiac_sign == _SIGN).all()
    assert len(rows) == 1, f"expected the original row to survive, found {len(rows)}"
    assert rows[0].general == "ORIGINAL", "existing horoscope was destroyed by a failed --force run"
    db.close()
    print("✓ --force with a dead LLM keeps the existing horoscope (was: deleted, never replaced)")


def test_force_still_replaces_when_llm_works():
    import json
    from datetime import date

    db = _session()
    today = date.today()
    _seed_daily(db, today)

    original = pdb._llm_generate
    try:
        # No zodiac_sign key: populate_horoscopes fills it per sign via setdefault.
        pdb._llm_generate = lambda *a, **k: json.dumps({
            "date": today.isoformat(), "general": "REFRESHED",
            "love": "l", "career": "c", "health": "h", "overall_score": 88,
            "lucky_number": 3, "lucky_color": "Ruby", "mood": "Bold",
        })
        pdb.populate_horoscopes(db, today, force=True)
    finally:
        pdb._llm_generate = original

    rows = db.query(Horoscope).filter(Horoscope.zodiac_sign == _SIGN).all()
    assert len(rows) == 1, f"--force left {len(rows)} rows for one sign (duplicate)"
    assert rows[0].general == "REFRESHED", "--force did not replace the old reading"
    db.close()
    print("✓ --force with a healthy LLM still replaces in place (exactly one row)")


def test_periodic_force_keeps_existing_when_llm_is_down():
    from datetime import date

    db = _session()
    today = date.today()
    period_key, _start, _end = pdb._period_bounds("weekly", today)
    db.add(PeriodicHoroscope(
        period="weekly", period_key=period_key, system="western", zodiac_sign=_SIGN,
        general="ORIGINAL", love="l", career="c", health="h",
        overall_score=80, lucky_number="7", lucky_color="Gold", mood="Bright",
    ))
    db.commit()

    original = pdb._llm_generate
    try:
        pdb._llm_generate = lambda *a, **k: None
        pdb.populate_periodic(db, today, "weekly", force=True)
    finally:
        pdb._llm_generate = original

    rows = db.query(PeriodicHoroscope).filter(PeriodicHoroscope.zodiac_sign == _SIGN).all()
    assert len(rows) == 1 and rows[0].general == "ORIGINAL", \
        "existing weekly horoscope was destroyed by a failed --force run"
    db.close()
    print("✓ weekly/monthly --force with a dead LLM keeps the existing reading")


def _seed_stories(db, n):
    for i in range(n):
        db.add(Story(title=f"ORIGINAL{i}", summary="s", content="c",
                     category="Spiritual", read_time="4 min", author="CG"))
    db.commit()


def test_stories_force_keeps_existing_when_llm_is_down():
    db = _session()
    _seed_stories(db, len(pdb.STORY_CATEGORIES))

    original = pdb._llm_generate
    try:
        pdb._llm_generate = lambda *a, **k: None
        pdb.populate_stories(db, force=True)
    finally:
        pdb._llm_generate = original

    rows = db.query(Story).all()
    assert len(rows) == len(pdb.STORY_CATEGORIES), f"feed changed size: {len(rows)}"
    assert all(r.title.startswith("ORIGINAL") for r in rows), \
        "existing stories were destroyed by a failed --force run"
    db.close()
    print("✓ stories --force with a dead LLM keeps the existing feed")


def test_stories_force_replaces_instead_of_growing():
    import json

    db = _session()
    _seed_stories(db, len(pdb.STORY_CATEGORIES))

    original = pdb._llm_generate
    try:
        pdb._llm_generate = lambda *a, **k: json.dumps({
            "title": "REFRESHED", "summary": "s",
            "content": "c" * 50, "read_time": "4 min",
        })
        pdb.populate_stories(db, force=True)
    finally:
        pdb._llm_generate = original

    rows = db.query(Story).all()
    assert len(rows) == len(pdb.STORY_CATEGORIES), \
        f"--force grew the table to {len(rows)} (old set was not retired)"
    assert all(r.title == "REFRESHED" for r in rows), "old stories were not replaced"
    db.close()
    print("✓ stories --force replaces the set instead of appending forever")


if __name__ == "__main__":
    test_force_keeps_existing_when_llm_is_down()
    test_force_still_replaces_when_llm_works()
    test_periodic_force_keeps_existing_when_llm_is_down()
    test_stories_force_keeps_existing_when_llm_is_down()
    test_stories_force_replaces_instead_of_growing()
    print("\nAll populate --force safety tests passed.")
