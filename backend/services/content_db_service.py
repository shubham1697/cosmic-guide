"""
Content database service — read/write layer for pre-generated daily content.

This service abstracts all DB operations for daily content (horoscopes,
fortune pools, stories, compatibility, tarot cards).  Both the API and the
daily population script use this service.

The underlying DB can be either the local SQLite or a remote PostgreSQL
running on a different machine — controlled by CONTENT_DB_URL / CONTENT_DB_ENABLED.
"""

from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from db.models import (
    Horoscope, FortunePool, Story, Compatibility, TarotCard,
)
from logger import get_logger

logger = get_logger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
#  Horoscopes
# ─────────────────────────────────────────────────────────────────────────────

def get_horoscope(db: Session, zodiac_sign: str, for_date: date) -> Optional[dict]:
    """Fetch a cached horoscope for the given sign and date."""
    row = (
        db.query(Horoscope)
        .filter(Horoscope.date == for_date.isoformat(), Horoscope.zodiac_sign == zodiac_sign)
        .first()
    )
    if not row:
        return None
    return {
        "zodiac_sign": row.zodiac_sign,
        "date": row.date,
        "general": row.general,
        "love": row.love,
        "career": row.career,
        "health": row.health,
        "overall_score": row.overall_score,
        "lucky_number": row.lucky_number,
        "lucky_color": row.lucky_color,
        "mood": row.mood,
    }


def get_all_horoscopes(db: Session, for_date: date) -> list[dict]:
    """Fetch all cached horoscopes for a given date."""
    rows = db.query(Horoscope).filter(Horoscope.date == for_date.isoformat()).all()
    return [
        {
            "zodiac_sign": r.zodiac_sign, "date": r.date,
            "general": r.general, "love": r.love, "career": r.career, "health": r.health,
            "overall_score": r.overall_score, "lucky_number": r.lucky_number,
            "lucky_color": r.lucky_color, "mood": r.mood,
        }
        for r in rows
    ]


def save_horoscope(db: Session, data: dict) -> bool:
    """Save a single horoscope to the content DB. Returns True on success."""
    try:
        db.add(Horoscope(
            date=data["date"],
            zodiac_sign=data["zodiac_sign"],
            general=data.get("general", ""),
            love=data.get("love", ""),
            career=data.get("career", ""),
            health=data.get("health", ""),
            overall_score=data.get("overall_score", 75),
            lucky_number=data.get("lucky_number", 7),
            lucky_color=data.get("lucky_color", "Violet"),
            mood=data.get("mood", "Thoughtful"),
        ))
        return True
    except Exception as exc:
        logger.error("Failed to save horoscope %s/%s: %s", data.get("zodiac_sign"), data.get("date"), exc)
        return False


def horoscopes_exist(db: Session, for_date: date) -> set[str]:
    """Return set of zodiac signs that already have a horoscope for the date."""
    return {
        row.zodiac_sign
        for row in db.query(Horoscope.zodiac_sign)
        .filter(Horoscope.date == for_date.isoformat())
        .all()
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Fortune Pool
# ─────────────────────────────────────────────────────────────────────────────

def get_fortune_pool(db: Session, zodiac_sign: str, topic: str, for_date: date) -> Optional[list]:
    """Fetch pre-generated fortune pool (list of 3 fortunes) for sign+topic+date."""
    row = (
        db.query(FortunePool)
        .filter(
            FortunePool.date == for_date.isoformat(),
            FortunePool.zodiac_sign == zodiac_sign,
            FortunePool.topic == topic,
        )
        .first()
    )
    return row.fortunes if row else None


def save_fortune_pool(db: Session, for_date: date, zodiac_sign: str,
                      topic: str, fortunes: list) -> bool:
    """Save a fortune pool entry."""
    try:
        db.add(FortunePool(
            date=for_date.isoformat(),
            zodiac_sign=zodiac_sign,
            topic=topic,
            fortunes=fortunes,
        ))
        return True
    except Exception as exc:
        logger.error("Failed to save fortune pool %s/%s: %s", zodiac_sign, topic, exc)
        return False


def fortune_pool_exists(db: Session, for_date: date) -> set[tuple[str, str]]:
    """Return set of (zodiac_sign, topic) that already have a pool for the date."""
    return {
        (row.zodiac_sign, row.topic)
        for row in db.query(FortunePool.zodiac_sign, FortunePool.topic)
        .filter(FortunePool.date == for_date.isoformat())
        .all()
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Stories
# ─────────────────────────────────────────────────────────────────────────────

def get_stories(db: Session, page: int = 1, per_page: int = 10,
                category: str = None) -> tuple[list[dict], int]:
    """Fetch paginated stories. Returns (list_of_story_dicts, total_count)."""
    q = db.query(Story)
    if category:
        q = q.filter(Story.category == category)
    total = q.count()
    rows = q.order_by(Story.published_at.desc()).offset((page - 1) * per_page).limit(per_page).all()
    stories = [
        {
            "id": r.id, "title": r.title, "summary": r.summary,
            "content": r.content, "category": r.category,
            "read_time": r.read_time, "author": r.author,
            "published_at": r.published_at.isoformat() if r.published_at else None,
            "is_featured": r.is_featured,
        }
        for r in rows
    ]
    return stories, total


def save_story(db: Session, data: dict) -> bool:
    """Save a single story to the content DB."""
    try:
        db.add(Story(
            title=data["title"],
            summary=data.get("summary", ""),
            content=data.get("content", ""),
            category=data.get("category", "Planetary"),
            read_time=data.get("read_time", "4 min"),
            author=data.get("author", "CosmicGuide"),
        ))
        return True
    except Exception as exc:
        logger.error("Failed to save story '%s': %s", data.get("title"), exc)
        return False


def get_today_story_count(db: Session, for_date: date) -> int:
    """Count stories published today."""
    start = datetime(for_date.year, for_date.month, for_date.day, tzinfo=timezone.utc)
    end = datetime(for_date.year, for_date.month, for_date.day, 23, 59, 59, tzinfo=timezone.utc)
    return db.query(Story).filter(Story.published_at.between(start, end)).count()


# ─────────────────────────────────────────────────────────────────────────────
#  Compatibility
# ─────────────────────────────────────────────────────────────────────────────

def get_compatibility(db: Session, sign1: str, sign2: str) -> Optional[dict]:
    """Fetch cached compatibility analysis for a sign pair."""
    row = (
        db.query(Compatibility)
        .filter(Compatibility.sign1 == sign1, Compatibility.sign2 == sign2)
        .first()
    )
    if not row:
        # Try reversed order
        row = (
            db.query(Compatibility)
            .filter(Compatibility.sign1 == sign2, Compatibility.sign2 == sign1)
            .first()
        )
    if not row:
        return None
    return {
        "sign1": row.sign1, "sign2": row.sign2, "score": row.score,
        "description": row.description, "love_advice": row.love_advice,
        "strengths": row.strengths, "challenges": row.challenges,
    }


def save_compatibility(db: Session, data: dict) -> bool:
    """Save a compatibility analysis."""
    try:
        db.add(Compatibility(
            sign1=data["sign1"], sign2=data["sign2"], score=data["score"],
            description=data.get("description", ""),
            love_advice=data.get("love_advice", ""),
            strengths=data.get("strengths_together", data.get("strengths", "")),
            challenges=data.get("challenges", ""),
        ))
        return True
    except Exception as exc:
        logger.error("Failed to save compatibility %s x %s: %s", data.get("sign1"), data.get("sign2"), exc)
        return False


def compatibility_pairs_exist(db: Session) -> set[tuple[str, str]]:
    """Return set of (sign1, sign2) already in the DB."""
    return {
        (row.sign1, row.sign2)
        for row in db.query(Compatibility.sign1, Compatibility.sign2).all()
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Tarot Cards
# ─────────────────────────────────────────────────────────────────────────────

def get_tarot_card(db: Session, name: str) -> Optional[dict]:
    """Fetch a tarot card by name."""
    row = db.query(TarotCard).filter(TarotCard.name == name).first()
    if not row:
        return None
    return {
        "name": row.name, "number": row.number, "meaning": row.meaning,
        "upright_interpretation": row.upright_interpretation,
        "reversed_interpretation": row.reversed_interpretation,
    }


def tarot_count(db: Session) -> int:
    """Return count of tarot cards in DB."""
    return db.query(TarotCard).count()


# ─────────────────────────────────────────────────────────────────────────────
#  Content freshness check
# ─────────────────────────────────────────────────────────────────────────────

def get_content_status(db: Session, for_date: date) -> dict:
    """
    Return a summary of what content is available for the given date.
    Useful for health checks and the daily population script.
    """
    horoscope_signs = horoscopes_exist(db, for_date)
    pool_combos = fortune_pool_exists(db, for_date)
    story_count = get_today_story_count(db, for_date)
    compat_count = db.query(Compatibility).count()
    tarot_ct = tarot_count(db)

    return {
        "date": for_date.isoformat(),
        "horoscopes": {"count": len(horoscope_signs), "expected": 12, "signs": sorted(horoscope_signs)},
        "fortune_pool": {"count": len(pool_combos), "expected": 60},  # 12 signs × 5 topics
        "stories_today": story_count,
        "compatibility_pairs": {"count": compat_count, "expected": 78},
        "tarot_cards": {"count": tarot_ct, "expected": 78},
        "fully_populated": (
            len(horoscope_signs) >= 12
            and len(pool_combos) >= 60
            and story_count >= 3
            and compat_count >= 78
            and tarot_ct >= 78
        ),
    }
