from sqlalchemy import Column, Integer, String, Float, Text, DateTime, Boolean, JSON, UniqueConstraint
from datetime import datetime, timezone
from database.connection import Base


class User(Base):
    """A signed-in account. Credentials live in Firebase, never here.

    Mirrors backend/db/models.py::User exactly — both run create_all against
    the same database, so any drift here produces the wrong table.
    """

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String(128), unique=True, index=True, nullable=False)
    email = Column(String(255), index=True)
    name = Column(String(100))
    birth_date = Column(String(10))
    birth_time = Column(String(5))
    birth_place = Column(String(255))
    zodiac_sign = Column(String(20))
    tradition = Column(String(10), default="western")
    is_premium = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class Horoscope(Base):
    __tablename__ = "horoscopes"
    __table_args__ = (UniqueConstraint("date", "zodiac_sign", "system", name="uq_horoscope_day"),)

    id = Column(Integer, primary_key=True, index=True)
    date = Column(String(10), index=True)
    zodiac_sign = Column(String(20), index=True)
    # 'western' (tropical Sun sign) | 'vedic' (sidereal Moon rashi)
    system = Column(String(10), index=True, default="western")
    general = Column(Text)
    love = Column(Text)
    career = Column(Text)
    health = Column(Text)
    overall_score = Column(Integer)
    lucky_number = Column(String(10))
    lucky_color = Column(String(50))
    mood = Column(String(50))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class PeriodicHoroscope(Base):
    """Weekly and monthly readings, cached per (period, key, system, sign)."""
    __tablename__ = "periodic_horoscopes"
    __table_args__ = (UniqueConstraint("period", "period_key", "system", "zodiac_sign", name="uq_periodic_horoscope"),)

    id = Column(Integer, primary_key=True, index=True)
    period = Column(String(10), index=True)       # 'weekly' | 'monthly'
    period_key = Column(String(10), index=True)   # e.g. '2026-W30' | '2026-07'
    system = Column(String(10), index=True)       # 'western' | 'vedic'
    zodiac_sign = Column(String(20), index=True)
    general = Column(Text)
    love = Column(Text)
    career = Column(Text)
    health = Column(Text)
    overall_score = Column(Integer)
    lucky_number = Column(String(10))
    lucky_color = Column(String(50))
    mood = Column(String(50))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class TarotCard(Base):
    __tablename__ = "tarot_cards"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    number = Column(String(20))
    meaning = Column(Text)
    upright_interpretation = Column(Text)
    reversed_interpretation = Column(Text)


class Compatibility(Base):
    __tablename__ = "compatibility"
    __table_args__ = (UniqueConstraint("sign1", "sign2", name="uq_compatibility_pair"),)

    id = Column(Integer, primary_key=True, index=True)
    sign1 = Column(String(20), index=True)
    sign2 = Column(String(20), index=True)
    score = Column(Integer)
    description = Column(Text)
    love_advice = Column(Text)
    strengths = Column(Text)
    challenges = Column(Text)


class FortuneHistory(Base):
    __tablename__ = "fortune_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    zodiac_sign = Column(String(20))
    topic = Column(String(50))
    mood = Column(String(50))
    fortune_text = Column(Text)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class Story(Base):
    __tablename__ = "stories"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    summary = Column(Text)
    content = Column(Text)
    category = Column(String(50), index=True)
    read_time = Column(String(20))
    author = Column(String(100))
    published_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_featured = Column(Boolean, default=False)


class FortunePool(Base):
    __tablename__ = "fortune_pool"
    __table_args__ = (UniqueConstraint("date", "zodiac_sign", "topic", name="uq_fortune_pool"),)

    id = Column(Integer, primary_key=True, index=True)
    date = Column(String(10), index=True)
    zodiac_sign = Column(String(20), index=True)
    topic = Column(String(50), index=True)
    fortunes = Column(JSON, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class KundliReport(Base):
    __tablename__ = "kundli_reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    person1_name = Column(String(100))
    person1_birth_date = Column(String(10))
    person1_birth_time = Column(String(5))
    person1_birth_place = Column(String(255))
    person2_name = Column(String(100))
    person2_birth_date = Column(String(10))
    person2_birth_time = Column(String(5))
    person2_birth_place = Column(String(255))
    total_score = Column(Integer)
    max_score = Column(Integer, default=36)
    koota_scores = Column(JSON)
    compatibility = Column(String(50))
    analysis = Column(Text)
    has_manglik_dosha = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
