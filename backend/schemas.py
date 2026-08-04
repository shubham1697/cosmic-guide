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


# --- Birth Chart Schemas ---

class BirthChartRequest(CamelModel):
    birth_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    birth_time: Optional[str] = None   # HH:MM (24h)
    birth_place: Optional[str] = None


class PlanetPosition(CamelModel):
    name: str
    symbol: str
    longitude: float
    latitude: float
    speed: float
    sign: str
    sign_symbol: str
    degree_in_sign: float
    degree_display: str
    is_retrograde: bool


class HouseCusp(CamelModel):
    house: int
    cusp_longitude: float
    sign: str
    degree_in_sign: float
    degree_display: str


class Big3Entry(CamelModel):
    sign: str
    degree: str
    description: str
    is_estimated: Optional[bool] = None


class Big3(CamelModel):
    sun: Big3Entry
    moon: Big3Entry
    rising: Big3Entry


class NakshatraInfo(CamelModel):
    name: str
    pada: int
    lord: str


class PointInfo(CamelModel):
    longitude: float
    sign: str
    degree_display: str


class AspectInfo(CamelModel):
    planet1: str
    planet2: str
    aspect: str
    angle: float
    orb: float


class BirthInfo(CamelModel):
    date: str
    time: str
    place: str
    latitude: float
    longitude: float
    timezone: str


class BirthChartResponse(CamelModel):
    birth_info: BirthInfo
    planets: list[PlanetPosition]
    houses: list[HouseCusp]
    big3: Big3
    moon_nakshatra: NakshatraInfo
    ascendant: PointInfo
    midheaven: PointInfo
    aspects: list[AspectInfo]
    has_accurate_houses: bool


class TransitPosition(CamelModel):
    name: str
    symbol: str
    longitude: float
    sign: str
    degree_in_sign: float
    degree_display: str
    is_retrograde: bool


class TransitsResponse(CamelModel):
    transits: list[TransitPosition]


# --- Vedic Home Summary Schemas ---

class VedicLocationSummary(CamelModel):
    name: str
    latitude: float
    longitude: float
    timezone: str


class PanchangSummary(CamelModel):
    date: str
    vara: str
    vara_ruler: str
    tithi: str
    paksha: str
    nakshatra: str
    yoga: str
    karana: str
    insight: str


class VedicCalendarSummary(CamelModel):
    month_name: str
    samvat_year: int
    next_festival_name: str
    next_festival_date: str
    note: str


class MuhurtaSummary(CamelModel):
    label: str
    starts_at: str
    ends_at: str
    note: str


class DailyTimingsSummary(CamelModel):
    """Location-aware daily timings derived from real sunrise/sunset."""

    sunrise: str
    sunset: str
    day_length: str
    abhijit: str
    brahma_muhurta: str
    rahu_kaal: str
    yamaganda: str
    gulika: str


class KundliHomeSummary(CamelModel):
    lagna: str
    moon_sign: str
    nakshatra: str
    note: str


class DashaHomeSummary(CamelModel):
    mahadasha: str
    mahadasha_ends_on: str
    antardasha: str
    guidance: str


class DoshaHomeSummary(CamelModel):
    active_count: int
    top_doshas: list[str]
    summary: str


class RemedyHomeSummary(CamelModel):
    focus: str
    gemstone: str
    mantra: str
    fasting_day: str
    guidance: str


# --- Notification Schemas ---

class DeviceTokenRegister(CamelModel):
    token: str = Field(..., min_length=10)
    platform: str = Field(..., pattern="^(android|ios)$")
    zodiac_sign: Optional[str] = None
    tradition: Optional[str] = None
    birth_date: Optional[str] = None
    birth_time: Optional[str] = None
    birth_place: Optional[str] = None
    daily_horoscope_enabled: Optional[bool] = True


class TokenRef(CamelModel):
    token: str = Field(..., min_length=10)


class NotificationPreferences(CamelModel):
    token: str = Field(..., min_length=10)
    daily_horoscope_enabled: bool


class TestPushRequest(CamelModel):
    token: str = Field(..., min_length=10)
    title: Optional[str] = None
    body: Optional[str] = None


class VedicHomeSummaryResponse(CamelModel):
    location: VedicLocationSummary
    panchang: PanchangSummary
    calendar: VedicCalendarSummary
    muhurta: MuhurtaSummary
    timings: DailyTimingsSummary
    kundli: Optional[KundliHomeSummary] = None
    dasha: Optional[DashaHomeSummary] = None
    dosha: Optional[DoshaHomeSummary] = None
    remedy: Optional[RemedyHomeSummary] = None
