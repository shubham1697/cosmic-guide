"""
Birth chart calculation using Swiss Ephemeris.

Computes real planetary positions, house cusps, zodiac placements,
nakshatras, and the Big 3 (Sun / Moon / Ascendant) for a given
birth date, time, and location.
"""

import math
from datetime import datetime
from typing import Optional

import swisseph as swe
from geopy.geocoders import Nominatim
from timezonefinder import TimezoneFinder
from zoneinfo import ZoneInfo

from logger import get_logger

logger = get_logger(__name__)

# Use built-in ephemeris (no external data files needed)
swe.set_ephe_path("")

# ── Constants ────────────────────────────────────────────────────────────────

ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
]

ZODIAC_SYMBOLS = [
    "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓",
]

PLANET_IDS = {
    "Sun":     swe.SUN,
    "Moon":    swe.MOON,
    "Mercury": swe.MERCURY,
    "Venus":   swe.VENUS,
    "Mars":    swe.MARS,
    "Jupiter": swe.JUPITER,
    "Saturn":  swe.SATURN,
    "Uranus":  swe.URANUS,
    "Neptune": swe.NEPTUNE,
    "Pluto":   swe.PLUTO,
}

PLANET_SYMBOLS = {
    "Sun": "☉", "Moon": "☽", "Mercury": "☿", "Venus": "♀",
    "Mars": "♂", "Jupiter": "♃", "Saturn": "♄", "Uranus": "♅",
    "Neptune": "♆", "Pluto": "♇",
}

# 27 Nakshatras — each spans 13°20' (13.3333°)
NAKSHATRAS = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni",
    "Uttara Phalguni", "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha",
    "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana",
    "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada",
    "Revati",
]

NAKSHATRA_LORDS = [
    "Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu",
    "Jupiter", "Saturn", "Mercury", "Ketu", "Venus",
    "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn",
    "Mercury", "Ketu", "Venus", "Sun", "Moon",
    "Mars", "Rahu", "Jupiter", "Saturn", "Mercury",
]

# Geocoder (lazy singleton)
_geocoder: Optional[Nominatim] = None
_tz_finder: Optional[TimezoneFinder] = None


def _get_geocoder() -> Nominatim:
    global _geocoder
    if _geocoder is None:
        _geocoder = Nominatim(user_agent="cosmicguide-astro")
    return _geocoder


def _get_tz_finder() -> TimezoneFinder:
    global _tz_finder
    if _tz_finder is None:
        _tz_finder = TimezoneFinder()
    return _tz_finder


# ── Helpers ──────────────────────────────────────────────────────────────────

def _sign_from_longitude(lon: float) -> str:
    """Return zodiac sign name from ecliptic longitude (0–360)."""
    return ZODIAC_SIGNS[int(lon / 30) % 12]


def _sign_symbol_from_longitude(lon: float) -> str:
    return ZODIAC_SYMBOLS[int(lon / 30) % 12]


def _degree_in_sign(lon: float) -> float:
    """Return degree within the sign (0–30)."""
    return lon % 30


def _nakshatra_from_longitude(lon: float) -> dict:
    """Return nakshatra name, pada (1-4), and lord from Moon longitude."""
    nak_index = int(lon / (360 / 27)) % 27
    pada = int((lon % (360 / 27)) / (360 / 108)) + 1
    return {
        "name": NAKSHATRAS[nak_index],
        "pada": min(pada, 4),
        "lord": NAKSHATRA_LORDS[nak_index],
    }


def _format_dms(degrees: float) -> str:
    """Format decimal degrees as D°M'S\"."""
    d = int(degrees)
    m = int((degrees - d) * 60)
    s = int(((degrees - d) * 60 - m) * 60)
    return f"{d}°{m:02d}'{s:02d}\""


def geocode_place(place: str) -> Optional[tuple[float, float]]:
    """Return (latitude, longitude) for a place name, or None."""
    try:
        location = _get_geocoder().geocode(place, timeout=10)
        if location:
            return (location.latitude, location.longitude)
    except Exception as e:
        logger.warning("Geocoding failed for '%s': %s", place, e)
    return None


def _get_timezone(lat: float, lon: float) -> str:
    """Return IANA timezone string for coordinates."""
    tz = _get_tz_finder().timezone_at(lat=lat, lng=lon)
    return tz or "UTC"


def _to_julian_day(dt_utc: datetime) -> float:
    """Convert a UTC datetime to Julian Day."""
    hour_decimal = dt_utc.hour + dt_utc.minute / 60.0 + dt_utc.second / 3600.0
    return swe.julday(dt_utc.year, dt_utc.month, dt_utc.day, hour_decimal)


# ── Main calculation ─────────────────────────────────────────────────────────

def calculate_birth_chart(
    birth_date: str,
    birth_time: Optional[str] = None,
    birth_place: Optional[str] = None,
) -> dict:
    """
    Calculate a full birth chart.

    Args:
        birth_date: "YYYY-MM-DD"
        birth_time: "HH:MM" (24h). Defaults to 12:00 if not provided.
        birth_place: City/place name. Defaults to 0°N 0°E if not provided.

    Returns:
        Dict with planets, houses, big3, nakshatras, aspects, etc.
    """
    # Parse birth date
    try:
        bd = datetime.strptime(birth_date, "%Y-%m-%d")
    except ValueError:
        raise ValueError(f"Invalid birth_date format: {birth_date}. Use YYYY-MM-DD.")

    # Parse birth time
    if birth_time:
        try:
            parts = birth_time.split(":")
            hour, minute = int(parts[0]), int(parts[1])
        except (ValueError, IndexError):
            hour, minute = 12, 0
            logger.warning("Invalid birth_time '%s', defaulting to 12:00", birth_time)
    else:
        hour, minute = 12, 0

    # Geocode birth place
    lat, lon = 0.0, 0.0
    tz_name = "UTC"
    if birth_place:
        coords = geocode_place(birth_place)
        if coords:
            lat, lon = coords
            tz_name = _get_timezone(lat, lon)
        else:
            logger.warning("Could not geocode '%s', using 0°N 0°E", birth_place)

    # Build local datetime and convert to UTC
    local_dt = datetime(bd.year, bd.month, bd.day, hour, minute)
    try:
        tz = ZoneInfo(tz_name)
        local_aware = local_dt.replace(tzinfo=tz)
        utc_dt = local_aware.astimezone(ZoneInfo("UTC"))
    except Exception:
        utc_dt = local_dt  # fallback

    jd = _to_julian_day(utc_dt)

    logger.info(
        "Calculating birth chart: date=%s time=%s place=%s lat=%.4f lon=%.4f jd=%.6f",
        birth_date, birth_time or "12:00", birth_place or "N/A", lat, lon, jd,
    )

    # ── Calculate planetary positions ────────────────────────────────────────
    planets = []
    for name, planet_id in PLANET_IDS.items():
        result, _flags = swe.calc_ut(jd, planet_id)
        longitude = result[0]  # ecliptic longitude
        latitude = result[1]
        speed = result[3]       # daily speed (negative = retrograde)

        sign = _sign_from_longitude(longitude)
        deg_in_sign = _degree_in_sign(longitude)
        is_retrograde = speed < 0

        planets.append({
            "name": name,
            "symbol": PLANET_SYMBOLS[name],
            "longitude": round(longitude, 4),
            "latitude": round(latitude, 4),
            "speed": round(speed, 4),
            "sign": sign,
            "sign_symbol": _sign_symbol_from_longitude(longitude),
            "degree_in_sign": round(deg_in_sign, 2),
            "degree_display": _format_dms(deg_in_sign),
            "is_retrograde": is_retrograde,
        })

    # ── Calculate house cusps (Placidus) ─────────────────────────────────────
    has_houses = birth_time is not None and birth_place is not None
    houses = []
    ascendant_lon = None

    if has_houses:
        cusps, asc_mc = swe.houses(jd, lat, lon, b'P')  # Placidus
        ascendant_lon = asc_mc[0]
        mc_lon = asc_mc[1]

        for i, cusp_lon in enumerate(cusps):
            houses.append({
                "house": i + 1,
                "cusp_longitude": round(cusp_lon, 4),
                "sign": _sign_from_longitude(cusp_lon),
                "degree_in_sign": round(_degree_in_sign(cusp_lon), 2),
                "degree_display": _format_dms(_degree_in_sign(cusp_lon)),
            })
    else:
        # Without birth time/place, estimate ascendant from Sun (whole sign)
        sun_lon = next(p["longitude"] for p in planets if p["name"] == "Sun")
        ascendant_lon = sun_lon  # crude fallback
        mc_lon = (sun_lon + 270) % 360

    # ── Big 3 ────────────────────────────────────────────────────────────────
    sun_data = next(p for p in planets if p["name"] == "Sun")
    moon_data = next(p for p in planets if p["name"] == "Moon")

    ascendant_sign = _sign_from_longitude(ascendant_lon)
    ascendant_deg = _degree_in_sign(ascendant_lon)

    big3 = {
        "sun": {
            "sign": sun_data["sign"],
            "degree": sun_data["degree_display"],
            "description": "Your core identity, ego, and life force.",
        },
        "moon": {
            "sign": moon_data["sign"],
            "degree": moon_data["degree_display"],
            "description": "Your emotions, instincts, and inner self.",
        },
        "rising": {
            "sign": ascendant_sign,
            "degree": _format_dms(ascendant_deg),
            "description": "How the world sees you, your outward persona.",
            "is_estimated": not has_houses,
        },
    }

    # ── Moon nakshatra (Vedic) ───────────────────────────────────────────────
    moon_nakshatra = _nakshatra_from_longitude(moon_data["longitude"])

    # ── Aspects ──────────────────────────────────────────────────────────────
    aspects = _calculate_aspects(planets)

    # ── Build response ───────────────────────────────────────────────────────
    chart = {
        "birth_info": {
            "date": birth_date,
            "time": birth_time or "12:00 (default)",
            "place": birth_place or "Unknown",
            "latitude": round(lat, 4),
            "longitude": round(lon, 4),
            "timezone": tz_name,
        },
        "planets": planets,
        "houses": houses,
        "big3": big3,
        "moon_nakshatra": moon_nakshatra,
        "ascendant": {
            "longitude": round(ascendant_lon, 4),
            "sign": ascendant_sign,
            "degree_display": _format_dms(ascendant_deg),
        },
        "midheaven": {
            "longitude": round(mc_lon, 4),
            "sign": _sign_from_longitude(mc_lon),
            "degree_display": _format_dms(_degree_in_sign(mc_lon)),
        },
        "aspects": aspects,
        "has_accurate_houses": has_houses,
    }

    logger.info(
        "Birth chart calculated: Sun=%s Moon=%s Rising=%s Nakshatra=%s",
        big3["sun"]["sign"], big3["moon"]["sign"],
        big3["rising"]["sign"], moon_nakshatra["name"],
    )
    return chart


# ── Aspect calculation ───────────────────────────────────────────────────────

ASPECT_TYPES = {
    "Conjunction": (0, 8),
    "Sextile": (60, 6),
    "Square": (90, 8),
    "Trine": (120, 8),
    "Opposition": (180, 8),
}


def _calculate_aspects(planets: list[dict]) -> list[dict]:
    """Calculate major aspects between all planet pairs."""
    aspects = []
    planet_names = [p["name"] for p in planets]

    for i in range(len(planets)):
        for j in range(i + 1, len(planets)):
            p1 = planets[i]
            p2 = planets[j]
            lon1 = p1["longitude"]
            lon2 = p2["longitude"]

            # Angular separation (0–180)
            diff = abs(lon1 - lon2)
            if diff > 180:
                diff = 360 - diff

            for aspect_name, (exact_angle, orb) in ASPECT_TYPES.items():
                if abs(diff - exact_angle) <= orb:
                    aspects.append({
                        "planet1": p1["name"],
                        "planet2": p2["name"],
                        "aspect": aspect_name,
                        "angle": round(diff, 2),
                        "orb": round(abs(diff - exact_angle), 2),
                    })
                    break  # only one aspect per pair

    return aspects


# ── Current transits ─────────────────────────────────────────────────────────

def calculate_current_transits() -> list[dict]:
    """Calculate current planetary positions (transits for today)."""
    now = datetime.utcnow()
    jd = _to_julian_day(now)

    transits = []
    for name, planet_id in PLANET_IDS.items():
        result, _flags = swe.calc_ut(jd, planet_id)
        longitude = result[0]
        speed = result[3]

        sign = _sign_from_longitude(longitude)
        is_retrograde = speed < 0

        transits.append({
            "name": name,
            "symbol": PLANET_SYMBOLS[name],
            "longitude": round(longitude, 4),
            "sign": sign,
            "degree_in_sign": round(_degree_in_sign(longitude), 2),
            "degree_display": _format_dms(_degree_in_sign(longitude)),
            "is_retrograde": is_retrograde,
        })

    return transits
