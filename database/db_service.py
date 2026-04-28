"""
Unified DB service for CosmicGuide — full CRUD layer for every entity.

Covers: Horoscopes, TarotCards, FortunePool, Compatibility, Stories, FortuneHistory.
All methods accept a SQLAlchemy Session and return plain dicts / lists.
"""

from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from database.models import (
    Horoscope, TarotCard, FortunePool, Compatibility, Story, FortuneHistory,
)
from database.config import get_logger

logger = get_logger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
#  Horoscopes
# ─────────────────────────────────────────────────────────────────────────────

def get_horoscope(db: Session, zodiac_sign: str, for_date: date) -> Optional[dict]:
    row = (
        db.query(Horoscope)
        .filter(Horoscope.date == for_date.isoformat(), Horoscope.zodiac_sign == zodiac_sign)
        .first()
    )
    if not row:
        return None
    return _horoscope_to_dict(row)


def get_all_horoscopes(db: Session, for_date: date) -> list[dict]:
    rows = db.query(Horoscope).filter(Horoscope.date == for_date.isoformat()).all()
    return [_horoscope_to_dict(r) for r in rows]


def save_horoscope(db: Session, data: dict, commit: bool = True) -> bool:
    try:
        db.add(Horoscope(
            date=data["date"],
            zodiac_sign=data["zodiac_sign"],
            general=data.get("general", ""),
            love=data.get("love", ""),
            career=data.get("career", ""),
            health=data.get("health", ""),
            overall_score=int(data.get("overall_score", 75)),
            lucky_number=int(data.get("lucky_number", 7)),
            lucky_color=str(data.get("lucky_color", "Violet")),
            mood=str(data.get("mood", "Thoughtful")),
        ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_horoscope %s/%s: %s", data.get("zodiac_sign"), data.get("date"), exc)
        db.rollback()
        return False


def delete_horoscope(db: Session, zodiac_sign: str, for_date: date, commit: bool = True) -> bool:
    row = (
        db.query(Horoscope)
        .filter(Horoscope.date == for_date.isoformat(), Horoscope.zodiac_sign == zodiac_sign)
        .first()
    )
    if row:
        db.delete(row)
        if commit:
            db.commit()
        return True
    return False


def horoscopes_exist(db: Session, for_date: date) -> set[str]:
    return {
        row.zodiac_sign
        for row in db.query(Horoscope.zodiac_sign)
        .filter(Horoscope.date == for_date.isoformat())
        .all()
    }


def _horoscope_to_dict(row: Horoscope) -> dict:
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


# ─────────────────────────────────────────────────────────────────────────────
#  Tarot Cards
# ─────────────────────────────────────────────────────────────────────────────

def get_tarot_card(db: Session, name: str) -> Optional[dict]:
    row = db.query(TarotCard).filter(TarotCard.name == name).first()
    if not row:
        return None
    return _tarot_to_dict(row)


def get_tarot_card_by_id(db: Session, card_id: int) -> Optional[dict]:
    row = db.query(TarotCard).filter(TarotCard.id == card_id).first()
    if not row:
        return None
    return _tarot_to_dict(row)


def get_all_tarot_cards(db: Session) -> list[dict]:
    rows = db.query(TarotCard).order_by(TarotCard.id).all()
    return [_tarot_to_dict(r) for r in rows]


def tarot_count(db: Session) -> int:
    return db.query(TarotCard).count()


def save_tarot_card(db: Session, data: dict, commit: bool = True) -> bool:
    try:
        existing = db.query(TarotCard).filter(TarotCard.name == data["name"]).first()
        if existing:
            existing.meaning = data.get("meaning", existing.meaning)
            existing.upright_interpretation = data.get("upright_interpretation", existing.upright_interpretation)
            existing.reversed_interpretation = data.get("reversed_interpretation", existing.reversed_interpretation)
        else:
            db.add(TarotCard(
                name=data["name"],
                number=data.get("number", ""),
                meaning=data.get("meaning", ""),
                upright_interpretation=data.get("upright_interpretation", ""),
                reversed_interpretation=data.get("reversed_interpretation", ""),
            ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_tarot_card '%s': %s", data.get("name"), exc)
        db.rollback()
        return False


def tarot_names_in_db(db: Session) -> set[str]:
    return {row.name for row in db.query(TarotCard.name).all()}


def _tarot_to_dict(row: TarotCard) -> dict:
    return {
        "id": row.id,
        "name": row.name,
        "number": row.number,
        "meaning": row.meaning,
        "upright_interpretation": row.upright_interpretation,
        "reversed_interpretation": row.reversed_interpretation,
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Fortune Pool
# ─────────────────────────────────────────────────────────────────────────────

def get_fortune_pool(db: Session, zodiac_sign: str, topic: str, for_date: date) -> Optional[list]:
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
                      topic: str, fortunes: list, commit: bool = True) -> bool:
    try:
        db.add(FortunePool(
            date=for_date.isoformat(),
            zodiac_sign=zodiac_sign,
            topic=topic,
            fortunes=fortunes,
        ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_fortune_pool %s/%s: %s", zodiac_sign, topic, exc)
        db.rollback()
        return False


def delete_fortune_pool(db: Session, zodiac_sign: str, topic: str,
                        for_date: date, commit: bool = True) -> bool:
    row = (
        db.query(FortunePool)
        .filter(
            FortunePool.date == for_date.isoformat(),
            FortunePool.zodiac_sign == zodiac_sign,
            FortunePool.topic == topic,
        )
        .first()
    )
    if row:
        db.delete(row)
        if commit:
            db.commit()
        return True
    return False


def fortune_pool_exists(db: Session, for_date: date) -> set[tuple[str, str]]:
    return {
        (row.zodiac_sign, row.topic)
        for row in db.query(FortunePool.zodiac_sign, FortunePool.topic)
        .filter(FortunePool.date == for_date.isoformat())
        .all()
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Compatibility
# ─────────────────────────────────────────────────────────────────────────────

def get_compatibility(db: Session, sign1: str, sign2: str) -> Optional[dict]:
    row = (
        db.query(Compatibility)
        .filter(Compatibility.sign1 == sign1, Compatibility.sign2 == sign2)
        .first()
    )
    if not row:
        row = (
            db.query(Compatibility)
            .filter(Compatibility.sign1 == sign2, Compatibility.sign2 == sign1)
            .first()
        )
    if not row:
        return None
    return _compat_to_dict(row)


def get_all_compatibility(db: Session) -> list[dict]:
    rows = db.query(Compatibility).all()
    return [_compat_to_dict(r) for r in rows]


def save_compatibility(db: Session, data: dict, commit: bool = True) -> bool:
    try:
        existing = (
            db.query(Compatibility)
            .filter(Compatibility.sign1 == data["sign1"], Compatibility.sign2 == data["sign2"])
            .first()
        )
        if existing:
            existing.score = data.get("score", existing.score)
            existing.description = data.get("description", existing.description)
            existing.love_advice = data.get("love_advice", existing.love_advice)
            existing.strengths = data.get("strengths_together", data.get("strengths", existing.strengths))
            existing.challenges = data.get("challenges", existing.challenges)
        else:
            db.add(Compatibility(
                sign1=data["sign1"],
                sign2=data["sign2"],
                score=data.get("score", 70),
                description=data.get("description", ""),
                love_advice=data.get("love_advice", ""),
                strengths=data.get("strengths_together", data.get("strengths", "")),
                challenges=data.get("challenges", ""),
            ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_compatibility %s x %s: %s", data.get("sign1"), data.get("sign2"), exc)
        db.rollback()
        return False


def compatibility_pairs_exist(db: Session) -> set[tuple[str, str]]:
    return {
        (row.sign1, row.sign2)
        for row in db.query(Compatibility.sign1, Compatibility.sign2).all()
    }


def _compat_to_dict(row: Compatibility) -> dict:
    return {
        "sign1": row.sign1,
        "sign2": row.sign2,
        "score": row.score,
        "description": row.description,
        "love_advice": row.love_advice,
        "strengths": row.strengths,
        "challenges": row.challenges,
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Stories
# ─────────────────────────────────────────────────────────────────────────────

def get_story(db: Session, story_id: int) -> Optional[dict]:
    row = db.query(Story).filter(Story.id == story_id).first()
    if not row:
        return None
    return _story_to_dict(row)


def get_stories(db: Session, page: int = 1, per_page: int = 10,
                category: str = None) -> tuple[list[dict], int]:
    q = db.query(Story)
    if category:
        q = q.filter(Story.category.ilike(category))
    total = q.count()
    rows = q.order_by(Story.published_at.desc()).offset((page - 1) * per_page).limit(per_page).all()
    return [_story_to_dict(r) for r in rows], total


def save_story(db: Session, data: dict, commit: bool = True) -> bool:
    try:
        db.add(Story(
            title=data["title"],
            summary=data.get("summary", ""),
            content=data.get("content", ""),
            category=data.get("category", "Planetary"),
            read_time=data.get("read_time", "4 min"),
            author=data.get("author", "CosmicGuide"),
            is_featured=data.get("is_featured", False),
        ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_story '%s': %s", data.get("title"), exc)
        db.rollback()
        return False


def delete_all_stories(db: Session, commit: bool = True) -> int:
    count = db.query(Story).delete()
    if commit:
        db.commit()
    return count


def story_count(db: Session) -> int:
    return db.query(Story).count()


def today_story_count(db: Session, for_date: date) -> int:
    start = datetime(for_date.year, for_date.month, for_date.day, tzinfo=timezone.utc)
    end = datetime(for_date.year, for_date.month, for_date.day, 23, 59, 59, tzinfo=timezone.utc)
    return db.query(Story).filter(Story.published_at.between(start, end)).count()


def _story_to_dict(row: Story) -> dict:
    return {
        "id": row.id,
        "title": row.title,
        "summary": row.summary,
        "content": row.content,
        "category": row.category,
        "read_time": row.read_time,
        "author": row.author,
        "published_at": row.published_at.isoformat() if row.published_at else None,
        "is_featured": row.is_featured,
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Fortune History
# ─────────────────────────────────────────────────────────────────────────────

def save_fortune_history(db: Session, user_id: int, zodiac_sign: str,
                         topic: str, mood: str, fortune_text: str,
                         commit: bool = True) -> bool:
    try:
        db.add(FortuneHistory(
            user_id=user_id,
            zodiac_sign=zodiac_sign,
            topic=topic,
            mood=mood,
            fortune_text=fortune_text,
        ))
        if commit:
            db.commit()
        return True
    except Exception as exc:
        logger.error("save_fortune_history user=%d: %s", user_id, exc)
        db.rollback()
        return False


def get_fortune_history(db: Session, user_id: int, limit: int = 20) -> list[dict]:
    rows = (
        db.query(FortuneHistory)
        .filter(FortuneHistory.user_id == user_id)
        .order_by(FortuneHistory.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "zodiac_sign": r.zodiac_sign,
            "topic": r.topic,
            "mood": r.mood,
            "fortune_text": r.fortune_text,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


# ─────────────────────────────────────────────────────────────────────────────
#  Content status (aggregate health check)
# ─────────────────────────────────────────────────────────────────────────────

def get_content_status(db: Session, for_date: date) -> dict:
    h_signs = horoscopes_exist(db, for_date)
    fp_combos = fortune_pool_exists(db, for_date)
    s_count = today_story_count(db, for_date)
    c_count = db.query(Compatibility).count()
    t_count = tarot_count(db)

    return {
        "date": for_date.isoformat(),
        "horoscopes": {"count": len(h_signs), "expected": 12, "signs": sorted(h_signs)},
        "fortune_pool": {"count": len(fp_combos), "expected": 60},
        "stories_today": s_count,
        "compatibility_pairs": {"count": c_count, "expected": 78},
        "tarot_cards": {"count": t_count, "expected": 78},
        "fully_populated": (
            len(h_signs) >= 12
            and len(fp_combos) >= 60
            and s_count >= 3
            and c_count >= 78
            and t_count >= 78
        ),
    }
