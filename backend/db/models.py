from sqlalchemy import Column, Integer, String, Float, Text, DateTime, Boolean, JSON
from datetime import datetime, timezone
from db.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    birth_date = Column(String(10))  # YYYY-MM-DD
    birth_time = Column(String(5))   # HH:MM
    birth_place = Column(String(255))
    zodiac_sign = Column(String(20))
    is_premium = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class Horoscope(Base):
    __tablename__ = "horoscopes"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(String(10), index=True)  # YYYY-MM-DD
    zodiac_sign = Column(String(20), index=True)
    general = Column(Text)
    love = Column(Text)
    career = Column(Text)
    health = Column(Text)
    overall_score = Column(Integer)
    lucky_number = Column(Integer)
    lucky_color = Column(String(50))
    mood = Column(String(50))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class TarotCard(Base):
    __tablename__ = "tarot_cards"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    number = Column(String(10))
    meaning = Column(Text)
    upright_interpretation = Column(Text)
    reversed_interpretation = Column(Text)


class Compatibility(Base):
    __tablename__ = "compatibility"

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
    """Pre-generated daily fortune pool — 3 fortunes per sign × topic, refreshed daily."""
    __tablename__ = "fortune_pool"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(String(10), index=True)          # YYYY-MM-DD
    zodiac_sign = Column(String(20), index=True)
    topic = Column(String(50), index=True)          # Love|Career|Health|Wealth|Spiritual
    fortunes = Column(JSON, nullable=False)          # list of 3 fortune strings
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
