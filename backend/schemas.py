from pydantic import BaseModel, ConfigDict, EmailStr, Field
from pydantic.alias_generators import to_camel
from typing import Optional
from datetime import datetime


class CamelModel(BaseModel):
    """Base model that serializes to camelCase JSON (matching Flutter conventions)."""
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )


# --- User Schemas ---

class UserCreate(CamelModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6)
    birth_date: Optional[str] = None
    birth_time: Optional[str] = None
    birth_place: Optional[str] = None
    zodiac_sign: Optional[str] = None


class UserResponse(CamelModel):
    id: int
    name: str
    email: str
    birth_date: Optional[str] = None
    birth_time: Optional[str] = None
    birth_place: Optional[str] = None
    zodiac_sign: Optional[str] = None
    is_premium: bool


class LoginRequest(CamelModel):
    email: EmailStr
    password: str


class TokenResponse(CamelModel):
    access_token: str
    token_type: str = "bearer"


# --- Horoscope Schemas ---

class HoroscopeResponse(CamelModel):
    sign: str
    date: str
    general: str
    love: str
    career: str
    health: str
    overall_score: int
    lucky_number: str
    lucky_color: str
    mood: str


# --- Tarot Schemas ---

class TarotCardResponse(CamelModel):
    name: str
    number: str
    meaning: str
    interpretation: str
    is_reversed: bool


# --- Fortune Schemas ---

class FortuneRequest(CamelModel):
    zodiac_sign: str
    topic: str = Field(..., pattern=r"^(Love|Career|Health|Wealth|Spiritual)$")
    mood: str = Field(..., pattern=r"^(Happy|Curious|Anxious|Hopeful|Reflective)$")


class FortuneResponse(CamelModel):
    zodiac_sign: str
    topic: str
    mood: str
    fortune_text: str


# --- Compatibility Schemas ---

class CompatibilityRequest(CamelModel):
    sign1: str
    sign2: str


class CompatibilityResponse(CamelModel):
    sign1: str
    sign2: str
    score: int
    description: str
    love_advice: str
    strengths_together: str
    challenges: str


# --- Kundli Schemas ---

class BirthDetails(CamelModel):
    name: str = Field(..., min_length=1, max_length=100)
    birth_date: str
    birth_time: Optional[str] = None
    birth_place: Optional[str] = None


class KundliRequest(CamelModel):
    person1: BirthDetails
    person2: BirthDetails


class KundliResponse(CamelModel):
    total_score: int
    max_score: int
    koota_scores: dict[str, int]
    compatibility: str
    analysis: str
    has_manglik_dosha: bool


# --- Story Schemas ---

class StoryResponse(CamelModel):
    id: int
    title: str
    summary: str
    content: str
    category: str
    read_time: str
    author: Optional[str] = None
    published_at: Optional[datetime] = None


class StoryListResponse(CamelModel):
    stories: list[StoryResponse]
    total: int
    page: int
    per_page: int
