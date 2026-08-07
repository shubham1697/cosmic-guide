"""
AI prompt templates for CosmicGuide daily content generation.

All prompts are designed to return structured JSON or clean prose that can
be parsed and stored in the database.  The tone is mystical, cosmic, and
positive — matching the app's voice.
"""

from datetime import date

# ────────────────────────────────────────────────────────────────────────────
#  SYSTEM PROMPT  (shared across all CosmicGuide completions)
# ────────────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are CosmicGuide's celestial oracle — an expert astrologer
with deep knowledge of Western astrology, planetary transits, and cosmic symbolism.
Your writing voice is mystical, warm, inspiring, and poetic without being vague.
You speak with authority born from the stars.

Rules you must always follow:
- Never be negative or doom-predicting; frame challenges as growth opportunities.
- Keep language accessible yet lyrical, between 9th and 11th grade reading level.
- Never mention specific dates, names of real people, or make financial promises.
- When asked for JSON, return ONLY valid JSON — no markdown fences, no commentary.
- Be specific to each zodiac sign's core traits and ruling planet.
"""
# Vedic rashi metadata for prompt shaping: English sign -> (Sanskrit rashi, rashi lord/swami)
RASHI_INFO = {
    "Aries": ("Mesha", "Mars (Mangala)"),
    "Taurus": ("Vrishabha", "Venus (Shukra)"),
    "Gemini": ("Mithuna", "Mercury (Budha)"),
    "Cancer": ("Karka", "Moon (Chandra)"),
    "Leo": ("Simha", "Sun (Surya)"),
    "Virgo": ("Kanya", "Mercury (Budha)"),
    "Libra": ("Tula", "Venus (Shukra)"),
    "Scorpio": ("Vrishchika", "Mars (Mangala)"),
    "Sagittarius": ("Dhanu", "Jupiter (Guru)"),
    "Capricorn": ("Makara", "Saturn (Shani)"),
    "Aquarius": ("Kumbha", "Saturn (Shani)"),
    "Pisces": ("Meena", "Jupiter (Guru)"),
}
# ────────────────────────────────────────────────────────────────────────────
#  HOROSCOPE PROMPT
# ────────────────────────────────────────────────────────────────────────────

def horoscope_prompt(zodiac_sign: str, for_date: date) -> str:
    """
    Returns a user-turn prompt that asks for a full daily horoscope JSON object.

    Expected response shape:
    {
      "general":       "...",   // 3-4 sentences, 60-80 words
      "love":          "...",   // 3-4 sentences, 60-80 words
      "career":        "...",   // 3-4 sentences, 60-80 words
      "health":        "...",   // 3-4 sentences, 60-80 words
      "overall_score": 72,      // integer 60-95
      "lucky_number":  "3",     // string, 1-12
      "lucky_color":   "Violet",
      "mood":          "Reflective"
    }
    """
    day_name = for_date.strftime("%A")
    month_name = for_date.strftime("%B")
    day_num = for_date.day
    year = for_date.year

    return f"""Generate a complete daily horoscope for {zodiac_sign} for {day_name}, {month_name} {day_num}, {year}.

Return ONLY a valid JSON object with these exact keys:
- "general"       — overall daily theme (60-80 words, inspiring, sign-specific)
- "love"          — romantic/relationship insights (60-80 words)
- "career"        — professional and financial guidance (60-80 words)
- "health"        — physical and mental wellness advice (60-80 words)
- "overall_score" — integer between 60 and 95 reflecting the day's cosmic energy
- "lucky_number"  — a single lucky number as a string (e.g. "7")
- "lucky_color"   — one color that resonates with {zodiac_sign}'s energy today
- "mood"          — one descriptive word capturing today's emotional tone

Ground each section in {zodiac_sign}'s ruling planet, element, and core personality.
Make today's entry distinct — reference the day of the week and seasonal energy of {month_name}.
Vary the overall_score naturally; not every day is 90+."""


# ────────────────────────────────────────────────────────────────────────────#  VEDIC HOROSCOPE PROMPT  (sidereal, keyed on Moon rashi / Janma Rashi)
# ───────────────────────────────────────────────────────────

def vedic_horoscope_prompt(moon_rashi: str, for_date: date) -> str:
    """
    Daily reading framed in Vedic (Jyotish) terms, keyed on the user's Moon
    sign (Janma Rashi). Returns the SAME JSON shape as horoscope_prompt so the
    rest of the pipeline (parsing, schema, mobile app) is unchanged.
    """
    day_name = for_date.strftime("%A")
    month_name = for_date.strftime("%B")
    day_num = for_date.day
    year = for_date.year
    sanskrit, lord = RASHI_INFO.get(moon_rashi, (moon_rashi, "its ruling graha"))

    return f"""You are a Vedic astrologer (Jyotishi). Write today's reading for a person whose Moon sign (Janma Rashi) is {moon_rashi} — {sanskrit} — for {day_name}, {month_name} {day_num}, {year}.

This is a SIDEREAL / Vedic reading. Base it on the Moon rashi {sanskrit}, whose rashi lord (swami) is {lord}. Draw on Vedic ideas — the Moon (Chandra) as the mind, the rashi lord {lord}, the grahas, and the emotional significations of the Janma Rashi. Do NOT use tropical Sun-sign framing.

Return ONLY a valid JSON object with these exact keys:
- "general"       — overall theme for this rashi today (60-80 words)
- "love"          — relationships and emotional life (60-80 words)
- "career"        — work, duty (dharma) and finances (60-80 words)
- "health"        — body and mind wellbeing (60-80 words)
- "overall_score" — integer between 60 and 95 reflecting today's graha energy
- "lucky_number"  — a single lucky number as a string
- "lucky_color"   — one auspicious color for {sanskrit} today
- "mood"          — one descriptive word capturing today's emotional tone

Reference the rashi lord {lord} and the Moon's influence naturally. Keep it warm and authentic to Jyotish, never doom-laden. Vary the overall_score; not every day is 90+."""


# ────────────────────────────────────────────────────────────────────────────
#  PERSONALIZED HOROSCOPE PROMPTS  (real natal chart + today's transits)
# ────────────────────────────────────────────────────────────────────────────

def _format_astro_context(context: dict) -> str:
    """Render the natal chart + today's transits as a compact block for the LLM."""
    lines: list[str] = []

    big3 = context.get("big3") or {}
    if big3:
        rising = big3.get("rising", {})
        rising_note = " (rising estimated — no exact birth time)" if rising.get("is_estimated") else ""
        lines.append(
            f"- Natal Big Three: Sun in {big3.get('sun', {}).get('sign', '?')}, "
            f"Moon in {big3.get('moon', {}).get('sign', '?')}, "
            f"Ascendant in {rising.get('sign', '?')}{rising_note}."
        )

    nak = context.get("moon_nakshatra")
    if nak:
        lines.append(
            f"- Moon nakshatra: {nak.get('name')} "
            f"(pada {nak.get('pada')}, ruled by {nak.get('lord')})."
        )

    transit_aspects = context.get("transit_aspects") or []
    if transit_aspects:
        lines.append("- Today's transits to the natal chart (tightest orb first):")
        for a in transit_aspects[:6]:
            retro = " retrograde" if a.get("is_retrograde") else ""
            lines.append(
                f"    \u00b7 transiting {a['transit_planet']}{retro} in {a['transit_sign']} "
                f"{a['aspect'].lower()} natal {a['natal_planet']} "
                f"(in {a['natal_sign']}, orb {a['orb']}\u00b0)"
            )
    else:
        transits = context.get("transits") or []
        if transits:
            sky = ", ".join(
                f"{t['name']} in {t['sign']}" + ("\u211e" if t.get("is_retrograde") else "")
                for t in transits[:7]
            )
            lines.append(f"- Sky today: {sky}.")

    return "\n".join(lines) if lines else "- (chart data unavailable)"


def personalized_horoscope_prompt(zodiac_sign: str, for_date: date, context: dict) -> str:
    """Daily Western reading grounded in this person's real natal chart and the
    live transits aspecting it — a genuine transit-to-natal reading."""
    base = horoscope_prompt(zodiac_sign, for_date)
    astro = _format_astro_context(context)
    return (
        f"{base}\n\n"
        "IMPORTANT: This reading is PERSONAL to one individual, not a generic "
        f"{zodiac_sign} Sun-sign column. Ground every section in their actual "
        "chart and today's real transits below — name the specific planets, "
        "signs, houses, and aspects that are active, and explain what each means "
        "for them today. Weave the astrology in naturally as an expert would; do "
        "not list it mechanically or invent placements not given.\n\n"
        f"This person's natal chart & today's sky:\n{astro}"
    )


def vedic_personalized_horoscope_prompt(moon_rashi: str, for_date: date, context: dict) -> str:
    """Daily Vedic reading grounded in this person's real sidereal chart, Moon
    nakshatra, and the live graha transits aspecting it."""
    base = vedic_horoscope_prompt(moon_rashi, for_date)
    astro = _format_astro_context(context)
    return (
        f"{base}\n\n"
        "IMPORTANT: This reading is PERSONAL to one individual (Jyotish), not a "
        "generic rashi column. Ground every section in their actual sidereal "
        "kundli, Janma Rashi, Moon nakshatra, and today's real graha transits "
        "below — name the specific grahas, rashis, bhavas, and aspects that are "
        "active for them today. Weave it in naturally; do not invent placements "
        "not given.\n\n"
        f"This person's kundli & today's sky:\n{astro}"
    )


# ────────────────────────────────────────────────────────────────────────────
#  PERIODIC HOROSCOPE PROMPTS  (weekly / monthly — same JSON shape as daily)
# ────────────────────────────────────────────────────────────────────────────

def period_horoscope_prompt(zodiac_sign: str, period: str,
                            start: date, end: date) -> str:
    """Weekly or monthly Sun-sign horoscope. Same JSON shape as the daily prompt."""
    if period == "monthly":
        cadence = "month"
        span = start.strftime("%B %Y")
        arc = "Cover the month's overall arc and how the energy shifts from the first week to the last."
    else:
        cadence = "week"
        span = f"{start.strftime('%b %d')} – {end.strftime('%b %d, %Y')}"
        arc = "Cover the week's arc from start to finish and note a couple of standout days."

    return f"""Generate a complete {cadence}ly horoscope for {zodiac_sign} for the {cadence} of {span}.

Return ONLY a valid JSON object with these exact keys:
- "general"       — overall {cadence} theme (70-100 words). {arc}
- "love"          — romantic/relationship outlook for the {cadence} (70-100 words)
- "career"        — professional and financial guidance for the {cadence} (70-100 words)
- "health"        — physical and mental wellness for the {cadence} (70-100 words)
- "overall_score" — integer between 60 and 95 reflecting the {cadence}'s cosmic energy
- "lucky_number"  — a single lucky number for the {cadence} as a string
- "lucky_color"   — one color that resonates with {zodiac_sign} this {cadence}
- "mood"          — one descriptive word capturing the {cadence}'s emotional tone

Ground each section in {zodiac_sign}'s ruling planet, element, and core personality.
Speak to the {cadence} as a whole, not a single day. Vary the overall_score naturally."""


def vedic_period_horoscope_prompt(moon_rashi: str, period: str,
                                  start: date, end: date) -> str:
    """Weekly or monthly Vedic (sidereal) reading keyed on the Moon rashi."""
    sanskrit, lord = RASHI_INFO.get(moon_rashi, (moon_rashi, "its ruling graha"))
    if period == "monthly":
        cadence = "month"
        span = start.strftime("%B %Y")
    else:
        cadence = "week"
        span = f"{start.strftime('%b %d')} – {end.strftime('%b %d, %Y')}"

    return f"""You are a Vedic astrologer (Jyotishi). Write the {cadence}ly reading for a person whose Moon sign (Janma Rashi) is {moon_rashi} — {sanskrit} — for the {cadence} of {span}.

This is a SIDEREAL / Vedic reading based on the Moon rashi {sanskrit}, whose rashi lord (swami) is {lord}. Draw on the grahas, the Moon (Chandra) as the mind, and the rashi lord {lord}. Do NOT use tropical Sun-sign framing.

Return ONLY a valid JSON object with these exact keys:
- "general"       — overall theme for this rashi this {cadence} (70-100 words)
- "love"          — relationships and emotional life (70-100 words)
- "career"        — work, dharma and finances (70-100 words)
- "health"        — body and mind wellbeing (70-100 words)
- "overall_score" — integer between 60 and 95 reflecting the {cadence}'s graha energy
- "lucky_number"  — a single lucky number as a string
- "lucky_color"   — one auspicious color for {sanskrit} this {cadence}
- "mood"          — one descriptive word capturing the {cadence}'s emotional tone

Reference the rashi lord {lord} and the Moon's influence naturally. Keep it warm and authentic to Jyotish. Speak to the {cadence} as a whole. Vary the overall_score."""


# ───────────────────────────────────────────────────────────#  BATCH HOROSCOPE PROMPT  (all 12 signs in one call — cost-efficient)
# ────────────────────────────────────────────────────────────────────────────

def batch_horoscope_prompt(for_date: date) -> str:
    """
    Generates all 12 daily horoscopes in a single API call.

    Expected response shape:
    {
      "Aries":       { ...horoscope fields... },
      "Taurus":      { ...horoscope fields... },
      ...
      "Pisces":      { ...horoscope fields... }
    }
    """
    day_name = for_date.strftime("%A")
    month_name = for_date.strftime("%B")
    day_num = for_date.day
    year = for_date.year
    signs = (
        "Aries, Taurus, Gemini, Cancer, Leo, Virgo, "
        "Libra, Scorpio, Sagittarius, Capricorn, Aquarius, Pisces"
    )

    return f"""Generate complete daily horoscopes for ALL 12 zodiac signs for {day_name}, {month_name} {day_num}, {year}.

Return ONLY a valid JSON object where each key is a zodiac sign name and the value is a horoscope object.

Each horoscope object must have these exact keys:
- "general"       — overall daily theme (60-80 words, unique per sign)
- "love"          — romantic/relationship insights (60-80 words)
- "career"        — professional and financial guidance (60-80 words)
- "health"        — physical and mental wellness advice (60-80 words)
- "overall_score" — integer 60-95 (vary meaningfully across signs)
- "lucky_number"  — lucky number as a string
- "lucky_color"   — one color
- "mood"          — one descriptive word

Signs to include: {signs}

Important:
- Every sign's content must be unique and grounded in that sign's ruling planet and element.
- Vary scores realistically — not all signs can have the same energy on the same day.
- Reference the energy of {day_name} and the season of {month_name} consistently.
- Return ONLY the JSON object, no extra text."""


# ────────────────────────────────────────────────────────────────────────────
#  FORTUNE PROMPT
# ────────────────────────────────────────────────────────────────────────────

def fortune_prompt(zodiac_sign: str, topic: str, mood: str) -> str:
    """
    Generates a single mystical fortune (2-3 sentences, 50-70 words).

    topic: Love | Career | Health | Wealth | Spiritual
    mood:  any descriptive mood string from the user/app
    """
    return f"""Write a mystical fortune for a {zodiac_sign} who is feeling {mood.lower()}.
Topic focus: {topic}

Requirements:
- Exactly 2-3 sentences, 50-70 words total.
- Cosmic and poetic — reference celestial imagery (stars, planets, moon, light).
- Speak directly to the reader using "you" and "your".
- Offer genuine hope and a subtle action hint without being prescriptive.
- Do NOT start with "The stars say" or "The universe says".
- Return ONLY the fortune text, no labels or JSON."""


# ────────────────────────────────────────────────────────────────────────────
#  TAROT INTERPRETATION PROMPT
# ────────────────────────────────────────────────────────────────────────────

def tarot_prompt(card_name: str, card_number: str, is_reversed: bool, zodiac_sign: str = None) -> str:
    """
    Generates a contextual tarot card interpretation (3-4 sentences, ~80 words).

    If zodiac_sign is provided, personalises interpretation to that sign.
    """
    orientation = "reversed" if is_reversed else "upright"
    sign_context = f" for a {zodiac_sign}" if zodiac_sign else ""

    return f"""Write a tarot card interpretation for {card_name} (card {card_number}) drawn in the {orientation} position{sign_context}.

Requirements:
- 3-4 sentences, approximately 70-90 words.
- Reference the card's core symbolism and archetype.
- {"Acknowledge the shadow or challenge aspect, then pivot to empowerment." if is_reversed else "Highlight opportunities and positive energies this card reveals."}
- Mystical, evocative language with cosmic imagery.
- End with a gentle, actionable insight.
- Return ONLY the interpretation text, no labels or JSON."""


# ────────────────────────────────────────────────────────────────────────────
#  COMPATIBILITY PROMPT
# ────────────────────────────────────────────────────────────────────────────

def compatibility_prompt(sign1: str, sign2: str, score: int) -> str:
    """
    Generates a full compatibility analysis for two zodiac signs.

    Expected response shape:
    {
      "description":        "...",  // 3-4 sentences
      "love_advice":        "...",  // 2-3 sentences
      "strengths_together": "...",  // 2-3 sentences
      "challenges":         "..."   // 2-3 sentences
    }
    """
    if score >= 80:
        harmony = "natural harmony and powerful chemistry"
    elif score >= 60:
        harmony = "dynamic contrast and growth potential"
    else:
        harmony = "intense friction that, when navigated wisely, forges deep transformation"

    return f"""Analyze the romantic compatibility between {sign1} and {sign2}.
Their elemental compatibility score is {score}/100, reflecting {harmony}.

Return ONLY a valid JSON object with these exact keys:
- "description"        — overall relationship dynamic (3-4 sentences, 70-90 words)
- "love_advice"        — practical guidance for nurturing this pairing (2-3 sentences, 50-60 words)
- "strengths_together" — what makes this pair powerful together (2-3 sentences, 50-60 words)
- "challenges"         — honest but growth-oriented challenge framing (2-3 sentences, 50-60 words)

Ground analysis in both signs' ruling planets, elements, modalities, and core traits.
Tone: insightful, romantic, and empowering."""


# ────────────────────────────────────────────────────────────────────────────
#  COSMIC STORIES PROMPTS
# ────────────────────────────────────────────────────────────────────────────

STORY_CATEGORIES = ["Planetary", "Weekly", "Relationships", "Wellness", "Spirituality", "Sign Spotlight"]

def story_prompt(category: str, for_date: date) -> str:
    """
    Generates a full cosmic story/article for the given category.

    Expected response shape:
    {
      "title":    "...",
      "summary":  "...",  // 1 sentence, 15-25 words
      "content":  "...",  // 4-6 paragraphs
      "category": "...",
      "read_time": "5 min",
      "tags":     ["tag1", "tag2"]
    }
    """
    month_name = for_date.strftime("%B")
    year = for_date.year

    category_hints = {
        "Planetary": f"Focus on a relevant planetary transit, retrograde, or aspect happening in {month_name} {year}.",
        "Weekly":    f"Cover which signs are favored this week in {month_name} {year} and why.",
        "Relationships": "Dive deep into how zodiac dynamics affect love, friendship, or family bonds.",
        "Wellness":  "Explore astrology-guided physical, mental, or spiritual wellness practices.",
        "Spirituality": "Connect cosmic cycles to meditation, intuition, chakras, or spiritual awakening.",
        "Sign Spotlight": "Feature one zodiac sign's hidden strengths, myths, and cosmic gifts this month.",
    }

    hint = category_hints.get(category, f"Write an engaging {category} astrology article.")

    return f"""Write an astrology article for the CosmicGuide app, category: {category}.
{hint}

Return ONLY a valid JSON object with these exact keys:
- "title"     — compelling, specific headline (8-12 words)
- "summary"   — single sentence hook for the preview card (15-25 words)
- "content"   — full article body (4-6 paragraphs, 350-500 words total)
- "category"  — the category string: "{category}"
- "read_time" — estimated reading time as a string like "4 min"
- "tags"      — array of 3-4 relevant keyword tags

Article style: educational yet mystical, conversational, 10th-grade reading level.
No clickbait. Deliver real astrological insight the reader can act on."""


def daily_stories_prompt(for_date: date, count: int = 5) -> str:
    """
    Generates multiple diverse story ideas + full content in one call.

    Expected response shape:
    [ { story_object }, { story_object }, ... ]  (array of story objects)
    """
    month_name = for_date.strftime("%B")
    day_name = for_date.strftime("%A")
    day_num = for_date.day
    year = for_date.year

    return f"""Generate {count} diverse astrology articles for CosmicGuide for {day_name}, {month_name} {day_num}, {year}.

Return ONLY a valid JSON array of {count} story objects. Each object must have:
- "title"     — compelling unique headline (8-12 words)
- "summary"   — single sentence hook (15-25 words)
- "content"   — full article (4-6 paragraphs, 300-450 words)
- "category"  — one of: Planetary, Weekly, Relationships, Wellness, Spirituality, Sign Spotlight
- "read_time" — e.g. "4 min"
- "tags"      — array of 3-4 keyword tags
- "author"    — always "CosmicGuide"

Rules:
- Each story must cover a DIFFERENT category or angle.
- Reference current celestial energy for {month_name} {year} where relevant.
- Mix educational and practical content.
- No duplicate topics across the {count} stories.
- Return ONLY the JSON array, no extra text."""


# ────────────────────────────────────────────────────────────────────────────
#  KUNDLI / BIRTH CHART PROMPT
# ────────────────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────────
#  BATCH FORTUNE POOL PROMPT  (6 signs × 5 topics × 3 fortunes in one call)
# ────────────────────────────────────────────────────────────────────────────

from data.fortune_options import FORTUNE_TOPICS


def batch_fortune_pool_prompt(signs: list, for_date: date) -> str:
    """
    Generates a daily pool of 3 fortunes for each sign × topic combination.

    Call twice (6 signs each) to cover all 12 signs with 2 LLM calls.

    Expected response shape:
    {
      "Aries": {
        "Love":     ["fortune_a", "fortune_b", "fortune_c"],
        "Career":   ["fortune_a", "fortune_b", "fortune_c"],
        "Health":   [...],
        "Wealth":   [...],
        "Spiritual":[...]
      },
      ...
    }
    """
    month_name = for_date.strftime("%B")
    day_name = for_date.strftime("%A")
    day_num = for_date.day
    year = for_date.year
    signs_str = ", ".join(signs)
    topics_str = ", ".join(FORTUNE_TOPICS)

    return f"""Generate a daily fortune pool for CosmicGuide for {day_name}, {month_name} {day_num}, {year}.
Signs to generate for: {signs_str}
Topics for each sign: {topics_str}

Return ONLY a valid JSON object where:
- Each key is a zodiac sign name from the list above.
- Each sign maps to an object where keys are the 5 topic names.
- Each topic maps to an array of EXACTLY 3 distinct fortune strings.

Fortune requirements (apply to all 180 fortunes):
- Each fortune is 2-3 sentences, 45-60 words.
- Cosmic and poetic — reference celestial imagery (stars, planets, moon, light).
- Speak directly to the reader using "you" and "your".
- Offer genuine hope and a subtle action hint.
- Every fortune must be UNIQUE — no two fortunes across any sign or topic may share the same opening.
- Ground each fortune in the sign's ruling planet, element, and personality traits.
- Reference the seasonal energy of {month_name} {year}.
- Vary tone across the 3 variants: one introspective, one action-oriented, one reassuring.

Return ONLY the JSON object, no extra text."""


# ────────────────────────────────────────────────────────────────────────────
#  BATCH COMPATIBILITY PAIRS PROMPT  (~20 sign pairs in one call)
# ────────────────────────────────────────────────────────────────────────────

def batch_compatibility_pairs_prompt(pairs: list) -> str:
    """
    Generates compatibility analysis for a batch of zodiac sign pairs.

    pairs: list of dicts {"sign1": str, "sign2": str, "score": int}

    Expected response shape:
    [
      {
        "sign1": "Aries", "sign2": "Leo",
        "description": "...",
        "love_advice": "...",
        "strengths_together": "...",
        "challenges": "..."
      },
      ...
    ]
    """
    pairs_list = "\n".join(
        f'{i + 1}. {p["sign1"]} + {p["sign2"]} (base score: {p["score"]}/100)'
        for i, p in enumerate(pairs)
    )

    score_harmony = {
        "high (80-100)": "natural harmony and powerful chemistry",
        "medium (60-79)": "dynamic contrast and growth potential",
        "low (below 60)": "intense friction that, when navigated wisely, forges deep transformation",
    }
    harmony_note = (
        "Score >= 80 → natural harmony; 60-79 → dynamic contrast; < 60 → transformative tension."
    )

    return f"""Generate complete romantic compatibility analyses for the following {len(pairs)} zodiac sign pairs.
{harmony_note}

Pairs to analyze:
{pairs_list}

Return ONLY a valid JSON array of {len(pairs)} objects in the SAME ORDER as the list above.
Each object must have these exact keys:
- "sign1"             — first sign name (copy from pair list)
- "sign2"             — second sign name (copy from pair list)
- "description"        — overall relationship dynamic (3-4 sentences, 70-90 words)
- "love_advice"        — practical guidance for this pairing (2-3 sentences, 50-65 words)
- "strengths_together" — what makes this pair powerful together (2-3 sentences, 50-65 words)
- "challenges"         — honest but growth-oriented challenge framing (2-3 sentences, 50-65 words)

Rules:
- Ground each analysis in both signs' ruling planets, elements, modalities, and core traits.
- Each pair's analysis must be UNIQUE — no copy-paste between pairs.
- Tone: insightful, romantic, and empowering.
- Return ONLY the JSON array, no extra text."""


# ────────────────────────────────────────────────────────────────────────────
#  BATCH TAROT INTERPRETATIONS PROMPT  (AI-quality for a group of cards)
# ────────────────────────────────────────────────────────────────────────────

def batch_tarot_group_prompt(cards: list) -> str:
    """
    Generates AI-quality upright + reversed interpretations for a group of tarot cards.

    cards: list of dicts {"name": str, "number": str, "meaning": str}

    Expected response shape:
    [
      {
        "name": "The Fool",
        "upright_interpretation": "...",   // 3-4 sentences, 70-90 words
        "reversed_interpretation": "..."   // 3-4 sentences, 70-90 words
      },
      ...
    ]
    """
    cards_list = "\n".join(
        f'{i + 1}. {c["name"]} ({c["number"]}) — Core meaning: {c["meaning"]}'
        for i, c in enumerate(cards)
    )

    return f"""Generate mystical tarot card interpretations for the following {len(cards)} cards.

Cards:
{cards_list}

Return ONLY a valid JSON array of {len(cards)} objects in the SAME ORDER as the list above.
Each object must have these exact keys:
- "name"                    — card name (copy exactly)
- "upright_interpretation"  — upright reading (3-4 sentences, 70-90 words)
- "reversed_interpretation" — reversed reading (3-4 sentences, 70-90 words)

Requirements for EVERY interpretation:
- Reference the card's core symbolism, archetype, and imagery.
- Upright: highlight opportunities, positive energies, and actionable insight.
- Reversed: acknowledge the shadow/challenge, then pivot clearly to empowerment.
- Mystical, evocative language with celestial and elemental imagery.
- End each interpretation with a gentle, concrete action insight.
- Each card's content must be UNIQUE — grounded in that card's specific archetype.

Return ONLY the JSON array, no extra text."""


# ────────────────────────────────────────────────────────────────────────────
#  KUNDLI / BIRTH CHART PROMPT
# ────────────────────────────────────────────────────────────────────────────

def kundli_personality_prompt(zodiac_sign: str, birth_date: str,
                               birth_time: str = None, birth_place: str = None) -> str:
    """
    Generates a personalised personality and life-path reading.

    Expected response shape:
    {
      "personality_summary": "...",   // 3-4 sentences
      "life_path":           "...",   // 2-3 sentences
      "strengths":           ["...", "...", "..."],
      "growth_areas":        ["...", "...", "..."],
      "cosmic_purpose":      "..."    // 2-3 sentences
    }
    """
    time_str = f", born at {birth_time}" if birth_time else ""
    place_str = f" in {birth_place}" if birth_place else ""

    return f"""Create a personalised cosmic birth chart reading for a {zodiac_sign}{time_str}{place_str}.
Birth date: {birth_date}

Return ONLY a valid JSON object with these exact keys:
- "personality_summary" — core personality traits and how they manifest (3-4 sentences, 70-90 words)
- "life_path"           — dominant life themes and soul's journey (2-3 sentences, 50-70 words)
- "strengths"           — array of exactly 5 unique strengths as short phrases
- "growth_areas"        — array of exactly 3 growth opportunities (framed positively, not as flaws)
- "cosmic_purpose"      — higher calling and soul mission (2-3 sentences, 50-70 words)

Base the reading primarily on the {zodiac_sign} Sun sign, enhanced with general wisdom.
Tone: deeply personal, empowering, and spiritually resonant."""
