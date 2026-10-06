"""
Birth chart calculation using Swiss Ephemeris.

Computes real planetary positions, house cusps, zodiac placements,
nakshatras, and the Big 3 (Sun / Moon / Ascendant) for a given
birth date, time, and location.
"""

import math
from collections import OrderedDict
from datetime import datetime, timezone
from typing import Optional

import swisseph as swe
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
from timezonefinder import TimezoneFinder
from zoneinfo import ZoneInfo

from logger import get_logger
from data.zodiac_data import ZODIAC_SIGNS, ZODIAC_SYMBOLS
from data.astro_constants import PLANET_IDS, PLANET_SYMBOLS, NAKSHATRAS, NAKSHATRA_LORDS, VEDIC_GRAHAS

logger = get_logger(__name__)

# Use built-in ephemeris (no external data files needed)
swe.set_ephe_path("")

# Geocoder (lazy singleton) + rate-limited call + place→coords cache
_geocoder: Optional[Nominatim] = None
_geocode_fn = None  # RateLimiter-wrapped geocode callable (Nominatim ToS: ≤1 req/s)
# Keys are caller-supplied place strings, so the cache must be bounded.
_GEOCODE_CACHE_MAX = 2048
_geocode_cache: OrderedDict[str, tuple[float, float]] = OrderedDict()
_tz_finder: Optional[TimezoneFinder] = None


def _get_geocode_fn():
    global _geocoder, _geocode_fn
    if _geocode_fn is None:
        _geocoder = Nominatim(user_agent="cosmicguide-astro")
        _geocode_fn = RateLimiter(_geocoder.geocode, min_delay_seconds=1.0)
    return _geocode_fn


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


def parse_birth_time(birth_time: Optional[str]) -> Optional[tuple[int, int]]:
    """Parse "HH:MM" into (hour, minute), or None when unusable.

    None means *no usable birth time*, which is different from midnight. The
    caller must then cast the chart at the 12:00 default AND report the
    ascendant as estimated — a blank, malformed or out-of-range time must never
    yield a house cusp presented as exact.
    """
    if not birth_time:
        return None
    parts = str(birth_time).strip().split(":")
    if len(parts) < 2:
        logger.warning("Unusable birth_time %r — treating as absent", birth_time)
        return None
    try:
        hour, minute = int(parts[0]), int(parts[1])
    except ValueError:
        logger.warning("Unusable birth_time %r — treating as absent", birth_time)
        return None
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        logger.warning("Out-of-range birth_time %r — treating as absent", birth_time)
        return None
    return hour, minute


def geocode_place(place: str) -> Optional[tuple[float, float]]:
    """Return (latitude, longitude) for a place name, or None.

    Successful lookups are cached (the same place is re-resolved many times per
    request); cache misses are throttled to Nominatim's 1 req/s ToS limit.
    """
    if not place:
        return None
    key = place.strip().lower()
    cached = _geocode_cache.get(key)
    if cached is not None:
        _geocode_cache.move_to_end(key)
        return cached
    try:
        location = _get_geocode_fn()(place, timeout=10)
        if location:
            coords = (location.latitude, location.longitude)
            _geocode_cache[key] = coords   # cache successes only — transient failures retry
            while len(_geocode_cache) > _GEOCODE_CACHE_MAX:
                _geocode_cache.popitem(last=False)   # evict least-recently-used
            return coords
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
    sidereal: bool = False,
) -> dict:
    """
    Calculate a full birth chart.

    Args:
        birth_date: "YYYY-MM-DD"
        birth_time: "HH:MM" (24h). Defaults to 12:00 if not provided.
        birth_place: City/place name. Defaults to 0°N 0°E if not provided.
        sidereal: When True, produces a Vedic (Jyotish) chart using the
            sidereal zodiac with Lahiri ayanamsa, the nine grahas
            (Sun–Saturn + Rahu/Ketu, no outer planets), and whole-sign
            houses. When False, produces a tropical (Western) chart.

    Returns:
        Dict with planets, houses, big3, nakshatras, aspects, etc.
    """
    # Parse birth date
    try:
        bd = datetime.strptime(birth_date, "%Y-%m-%d")
    except ValueError:
        raise ValueError(f"Invalid birth_date format: {birth_date}. Use YYYY-MM-DD.")

    # Parse birth time. An unusable value is treated as absent, so the chart is
    # cast at noon and the ascendant is reported as an estimate.
    parsed_time = parse_birth_time(birth_time)
    hour, minute = parsed_time if parsed_time else (12, 0)

    # Geocode birth place
    lat, lon = 0.0, 0.0
    tz_name = "UTC"
    geocoded = False
    if birth_place:
        coords = geocode_place(birth_place)
        if coords:
            lat, lon = coords
            tz_name = _get_timezone(lat, lon)
            geocoded = True
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

    # Sidereal (Vedic) mode uses the Lahiri ayanamsa — the Indian government
    # standard for Jyotish. The FLG_SIDEREAL flag then shifts every longitude
    # from the tropical to the sidereal zodiac.
    calc_flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    if sidereal:
        swe.set_sid_mode(swe.SIDM_LAHIRI, 0, 0)
        calc_flags |= swe.FLG_SIDEREAL

    logger.info(
        "Calculating %s birth chart: date=%s time=%s place=%s lat=%.4f lon=%.4f jd=%.6f",
        "sidereal (Vedic)" if sidereal else "tropical",
        birth_date, birth_time or "12:00", birth_place or "N/A", lat, lon, jd,
    )

    # ── Calculate planetary positions ────────────────────────────────────────
    # Vedic charts use the seven visible grahas; the two lunar nodes (Rahu/Ketu)
    # are added below. Western charts additionally include the outer planets.
    planet_ids = (
        {name: PLANET_IDS[name] for name in VEDIC_GRAHAS}
        if sidereal
        else PLANET_IDS
    )

    planets = []
    for name, planet_id in planet_ids.items():
        result, _flags = swe.calc_ut(jd, planet_id, calc_flags)
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

    # ── Lunar nodes: Rahu (North) & Ketu (South) — mandatory in Jyotish ───────
    if sidereal:
        node_res, _ = swe.calc_ut(jd, swe.MEAN_NODE, calc_flags)
        rahu_lon = node_res[0] % 360
        ketu_lon = (rahu_lon + 180) % 360
        for node_name, node_lon in (("Rahu", rahu_lon), ("Ketu", ketu_lon)):
            deg_in_sign = _degree_in_sign(node_lon)
            planets.append({
                "name": node_name,
                "symbol": PLANET_SYMBOLS[node_name],
                "longitude": round(node_lon, 4),
                "latitude": 0.0,
                "speed": round(node_res[3], 4),
                "sign": _sign_from_longitude(node_lon),
                "sign_symbol": _sign_symbol_from_longitude(node_lon),
                "degree_in_sign": round(deg_in_sign, 2),
                "degree_display": _format_dms(deg_in_sign),
                "is_retrograde": True,  # nodes are always retrograde
            })

    # ── Calculate houses ─────────────────────────────────────────────────────
    # Houses/ascendant need both a birth time and successfully geocoded
    # coordinates. A place that failed to geocode leaves lat/lon at 0°N 0°E,
    # which would otherwise yield a bogus (but real-looking) ascendant.
    # A blank or unusable birth time counts as absent: the chart is then cast at
    # the 12:00 default, so the ascendant is an estimate and must say so.
    has_houses = parsed_time is not None and geocoded
    houses = []
    ascendant_lon = None

    if sidereal:
        # Vedic rasi chart: whole-sign houses. The ascendant's entire sign is
        # the 1st house (0°–30°), the next sign the 2nd, and so on.
        if has_houses:
            try:
                _cusps, ascmc = swe.houses_ex(jd, lat, lon, b'W', swe.FLG_SIDEREAL)
                ascendant_lon = ascmc[0]
                mc_lon = ascmc[1]
            except Exception as e:
                logger.warning("Sidereal houses failed (%s); estimating from Moon", e)
                has_houses = False

        if not has_houses:
            # Without an accurate birth time the Lagna cannot be fixed; fall
            # back to the sidereal Moon's sign (Chandra Lagna) as a proxy.
            moon_lon = next(p["longitude"] for p in planets if p["name"] == "Moon")
            ascendant_lon = float((int(moon_lon / 30) % 12) * 30)
            mc_lon = (ascendant_lon + 270) % 360

        asc_sign_index = int(ascendant_lon / 30) % 12
        for i in range(12):
            cusp_lon = float(((asc_sign_index + i) % 12) * 30)
            houses.append({
                "house": i + 1,
                "cusp_longitude": round(cusp_lon, 4),
                "sign": _sign_from_longitude(cusp_lon),
                "degree_in_sign": 0.0,
                "degree_display": _format_dms(0.0),
            })
    elif has_houses:
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

    # ── Moon nakshatra (always sidereal) ──────────────────────────────────
    # Nakshatras are defined on the sidereal zodiac. The Vedic path already
    # produced a sidereal Moon; for the tropical (Western) path we subtract the
    # Lahiri ayanamsa so the nakshatra is astronomically correct.
    if sidereal:
        moon_sidereal_lon = moon_data["longitude"]
    else:
        swe.set_sid_mode(swe.SIDM_LAHIRI, 0, 0)
        moon_sidereal_lon = (moon_data["longitude"] - swe.get_ayanamsa_ut(jd)) % 360
    moon_nakshatra = _nakshatra_from_longitude(moon_sidereal_lon)

    # ── Aspects ──────────────────────────────────────────────────────────────
    aspects = _calculate_aspects(planets)

    # ── Build response ───────────────────────────────────────────────────────
    chart = {
        "birth_info": {
            "date": birth_date,
            "time": birth_time if parsed_time else "12:00 (default)",
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

def calculate_current_transits(sidereal: bool = False, when: Optional[datetime] = None) -> list[dict]:
    """Calculate planetary positions for ``when`` (defaults to now) — i.e. the
    transits for a given day.

    When ``sidereal`` is True the positions use the Lahiri ayanamsa so the
    reported signs match a Vedic (Jyotish) reading; otherwise they are tropical.
    """
    now = when or datetime.now(timezone.utc)
    jd = _to_julian_day(now)

    calc_flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    if sidereal:
        swe.set_sid_mode(swe.SIDM_LAHIRI, 0, 0)
        calc_flags |= swe.FLG_SIDEREAL

    # Vedic uses the seven grahas + the lunar nodes; Western adds the outer planets.
    planet_ids = (
        {name: PLANET_IDS[name] for name in VEDIC_GRAHAS}
        if sidereal
        else PLANET_IDS
    )

    transits = []
    for name, planet_id in planet_ids.items():
        result, _flags = swe.calc_ut(jd, planet_id, calc_flags)
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

    if sidereal:
        node_res, _ = swe.calc_ut(jd, swe.MEAN_NODE, calc_flags)
        rahu_lon = node_res[0] % 360
        ketu_lon = (rahu_lon + 180) % 360
        for node_name, node_lon in (("Rahu", rahu_lon), ("Ketu", ketu_lon)):
            transits.append({
                "name": node_name,
                "symbol": PLANET_SYMBOLS[node_name],
                "longitude": round(node_lon, 4),
                "sign": _sign_from_longitude(node_lon),
                "degree_in_sign": round(_degree_in_sign(node_lon), 2),
                "degree_display": _format_dms(_degree_in_sign(node_lon)),
                "is_retrograde": True,  # nodes are always retrograde
            })

    return transits


def calculate_transit_aspects_to_natal(
    natal_planets: list[dict], transit_planets: list[dict]
) -> list[dict]:
    """Aspects today's transiting planets make to the natal planets.

    This is the transit-to-natal synthesis a real astrologer reads (e.g. a
    transiting Saturn square the natal Sun). It reuses the same major aspects
    and orbs as natal aspects. The angular separation is ayanamsa-invariant, so
    the result is valid as long as both sets share the same zodiac (both
    tropical or both sidereal). Returned tightest-orb first.
    """
    aspects: list[dict] = []
    for t in transit_planets:
        for n in natal_planets:
            diff = abs(t["longitude"] - n["longitude"]) % 360
            if diff > 180:
                diff = 360 - diff
            for aspect_name, (exact_angle, orb) in ASPECT_TYPES.items():
                delta = abs(diff - exact_angle)
                if delta <= orb:
                    aspects.append({
                        "transit_planet": t["name"],
                        "natal_planet": n["name"],
                        "aspect": aspect_name,
                        "orb": round(delta, 2),
                        "transit_sign": t["sign"],
                        "natal_sign": n["sign"],
                        "is_retrograde": t.get("is_retrograde", False),
                    })
                    break
    aspects.sort(key=lambda a: a["orb"])
    return aspects


# ── Day-favorability score ─────────────────────────────────────────────

# How each major aspect colours the day. Conjunctions are neutral here and
# resolved by the transiting planet's nature below.
_ASPECT_POINTS = {
    "Trine": 7.0,
    "Sextile": 5.0,
    "Square": -7.0,
    "Opposition": -6.0,
}
_CONJUNCTION_POINTS = {"benefic": 6.0, "malefic": -3.0, "neutral": 2.0}
_BENEFICS = {"Jupiter", "Venus"}
_MALEFICS = {"Saturn", "Mars"}
# Prominence of a body: luminaries and the slow karmic planets move the needle
# more than the personal/outer planets. Used for both ends of an aspect.
_PLANET_WEIGHT = {
    "Sun": 1.3, "Moon": 1.3,
    "Jupiter": 1.1, "Saturn": 1.1,
    "Mercury": 1.0, "Venus": 1.0, "Mars": 1.0,
}
_DEFAULT_WEIGHT = 0.85  # Uranus, Neptune, Pluto, Rahu, Ketu, etc.


def _aspect_contribution(a: dict) -> float:
    """Signed weight one transit-to-natal aspect adds to the day score."""
    aspect = a.get("aspect")
    if aspect == "Conjunction":
        planet = a.get("transit_planet")
        nature = "benefic" if planet in _BENEFICS else "malefic" if planet in _MALEFICS else "neutral"
        base = _CONJUNCTION_POINTS[nature]
    else:
        base = _ASPECT_POINTS.get(aspect)
        if base is None:
            return 0.0

    tightness = max(0.0, 1.0 - a.get("orb", 0.0) / 8.0)
    weight = (
        _PLANET_WEIGHT.get(a.get("transit_planet"), _DEFAULT_WEIGHT)
        + _PLANET_WEIGHT.get(a.get("natal_planet"), _DEFAULT_WEIGHT)
    ) / 2.0
    contribution = base * weight * (0.4 + 0.6 * tightness)
    if a.get("is_retrograde") and contribution < 0:
        contribution *= 1.1  # a retrograde transit intensifies a hard contact
    return contribution


def _score_from_net(net: float) -> int:
    """Squash the summed contributions into a bounded percentage."""
    return max(45, min(97, round(72 + 22 * math.tanh(net / 16.0))))


def score_transit_aspects(transit_aspects: list[dict]) -> Optional[int]:
    """Derive a deterministic day-favorability score (a percentage) from the
    transit-to-natal aspects instead of leaving it to an LLM guess.

    Harmonious aspects (trine, sextile, benefic conjunction) raise the score;
    hard aspects (square, opposition, malefic conjunction) lower it — each
    weighted by how tight the orb is and how prominent the two bodies are. The
    running total is squashed through ``tanh`` so the score varies meaningfully
    around a neutral baseline without ever reaching alarming extremes. Returns
    None when there is nothing to score so the caller can fall back.
    """
    if not transit_aspects:
        return None
    return _score_from_net(sum(_aspect_contribution(a) for a in transit_aspects))


# Qualitative bands for the score (which is clamped to 45–97).
_SCORE_BANDS = ((85, "Excellent"), (72, "Favorable"), (62, "Steady"), (52, "Mixed"), (0, "Challenging"))


def band_for_score(score: int) -> str:
    """Map a numeric day score to a human label."""
    for threshold, label in _SCORE_BANDS:
        if score >= threshold:
            return label
    return "Challenging"


# How each aspect reads as a short phrase in the day summary.
_ASPECT_PHRASE = {
    "Trine": "trine to",
    "Sextile": "sextile to",
    "Conjunction": "conjunction with",
    "Square": "square to",
    "Opposition": "opposition to",
}


def _aspect_phrase(a: dict) -> str:
    """A readable phrase for one aspect, e.g. "Venus's trine to your Moon"."""
    verb = _ASPECT_PHRASE.get(a.get("aspect"), "aspect to")
    retro = " retrograde" if a.get("is_retrograde") else ""
    return f"{a['transit_planet']}'s{retro} {verb} your {a['natal_planet']}"


def _cap(text: str) -> str:
    return text[0].upper() + text[1:] if text else text


def _compose_summary(supports: list[str], challenges: list[str]) -> str:
    """One-line, plain-language "why" for the day from its top drivers."""
    if supports and challenges:
        return f"{_cap(supports[0])} lifts the day, while {challenges[0]} asks for patience."
    if supports:
        extra = f" and {supports[1]}" if len(supports) > 1 else ""
        return f"{_cap(supports[0])}{extra} keeps the day flowing."
    if challenges:
        extra = f" and {challenges[1]}" if len(challenges) > 1 else ""
        return f"{_cap(challenges[0])}{extra} brings some friction — pace yourself."
    return "A calm day with no strong transits to your chart."


def describe_day(transit_aspects: list[dict]) -> Optional[dict]:
    """Full day read: the score, its band label, a one-line "why", and the top
    supportive/challenging transit phrases. Returns None with nothing to score.
    """
    if not transit_aspects:
        return None

    scored = [(a, _aspect_contribution(a)) for a in transit_aspects]
    scored = [(a, c) for a, c in scored if c != 0.0]
    if not scored:
        return None

    score = _score_from_net(sum(c for _, c in scored))
    supports = [_aspect_phrase(a) for a, c in sorted(scored, key=lambda x: x[1], reverse=True) if c > 0][:2]
    challenges = [_aspect_phrase(a) for a, c in sorted(scored, key=lambda x: x[1]) if c < 0][:2]
    return {
        "score": score,
        "band": band_for_score(score),
        "summary": _compose_summary(supports, challenges),
        "supports": supports,
        "challenges": challenges,
    }
