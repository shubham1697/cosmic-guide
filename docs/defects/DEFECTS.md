# Defect Review — CosmicGuide (astro-scope)

_Reviewed: 2026-08-07_

## Method

- `flutter analyze` → **No issues found**.
- `python -m compileall backend database shared` → **clean** (no syntax errors).
- Manual logic/contract review of the backend (FastAPI), Flutter app, DB models, and cross-layer API contracts.

Static analysis is clean, so everything below is a **logic / robustness / config** defect that a compiler or linter does not catch. Each item was individually verified against the source (many candidate issues turned out to be false positives — see the last section).

## Summary

| # | Severity | Area | Defect |
|---|----------|------|--------|
| 1 | Medium | Flutter | `TarotScreen._drawCard` calls `setState` after `await` with no `mounted` check → crash on fast navigation |
| 2 | Medium | Backend | `/admin/clear-cache` does **not** clear the personalized & forecast caches despite claiming "clear all" |
| 3 | Low–Med | Backend | In-memory caches never evict → unbounded memory growth in a long-running process |
| 4 | Low–Med | Backend | Hardcoded `FESTIVAL_DATES` become stale → "next festival" shows a **past** date once the list is exhausted |
| 5 | Low | Backend | CORS `allow_origins=["*"]` combined with `allow_credentials=True` (spec-invalid config) |
| 6 | Low | Backend | Inconsistent birth-date validation across endpoints; `/admin/content-status` returns 500 on a bad date |
| 7 | Low | Flutter | `OnboardingScreen._completeOnboarding` has no `mounted` check after a 2s delay + async work |
| 8 | Low | Flutter | `PlanetPosition.placement` is declared but never parsed or read (dead field) |
| 9 | Info | Backend | `lucky_number` type diverges across model / schema layers (Integer vs String) |

---

## Details

### 1. Tarot screen: `setState` after `await` without a `mounted` guard — Medium
**File:** `mobile-app/lib/screens/tarot_screen.dart` (`_drawCard`, ~L44–L57)

```dart
Future<void> _drawCard() async {
  final result = await ApiService.drawTarotCard();
  if (result == null) return;
  setState(() { ... });   // ← no `if (!mounted) return;`
```

If the user leaves the Tarot screen while the network request is in flight, the widget is disposed and this `setState` throws **`setState() called after dispose()`**.

This is a clear inconsistency: the sibling flow `tarot_spread_screen.dart` (L68) correctly does `if (!mounted) return;` after its `await`, and virtually every other screen (`home_screen`, `horoscope_screen`, `profile_screen`, `kundli_screen`, …) guards with `mounted`. `_drawCard` is the outlier.

**Fix:** add `if (!mounted) return;` immediately after the `await` (before `setState`).

---

### 2. `/admin/clear-cache` does not clear all caches — Medium
**Files:** `backend/services/horoscope_service.py` (`clear_horoscope_cache`, L473–L478); endpoint in `backend/main.py` (`/admin/clear-cache`).

```python
def clear_horoscope_cache():
    """Clear the in-memory horoscope caches (call after DB repopulation)."""
    _horoscope_cache.clear()
    _periodic_cache.clear()
    # _personalized_cache  and  _forecast_cache  are NOT cleared
```

The module holds **four** caches — `_horoscope_cache`, `_periodic_cache`, `_personalized_cache` (L23) and `_forecast_cache` (L133) — but only two are cleared. The admin endpoint's docstring says _"Clear all in-memory caches"_, which is inaccurate. After a DB repopulation (or any admin cache flush) the personalized daily readings and energy forecasts remain cached and can only be cleared by restarting the process.

**Fix:** add `_personalized_cache.clear()` and `_forecast_cache.clear()` to `clear_horoscope_cache()`.

---

### 3. Unbounded in-memory cache growth — Low–Medium
**File:** `backend/services/horoscope_service.py` — `_horoscope_cache`, `_periodic_cache`, `_personalized_cache`, `_forecast_cache`.

None of these dicts evict old entries. The daily/periodic caches are keyed partly by date, and `_personalized_cache` / `_forecast_cache` are additionally keyed by a per-user birth hash. In a long-running process the personalized/forecast caches grow with **unique users × days** and are never reclaimed (made worse by defect #2, which means two of them cannot even be flushed via the admin endpoint).

**Fix:** evict stale-date entries on write, or use a bounded LRU / TTL cache.

---

### 4. Stale hardcoded festival dates → "next festival" becomes a past date — Low–Medium
**Files:** `backend/data/vedic_reference.py` (`FESTIVAL_DATES`, last entry `2027-03-24`); consumed by `backend/services/vedic_service.py` (`_next_festival`).

```python
def _next_festival(target_date):
    for item in FESTIVAL_DATES:
        if date.fromisoformat(item["date"]) >= target_date:
            return ...
    item = FESTIVAL_DATES[-1]   # ← all festivals are in the PAST here
    return {"name": item["name"], "date": item["date"], ...}
```

Once the current date passes the last hardcoded festival, the "upcoming festival" surface silently shows a **past** date. `HINDU_MONTH_WINDOWS` in the same file carries the same annual-staleness risk. (Currently benign — the next real hit is after 2027-03-24 — but it will fail silently rather than loudly.)

**Fix:** compute festival dates, or handle the "all dates past" case explicitly (return `None` / a maintenance signal) instead of returning a past festival.

---

### 5. CORS: wildcard origin with credentials — Low (latent security)
**Files:** `backend/config.py` (`CORS_ORIGINS = ["*"]`, L53) + `backend/main.py` (`allow_credentials=True`, L40–L46).

`allow_origins=["*"]` together with `allow_credentials=True` is invalid per the CORS spec; Starlette works around it by echoing the caller's `Origin`, which effectively lets **any** website make credentialed cross-origin requests. The app currently uses no cookies/auth, so real-world risk is low today — but this becomes exploitable the moment any authenticated/cookie-based endpoint is added.

**Fix:** set an explicit allow-list of origins, or keep `allow_credentials=False` while origins is `*`.

---

### 6. Inconsistent birth-date input validation — Low
**Files:** `backend/api/horoscope.py` (`/today` `birthDate`, `/forecast` `birthDate`), `backend/api/vedic.py` (`targetDate`), `backend/main.py` (`/admin/content-status`, `/admin/refresh-daily` `target_date`).

`/forecast` validates its date with `pattern=r"^\d{4}-\d{2}-\d{2}$"`, but the other endpoints do not. Consequences:
- `/horoscope/today?...&birthDate=garbage` → the personalized path throws internally but is caught, so it **degrades gracefully** to the generic reading (OK, but by luck).
- `/admin/content-status?target_date=garbage` → `date.fromisoformat(...)` raises `ValueError` → **HTTP 500** instead of a 400. (Admin-only, low impact.)

**Fix:** apply the same date `pattern` / validation consistently, or catch `ValueError` → return `400`.

---

### 7. Onboarding: no `mounted` check after async work — Low
**File:** `mobile-app/lib/screens/onboarding_screen.dart` (`_completeOnboarding`, ~L120–L150)

```dart
setState(() => _isRevealing = true);
await Future.delayed(const Duration(seconds: 2));
final prefs = await SharedPreferences.getInstance();
...
widget.onComplete(_nameController.text, _selectedSign!);  // no mounted check
```

After the 2-second delay and the `SharedPreferences` await, the code reads `_nameController.text` and invokes the parent callback without checking `mounted`. If the screen is disposed during that window it can touch a disposed controller / fire a callback on a dead widget. Low severity because onboarding is hard to interrupt (the `PageView` is non-scrollable and this is the app root), but it is the same latent pattern as #1.

**Fix:** add `if (!mounted) return;` after the awaits.

---

### 8. Dead field: `PlanetPosition.placement` — Low
**File:** `mobile-app/lib/models/zodiac.dart` (`PlanetPosition`, ~L157–L190)

The class declares `final String? placement;` and accepts it in the constructor, but `PlanetPosition.fromJson` never assigns it, and no code anywhere reads `.placement`. It is dead today; if the UI is later wired to show planet placement, it will silently always be `null`.

**Fix:** either populate it in `fromJson` (e.g. `placement: json['placement']`) or remove the field.

---

### 9. `lucky_number` type divergence across layers — Informational
**Files:** `backend/db/models.py` (`Horoscope.lucky_number = Column(Integer)`), `backend/schemas.py` (`HoroscopeResponse.lucky_number: str`), and `PeriodicHoroscope.lucky_number = Column(String(10))`.

The daily table stores `lucky_number` as an **Integer**, the response schema exposes it as a **str**, and the periodic table stores it as **String(10)**. It works today because the code casts (`str(...)`), but the inconsistency is a maintenance hazard (a future cast-free code path would break). Mirrored identically in `database/models.py`, so the two model definitions are at least consistent with each other.

**Fix:** pick one representation for `lucky_number` across model + schema.

---

## Checked and found NOT to be defects (false positives)

These were investigated during the review and confirmed to be safe/by-design — recorded here to avoid re-flagging:

- **`next(p for p in planets if p["name"]=="Sun"/"Moon")`** in `birth_chart_service.py`, `vedic_service.py`, `kundli_service.py` (no default) — the planet set is fixed (`PLANET_IDS` / `VEDIC_GRAHAS` always include Sun & Moon and the build loop has no per-planet skip), so `StopIteration` is not reachable in practice.
- **`fortune_service.generate_fortune` returning `None`** — it always returns a string (`_pick_mock_fortune` has a hardcoded final fallback).
- **Flutter "unsafe JSON parsing"** in `getHoroscope`, `calculateKundli`, `getStories` — all wrapped in `try/catch`, so a malformed/short response degrades to `null` / empty list, not a crash.
- **Tarot response "contract mismatch"** — the backend intentionally sends one `interpretation` for the drawn orientation, and `drawTarotCard` correctly routes it into `interpretation` vs `reversedInterpretation` based on `isReversed`.
- **Admin endpoints leaking DB sessions** — `content_status` and `refresh_daily_content` both use `try/finally: db.close()` (and `rollback()` on error).
- **`RAHU_KAAL_OCTANT` / `YAMAGANDA_OCTANT` / `GULIKA_OCTANT` `KeyError`** — all three maps define every weekday key `0..6`.
- **`DeviceToken` missing from `database/models.py`** — by design; the `device_tokens` table is created by the backend's `create_all`, and the populator does not manage push tokens.
- **`HoroscopeData` field types** — `overallScore` (int) / `luckyNumber` (String) / `luckyColor` (String) match the backend response.
