"""Vedic home summary service for the Vedic hub screen."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import swisseph as swe

from data.astro_constants import NAKSHATRAS, NAKSHATRA_LORDS
from data.mock.vedic_content_data import VEDIC_CONTENT
from data.vedic_reference import (
    DASHA_SEQUENCE,
    DASHA_YEARS,
    FESTIVAL_DATES,
    HINDU_MONTH_WINDOWS,
    KARANA_FIXED,
    KARANA_SEQUENCE,
    MUHURTA_LABELS,
    PLANET_FASTING_DAYS,
    PLANET_GEMSTONES,
    PLANET_MANTRAS,
    RASHI_NAMES,
    TITHI_NAMES,
    VARA_NAMES,
    VARA_RULERS,
    YOGA_NAMES,
)
from logger import get_logger
from services.birth_chart_service import calculate_birth_chart, geocode_place

logger = get_logger(__name__)

swe.set_ephe_path("")
swe.set_sid_mode(swe.SIDM_LAHIRI)

_PLANET_IDS = {
    "Sun": swe.SUN,
    "Moon": swe.MOON,
    "Mars": swe.MARS,
    "Mercury": swe.MERCURY,
    "Jupiter": swe.JUPITER,
    "Venus": swe.VENUS,
    "Saturn": swe.SATURN,
}


def _to_julian_day(dt_utc: datetime) -> float:
    hour_decimal = dt_utc.hour + dt_utc.minute / 60.0 + dt_utc.second / 3600.0
    return swe.julday(dt_utc.year, dt_utc.month, dt_utc.day, hour_decimal)


def _timezone_name(place: str | None) -> str:
    if not place:
        return "Asia/Kolkata"
    coords = geocode_place(place)
    if not coords:
        return "Asia/Kolkata"
    try:
        from services.birth_chart_service import _get_timezone  # noqa: PLC0415

        return _get_timezone(coords[0], coords[1])
    except Exception:
        return "Asia/Kolkata"


def _birth_jd(birth_date: str, birth_time: str | None, birth_place: str | None) -> float:
    bd = datetime.strptime(birth_date, "%Y-%m-%d")
    hour = 12
    minute = 0
    if birth_time:
        try:
            parts = birth_time.split(":")
            hour = int(parts[0])
            minute = int(parts[1])
        except (ValueError, IndexError):
            logger.warning("Invalid birth_time '%s', using 12:00", birth_time)
    tz_name = _timezone_name(birth_place)
    local_dt = datetime(bd.year, bd.month, bd.day, hour, minute, tzinfo=ZoneInfo(tz_name))
    return _to_julian_day(local_dt.astimezone(ZoneInfo("UTC")))


def _daily_jd(target_date: date, tz_name: str) -> float:
    local_dt = datetime(target_date.year, target_date.month, target_date.day, 12, 0, tzinfo=ZoneInfo(tz_name))
    return _to_julian_day(local_dt.astimezone(ZoneInfo("UTC")))


def _sidereal_longitude(jd: float, planet_id: int) -> float:
    result, _ = swe.calc_ut(jd, planet_id, swe.FLG_SIDEREAL)
    return result[0] % 360


def _rashi_name_from_longitude(longitude: float) -> str:
    return RASHI_NAMES[int(longitude / 30) % 12]


def _nakshatra_from_longitude(longitude: float) -> dict:
    index = int(longitude / (360 / 27)) % 27
    pada = int((longitude % (360 / 27)) / (360 / 108)) + 1
    return {
        "name": NAKSHATRAS[index],
        "pada": min(pada, 4),
        "lord": NAKSHATRA_LORDS[index],
        "index": index,
    }


def _karana_name(lunar_phase_deg: float) -> str:
    karana_index = int(lunar_phase_deg / 6) + 1
    if karana_index in KARANA_FIXED:
        return KARANA_FIXED[karana_index]
    seq_index = (karana_index - 1) % len(KARANA_SEQUENCE)
    return KARANA_SEQUENCE[seq_index]


def _samvat_year(target_date: date) -> int:
    if target_date.month > 4 or (target_date.month == 4 and target_date.day >= 14):
        return target_date.year + 57
    return target_date.year + 56


def _hindu_month_name(target_date: date) -> str:
    current = HINDU_MONTH_WINDOWS[-1][1]
    month_day = (target_date.month, target_date.day)
    for start, name in HINDU_MONTH_WINDOWS:
        if month_day >= start:
            current = name
    return current


def _next_festival(target_date: date) -> dict:
    for item in FESTIVAL_DATES:
        fest_date = date.fromisoformat(item["date"])
        if fest_date >= target_date:
            note = VEDIC_CONTENT["festivals"].get(item["name"], "")
            return {"name": item["name"], "date": item["date"], "note": note}
    item = FESTIVAL_DATES[-1]
    return {
        "name": item["name"],
        "date": item["date"],
        "note": VEDIC_CONTENT["festivals"].get(item["name"], ""),
    }


def _abbreviate_date(iso_date: str) -> str:
    return datetime.fromisoformat(iso_date).strftime("%d %b %Y")


def _mahadasha_timeline(birth_date: str, birth_time: str | None, birth_place: str | None) -> list[dict]:
    jd = _birth_jd(birth_date, birth_time, birth_place)
    moon_lon = _sidereal_longitude(jd, swe.MOON)
    nak = _nakshatra_from_longitude(moon_lon)
    lord = nak["lord"]
    fraction_complete = (moon_lon % (360 / 27)) / (360 / 27)
    remaining_fraction = max(0.0, 1.0 - fraction_complete)

    start = datetime.strptime(birth_date, "%Y-%m-%d").date()
    timeline = []
    start_index = DASHA_SEQUENCE.index(lord)

    first_years = DASHA_YEARS[lord] * remaining_fraction
    current_start = start
    for offset in range(len(DASHA_SEQUENCE) + 3):
        active_lord = DASHA_SEQUENCE[(start_index + offset) % len(DASHA_SEQUENCE)]
        years = first_years if offset == 0 else DASHA_YEARS[active_lord]
        end = current_start + timedelta(days=int(years * 365.25))
        timeline.append(
            {
                "lord": active_lord,
                "start": current_start.isoformat(),
                "end": end.isoformat(),
            }
        )
        current_start = end
    return timeline


def _current_dasha(birth_date: str, birth_time: str | None, birth_place: str | None, target_date: date) -> dict:
    timeline = _mahadasha_timeline(birth_date, birth_time, birth_place)
    target_dt = target_date.isoformat()
    current = timeline[-1]
    for period in timeline:
        if period["start"] <= target_dt < period["end"]:
            current = period
            break

    maha_lord = current["lord"]
    maha_start = date.fromisoformat(current["start"])
    maha_end = date.fromisoformat(current["end"])
    maha_days = max(1, (maha_end - maha_start).days)
    elapsed_days = max(0, (target_date - maha_start).days)

    sub_periods = []
    cursor = maha_start
    for sub_lord in DASHA_SEQUENCE:
        sub_days = max(1, int(maha_days * (DASHA_YEARS[sub_lord] / 120.0)))
        sub_end = cursor + timedelta(days=sub_days)
        sub_periods.append(
            {"lord": sub_lord, "start": cursor.isoformat(), "end": sub_end.isoformat()}
        )
        cursor = sub_end

    active_sub = sub_periods[-1]
    for sub in sub_periods:
        if sub["start"] <= target_dt < sub["end"]:
            active_sub = sub
            break

    guidance = VEDIC_CONTENT["dasha_lords"].get(maha_lord, "")
    return {
        "mahadasha": maha_lord,
        "mahadasha_ends_on": current["end"],
        "antardasha": active_sub["lord"],
        "guidance": guidance,
    }


def _count_house(chart: dict, planet_name: str) -> int | None:
    if not chart.get("houses"):
        return None
    planet = next((item for item in chart["planets"] if item["name"] == planet_name), None)
    if not planet:
        return None
    planet_lon = planet["longitude"]
    cusps = [item["cusp_longitude"] for item in chart["houses"]]
    for index in range(12):
        start = cusps[index]
        end = cusps[(index + 1) % 12]
        if start <= end:
            if start <= planet_lon < end:
                return index + 1
        else:
            if planet_lon >= start or planet_lon < end:
                return index + 1
    return 1


def _detect_doshas(chart: dict, birth_date: str, birth_time: str | None, birth_place: str | None) -> list[str]:
    active = []
    mars_house = _count_house(chart, "Mars")
    if mars_house in (1, 2, 4, 7, 8, 12):
        active.append("Manglik Dosha")

    jd_birth = _birth_jd(birth_date, birth_time, birth_place)
    moon_lon = _sidereal_longitude(jd_birth, swe.MOON)
    moon_sign = int(moon_lon / 30) % 12

    jd_now = _daily_jd(date.today(), _timezone_name(birth_place))
    saturn_lon = _sidereal_longitude(jd_now, swe.SATURN)
    saturn_sign = int(saturn_lon / 30) % 12
    diff = (saturn_sign - moon_sign) % 12
    if diff in (11, 0, 1):
        active.append("Sade Sati")

    rahu_lon = _sidereal_longitude(jd_birth, swe.TRUE_NODE)
    ketu_lon = (rahu_lon + 180) % 360
    seven = [
        _sidereal_longitude(jd_birth, _PLANET_IDS[name])
        for name in ("Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn")
    ]
    clockwise_span = [value for value in seven if (value - rahu_lon) % 360 <= 180]
    if len(clockwise_span) == len(seven) or len(clockwise_span) == 0:
        active.append("Kaal Sarp Dosha")
    _ = ketu_lon

    return active


def _remedy_summary(dasha: dict, doshas: list[str]) -> dict:
    focus = doshas[0] if doshas else dasha["mahadasha"]
    remedy_lord = "Mars" if focus == "Manglik Dosha" else dasha["mahadasha"]
    return {
        "focus": focus,
        "gemstone": PLANET_GEMSTONES.get(remedy_lord, "Pearl"),
        "mantra": PLANET_MANTRAS.get(remedy_lord, "Om Namah Shivaya"),
        "fasting_day": PLANET_FASTING_DAYS.get(remedy_lord, "Monday"),
        "guidance": VEDIC_CONTENT["remedies"].get(focus, VEDIC_CONTENT["remedies"]["default"]),
    }


def _muhurta_summary(target_date: date) -> dict:
    start = datetime(target_date.year, target_date.month, target_date.day, 12, 6)
    end = start + timedelta(minutes=48)
    return {
        "label": MUHURTA_LABELS["abhijit"],
        "starts_at": start.strftime("%I:%M %p"),
        "ends_at": end.strftime("%I:%M %p"),
        "note": VEDIC_CONTENT["muhurta"]["default"],
    }


def get_vedic_home_summary(
    target_date: str | None = None,
    birth_date: str | None = None,
    birth_time: str | None = None,
    birth_place: str | None = None,
) -> dict:
    today = date.fromisoformat(target_date) if target_date else date.today()
    location_name = birth_place or "India"
    coords = geocode_place(location_name) or (20.5937, 78.9629)
    tz_name = _timezone_name(location_name)
    jd_today = _daily_jd(today, tz_name)

    sun_lon = _sidereal_longitude(jd_today, swe.SUN)
    moon_lon = _sidereal_longitude(jd_today, swe.MOON)
    lunar_phase = (moon_lon - sun_lon) % 360

    tithi_index = int(lunar_phase / 12) % 30
    yoga_index = int(((sun_lon + moon_lon) % 360) / (360 / 27)) % 27
    nak = _nakshatra_from_longitude(moon_lon)

    weekday_index = today.weekday()
    panchang = {
        "date": today.isoformat(),
        "vara": VARA_NAMES[weekday_index],
        "vara_ruler": VARA_RULERS[weekday_index],
        "tithi": TITHI_NAMES[tithi_index],
        "paksha": "Shukla" if tithi_index < 15 else "Krishna",
        "nakshatra": nak["name"],
        "yoga": YOGA_NAMES[yoga_index],
        "karana": _karana_name(lunar_phase),
        "insight": VEDIC_CONTENT["panchang"]["default"],
    }

    result = {
        "location": {
            "name": location_name,
            "latitude": round(coords[0], 4),
            "longitude": round(coords[1], 4),
            "timezone": tz_name,
        },
        "panchang": panchang,
        "calendar": {
            "month_name": _hindu_month_name(today),
            "samvat_year": _samvat_year(today),
            "next_festival_name": _next_festival(today)["name"],
            "next_festival_date": _abbreviate_date(_next_festival(today)["date"]),
            "note": _next_festival(today)["note"],
        },
        "muhurta": _muhurta_summary(today),
        "kundli": None,
        "dasha": None,
        "dosha": None,
        "remedy": None,
    }

    if not birth_date:
        return result

    chart = calculate_birth_chart(birth_date=birth_date, birth_time=birth_time, birth_place=birth_place)
    jd_birth = _birth_jd(birth_date, birth_time, birth_place)
    ayanamsha = swe.get_ayanamsa_ut(jd_birth)
    sidereal_asc = (chart["ascendant"]["longitude"] - ayanamsha) % 360
    sidereal_moon = _sidereal_longitude(jd_birth, swe.MOON)
    birth_nak = _nakshatra_from_longitude(sidereal_moon)

    kundli = {
        "lagna": _rashi_name_from_longitude(sidereal_asc),
        "moon_sign": _rashi_name_from_longitude(sidereal_moon),
        "nakshatra": birth_nak["name"],
        "note": "Birth time missing, houses may be estimated." if not birth_time else "Chart summary ready.",
    }

    dasha = _current_dasha(birth_date, birth_time, birth_place, today)
    active_doshas = _detect_doshas(chart, birth_date, birth_time, birth_place)
    dosha_summary = {
        "active_count": len(active_doshas),
        "top_doshas": active_doshas[:2],
        "summary": VEDIC_CONTENT["doshas"]["clear"] if not active_doshas else VEDIC_CONTENT["doshas"].get(active_doshas[0], VEDIC_CONTENT["doshas"]["clear"]),
    }
    remedy = _remedy_summary(dasha, active_doshas)

    result.update({
        "kundli": kundli,
        "dasha": dasha,
        "dosha": dosha_summary,
        "remedy": remedy,
    })
    return result
