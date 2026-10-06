# Vedic Screen Data Population Plan

This document defines how each feature on the Vedic screen should be populated, which parts are static vs dynamic, and where each piece of data should come from.

## Purpose

The Vedic hub in `mobile-app/lib/screens/vedic_home_screen.dart` should not be treated as a pure UI page. Each card should be backed by one of these data types:

1. Static reference data
2. Derived local data
3. Dynamic backend-calculated data
4. Optional editorial or AI-enhanced content

The correct split matters because Vedic features are calculation-heavy. Anything based on planetary positions, sunrise, moon phase, or house placement should come from the backend. Anything like label dictionaries, deity names, weekday names, festival descriptions, and remedy lookup tables can be static.

---

## Guiding Rule

Use this rule consistently:

- If the value changes based on date, time, location, or birth details, it is dynamic.
- If the value is a canonical mapping or lookup table, it is static.
- If the value is explanatory text layered on top of computed results, it should be data-driven first and AI-enhanced only optionally.

---

## Existing Reusable Backend

These parts already exist and should be reused instead of rebuilt:

- `backend/services/birth_chart_service.py`
  - Computes planetary positions, houses, nakshatra, ascendant, timezone lookup, geocoding, and chart primitives.
- `backend/services/kundli_service.py`
  - Computes Ashta Koota scores and Manglik detection.
- `backend/data/astro_constants.py`
  - Contains nakshatras, lords, and planet identifiers.
- `backend/data/kundli_tables.py`
  - Contains Vedic compatibility lookup tables.
- `backend/schemas.py`
  - Already has `BirthChartResponse`, `NakshatraInfo`, `PointInfo`, etc.

This means:

- `Kundli Chart`, `Dasha`, and `Doshas` should all build on the same birth-chart foundation.
- `Panchang`, `Muhurta`, and `Hindu Calendar` should share one daily calendar calculation layer.

---

## Screen-Level Data Strategy

### 1. Vedic Header
Current UI:
- Title: `Vedic Astrology`
- Samvat year

Data split:
- Static:
  - Title text
- Derived local:
  - Approximate Samvat year can be shown locally as a temporary placeholder
- Dynamic backend:
  - Final Hindu calendar year and month label should come from Panchang/Hindu calendar service, not local approximation

Recommended source:
- Temporary: local logic in Flutter is fine
- Final: `GET /panchang/daily` should return:
  - `vikram_samvat_year`
  - `hindu_month_name`
  - `paksha`
  - `tithi_name`

Recommendation:
- Keep current local Samvat display only as interim UI.
- Replace it once Panchang exists.

---

### 2. Today's Vara Card
Current UI:
- Vara name
- Planet symbol
- Day ruler

Data split:
- Static:
  - Vara names
  - Vara planet rulers
  - Planet symbols
- Derived local:
  - Current weekday from device time
- Dynamic backend:
  - None required if only weekday name is shown
  - If tied to sunrise-to-sunrise Vedic day boundaries, backend should own it

Recommended source:
- Static file in backend or shared constants:
  - `backend/data/panchang_constants.py`
- Current simple mode:
  - Flutter local `DateTime.now()` is acceptable
- Accurate mode:
  - Backend computes Vara using local sunrise boundary for user location

Recommendation:
- For MVP, local is fine.
- For production Vedic accuracy, move Vara into Panchang response.

---

## Feature-by-Feature Data Plan

### 3. Panchang
This is the primary daily Vedic feature and should drive much of the Vedic tab.

What user sees:
- Tithi
- Vara
- Nakshatra
- Yoga
- Karana
- Sunrise / Sunset / Moonrise / Moonset
- Rahu Kaal
- Yamagandam
- Gulika Kaal
- Abhijit Muhurta
- Brahma Muhurta

Data split:
- Static:
  - Tithi names and deity mapping
  - Nakshatra descriptions and lords
  - Yoga names
  - Karana names
  - Rahu Kaal weekday slot rules
  - Display labels in English and Hindi
- Dynamic:
  - Actual Tithi for date/location
  - Actual Nakshatra at sunrise or current time
  - Current Yoga and Karana
  - Sunrise, sunset, moonrise, moonset
  - Auspicious and inauspicious time slots for the selected date and place

Where data comes from:
- Dynamic source:
  - Swiss Ephemeris calculations in a new `backend/services/panchang_service.py`
- Static source:
  - New `backend/data/panchang_constants.py`
  - New `backend/data/nakshatra_reference.py` if descriptions get large

Backend input:
- date
- latitude
- longitude
- timezone

Backend response should contain:
```json
{
  "date": "2026-04-30",
  "location": {
    "name": "Mumbai",
    "latitude": 19.076,
    "longitude": 72.8777,
    "timezone": "Asia/Kolkata"
  },
  "vikram_samvat_year": 2083,
  "hindu_month_name": "Vaishakha",
  "paksha": "Shukla",
  "tithi": {
    "index": 12,
    "name": "Dwadashi",
    "ends_at": "2026-04-30T17:42:00+05:30",
    "deity": "Vishnu"
  },
  "vara": {
    "name": "Guruvaar",
    "ruler": "Jupiter",
    "symbol": "♃"
  },
  "nakshatra": {
    "name": "Rohini",
    "pada": 3,
    "lord": "Moon",
    "ends_at": "2026-04-30T14:10:00+05:30"
  },
  "yoga": {
    "name": "Sukarma",
    "ends_at": "2026-04-30T20:15:00+05:30"
  },
  "karana": {
    "name": "Bava",
    "ends_at": "2026-04-30T11:20:00+05:30"
  },
  "sun_times": {
    "sunrise": "06:10",
    "sunset": "18:51",
    "moonrise": "15:42",
    "moonset": "03:18"
  },
  "time_windows": {
    "rahu_kaal": "13:30-15:00",
    "yamagandam": "06:10-07:40",
    "gulika_kaal": "09:10-10:40",
    "abhijit_muhurta": "12:03-12:51",
    "brahma_muhurta": "04:34-05:22"
  }
}
```

Population strategy on the Vedic screen:
- Panchang banner on hub:
  - Show only summary values from the latest daily Panchang response
  - Suggested summary fields:
    - Tithi
    - Nakshatra
    - Rahu Kaal or next important slot
- Full details live on a dedicated Panchang screen

Caching:
- Cache daily by `date + lat + lon`
- Refresh automatically at local midnight or when location changes

---

### 4. Kundli Chart
What user sees:
- North Indian or South Indian chart
- Planet placements by house
- Lagna
- Moon sign
- Nakshatra

Data split:
- Static:
  - House labels
  - Rashi names and symbols
  - Planet glyphs
  - Chart style templates for North/South layouts
- Dynamic:
  - Planet longitudes
  - House cusps
  - Ascendant
  - Nakshatra and pada
  - Retrograde flags
  - Sidereal placements

Where data comes from:
- Dynamic source:
  - Extend `backend/services/birth_chart_service.py`
- Important note:
  - Current birth chart logic is using Swiss Ephemeris but appears structured more generally; Vedic chart mode must explicitly use sidereal zodiac and chosen ayanamsha
- Static source:
  - `backend/data/vedic_chart_reference.py` or reuse `astro_constants.py`

Required backend additions:
- New endpoint: `POST /chart/vedic`
- Add response fields for:
  - `ayanamsha`
  - `chart_style_supported`
  - `planets_by_house`
  - `lagna_rashi`
  - `moon_rashi`
  - `moon_nakshatra`

Population strategy:
- Hub card summary:
  - Lagna
  - Moon sign
  - Nakshatra
- Dedicated chart screen:
  - Full visual chart and table view

Data ownership:
- Backend owns all real chart data
- Flutter only handles chart rendering and toggling North/South layout

---

### 5. Dasha
What user sees:
- Current Mahadasha
- Current Antardasha
- Start/end dates
- Remaining duration
- Timeline of upcoming periods

Data split:
- Static:
  - Vimshottari order of lords
  - Dasha durations
  - Descriptions of each Dasha lord
- Dynamic:
  - Birth moon longitude
  - Birth nakshatra
  - Dasha balance at birth
  - Current active Mahadasha / Antardasha / optionally Pratyantardasha
  - Timeline based on current date

Where data comes from:
- Dynamic source:
  - New `backend/services/dasha_service.py`
  - Input should reuse `calculate_birth_chart()` for moon longitude and nakshatra
- Static source:
  - New `backend/data/dasha_constants.py`

Required backend response:
```json
{
  "birth_nakshatra": "Rohini",
  "birth_nakshatra_lord": "Moon",
  "mahadasha": {
    "lord": "Moon",
    "start": "2021-08-10",
    "end": "2031-08-10",
    "remaining_days": 1924
  },
  "antardasha": {
    "lord": "Jupiter",
    "start": "2025-11-02",
    "end": "2027-03-08"
  },
  "timeline": [
    {"level": "mahadasha", "lord": "Moon", "start": "2021-08-10", "end": "2031-08-10"},
    {"level": "mahadasha", "lord": "Mars", "start": "2031-08-10", "end": "2038-08-10"}
  ]
}
```

Population strategy:
- Hub card summary:
  - Current Mahadasha lord
  - Current Antardasha lord
  - Ends in X months
- Dedicated screen:
  - Scrollable timeline
  - Table of periods
  - Meaning cards

Recommendation:
- No AI required for core Dasha calculation.
- If you add interpretation text, do static first, AI optional later.

---

### 6. Doshas
What user sees:
- Whether key doshas are present
- Severity
- Short explanation
- Relevant remedies

Doshas in scope:
- Mangal Dosha
- Kaal Sarp Dosha
- Nadi Dosha
- Sade Sati
- Pitru Dosha

Data split:
- Static:
  - Detection rule descriptions
  - Severity labels
  - Explanatory text per dosha
  - Remedy mapping
- Dynamic:
  - Planet placements and house placements
  - Moon sign and Saturn transit for Sade Sati
  - Compatibility-specific Nadi dosha result

Where data comes from:
- Dynamic source:
  - New `backend/services/dosha_service.py`
  - Reuse `birth_chart_service.py`
  - Reuse `kundli_service.py` for Nadi result when in match context
  - For Sade Sati, add transit calculation endpoint or shared utility
- Static source:
  - New `backend/data/dosha_reference.py`

Recommended response:
```json
{
  "doshas": [
    {
      "name": "Mangal Dosha",
      "present": true,
      "severity": "moderate",
      "reason": "Mars is placed in the 7th house from Lagna.",
      "confidence": "high"
    },
    {
      "name": "Sade Sati",
      "present": false,
      "severity": null,
      "reason": "Saturn is not transiting the Moon sign or adjacent signs.",
      "confidence": "high"
    }
  ]
}
```

Population strategy:
- Hub card summary:
  - `2 active doshas` or `No major dosha detected`
- Dedicated screen:
  - List each dosha with present/absent state, reason, severity, and remedy CTA

Recommendation:
- Keep detection deterministic.
- Do not use AI to decide if a dosha exists.

---

### 7. Remedies
What user sees:
- Gemstone
- Mantra
- Fasting day
- Charity recommendation
- Colour recommendation

Data split:
- Static:
  - Planet to gemstone mapping
  - Planet to mantra mapping
  - Planet to fasting weekday mapping
  - Donation recommendations
  - Colour mappings
- Dynamic:
  - Which planet or dosha to base the remedy on
  - Current Mahadasha lord
  - Lagna lord
  - Detected doshas

Where data comes from:
- Static source:
  - New `backend/data/remedies_data.py`
- Dynamic source:
  - Remedy selector logic in new `backend/services/remedy_service.py`
  - Inputs from:
    - `chart/vedic`
    - `dasha/calculate`
    - `dosha/detect`

Population strategy:
- Hub card summary:
  - Primary remedy of the day or top 1 to 2 recommended remedies
- Dedicated screen:
  - Sections by category: gemstone, mantra, fasting, charity, colour

Important constraint:
- Remedies should be shown as traditional suggestions, not medical or guaranteed outcomes.

Recommendation:
- Static data-first approach is correct.
- AI should only rewrite tone, never invent remedies.

---

### 8. Hindu Calendar
What user sees:
- Hindu month name
- Paksha
- Tithi per day
- Festivals
- Ekadashi, Pradosh, Purnima, Amavasya

Data split:
- Static:
  - Festival descriptions
  - Festival category labels
  - Holiday stories / significance text
- Dynamic:
  - Hindu month assignment
  - Daily Tithi and Paksha
  - Monthly Ekadashi / Pradosh / Purnima / Amavasya dates
- Hybrid:
  - Festival date source depends on festival type

Where data comes from:
- Dynamic source:
  - New `backend/services/hindu_calendar_service.py`
  - Reuse Panchang logic for daily Tithi-driven festival dates
- Static source:
  - New `backend/data/festival_reference.py`

Recommended split for festivals:
- Static fixed-date festivals in Gregorian terms:
  - Republic Day, Independence Day, Christmas, etc.
- Static rule-based festivals tied to Hindu calendar:
  - Diwali, Holi, Navratri, Janmashtami, Shivratri, etc.
- Dynamic computation:
  - Actual mapped Gregorian date for each Hindu lunar festival in a given year

Population strategy:
- Hub card summary:
  - Current Hindu month + next upcoming festival
- Dedicated monthly screen:
  - Calendar grid with Tithi overlays and festival markers

Caching:
- Cache monthly by `year + month + lat + lon`

---

### 9. Muhurta
What user sees:
- Best date/time windows for a task
- Why a slot is good or bad
- Inauspicious slots excluded

Data split:
- Static:
  - Muhurta category definitions
  - Base rule weights for Tithi, Vara, Nakshatra, Yoga, Karana
  - Category-specific exclusions
- Dynamic:
  - Actual Panchang values for each candidate slot
  - Ranked windows based on location and date range
  - Exclusion of Rahu Kaal, Yamagandam, Gulika Kaal

Where data comes from:
- Dynamic source:
  - New `backend/services/muhurta_service.py`
  - Built on Panchang service outputs
- Static source:
  - New `backend/data/muhurta_rules.py`

Population strategy:
- Hub card summary:
  - `Next good muhurta: Fri 10:42–11:26`
- Dedicated screen:
  - Search form by purpose
  - Results list and calendar ranking

Recommendation:
- Keep the scoring rules deterministic and auditable.
- Avoid opaque AI scoring for auspicious timing.

---

## Static vs Dynamic Summary Table

| Feature | Static Data | Dynamic Data | Primary Source |
|---|---|---|---|
| Header | labels | Samvat month/year | Panchang service |
| Vara | weekday names, rulers, symbols | current Vara | local initially, backend later |
| Panchang | names, deity/ruler lookup, labels | Tithi, Nakshatra, Yoga, Karana, sun/moon times | Swiss Ephemeris via panchang service |
| Kundli Chart | glyphs, rashi labels, chart templates | planet positions, houses, ascendant | birth chart service |
| Dasha | dasha order, durations, descriptions | active Mahadasha / Antardasha | dasha service |
| Doshas | rule descriptions, severity labels | actual dosha presence | dosha service |
| Remedies | remedy tables | selected remedies for user | remedy service + chart/dasha/dosha inputs |
| Hindu Calendar | festival descriptions | Tithi calendar, festival dates | hindu calendar service |
| Muhurta | scoring rules | ranked auspicious slots | muhurta service |

---

## Recommended Backend File Layout

```text
backend/
  api/
    panchang.py
    dasha.py
    dosha.py
    muhurta.py
    vedic_chart.py
    hindu_calendar.py
    remedies.py
  services/
    panchang_service.py
    dasha_service.py
    dosha_service.py
    muhurta_service.py
    hindu_calendar_service.py
    remedy_service.py
  data/
    panchang_constants.py
    dasha_constants.py
    dosha_reference.py
    remedies_data.py
    festival_reference.py
    muhurta_rules.py
```

---

## Recommended Population Flow on App Launch

### Vedic hub
1. Read saved birth details and location from onboarding/profile.
2. If location exists, fetch daily Panchang summary.
3. If birth date exists, fetch chart summary, Dasha summary, and dosha summary in parallel.
4. If no birth time or place exists, keep Panchang enabled but show locked/limited state for Kundli, Dasha, and Doshas.

### Minimal hub payloads
The hub should not fetch full-detail payloads for every feature on initial load. Use lightweight summaries:

- `GET /vedic/home-summary?date=...&lat=...&lon=...`
- `POST /vedic/personal-summary`

Suggested split:
- `home-summary`
  - Vara
  - Panchang summary
  - Hindu month summary
  - Next muhurta snippet
- `personal-summary`
  - Lagna
  - Moon sign
  - Nakshatra
  - Current Mahadasha / Antardasha
  - Major dosha count
  - Top remedy

This avoids calling 5 heavy endpoints on every tab open.

---

## Recommended Frontend States Per Card

### Panchang card
- Loading: shimmer or compact skeleton
- Loaded: Tithi + Nakshatra + next key time window
- Error: `Unable to load today's Panchang`
- Missing location: `Add location to see accurate Panchang`

### Kundli card
- Loaded: Lagna + Moon sign + Nakshatra
- Partial: `Birth time missing, houses may be estimated`
- Missing birth data: `Add birth date, time, and place`

### Dasha card
- Loaded: `Moon Mahadasha · Jupiter Antardasha`
- Missing birth time/place: locked state

### Dosha card
- Loaded: `No major dosha detected` or `2 active doshas`
- Missing birth details: locked state

### Remedies card
- Loaded: `Top remedy: Pearl mantra on Monday`
- No inputs: generic traditional remedies disabled

### Hindu Calendar card
- Loaded: `Vaishakha · Next festival: Akshaya Tritiya`
- Error: fallback to current month label only

### Muhurta card
- Loaded: next best slot
- No location: disabled

---

## Recommended Data Priorities

### Phase 1
Implement first:
- Panchang
- Kundli chart summary
- Dasha summary
- Dosha summary

### Phase 2
Then add:
- Hindu calendar
- Remedies
- Muhurta

This order is correct because:
- Panchang powers daily relevance
- Birth chart powers all personal Vedic features
- Dasha and Doshas are high-user-value and reuse the same chart inputs
- Muhurta should come after Panchang is reliable

---

## What Should Not Be Hardcoded in Flutter

Do not permanently hardcode these in the app:
- Samvat year and month
- Tithi
- Nakshatra
- Dasha periods
- Dosha detection
- Muhurta windows
- Festival dates for lunar festivals

Flutter should only hardcode:
- visual labels
- icons
- fallback placeholders
- purely presentational mappings already stable in UI

---

## Practical Recommendation for This Repo

Use the current screen as a staged rollout:

### Keep local for now
- Vara label
- Planet symbol
- temporary Samvat approximation
- card titles/subtitles

### Move to backend next
- Panchang summary card
- Kundli summary card
- Dasha summary card
- Dosha summary card

### Add static data files before AI
- festival descriptions
- remedy tables
- dasha lord meanings
- nakshatra descriptions
- yoga / karana / tithi names

### Use AI only for optional enrichment
- narrative explanation of chart
- remedy explanation tone
- long-form festival stories
- personalized spiritual guidance

AI should never be the source of truth for Vedic calculations.

---

## Final Recommendation

For the Vedic screen, treat it as two data groups:

- Daily location-based data:
  - Panchang
  - Hindu Calendar
  - Muhurta
- Personal birth-based data:
  - Kundli Chart
  - Dasha
  - Doshas
  - Remedies

That gives you a clean architecture:

- one calendar engine
- one birth-chart engine
- static reference tables for names, descriptions, and mappings
- optional AI layer only for explanations
