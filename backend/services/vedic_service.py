"""Vedic home summary service for the Vedic hub screen."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import swisseph as swe

from data.astro_constants import NAKSHATRAS, NAKSHATRA_LORDS
from data.zodiac_data import ZODIAC_SIGNS
from data.mock.vedic_content_data import VEDIC_CONTENT
from data.vedic_reference import (
    DASHA_SEQUENCE,
    DASHA_YEARS,
    FESTIVAL_DATES,
    GULIKA_OCTANT,
    HINDU_MONTH_WINDOWS,
    KARANA_FIXED,
    KARANA_SEQUENCE,
    MUHURTA_LABELS,
    PAKSHA_TONE,
    PLANET_FASTING_DAYS,
    PLANET_GEMSTONES,
    PLANET_MANTRAS,
    RAHU_KAAL_OCTANT,
    TITHI_NAMES,
    VARA_NAMES,
    VARA_RULERS,
    VARA_TONE,
    YAMAGANDA_OCTANT,
    YOGA_NAMES,
)
from logger import get_logger
from services.birth_chart_service import calculate_birth_chart, geocode_place, parse_birth_time

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


def _timezone_name(place: str | None, default: str = "Asia/Kolkata") -> str:
    if not place:
        return default
    coords = geocode_place(place)
    if not coords:
        return default
    try:
        from services.birth_chart_service import _get_timezone  # noqa: PLC0415

        return _get_timezone(coords[0], coords[1])
    except Exception:
        return default


def _birth_jd(birth_date: str, birth_time: str | None, birth_place: str | None) -> float:
    bd = datetime.strptime(birth_date, "%Y-%m-%d")
    # Shares calculate_birth_chart's parser so both agree on what "no usable
    # birth time" means (and neither crashes on e.g. "25:99").
    hour, minute = parse_birth_time(birth_time) or (12, 0)
    # Must resolve exactly like calculate_birth_chart, which falls back to UTC
    # when the birth place is missing or un-geocodable. Defaulting to IST here
    # instead shifted the birth Moon by 5.5h, so the Dasha could be derived from
    # a different nakshatra than the Kundli shown beside it in the same response.
    tz_name = _timezone_name(birth_place, default="UTC")
    local_dt = datetime(bd.year, bd.month, bd.day, hour, minute, tzinfo=ZoneInfo(tz_name))
    return _to_julian_day(local_dt.astimezone(ZoneInfo("UTC")))


def _daily_jd(target_date: date, tz_name: str) -> float:
    local_dt = datetime(target_date.year, target_date.month, target_date.day, 12, 0, tzinfo=ZoneInfo(tz_name))
    return _to_julian_day(local_dt.astimezone(ZoneInfo("UTC")))


def _jd_to_local(jd: float, tz_name: str) -> datetime:
    """Convert a Julian Day (UT) to a timezone-aware local datetime."""
    year, month, day, hour = swe.revjul(jd)
    base_utc = datetime(year, month, day, tzinfo=ZoneInfo("UTC")) + timedelta(hours=hour)
    return base_utc.astimezone(ZoneInfo(tz_name))


def _sun_rise_set(target_date: date, lat: float, lon: float, tz_name: str) -> tuple[float | None, float | None]:
    """Real sunrise/sunset (JD UT) for the local calendar day, disc-centre."""
    local_midnight = datetime(
        target_date.year, target_date.month, target_date.day, 0, 0, tzinfo=ZoneInfo(tz_name)
    )
    jd_start = _to_julian_day(local_midnight.astimezone(ZoneInfo("UTC")))
    try:
        rise_res, rise_t = swe.rise_trans(jd_start, swe.SUN, swe.CALC_RISE | swe.BIT_DISC_CENTER, (lon, lat, 0.0))
        set_res, set_t = swe.rise_trans(jd_start, swe.SUN, swe.CALC_SET | swe.BIT_DISC_CENTER, (lon, lat, 0.0))
        sunrise = rise_t[0] if rise_res == 0 else None
        sunset = set_t[0] if set_res == 0 else None
        return sunrise, sunset
    except Exception as exc:  # circumpolar or ephemeris failure
        logger.warning("Sunrise/sunset calculation failed: %s", exc)
        return None, None


def _fmt_clock(jd: float, tz_name: str) -> str:
    return _jd_to_local(jd, tz_name).strftime("%I:%M %p").lstrip("0")


def _fmt_window(start_jd: float, end_jd: float, tz_name: str) -> str:
    return f"{_fmt_clock(start_jd, tz_name)} \u2013 {_fmt_clock(end_jd, tz_name)}"


def _daily_timings(target_date: date, lat: float, lon: float, tz_name: str) -> dict:
    """Sunrise/sunset plus the auspicious and inauspicious daily windows.

    Rahu Kaal, Yamaganda and Gulika each occupy a fixed 1/8th slice of the
    daytime; Abhijit is the 8th of the 15 day-muhurtas (straddling solar noon);
    Brahma Muhurta is the 96→48 minute window before sunrise.
    """
    sunrise, sunset = _sun_rise_set(target_date, lat, lon, tz_name)
    if sunrise is None or sunset is None:
        return {
            "sunrise": "—",
            "sunset": "—",
            "day_length": "—",
            "abhijit": "—",
            "brahma_muhurta": "—",
            "rahu_kaal": "—",
            "yamaganda": "—",
            "gulika": "—",
        }

    day_span = sunset - sunrise          # in days (JD units)
    octant = day_span / 8.0
    muhurta = day_span / 15.0
    weekday = target_date.weekday()

    def _kaal(octant_map: dict) -> str:
        part = octant_map[weekday]
        return _fmt_window(sunrise + (part - 1) * octant, sunrise + part * octant, tz_name)

    total_minutes = int(round(day_span * 24 * 60))
    hours, minutes = divmod(total_minutes, 60)

    return {
        "sunrise": _fmt_clock(sunrise, tz_name),
        "sunset": _fmt_clock(sunset, tz_name),
        "day_length": f"{hours}h {minutes:02d}m",
        "abhijit": _fmt_window(sunrise + 7 * muhurta, sunrise + 8 * muhurta, tz_name),
        "brahma_muhurta": _fmt_window(sunrise - 96 / 1440.0, sunrise - 48 / 1440.0, tz_name),
        "rahu_kaal": _kaal(RAHU_KAAL_OCTANT),
        "yamaganda": _kaal(YAMAGANDA_OCTANT),
        "gulika": _kaal(GULIKA_OCTANT),
    }


def _panchang_insight(vara_ruler: str, paksha: str) -> str:
    """A relevant, day-specific Panchang insight (varies by ruler + paksha)."""
    tone = VARA_TONE.get(vara_ruler, "steady, mindful effort")
    phase = PAKSHA_TONE.get(paksha, "")
    return f"Ruled by {vara_ruler}, today leans toward {tone}. {phase}".strip()


def _sidereal_longitude(jd: float, planet_id: int) -> float:
    result, _ = swe.calc_ut(jd, planet_id, swe.FLG_SIDEREAL)
    return result[0] % 360


def _sign_name_from_longitude(longitude: float) -> str:
    # English sign name — the app's canonical label (used by /chart, the sign
    # resolver, and the horoscope prompt). Keeps /vedic and /chart consistent.
    return ZODIAC_SIGNS[int(longitude / 30) % 12]


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
    seq_index = (karana_index - 2) % len(KARANA_SEQUENCE)
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


def _next_festival(target_date: date) -> dict | None:
    for item in FESTIVAL_DATES:
        fest_date = date.fromisoformat(item["date"])
        if fest_date >= target_date:
            note = VEDIC_CONTENT["festivals"].get(item["name"], "")
            return {"name": item["name"], "date": item["date"], "note": note}
    # All hard-coded festival dates are in the past — signal staleness rather than
    # silently returning a past date (the list needs refreshing / a Panchang engine).
    return None


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

    # Antardashas run in the standard order but starting from the mahadasha lord.
    maha_index = DASHA_SEQUENCE.index(maha_lord)
    sub_order = [DASHA_SEQUENCE[(maha_index + i) % len(DASHA_SEQUENCE)]
                 for i in range(len(DASHA_SEQUENCE))]
    sub_periods = []
    cursor = maha_start
    for sub_lord in sub_order:
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

    rahu_lon = _sidereal_longitude(jd_birth, swe.MEAN_NODE)  # mean node — consistent with birth_chart_service
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


def _muhurta_summary(target_date: date, lat: float, lon: float, tz_name: str) -> dict:
    """Abhijit Muhurta — the 8th of the 15 day-muhurtas, centred on solar noon."""
    sunrise, sunset = _sun_rise_set(target_date, lat, lon, tz_name)
    if sunrise is None or sunset is None:
        start = datetime(target_date.year, target_date.month, target_date.day, 12, 6)
        end = start + timedelta(minutes=48)
        starts_at = start.strftime("%I:%M %p").lstrip("0")
        ends_at = end.strftime("%I:%M %p").lstrip("0")
    else:
        muhurta = (sunset - sunrise) / 15.0
        starts_at = _fmt_clock(sunrise + 7 * muhurta, tz_name)
        ends_at = _fmt_clock(sunrise + 8 * muhurta, tz_name)

    if target_date.weekday() == 2:  # Wednesday
        note = (
            "Abhijit straddles solar noon and is the day's most dependable window — "
            "though tradition sets it aside on Wednesdays."
        )
    else:
        note = VEDIC_CONTENT["muhurta"]["default"]

    return {
        "label": MUHURTA_LABELS["abhijit"],
        "starts_at": starts_at,
        "ends_at": ends_at,
        "note": note,
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
    lat, lon = coords
    tz_name = _timezone_name(location_name)

    # Panchang is traditionally reckoned from sunrise; fall back to local noon
    # only if sunrise cannot be resolved (e.g. polar latitudes).
    sunrise_jd, _sunset_jd = _sun_rise_set(today, lat, lon, tz_name)
    reference_jd = sunrise_jd if sunrise_jd is not None else _daily_jd(today, tz_name)

    sun_lon = _sidereal_longitude(reference_jd, swe.SUN)
    moon_lon = _sidereal_longitude(reference_jd, swe.MOON)
    lunar_phase = (moon_lon - sun_lon) % 360

    tithi_index = int(lunar_phase / 12) % 30
    yoga_index = int(((sun_lon + moon_lon) % 360) / (360 / 27)) % 27
    nak = _nakshatra_from_longitude(moon_lon)

    weekday_index = today.weekday()
    paksha = "Shukla" if tithi_index < 15 else "Krishna"
    vara_ruler = VARA_RULERS[weekday_index]
    panchang = {
        "date": today.isoformat(),
        "vara": VARA_NAMES[weekday_index],
        "vara_ruler": vara_ruler,
        "tithi": TITHI_NAMES[tithi_index],
        "paksha": paksha,
        "nakshatra": nak["name"],
        "yoga": YOGA_NAMES[yoga_index],
        "karana": _karana_name(lunar_phase),
        "insight": _panchang_insight(vara_ruler, paksha),
    }

    fest = _next_festival(today)
    result = {
        "location": {
            "name": location_name,
            "latitude": round(lat, 4),
            "longitude": round(lon, 4),
            "timezone": tz_name,
        },
        "panchang": panchang,
        "calendar": {
            "month_name": _hindu_month_name(today),
            "samvat_year": _samvat_year(today),
            "next_festival_name": fest["name"] if fest else "To be announced",
            "next_festival_date": _abbreviate_date(fest["date"]) if fest else "",
            "note": fest["note"] if fest else "Upcoming festival dates will be updated soon.",
        },
        "muhurta": _muhurta_summary(today, lat, lon, tz_name),
        "timings": _daily_timings(today, lat, lon, tz_name),
        "kundli": None,
        "dasha": None,
        "dosha": None,
        "remedy": None,
    }

    if not birth_date:
        return result

    chart = calculate_birth_chart(
        birth_date=birth_date, birth_time=birth_time, birth_place=birth_place, sidereal=True
    )
    sidereal_asc = chart["ascendant"]["longitude"]
    sidereal_moon = next(p["longitude"] for p in chart["planets"] if p["name"] == "Moon")
    birth_nak = _nakshatra_from_longitude(sidereal_moon)

    kundli = {
        "lagna": _sign_name_from_longitude(sidereal_asc),
        "moon_sign": _sign_name_from_longitude(sidereal_moon),
        "nakshatra": birth_nak["name"],
        "note": "Birth time missing — Lagna estimated from the Moon sign." if not birth_time else "Chart summary ready.",
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
