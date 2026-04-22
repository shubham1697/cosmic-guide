# CosmicGuide — Competitor Analysis & Feature Gap

> Last updated: April 18, 2026

## Apps Compared

| App | Key Differentiator |
|---|---|
| **Co–Star** | Full natal chart + social layer (friends/synastry) + NASA data |
| **The Pattern** | Deep personality patterns + compatibility across relationship types |
| **Sanctuary** | Live human astrologers + AI oracle + premium reports |
| **Nebula** | Aggressive monetization, per-minute astrologer chat, daily notifs |
| **Astro Future** | Planet positions widget, transits, detailed chart wheel |
| **TimePassages** | Power-user features (void-of-course moon, detailed transits) |

---

## What CosmicGuide Already Has ✅

- Daily horoscope (General / Love / Career / Health tabs)
- Fortune generator (topic + mood)
- Tarot draw — full 78-card deck with reversed cards
- Compatibility checker (score + descriptions)
- Kundli / Gun Milan (Ashta Koota)
- AI-generated content via Gemini
- Cosmic stories feed
- Basic personality traits per zodiac sign

---

## Feature Gaps — By Priority

### P0 — Expected on Day 1

| Feature | Who Does It | Why It Matters |
|---|---|---|
| **Full natal / birth chart** — chart wheel with all 10 planets, 12 houses, ascendant | Co-Star, Sanctuary, Astro Future | Your "birth chart" is currently Sun-sign only. This is the core product of every serious astrology app. |
| **Rising sign + Moon sign** calculation | Co-Star, all others | Users who know astrology care more about these than Sun sign. Requires birth time + place. |
| **Daily push notifications** | Co-Star, Nebula | The #1 retention driver. Co-Star's brutally honest notifs went viral and drove mass downloads. |
| **Planetary transits today** | Sanctuary, Astro Future | "Mercury is in your 7th house today" — contextualizes the daily reading. |

---

### P1 — Retention & Engagement

| Feature | Who Does It | Notes |
|---|---|---|
| **Friends / social layer** | Co-Star (core differentiator) | Add friends by username, see their daily chart, compare synastry. Biggest viral loop in the category. |
| **Real daily streak tracking** | Nebula, wellness apps | Currently hardcoded as 7 days — needs to be calculated from actual usage. |
| **Weekly & monthly horoscope** | Every major app | Currently only `today`. A weekly view is a near-zero-effort high-impact addition. |
| **Reading history / journal** | Nebula, Sanctuary | Save drawn tarot cards, fortunes, and horoscopes with dates. Users love looking back. |
| **Synastry chart** (couple birth chart overlay) | Sanctuary, Astro Future | Much deeper than a compatibility score — shows actual planet-to-planet interactions. |
| **Moon phase tracker** | TimePassages, Astro Future | Daily moon phase with ritual suggestions. Very popular with the target audience. |
| **Void-of-course Moon alerts** | TimePassages | Power-user feature that drives premium upgrades. |

---

### P2 — Depth & Premium Content

| Feature | Who Does It | Notes |
|---|---|---|
| **Year-ahead forecast** | Sanctuary, Nebula (paid) | AI-generated annual prediction per sign — strong premium upsell. |
| **Home screen planet widget** | Astro Future | Shows current planetary positions without opening the app. |
| **Retrograde calendar** | Most apps | Upcoming retrogrades with dates + what-to-expect per sign. |
| **Birth chart PDF export** | Sanctuary (paid) | Planned for Kundli — extend to full natal chart once chart calculation is added. |
| **Ask the oracle** (free-text AI Q&A) | Sanctuary AI, Nebula | "Will I get this job?" → AI answers with astrological framing. |
| **Multi-type compatibility** | The Pattern | Not just romance — friendship, work, and family compatibility modes. |

---

### P3 — Virality & Growth

| Feature | Who Does It | Notes |
|---|---|---|
| **Shareable chart card** | Co-Star, The Pattern | Beautiful image of your chart to post on Instagram/X. Massive free acquisition channel. |
| **Sun ☉ / Moon ☽ / Rising ↑ profile badge** | Co-Star | Users display and share "Scorpio ☉ / Aquarius ☽ / Leo ↑" everywhere — drives installs. |
| **Zodiac meme / daily quote card** | Nebula | Short-form shareable content — lowest-effort viral loop. |
| **Invite via birth details widget** | The Pattern | Share your chart details with friends to pull them into the app. |

---

### P4 — Monetization Depth

| Feature | Who Does It | Notes |
|---|---|---|
| **Live chat with human astrologers** | Nebula (main revenue) | Per-minute billing — highest ARPU in the category. |
| **Detailed paid reports** | Sanctuary, Nebula | Solar return, Saturn return, Venus return — ₹199–₹499 each. |
| **Couples synastry report PDF** | Sanctuary | Deep synastry PDF — your Kundli PDF extended to Western astrology. |
| **Personalized year report** | All premium apps | AI-generated 12-month outlook per house — biggest single premium justification. |

---

## The Single Biggest Gap

**Co-Star's core value in one sentence:**
> *"Your full birth chart, mapped against real-time planetary positions, compared with your friends' charts."*

CosmicGuide currently only uses **Sun sign**. Adding a natal chart calculation (Sun + Moon + Rising from birth date/time/place) would immediately unlock:

- Personalised daily readings per planet (not just Sun sign)
- Synastry / couple chart comparison
- Transit tracking ("Mars enters your 10th house today")
- Ascending & Moon sign personality layers
- Credibility with users who know astrology

This is the single highest-leverage feature to build next.

---

## Suggested Next Build Order

1. **Natal chart engine** — calculate all planets + houses from birth data (use `flatlib` or `kerykeion` Python library)
2. **Moon + Rising sign** — surface on profile and in horoscope
3. **Weekly horoscope** — 1 extra backend endpoint, reuse existing UI
4. **Push notifications** — daily horoscope push via Firebase FCM
5. **Reading history** — persist tarot / fortune draws per user
6. **Shareable chart card** — Flutter `RepaintBoundary` → PNG → share sheet
7. **Retrograde calendar** — static + AI-enriched content, refreshed monthly
8. **Ask the oracle** — free-text input → Gemini → astrological answer
9. **Year-ahead report** — premium PDF, AI-generated per sign
10. **Friends / social layer** — friend codes, shared feed, synastry comparison
