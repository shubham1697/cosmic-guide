# CosmicGuide - Detailed Feature Tracker

> Last updated: July 24, 2026

## 🐛 Bugs / Investigations

- [x] **Today's Horoscope opened the Kundli screen in Vedic mode** — FIXED (Jul 24). The daily card was wired to `onChartTap`, which falls back to the Vedic/Kundli tab when there is no Chart tab (Vedic navigation). It now pushes the detailed `HoroscopeScreen` directly, threaded with the resolved `system` (`western`/`vedic`), so it behaves the same in every tradition. This also repurposes the previously orphaned `lib/screens/horoscope_screen.dart`. Files: `lib/screens/home_screen.dart`, `lib/screens/horoscope_screen.dart`, `lib/main.dart`.
- [~] **Tarot cards not loading** — Likely resolved: `backend/logs/audit.log` shows `/api/v1/tarot/draw` returning `200` consistently, and the home screen caches a daily draw. Re-verify once on-device, then close. Data comes from the backend (with a local-deck fallback).

---

## 📊 Status Update — July 24, 2026

### ✅ Recently Completed (verified in code)

- **Natal / birth chart engine** — backend `POST /api/v1/chart/birth`, `POST /api/v1/chart/vedic`, `GET /api/v1/chart/transits` (`backend/api/chart.py`); Flutter chart wheel with 10 planets, houses, ascendant/MC, Big 3, nakshatra, and live transits (`lib/screens/chart_screen.dart`). This closes the "single biggest gap" called out in `COMPETITOR_ANALYSIS.md`.
- **Dual-tradition reforms R1–R4** — tradition capture, tradition-aware daily reading (`?system=western|vedic`), Moon-rashi sign resolver, and adaptive navigation (see the Reforms section below).
- **Splash screen** — `lib/screens/splash_screen.dart`, wired in `main.dart`.
- **Tarot 3-card spread** — `lib/screens/tarot_spread_screen.dart`, reachable from the Tarot screen.
- **Daily tarot card** — auto-drawn once per day and cached in SharedPreferences (`home_screen.dart`).
- **North/South Indian Kundli chart** — `lib/screens/kundli_chart_screen.dart`, opened from the Vedic hub.
- **Astrology glossary** — `lib/screens/astro_glossary_screen.dart` (tropical vs sidereal explainer).
- **Vedic home summary** — `GET /api/v1/vedic/home-summary` (`backend/api/vedic.py`) + `lib/screens/vedic_home_screen.dart`.

### 🔧 Improvements / Fixes Needed (highest value first)

- **[P0] AI reliability & latency** — `backend/logs/audit.log` shows the horoscope path taking **60–80s** and usually failing: Ollama (`192.168.29.159:11434`) returns `Connection refused` on every call and the iPhone-LLM fallback mostly errors. Likely causes: no `GEMINI_API_KEY` set (auto mode never reaches the cloud provider) and 360s provider timeouts in `shared/llm_config.py`. Fix: set `GEMINI_API_KEY`, cut connect timeouts to 1–2s with fast failover, health-check/skip dead providers, and pre-generate + cache daily horoscopes (`generate_all_horoscopes()` already exists).
- **Client request de-duplication** — the app fires the same horoscope call 3–4× simultaneously (repeated identical requests in `audit.log`). Coalesce in `lib/services/api_service.dart` / `MainShell`.
- **Stale client path** — `GET /api/v1/horoscope/aries` returns 404 somewhere; should be `/horoscope/today?zodiac_sign=`.
- **Weekly / monthly horoscope** — still only `today`. Near-zero-effort, high-impact backend addition that can reuse the existing UI.
- **Slow `/vedic/home-summary`** — consistently 2.5–4.5s; cache or precompute.

### 🗑️ Cleanup / Removal Candidates

- **`lib/screens/discover_screen.dart`** — built but not wired into navigation or pushed anywhere. Either surface it (e.g. a Discover/Stories tab) or remove it.
- **Mock-data fallbacks** — decide a policy: `horoscope_mock_data.dart`, `tarot_deck_data.dart`, and `stories_mock_data.dart` still ship as offline fallbacks; consolidate or gate behind a debug flag.
- **Duplicated data layers** — `backend/data/` vs `database/data/` overlap (compatibility, fortune, tarot, zodiac); consolidate to one source of truth.

### 💡 New Feature Ideas (from competitor analysis, adjusted for what already exists)

- **Push notifications (FCM)** — the #1 retention driver; still not started.
- **Real streak & reading history** — profile stats are hardcoded (`7 days`); persist tarot/fortune/horoscope draws.
- **Shareable chart card** — `RepaintBoundary` → PNG → share sheet; cheap viral loop.
- **Ask the Oracle** — free-text question → AI answer with astrological framing.
- **"Both" compare view** — Western Sun vs Vedic Moon-rashi reading side by side (R5 remaining).

---

## 🚀 TOP PRIORITY — Dual-Tradition Reforms (Western + Vedic)

> Cross-cutting work to make the app usable **and** astrologically plausible for both audiences.
> Vedic users now get a Moon-rashi (Janma Rashi) daily reading via `system=vedic` once birth
> time + place are known; otherwise the app nudges them and falls back to a Western reading.
> **Order:** R1 + R4 (quick wins) → R2 + R3 (keystone) → R5 (polish).
> **Progress:** R1 ✅ · R2 ✅ (backend) · R3 ✅ · R4 ✅ (nav-level) · R5 🚧 (glossary + North/South done; terminology & "both" compare remain).
>
> **Decision (settled):** adaptive single-tradition per user, with a **"Both" default** — navigation
> and the daily-reading emphasis adapt to the chosen tradition.

### R1. Tradition preference — capture ✅ DONE

**Files:** `lib/screens/onboarding_screen.dart`, `lib/screens/profile_screen.dart`

- [x] **Onboarding tradition step** — added page 4/5 ("How do you read the stars?" → Western / Vedic / Both / Not sure); saves `tradition` via SharedPreferences in `_completeOnboarding` (default `both`)
- [x] **Profile tradition toggle** — editable selector (chips) in `_EditProfileSheet` + "Reading style" badge on profile
- [x] **Sign-difference education** — info box on tradition step explaining the ~24° sidereal shift ("your Vedic Sun is often the previous sign")

### R2. Tradition-aware daily reading — KEYSTONE — ✅ DONE (backend)

**Files:** `backend/api/horoscope.py`, `backend/services/horoscope_service.py`, `backend/services/ai_prompts.py`, `backend/services/ai_service.py`

- [x] **Sidereal reading path** — `/today` now takes `?system=western|vedic` (default western). Vedic uses new `vedic_horoscope_prompt(moon_rashi, date)` (Jyotishi framing on the Janma/Moon rashi, Sanskrit name + rashi lord via `RASHI_INFO`), same JSON shape → schema & mobile unchanged
- [x] **Cache key update** — in-memory cache key is now `(sign, system, date)`
- [x] **System threaded end-to-end** — `today_horoscope` → `get_horoscope(sign, system, db)` → `generate_daily_horoscope(sign, date, system)`. Western stays fully DB-backed; **Vedic uses memory + AI + template only (no DB persistence)** to avoid a `horoscopes` schema migration (no `system` column; `create_all` won't alter existing tables)
- [ ] _Deferred:_ nakshatra-level detail + Vedic DB persistence (needs `system` column + migration)
- [x] _R3 scope:_ resolve WHICH rashi is the user's Moon sign (client-side, via existing sidereal `/chart/vedic`) and pass it as `zodiac_sign` with `system=vedic` — **done in R3**

### R3. Sign-identity resolver — consistency — ✅ DONE

**Files:** `lib/services/sign_resolver.dart` (new), `lib/services/api_service.dart`, `lib/main.dart`, `lib/screens/home_screen.dart`

- [x] **Resolver** — new `SignResolver.resolve(tradition, sunSign, birth…)` → `ReadingIdentity(readingSign, system)`. Western/Both → tropical Sun + `system=western`; Vedic → sidereal **Moon rashi** (Janma Rashi) + `system=vedic`. Moon sign is fetched once via `/chart/vedic` and cached in SharedPreferences (`vedicMoonSign`, keyed on birth inputs so it auto-invalidates)
- [x] **Wired end-to-end** — `getHoroscope(sign, {system})` now appends `&system=`; MainShell resolves identity before fetching (loads birth data first) and passes `readingSign`/`system` to Home; Home fetches + displays the resolved sign, with a "Moon sign · Janma Rashi" subtitle in Vedic mode
- [x] **Gate Vedic on birth time + place** — Vedic chosen but time/place missing → falls back to Western **and** Home shows a tap-to-fix nudge ("Add your birth time & place…") that opens Profile. Transient chart-fetch failures fall back silently (no nag)
- [ ] _Deferred (R5):_ sidereal-Sun identity display, nakshatra-level reading, and making the standalone `horoscope_screen.dart` / `chart_screen.dart` (Western surfaces) tradition-aware

### R4. Adaptive navigation & framing — ✅ nav done (deep terms → R5)

**Files:** `lib/main.dart`

- [x] **Conditional tabs** — tab set built in `_MainShellState` from `tradition` (`both`→all 5; `western`→Home/Chart/Match/Profile; `vedic`→Home/Kundli/Match/Profile); selected tab is preserved when the set changes
- [~] **Per-tradition labels** — nav-level done (Vedic tab reads "Kundli" for Vedic users); in-screen Rising↔Lagna / Birth Chart↔Kundli deferred to R5 Jyotish terminology

### R5. Authenticity polish — 🚧 in progress

**Files:** `lib/screens/astro_glossary_screen.dart` (new), `lib/screens/vedic_home_screen.dart`, `lib/screens/kundli_chart_screen.dart`, `lib/screens/match_screen.dart`

- [ ] **Jyotish terminology** in Vedic mode (Rashi, Lagna, Graha, Nakshatra, Dasha) — _kundli chart already uses Lagna/Nakshatra; audit + fold in R4-deferred Rising↔Lagna / Birth Chart↔Kundli relabels_
- [x] **Glossary / "why signs differ"** explainer screen — new `AstroGlossaryScreen` (tropical vs. sidereal + ~24° Lahiri ayanamsa, plus Jyotish & Western term cards). Reachable via **Profile → Astrology Guide**. `flutter analyze` clean
- [x] **Vedic wheel defaults to North/South** — already satisfied: `kundli_chart_screen.dart` defaults to `_KundliChartStyle.north` and uses Lagna/Nakshatra terminology (verified in R5)
- [ ] **"Both" compare view** — reuse the Match screen's Western/Vedic tab pattern (Western Sun reading vs. Vedic Moon-rashi reading side by side)

---

## Status Legend

| Icon | Meaning |
|------|---------|
| [x]  | Complete — fully built and functional |
| [~]  | Partial — UI built, needs backend/real data |
| [ ]  | Pending — not started |

---

## Feature Track Overview

This app serves two distinct astrology traditions. Features are organised accordingly:

| Track | Focus | Target Users |
|-------|-------|--------------|
| 🌟 **Western** | Tropical zodiac, tarot, horoscope, compatibility | Global / English-first |
| 🕉️ **Vedic** | Sidereal zodiac, Kundli, Panchang, Dasha, Nakshatra | Indian region / Hindi |

Backend, auth, navigation, and infrastructure are **shared** across both tracks.

---

# 🌟 WESTERN ASTROLOGY TRACK

---

## Phase 1 — MVP (Current)

### 1. Onboarding & User Setup

**File:** `lib/screens/onboarding_screen.dart`

- [x] Welcome screen — app intro with "Begin Your Journey" CTA
- [x] Name input step — text field with validation, "The stars wish to know you" subtitle
- [x] Birth date picker — native date picker, dark themed, range 1940-present
- [x] Automatic zodiac calculation — Western zodiac from month/day ranges (all 12 signs)
- [x] Zodiac reveal — animated sign symbol + name display after date selection
- [x] Page indicators — 3-dot animated indicators with width transition (8px → 24px)
- [x] Data persistence — saves `userName`, `userSign`, `onboarded` flag via SharedPreferences
- [x] Birth time input — optional step (skippable), saved to SharedPreferences
- [x] Birth place input — optional step (skippable), saved to SharedPreferences
- [ ] Manual zodiac override — let user pick sign if they disagree with calculation

### 2. Authentication (Not Started)

- [ ] Email + password sign-up/login
- [ ] Google OAuth sign-in
- [ ] Apple Sign-In (iOS requirement)
- [ ] OTP / email verification flow
- [ ] Forgot password / reset flow
- [ ] JWT token storage (secure storage, not SharedPreferences)
- [ ] Session management — auto-refresh tokens, logout
- [ ] Guest mode — use app without account, prompt to sign up for saves

---

### 3. Home Screen

**File:** `lib/screens/home_screen.dart`

- [x] Time-based greeting — "Good Morning/Afternoon/Evening" based on device clock
- [x] User zodiac display — sign name + Unicode symbol (e.g., "Scorpio ♏")
- [x] Zodiac avatar — circular container with purple gradient background
- [x] Today's horoscope card — tappable, shows general prediction (3-line truncated)
- [x] Overall daily score — gold gradient badge showing percentage (e.g., "85%")
- [x] Lucky info chips — Lucky Number, Lucky Color, Mood (with icons)
- [x] Quick action grid — 4 buttons: Tarot (purple), Fortune (gold), Match (pink), Kundli (teal)
- [x] Cosmic stories feed — 3 story preview cards with title, summary, category, read time
- [x] Pull-to-refresh — re-fetches horoscope + stories from backend
- [x] Today's tarot card widget — mini daily card preview
- [x] Greeting by name — shows "Good Morning, {name}" using saved userName from onboarding
- [ ] Notification bell icon — show unread notification count

---

### 4. Daily Horoscope

**File:** `lib/screens/horoscope_screen.dart`

- [x] Sign header — zodiac symbol (large) + sign name (Playfair Display) + date range
- [x] Score ring — circular container with 2px gold border, score% + "Overall" label
- [x] Tabbed categories — 4 tabs: General (star icon), Love (heart), Career (work), Health (safety)
  - [x] Tab bar — custom container with purple gradient indicator, 13px text
  - [x] Tab content — each tab has icon + scrollable text in a card
- [x] Lucky section — bottom card with 3 items: Lucky Number, Lucky Color, Mood
- [x] Horoscope content — unique mock data for all 12 signs with custom text, scores, lucky numbers, colors, and moods
- [ ] Swipe gesture — navigate to previous/next day horoscope
- [ ] Date selector — pick any date to view past/future predictions
- [ ] Share horoscope — share as text or styled image to social media
- [ ] Weekly/monthly view — extended prediction timeframes
- [ ] Real AI-generated content — replace mock data with OpenAI/Gemini responses
- [x] Backend integration — GET /horoscope/today?zodiac_sign={sign}, falls back to mock data

---

### 5. Tarot Reading

**File:** `lib/screens/tarot_screen.dart`

- [x] Screen layout — title "Draw Your Card" + subtitle "Tap the card to reveal your destiny"
- [x] Card back design — 220x340px, purple gradient, gold 2px border, star icon, "Tap to Reveal"
- [x] Draw button — "Draw a Card" / "Draw Again" toggle, style icon
- [x] Random card selection — picks from full 78-card deck via backend API (fallback to local deck)
- [x] 3D card flip animation
  - AnimationController: 800ms duration, easeInOut curve
  - Matrix4 transform with perspective (0.001) + Y-axis rotation
  - Front/back detection at 0.5 threshold
  - Back is flipped with extra pi rotation to read correctly
- [x] Card face display — number (Playfair, 32px, gold), star icon (56px), name (22px), meaning (12px italic)
- [x] Glow effect — purple shadow on back, gold shadow on face (blurRadius 20, spreadRadius 2)
- [x] Interpretation panel — appears after reveal, purple bordered card with italic text
- [x] Full 78-card tarot deck with custom interpretations:
  - 22 Major Arcana: The Fool (0) through The World (XXI)
  - 14 Wands (Fire): Ace through King
  - 14 Cups (Water): Ace through King
  - 14 Swords (Air): Ace through King
  - 14 Pentacles (Earth): Ace through King
- [x] Card interpretations — pre-generated data for all 78 cards (see Hybrid Model below)
- [x] Reversed card option — 30% chance reversed, 180° rotation, red glow/border, "Reversed" badge, unique reversed interpretations for all 78 cards
- [x] Daily card of the day — auto-draw one card per day, cache result
- [~] Card spread layouts — 3-card spread built (`lib/screens/tarot_spread_screen.dart`); Celtic Cross still pending
- [ ] Card history / journal — save drawn cards with date, let user add notes
- [ ] Card animation sound effects — swipe/flip audio feedback
- [x] Backend integration — GET /tarot/draw, falls back to local mock deck

#### Hybrid Tarot Model (Planned Approach)

**Step 1: Pre-generated data as base (current priority)**
- [x] When user taps "Draw Card", instantly show:
  - Card image/visual
  - Pre-written meaning & interpretation
- [x] Pre-generated interpretations for all 78 cards (upright + reversed in backend)
- [ ] Ensure instant, offline-capable card reveals with no loading delay

**Step 2: AI-enhanced personalized reading (future, optional)**
- [ ] Add "Get Personalized Insight" button after card reveal
- [ ] Add "Interpret for My Situation" option for contextual readings
- [ ] On tap, send to AI service:
  - Card drawn (name + number)
  - Upright or reversed orientation
  - User's zodiac sign
  - User's question or context (if provided)
- [ ] Display AI-generated deeper, customized reading below the pre-generated one
- [ ] Cache AI responses to reduce API calls for repeated draws
- [ ] Graceful fallback — if AI is unavailable, pre-generated interpretation remains visible

---

### 6. Fortune Generator

**File:** `lib/screens/fortune_screen.dart`

- [x] Crystal ball animation — 140px circle with pulsating RadialGradient
  - AnimationController: 2-second loop with reverse
  - Purple glow: alpha oscillates 128-205 (inner), 77-128 (mid)
  - BoxShadow: blurRadius 30-40, spreadRadius 5-10
  - Star icon (56px gold) at center
- [x] Topic selector — 5 options: Love, Career, Health, Wealth, Spiritual
  - Pill-shaped buttons with purple gradient when selected
- [x] Mood selector — 5 options: Happy, Curious, Anxious, Hopeful, Reflective
  - Pill-shaped buttons with gold gradient when selected
- [x] Generate button — disabled until both topic + mood selected
  - Loading state: "Consulting the Stars..." with spinner (2-second fake delay)
- [x] Fortune card — gradient card with gold border, star icon, italic Playfair Display text
- [x] Fortune content — backend generates fortunes from topic-based templates, falls back to local pool
- [ ] AI-powered fortunes — send zodiac + topic + mood to OpenAI/Gemini for unique response
- [ ] Fortune history — save generated fortunes with timestamp
- [ ] Save/bookmark — mark favorite fortunes
- [ ] Share as image — generate styled image card for sharing
- [ ] Daily fortune limit — free users get 3/day, premium unlimited
- [x] Backend integration — POST /fortune/generate { zodiacSign, topic, mood }, falls back to mock fortunes

---

## Phase 2 — Enhanced Features

### 7. Compatibility Checker

**File:** `lib/screens/compatibility_screen.dart`

- [x] Screen header — "Zodiac Match" title (Playfair 28px) + subtitle
- [x] Dual sign picker — two side-by-side containers with labels ("Your Sign" / "Their Sign")
  - Dropdown with all 12 signs showing symbol + name
  - Selected sign shows large zodiac symbol (40px)
  - Pink border highlight when sign selected
- [x] Heart icon — pink favorite icon (32px) between the two pickers
- [x] Check button — disabled until both signs selected, pink heart icon
  - Loading: "Matching Stars..." with spinner (1-second delay)
- [x] Score display — Playfair Display 48px, color-coded:
  - >= 80%: green (AppColors.health) + "Excellent Match!"
  - >= 60%: gold (AppColors.accent) + "Promising Match"
  - < 60%: pink (AppColors.love) + "Challenging Match"
- [x] Zodiac symbol pair — shows both symbols with heart between them
- [x] Description text — element-based compatibility explanation
- [x] Love Advice card — pink icon + personalized advice
- [x] Strengths Together card — gold flash icon + strengths description
- [x] Challenges card — amber warning icon + challenges description
- [~] Compatibility scoring — element-based lookup table (16 combinations):
  - Fire+Fire: 80, Fire+Air: 85, Fire+Earth: 55, Fire+Water: 50
  - Air+Air: 75, Air+Earth: 60, Air+Water: 65
  - Earth+Earth: 90, Earth+Water: 85
  - Water+Water: 80
  - Needs sign-specific detailed compatibility (144 unique pairs)
- [ ] Reverse compatibility — show if result differs when signs are swapped
- [ ] Compatibility history — save previous checks
- [ ] Detailed breakdown — love, friendship, work compatibility sub-scores
- [ ] Celebrity matches — show famous couples with same sign pairing
- [x] Backend integration — POST /compatibility/check { sign1, sign2 }, falls back to mock data

---

### 8. Kundli Matching (Gun Milan)

**File:** `lib/screens/kundli_screen.dart`

- [x] Screen header — "Gun Milan" (Playfair 28px gold) + "Ashta Koota compatibility analysis"
- [x] Person 1 form — teal-bordered card with:
  - Full Name text field (person icon)
  - Birth Date picker (calendar icon) — shows DD/MM/YYYY when selected
  - Birth Time picker (clock icon) — shows formatted time when selected
  - Birth Place text field (location icon)
- [x] Person 2 form — identical layout to Person 1
- [x] Form validation — all 6 fields required (names + dates + places, times optional in validation)
- [x] Calculate button — disabled until valid, "Calculate Kundli" / "Calculating..." states (2-second delay)
- [x] Total score — Playfair 48px, "26/36" format
  - Green if score >= 24, gold otherwise
- [x] Compatibility label — "Good" text below score, matching color
- [x] Ashta Koota breakdown — 8 rows, each with:
  - Factor name (100px width, 13px text)
  - LinearProgressIndicator (value/max ratio, green if full, gold otherwise, 8px height)
  - Score display "value/max" (13px muted text)
  - Koota factors and max scores:
    - Varna: max 1
    - Vashya: max 2
    - Tara: max 3
    - Yoni: max 4
    - Graha Maitri: max 5
    - Gana: max 6
    - Bhakoot: max 7
    - Nadi: max 8
- [x] Manglik Dosha warning — red-bordered card with warning icon (conditional, currently false)
- [x] Analysis section — teal-accented card with AI-style analysis text
- [~] Mock data — returns fixed result every time (26/36, "Good", no dosha)
  - Needs real Vedic astrology calculations based on actual birth charts
- [ ] Real Ashta Koota algorithm — calculate Nakshatra from birth details, compute actual scores
- [ ] Manglik Dosha calculation — check Mars position in 1st/2nd/4th/7th/8th/12th house
- [ ] Dosha remedies — suggest remedies based on detected doshas
- [ ] Download PDF report — generate styled PDF with full analysis
- [ ] Share report — send via WhatsApp/email
- [ ] Save reports — store in user history
- [ ] Detailed Nakshatra display — show both persons' nakshatras
- [x] Backend integration — POST /kundli/match { person1, person2 }, falls back to mock data

---

### 9. Personality Insights

**File:** `lib/screens/profile_screen.dart` (embedded in profile)

- [x] Section header — "Personality Traits" (Playfair 18px purple) with psychology icon
- [x] Strengths row — green color bar (4px wide, 40px tall) + label + text
- [x] Weaknesses row — pink/love color bar + label + text
- [x] Emotional patterns row — teal color bar + label + text
- [x] Purple-bordered gradient card container
- [x] Trait data — unique traits for all 12 zodiac signs
- [x] Complete all 12 signs — unique strengths, weaknesses, emotional patterns for all 12 zodiac signs
- [ ] Standalone personality screen — separate from profile, with more detail
- [ ] Detailed personality report — strengths, weaknesses, emotional patterns, love style, career aptitude, communication style
- [ ] AI-generated insights — dynamic personality readings based on full birth chart
- [ ] Personality comparison — compare two signs side by side
- [ ] Element & modality breakdown — show Fire/Earth/Air/Water + Cardinal/Fixed/Mutable traits

---

### 10. Astrology Stories

**File:** `lib/screens/home_screen.dart` (embedded in home feed) + `lib/data/mock_data.dart`

- [x] Story card layout — icon container (50px, purple gradient) + title (14px bold) + summary (12px, 1 line) + read time
- [x] Home feed — shows top 3 stories in vertical list
- [x] 5 sample stories with full metadata:
  1. "Mercury Retrograde Survival Guide" — Planetary, 5 min
  2. "Luckiest Zodiac Signs This Week" — Weekly, 3 min
  3. "Your Zodiac Love Language" — Relationships, 7 min
  4. "Full Moon Rituals for Each Element" — Rituals, 6 min
  5. "Career Paths Written in the Stars" — Career, 8 min
- [x] Story detail screen — full article view with content display
- [ ] Category filter bar — horizontal chips: All, Weekly, Planetary, Relationships, Rituals, Career
- [ ] Bookmark/save articles — heart icon on each card, save to user collection
- [ ] Share stories — share article link or preview image
- [ ] Like/react to stories — engagement metrics
- [ ] Related stories — show similar articles at bottom of detail view
- [ ] AI-generated stories — auto-generate weekly content via AI prompts
- [ ] Push notification on new story — alert users of fresh content
- [ ] Backend-driven feed — fetch stories from API with pagination
- [ ] Dedicated stories tab — consider replacing a nav tab or adding as sub-navigation

---

## Phase 3 — Profile & Settings

### 11. Profile Screen

**File:** `lib/screens/profile_screen.dart`

- [x] Zodiac avatar — 100px circle, purple gradient, gold 2px border, purple glow shadow, zodiac symbol (44px)
- [x] User name — Playfair Display 28px bold
- [x] Sign info line — "Scorpio ♏ | Oct 23 - Nov 21" format (14px muted)
- [x] Stats row — 3 stats with dividers:
  - Readings: 24 (hardcoded)
  - Streak: 7 days (hardcoded)
  - Fortune: 12 (hardcoded)
- [x] Personality traits section — (see section 9 above)
- [x] Sign details card — 3 rows with dividers:
  - Element (water drop icon)
  - Ruling Planet (globe icon)
  - Date Range (calendar icon)
- [x] Premium CTA — gold gradient card: "Upgrade to Premium" + "Unlock advanced reports & unlimited readings" + arrow icon
- [x] Menu items — 4 list tiles in rounded cards:
  - Notifications (bell, gold)
  - Reading History (history, purple)
  - Settings (gear, grey)
  - Help & Support (help, teal)
- [ ] Edit profile — change name, update birth details
- [ ] Profile photo — upload or choose avatar
- [ ] Change birth details — re-enter DOB, recalculate sign
- [ ] Real stats tracking — count actual readings, calculate real streak from usage dates
- [ ] Dark/light theme toggle — currently dark only
- [ ] Language selection — multi-language support (Hindi, etc.)
- [ ] Account deletion — GDPR compliance, delete all user data
- [ ] Logout functionality

---

### 12. Navigation & App Shell

**File:** `lib/main.dart`

- [x] App entry point — `CosmicGuideApp` → `AppEntry` with loading state
- [x] Onboarding check — reads SharedPreferences, shows onboarding or main shell
- [x] Bottom navigation bar — 5 tabs with outlined/filled icon states:
  1. Home (home icon)
  2. Horoscope (auto_awesome icon)
  3. Tarot (style icon)
  4. Match (favorite icon)
  5. Profile (person icon)
- [x] IndexedStack — all 5 screens stay alive in memory during session
- [x] Push navigation — Fortune & Kundli screens pushed via `Navigator.push` from home quick actions
- [x] Nav bar styling — dark secondary background, gold selected color, muted unselected, shadow
- [ ] Deep linking — handle URLs to specific screens (for notifications, sharing)
- [ ] Route animations — custom page transitions (fade, slide)
- [ ] Back button handling — confirm exit on home screen

---

### 13. UI/Theme System

**File:** `lib/theme/app_theme.dart` + `lib/widgets/starry_background.dart`

#### Colors (all implemented)
- [x] Primary: `#1A1A2E` (dark navy) — scaffold background
- [x] Secondary: `#16213E` — nav bar background
- [x] Accent/Gold: `#FFD700` — buttons, highlights, selected states
- [x] Surface: `#0F3460` — progress bar backgrounds
- [x] Card: `#1E2A4A` — card backgrounds
- [x] Love: `#E91E63` — compatibility, hearts
- [x] Career/Gold: `#FFD700` — career category
- [x] Health/Teal: `#00BFA5` — health category, good scores
- [x] General/Purple: `#7C4DFF` — general category, accents
- [x] Deep Purple: `#4A148C` — gradient endpoints
- [x] Mystic Teal: `#00BCD4` — kundli accents

#### Gradients (all implemented)
- [x] gradientPrimary — 3-stop: `#1A1A2E` → `#16213E` → `#0F3460`
- [x] gradientCard — 2-stop: `#1E2A4A` → `#253559`
- [x] gradientGold — 2-stop: `#FFD700` → `#FFA000`
- [x] gradientPurple — 2-stop: `#7C4DFF` → `#4A148C`

#### Typography (all implemented)
- [x] Headings — Playfair Display (serif, mystical feel) via google_fonts
- [x] Body — Poppins (clean sans-serif) via google_fonts
- [x] Font scale — display: 32/24px, title: 20/16px, body: 16/14/12px

#### Starry Background Widget
- [x] CustomPainter with 50 animated stars
- [x] Each star: random position, size (0.5-2.5px), opacity (0.2-0.7), speed (0.5-1.0)
- [x] AnimationController: 3-second cycle, repeats with reverse
- [x] Star color: gold (`#FFD700`) with varying alpha

#### Pending UI Enhancements
- [x] Splash screen — app logo + loading animation on startup (`lib/screens/splash_screen.dart`)
- [ ] App icon — custom icon for Android & iOS
- [ ] Lottie/Rive animations — replace simple loading spinners with rich animations
- [ ] Shimmer loading — skeleton placeholders while data loads
- [ ] Haptic feedback — vibration on card flip, button taps
- [ ] Particle effects — constellation drawing, sparkle bursts
- [ ] Light theme option — alternative color scheme

---

## Phase 4 — Backend & Infrastructure

### 14. Backend API (Not Started)

**Technology:** Python FastAPI on Render

**Planned folder structure:**
```
backend/
├── main.py
├── api/
│   ├── horoscope.py
│   ├── fortune.py
│   ├── tarot.py
│   ├── compatibility.py
│   ├── kundli.py
│   └── user.py
├── services/
│   ├── ai_service.py
│   ├── astrology_service.py
│   └── notification_service.py
├── db/
│   ├── models.py
│   └── database.py
├── utils/
└── config.py
```

**API Endpoints:**
- [ ] `POST /users/create` — register new user (name, email, birth details)
- [ ] `GET /users/profile` — retrieve user profile by auth token
- [ ] `PUT /users/update` — update user details
- [ ] `POST /auth/login` — email + password login, return JWT
- [ ] `POST /auth/google` — Google OAuth flow
- [ ] `POST /auth/refresh` — refresh expired JWT token
- [ ] `GET /horoscope/today?zodiac_sign=Aries` — daily horoscope for sign
- [ ] `GET /horoscope/weekly?zodiac_sign=Aries` — weekly horoscope
- [ ] `POST /fortune/generate` — body: { zodiac_sign, topic, mood }
- [ ] `GET /tarot/draw` — random tarot card with interpretation
- [ ] `POST /compatibility/check` — body: { sign1, sign2 }
- [ ] `POST /kundli/match` — body: { person1_birth_details, person2_birth_details }
- [ ] `GET /stories` — paginated story feed
- [ ] `GET /stories/:id` — single story detail
- [ ] `GET /panchang/daily?date={date}&lat={lat}&lon={lon}` — Tithi, Vara, Nakshatra, Yoga, Karana, time slots
- [ ] `GET /panchang/monthly?month={m}&year={y}&lat={lat}&lon={lon}` — full month Panchang
- [ ] `POST /dasha/calculate` — body: { birth_date, birth_time, birth_place } → Vimshottari Dasha timeline
- [ ] `POST /chart/vedic` — sidereal birth chart with house-wise planet placements
- [ ] `POST /dosha/detect` — detect Mangal, Kaal Sarp, Nadi, Sade Sati, Pitru doshas
- [ ] `POST /muhurta/find` — body: { category, date_from, date_to, lat, lon } → ranked muhurta list
- [ ] `GET /calendar/hindu?month={m}&year={y}` — Hindu month, festivals, Ekadashi, Amavasya, Purnima

**Infrastructure:**
- [ ] JWT authentication middleware
- [ ] Rate limiting (per user, per endpoint)
- [ ] Request validation (Pydantic models)
- [ ] CORS configuration
- [ ] Error handling middleware
- [ ] Logging setup
- [ ] Health check endpoint

---

### 15. Database (Not Started)

**Technology:** PostgreSQL on Render

**Tables with fields:**

- [ ] `users` — id, name, email, password_hash, birth_date, birth_time, birth_place, zodiac_sign, is_premium, created_at, updated_at
- [ ] `horoscopes` — id, date, zodiac_sign, general, love, career, health, overall_score, lucky_number, lucky_color, mood, created_at
- [ ] `tarot_cards` — id, card_name, number, description, meaning, upright_interpretation, reversed_interpretation
- [ ] `tarot_draws` — id, user_id, card_id, is_reversed, drawn_at
- [ ] `compatibility` — id, sign1, sign2, score, description, love_advice, strengths, challenges
- [ ] `kundli_reports` — id, user_id, person1_name, person1_birth_details, person2_name, person2_birth_details, gun_milan_score, koota_scores (JSONB), analysis, has_manglik_dosha, created_at
- [ ] `fortune_history` — id, user_id, zodiac_sign, topic, mood, fortune_text, created_at
- [ ] `premium_purchases` — id, user_id, product_id, product_type, amount, currency, purchase_date, expires_at
- [ ] `subscriptions` — id, user_id, plan_name, price, currency, status, start_date, end_date, auto_renew
- [ ] `stories` — id, title, summary, content, category, read_time, author, published_at, is_featured
- [ ] `bookmarks` — id, user_id, story_id, created_at

**Database tasks:**
- [ ] Schema migrations setup (Alembic)
- [ ] Seed data — all 12 zodiac signs, 78 tarot cards, 144 compatibility pairs
- [ ] Connection pooling
- [ ] Indexes on frequently queried columns (zodiac_sign, date, user_id)
- [ ] Backup strategy

---

### 16. AI Integration (Not Started)

**Providers:** OpenAI / Gemini / Claude

- [ ] AI service abstraction layer — support multiple providers with fallback
- [ ] Fortune generation prompts — template: "Generate a mystical fortune for a {sign} related to {topic}. Tone should be {mood}-appropriate, positive and inspiring. Max 3 sentences."
- [ ] Horoscope generation prompts — daily predictions for each category (general, love, career, health)
- [ ] Personality insight prompts — detailed traits based on zodiac sign
- [ ] Compatibility explanation prompts — relationship advice based on sign pairing
- [ ] Tarot interpretation prompts — dynamic card readings based on context (user's sign, question, card drawn)
- [ ] Astrology story generation — weekly articles on trending astrology topics
- [ ] Content caching strategy:
  - Daily horoscopes: generate once per zodiac per day (12 API calls/day)
  - Fortunes: generate on demand, cache for same sign+topic+mood combo per day
  - Stories: generate weekly batch
- [ ] Token usage tracking — monitor API costs
- [ ] Content moderation — ensure AI outputs are appropriate
- [ ] Fallback content — show cached/static content if AI API is down

---

### 17. Astrology Logic Engine (Not Started)

**Technology:** Pure Python (no AI dependency)

- [ ] Western zodiac calculation — from birth date (month/day ranges) — already done in Flutter, needs backend mirror
- [ ] Vedic zodiac (Rashi) calculation — sidereal zodiac based on actual star positions
- [ ] Nakshatra determination — 27 lunar mansions from birth moon position
- [ ] Ashta Koota algorithm — 8 compatibility factors:
  1. **Varna** (1 pt) — spiritual compatibility (Brahmin/Kshatriya/Vaishya/Shudra)
  2. **Vashya** (2 pts) — dominance/control compatibility
  3. **Tara** (3 pts) — destiny/luck compatibility (27 Nakshatras → 9 groups)
  4. **Yoni** (4 pts) — physical/sexual compatibility (14 animal symbols)
  5. **Graha Maitri** (5 pts) — mental compatibility (planetary friendship)
  6. **Gana** (6 pts) — temperament (Deva/Manushya/Rakshasa)
  7. **Bhakoot** (7 pts) — love/relationship longevity
  8. **Nadi** (8 pts) — health/gene compatibility (Aadi/Madhya/Antya)
- [ ] Manglik Dosha detection — Mars in 1st/2nd/4th/7th/8th/12th house
- [ ] Element-based compatibility — Fire/Earth/Air/Water pairing scores
- [ ] Planetary position calculations — ephemeris-based planet positions for birth chart
- [ ] House system calculations — 12 houses from ascendant

---

## Phase 5 — Monetization & Engagement

### 18. Push Notifications (Not Started)

**Technology:** Firebase Cloud Messaging (FCM)

- [ ] FCM SDK integration in Flutter app
- [ ] Firebase project setup (Android + iOS)
- [ ] Device token registration — save to backend on login
- [ ] Daily horoscope reminder — "Your horoscope for today is ready" at 8 AM
- [ ] Tarot card of the day — "Your daily tarot card awaits" at 9 AM
- [ ] Engagement nudges — "You haven't checked your fortune in 3 days" (re-engagement)
- [ ] Weekly digest — "Your weekly cosmic forecast is here" on Mondays
- [ ] Premium feature teasers — "Unlock your full birth chart" for free users
- [ ] New story alerts — notification when new astrology article is published
- [ ] Notification preferences screen — let users toggle notification types on/off
- [ ] Server-side scheduled sending — Render worker service for batch sends

---

### 19. Monetization (Not Started)

**Payment providers:** Razorpay / Stripe / Google Play / App Store

#### Subscription Plans
- [ ] Monthly Basic: ₹299/month — unlimited tarot, detailed horoscope
- [ ] Monthly Premium: ₹699/month — all Basic + kundli reports, compatibility insights, ad-free
- [ ] Annual plan — discounted rate (e.g., ₹2,999/year = ₹250/month)
- [ ] Free trial — 7-day premium trial for new users

#### One-Time Paid Reports
- [ ] Full Birth Chart Report: ₹199
- [ ] Marriage Compatibility Report: ₹149
- [ ] Career Prediction Report: ₹149
- [ ] Annual Forecast Report: ₹299

#### Ad Integration
- [ ] Google AdMob setup (Android + iOS)
- [ ] Banner ads on home screen (free users)
- [ ] Interstitial ads between readings (free users, max 1 per 5 minutes)
- [ ] Rewarded video ads — watch ad to unlock 1 extra fortune/reading

#### Premium Gating UI
- [ ] Lock icon with gold shimmer on premium features
- [ ] Blurred preview of premium content
- [ ] "Upgrade" CTA button with gradient gold styling
- [ ] Paywall screen with plan comparison
- [ ] Restore purchases button

#### Backend Support
- [ ] Razorpay/Stripe payment webhook handlers
- [ ] In-app purchase receipt validation (Google Play, App Store)
- [ ] Subscription status tracking (active, expired, cancelled)
- [ ] Grace period handling for failed payments

---

## Phase 6 — Deployment & Launch

### 20. Deployment (Not Started)

#### Mobile App
- [ ] Android release build — signed APK/AAB
- [ ] Google Play Store listing — screenshots, description, icon, feature graphic
- [ ] iOS release build — Archive via Xcode
- [ ] Apple App Store listing — screenshots, description, review submission
- [ ] App icon — design for both platforms (adaptive icon for Android)
- [ ] Splash screen — native splash for Android + iOS

#### Backend
- [ ] Render Web Service — deploy FastAPI from GitHub
- [ ] Render PostgreSQL — create managed database
- [ ] Render Worker Service — background jobs (daily horoscope generation, notifications)
- [ ] Environment variables:
  - `DATABASE_URL` — postgresql://user:password@host:port/dbname
  - `OPENAI_API_KEY` — AI content generation
  - `FIREBASE_SERVER_KEY` — push notifications
  - `SECRET_KEY` — JWT signing
  - `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` — payments

#### DevOps
- [ ] CI/CD pipeline — auto-test + deploy on push (GitHub Actions)
- [ ] Staging environment — separate Render instance for testing
- [ ] Error monitoring — Sentry integration (Flutter + backend)
- [ ] Analytics — Firebase Analytics / Mixpanel for user behavior tracking
- [ ] Performance monitoring — API response times, crash reporting
- [ ] SSL/HTTPS — auto-configured on Render

#### Scaling Roadmap
- [ ] Stage 1 (0–10k users): Render free tier, no caching
- [ ] Stage 2 (10k–100k): Upgrade instance, add Redis caching, add worker
- [ ] Stage 3 (100k+): Multiple instances, load balancing, DB read replicas, CDN

---

## Data Models (Implemented in Flutter)

**File:** `lib/models/zodiac.dart`

| Model | Fields | Status |
|-------|--------|--------|
| `ZodiacSign` | name, symbol, element, dateRange, rulingPlanet, icon | [x] Complete |
| `TarotCard` | name, number, meaning, interpretation, isReversed | [x] Complete |
| `HoroscopeData` | sign, date, general, love, career, health, overallScore, luckyNumber, luckyColor, mood | [x] Complete |
| `CompatibilityResult` | sign1, sign2, score, description, loveAdvice, strengthsTogether, challenges | [x] Complete |
| `KundliResult` | totalScore, maxScore, kootaScores, compatibility, analysis, hasManglikDosha | [x] Complete |
| `AstrologyStory` | title, summary, category, readTime, content | [x] Complete |

---

## Dependencies (Installed)

| Package | Version | Purpose |
|---------|---------|---------|
| google_fonts | ^6.1.0 | Playfair Display + Poppins typography |
| flutter_animate | ^4.5.0 | Declarative animations (available, not yet used) |
| smooth_page_indicator | ^1.1.0 | Page dots (available, custom implementation used) |
| percent_indicator | ^4.2.3 | Circular/linear progress (available, not yet used) |
| intl | ^0.19.0 | Date/time formatting |
| shared_preferences | ^2.2.2 | Local key-value storage for onboarding state |

---

## Summary Table

| Category                | Done | Partial | Pending | Total |
|-------------------------|------|---------|---------|-------|
| Onboarding & User Setup | 7    | 0       | 3       | 10    |
| Authentication          | 0    | 0       | 8       | 8     |
| Home Screen             | 7    | 0       | 4       | 11    |
| Daily Horoscope         | 4    | 1       | 6       | 11    |
| Tarot Reading           | 8    | 1       | 7       | 16    |
| Fortune Generator       | 5    | 1       | 6       | 12    |
| Compatibility Checker   | 9    | 1       | 5       | 15    |
| Kundli Matching         | 11   | 1       | 8       | 20    |
| Personality Insights    | 4    | 1       | 6       | 11    |
| Astrology Stories       | 3    | 0       | 10      | 13    |
| **— VEDIC TRACK —**     |      |         |         |       |
| Panchang                | 0    | 0       | 14      | 14    |
| Vimshottari Dasha       | 0    | 0       | 8       | 8     |
| Kundli Chart Visual     | 0    | 0       | 9       | 9     |
| Dosha Detection         | 0    | 0       | 7       | 7     |
| Muhurta                 | 0    | 0       | 7       | 7     |
| Hindu Calendar          | 0    | 0       | 11      | 11    |
| Remedies (Upay)         | 0    | 0       | 9       | 9     |
| Localization & Indian UX| 0    | 0       | 9       | 9     |
| **— SHARED —**          |      |         |         |       |
| Profile Screen          | 8    | 0       | 8       | 16    |
| Navigation & App Shell  | 6    | 0       | 3       | 9     |
| UI/Theme System         | 16   | 0       | 7       | 23    |
| Backend API             | 0    | 0       | 21      | 21    |
| Database                | 0    | 0       | 16      | 16    |
| AI Integration          | 0    | 0       | 12      | 12    |
| Astrology Engine        | 0    | 0       | 9       | 9     |
| Push Notifications      | 0    | 0       | 11      | 11    |
| Monetization            | 0    | 0       | 17      | 17    |
| Deployment              | 0    | 0       | 17      | 17    |
| **TOTAL**               | **88** | **6** | **258** | **352** |

### Progress: 88 complete + 6 partial out of 352 total (27%)

**Western track UI: ~68% done** — all major screens built with mock data
**Vedic track: 0% done** — 74 new items across 8 feature areas
**Backend/Infra: 0% done** — entirely pending, by design ("backend can be done later")
