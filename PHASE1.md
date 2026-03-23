# CosmicGuide — Phase 1: MVP

> Last updated: March 20, 2026

## Status Legend

| Icon | Meaning |
|------|---------|
| [x]  | Complete — fully built and functional |
| [~]  | Partial — UI built, needs backend/real data |
| [ ]  | Pending — not started |

---

## 1. Onboarding & User Setup

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

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 9    | 0       | 1       | 10    |

---

## 2. Authentication (Not Started)

- [ ] Email + password sign-up/login
- [ ] Google OAuth sign-in
- [ ] Apple Sign-In (iOS requirement)
- [ ] OTP / email verification flow
- [ ] Forgot password / reset flow
- [ ] JWT token storage (secure storage, not SharedPreferences)
- [ ] Session management — auto-refresh tokens, logout
- [ ] Guest mode — use app without account, prompt to sign up for saves

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 0    | 0       | 8       | 8     |

---

## 3. Home Screen

**File:** `lib/screens/home_screen.dart`

- [x] Time-based greeting — "Good Morning/Afternoon/Evening" based on device clock
- [x] User zodiac display — sign name + Unicode symbol (e.g., "Scorpio ♏")
- [x] Zodiac avatar — circular container with purple gradient background
- [x] Today's horoscope card — tappable, shows general prediction (3-line truncated)
- [x] Overall daily score — gold gradient badge showing percentage (e.g., "85%")
- [x] Lucky info chips — Lucky Number, Lucky Color, Mood (with icons)
- [x] Quick action grid — 4 buttons: Tarot (purple), Fortune (gold), Match (pink), Kundli (teal)
- [x] Cosmic stories feed — 3 story preview cards with title, summary, category, read time
- [ ] Pull-to-refresh — fetch fresh data from backend
- [ ] Today's tarot card widget — mini daily card preview
- [ ] Greeting by name — currently shows "Good Morning," but not user's name
- [ ] Notification bell icon — show unread notification count

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 7    | 0       | 4       | 11    |

---

## 4. Daily Horoscope

**File:** `lib/screens/horoscope_screen.dart`

- [x] Sign header — zodiac symbol (large) + sign name (Playfair Display) + date range
- [x] Score ring — circular container with 2px gold border, score% + "Overall" label
- [x] Tabbed categories — 4 tabs: General (star icon), Love (heart), Career (work), Health (safety)
  - [x] Tab bar — custom container with purple gradient indicator, 13px text
  - [x] Tab content — each tab has icon + scrollable text in a card
- [x] Lucky section — bottom card with 3 items: Lucky Number, Lucky Color, Mood
- [~] Horoscope content — currently mock data
  - Aries: score 85, lucky 7, Red, Energetic — full custom text for all 4 categories
  - Taurus: score 78, lucky 4, Green, Grounded — full custom text for all 4 categories
  - All other signs: generic fallback — score 75, lucky 9, Purple, Intuitive
- [ ] Swipe gesture — navigate to previous/next day horoscope
- [ ] Date selector — pick any date to view past/future predictions
- [ ] Share horoscope — share as text or styled image to social media
- [ ] Weekly/monthly view — extended prediction timeframes
- [ ] Real AI-generated content — replace mock data with OpenAI/Gemini responses
- [ ] Backend integration — GET /horoscope/today?zodiac_sign=Aries

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 4    | 1       | 6       | 11    |

---

## 5. Tarot Reading

**File:** `lib/screens/tarot_screen.dart`

- [x] Screen layout — title "Draw Your Card" + subtitle "Tap the card to reveal your destiny"
- [x] Card back design — 220x340px, purple gradient, gold 2px border, star icon, "Tap to Reveal"
- [x] Draw button — "Draw a Card" / "Draw Again" toggle, style icon
- [x] Random card selection — picks from 16-card subset using `dart:math` Random
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
- [ ] Reversed card option — `isReversed` field exists in model but not used
- [ ] Daily card of the day — auto-draw one card per day, cache result
- [ ] Card spread layouts — 3-card spread (past/present/future), Celtic Cross
- [ ] Card history / journal — save drawn cards with date, let user add notes
- [ ] Card animation sound effects — swipe/flip audio feedback
- [ ] Backend integration — GET /tarot/draw

### Hybrid Tarot Model (Planned Approach)

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

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 9    | 1       | 12      | 22    |

---

## 6. Fortune Generator

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
- [~] Fortune content — randomly picks from 5 pre-written fortune texts (not AI-generated)
- [ ] AI-powered fortunes — send zodiac + topic + mood to OpenAI/Gemini for unique response
- [ ] Fortune history — save generated fortunes with timestamp
- [ ] Save/bookmark — mark favorite fortunes
- [ ] Share as image — generate styled image card for sharing
- [ ] Daily fortune limit — free users get 3/day, premium unlimited
- [ ] Backend integration — POST /fortune/generate { zodiac_sign, topic, mood }

| Done | Partial | Pending | Total |
|------|---------|---------|-------|
| 5    | 1       | 6       | 12    |

---

## Phase 1 Summary

| Section                 | Done | Partial | Pending | Total |
|-------------------------|------|---------|---------|-------|
| Onboarding & User Setup | 9    | 0       | 1       | 10    |
| Authentication          | 0    | 0       | 8       | 8     |
| Home Screen             | 7    | 0       | 4       | 11    |
| Daily Horoscope         | 4    | 1       | 6       | 11    |
| Tarot Reading           | 9    | 1       | 12      | 22    |
| Fortune Generator       | 5    | 1       | 6       | 12    |
| **TOTAL**               | **34** | **3** | **37**  | **74** |

### Progress: 34 complete + 3 partial out of 74 total (50%)
