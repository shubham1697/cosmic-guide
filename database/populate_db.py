#!/usr/bin/env python3
"""
populate_db.py — Generate ALL content for CosmicGuide via Ollama and populate the DB.

Connects to Ollama at 192.168.29.159 and generates content one item at a time:
  - Horoscopes:     12 signs  (today's date)
  - Tarot Cards:    78 cards  (AI-quality upright + reversed interpretations)
  - Fortune Pool:   12 signs × 5 topics = 60 entries  (3 fortunes each)
  - Compatibility:  78 sign pairs  (full descriptions)
  - Stories:        6 categories  (cosmic articles)

Usage:
    python populate_db.py                      # run everything
    python populate_db.py --horoscopes         # horoscopes only
    python populate_db.py --tarot              # tarot cards only
    python populate_db.py --fortunes           # fortune pool only
    python populate_db.py --compatibility      # compatibility only
    python populate_db.py --stories            # stories only
    python populate_db.py --force              # regenerate even if data exists
    python populate_db.py --date 2026-04-28    # generate for a specific date
"""

import sys
import os
import json
import argparse
import http.client
import time
import re
from datetime import date

# Ensure the project root is on sys.path so `database.*` imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.config import (
    configure_logging, get_logger,
    DATABASE_URL, OLLAMA_HOST, OLLAMA_MODEL, OLLAMA_TIMEOUT,
)

configure_logging()
log = get_logger("populate_db")

from database.connection import engine, SessionLocal, Base
from database.models import *  # noqa: F401,F403  — ensure all models are registered
from database.data.zodiac_data import ZODIAC_SIGNS
from database.data.fortune_options import FORTUNE_TOPICS
from database.data.compatibility_data import SIGN_PAIR_SCORES
from database.data.tarot_data import TAROT_CARDS
from database.db_service import (
    save_horoscope, delete_horoscope, horoscopes_exist,
    save_tarot_card, tarot_names_in_db, tarot_count,
    save_fortune_pool, delete_fortune_pool, fortune_pool_exists,
    save_compatibility, compatibility_pairs_exist,
    save_story, delete_all_stories, story_count,
    get_content_status,
)

# Ensure all tables exist on the target DB
Base.metadata.create_all(engine)


# ── Ollama helpers ────────────────────────────────────────────────────────────

def _ollama_generate(prompt: str, expect_json: bool = True,
                     max_tokens: int = 800) -> str | None:
    """Call Ollama /api/chat with streaming and return the full reply, or None."""
    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": True,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.8,
        },
    }).encode()

    t0 = time.perf_counter()
    try:
        conn = http.client.HTTPConnection(OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)
        conn.request(
            "POST", "/api/chat",
            body=payload,
            headers={"Content-Type": "application/json"},
        )
        resp = conn.getresponse()
        parts = []
        for raw_line in resp:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            chunk = json.loads(raw_line)
            parts.append(chunk.get("message", {}).get("content", ""))
            if chunk.get("done"):
                break
        conn.close()
        elapsed = time.perf_counter() - t0
        text = "".join(parts).strip()
        log.debug("Ollama response in %.1fs  len=%d", elapsed, len(text))
        return text
    except Exception as exc:
        elapsed = time.perf_counter() - t0
        log.error("Ollama error after %.1fs: %s", elapsed, exc)
        return None


def _parse_json(raw: str, log_error: bool = True) -> dict | list | None:
    """Strip markdown fences and parse JSON."""
    if not raw:
        return None
    raw = raw.strip()
    if raw.startswith("```"):
        lines = raw.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        raw = "\n".join(lines).strip()

    def _escape_controls_inside_strings(text: str) -> str:
        """Escape literal control chars that appear inside quoted JSON strings."""
        out = []
        in_string = False
        escaped = False
        for ch in text:
            if escaped:
                out.append(ch)
                escaped = False
                continue
            if ch == "\\":
                out.append(ch)
                if in_string:
                    escaped = True
                continue
            if ch == '"':
                out.append(ch)
                in_string = not in_string
                continue
            if in_string and ch == "\n":
                out.append("\\n")
                continue
            if in_string and ch == "\r":
                out.append("\\r")
                continue
            if in_string and ch == "\t":
                out.append("\\t")
                continue
            out.append(ch)
        return "".join(out)

    def _repair_common_json_issues(text: str) -> str:
        """
        Repair frequent LLM JSON mistakes:
        - trailing commas before ] or }
        - unterminated final string (missing quote before ] or })
        """
        import re

        fixed = re.sub(r",\s*([\]}])", r"\1", text)

        # If quote count is odd, try closing the final string before terminal ] or }.
        quote_count = 0
        escaped = False
        for ch in fixed:
            if escaped:
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                continue
            if ch == '"':
                quote_count += 1

        if quote_count % 2 == 1:
            tail = fixed.rstrip()
            if tail.endswith("]") or tail.endswith("}"):
                fixed = tail[:-1] + '"' + tail[-1]
            else:
                fixed = tail + '"'

        return fixed

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        fixed = _escape_controls_inside_strings(raw)
        fixed = _repair_common_json_issues(fixed)
        try:
            return json.loads(fixed)
        except json.JSONDecodeError as exc:
            if log_error:
                log.error("JSON parse error: %s | raw[:300]: %s", exc, raw[:300])
            return None


def _extract_story_fields(raw: str) -> dict | None:
    """Best-effort field extraction for malformed story JSON responses."""
    if not raw:
        return None

    text = raw.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    def _grab(key: str, next_keys: list[str]) -> str:
        next_group = "|".join(re.escape(k) for k in next_keys)
        pattern = (
            rf'"{re.escape(key)}"\s*:\s*"(.*?)"\s*'
            rf'(?=\s*,?\s*"(?:{next_group})"\s*:|\s*\}}|\s*\Z)'
        )
        m = re.search(pattern, text, re.DOTALL)
        if not m:
            return ""
        value = m.group(1)
        return (
            value
            .replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\r", "")
            .replace("\\t", "\t")
            .strip()
        )

    title = _grab("title", ["summary", "content", "read_time"])
    summary = _grab("summary", ["content", "read_time"])
    content = _grab("content", ["read_time"])
    read_time = _grab("read_time", []) or "4 min"

    if not title and not content:
        return None

    return {
        "title": title or "Cosmic Insights",
        "summary": summary,
        "content": content,
        "read_time": read_time,
    }


def _check_ollama() -> bool:
    """Verify Ollama is reachable."""
    try:
        conn = http.client.HTTPConnection(OLLAMA_HOST, timeout=10)
        conn.request("GET", "/api/tags")
        resp = conn.getresponse()
        data = json.loads(resp.read())
        conn.close()
        models = [m.get("name", "") for m in data.get("models", [])]
        log.info("Ollama OK at %s  models=%s", OLLAMA_HOST, models)
        return resp.status == 200
    except Exception as exc:
        log.error("Cannot reach Ollama at %s: %s", OLLAMA_HOST, exc)
        return False


# ── Content generators ────────────────────────────────────────────────────────

def populate_horoscopes(db, target_date: date, force: bool = False) -> int:
    date_str = target_date.isoformat()
    day_label = target_date.strftime("%A, %B %d, %Y")
    generated = 0

    existing = horoscopes_exist(db, target_date)
    log.info("Horoscopes for %s: %d/12 already exist", date_str, len(existing))

    for sign in ZODIAC_SIGNS:
        if sign in existing and not force:
            log.info("  [SKIP] %s — already exists", sign)
            continue
        if sign in existing and force:
            delete_horoscope(db, sign, target_date)

        log.info("  [GEN] %s ...", sign)
        prompt = (
            f"Generate a daily horoscope for {sign} for {day_label}.\n"
            "Return ONLY valid JSON, no markdown fences, with these exact keys:\n"
            f'{{"zodiac_sign":"{sign}","date":"{date_str}",'
            '"general":"2-3 uplifting sentences about the day (60-80 words)",'
            '"love":"1-2 sentences on romance and relationships",'
            '"career":"1-2 sentences on work and professional life",'
            '"health":"1-2 sentences on wellness and self-care",'
            '"overall_score": <integer 65-95>,'
            '"lucky_number": <integer 1-99>,'
            '"lucky_color":"one color word",'
            '"mood":"one positive descriptive word"}'
        )

        raw = _ollama_generate(prompt)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s — bad response", sign)
            continue

        data.setdefault("zodiac_sign", sign)
        data.setdefault("date", date_str)

        if save_horoscope(db, data):
            log.info("  [OK] %s  score=%s  mood=%s",
                      sign, data.get("overall_score"), data.get("mood"))
            generated += 1
        else:
            log.error("  [FAIL] %s — DB error", sign)

    log.info("Horoscopes: %d/%d generated", generated, len(ZODIAC_SIGNS))
    return generated


def populate_tarot(db, force: bool = False) -> int:
    existing_names = tarot_names_in_db(db)
    generated = 0

    log.info("Tarot cards in DB: %d/%d", len(existing_names), len(TAROT_CARDS))

    for card in TAROT_CARDS:
        name = card["name"]
        if name in existing_names and not force:
            log.info("  [SKIP] %s — already exists", name)
            continue

        log.info("  [GEN] %s (%s) ...", name, card["number"])
        prompt = (
            f'Generate mystical tarot interpretations for "{name}" '
            f'(card {card["number"]}). Core meaning: {card["meaning"]}.\n\n'
            "Return ONLY valid JSON with these exact keys:\n"
            '{"upright_interpretation":"3-4 evocative sentences (70-90 words) about what this card '
            'means when drawn upright. Reference the card\'s symbolism and archetype. '
            'End with an actionable insight.",'
            '"reversed_interpretation":"3-4 sentences (70-90 words) about the reversed meaning. '
            'Acknowledge the shadow aspect, then pivot to empowerment. End with guidance."}'
        )

        raw = _ollama_generate(prompt, max_tokens=600)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s — bad response", name)
            continue

        card_data = {
            "name": name,
            "number": card["number"],
            "meaning": card["meaning"],
            "upright_interpretation": data.get("upright_interpretation", card["upright"]),
            "reversed_interpretation": data.get("reversed_interpretation", card["reversed"]),
        }

        if save_tarot_card(db, card_data):
            log.info("  [OK] %s", name)
            generated += 1
        else:
            log.error("  [FAIL] %s — DB error", name)

    log.info("Tarot: %d/%d generated", generated, len(TAROT_CARDS))
    return generated


def populate_fortunes(db, target_date: date, force: bool = False) -> int:
    date_str = target_date.isoformat()
    total_expected = len(ZODIAC_SIGNS) * len(FORTUNE_TOPICS)
    generated = 0

    existing = fortune_pool_exists(db, target_date)
    log.info("Fortune pools for %s: %d/%d already exist", date_str, len(existing), total_expected)

    for sign in ZODIAC_SIGNS:
        for topic in FORTUNE_TOPICS:
            if (sign, topic) in existing and not force:
                continue
            if (sign, topic) in existing and force:
                delete_fortune_pool(db, sign, topic, target_date)

            log.info("  [GEN] %s / %s ...", sign, topic)
            prompt = (
                f"Generate exactly 3 short {topic} fortune messages for {sign} today ({date_str}).\n"
                "Each fortune should be 1-2 mystical sentences (15-25 words), referencing "
                "celestial imagery. Speak directly using 'you' and 'your'.\n"
                "Return ONLY a valid JSON array of 3 strings.\n"
                'Example: ["A cosmic wind carries new opportunities your way.", '
                '"The stars align to brighten your path forward.", '
                '"Trust the celestial rhythm guiding your heart."]'
            )

            raw = _ollama_generate(prompt, max_tokens=300)
            data = _parse_json(raw)

            if isinstance(data, dict) and any(isinstance(v, list) for v in data.values()):
                for v in data.values():
                    if isinstance(v, list):
                        data = v
                        break

            if not isinstance(data, list) or len(data) < 1:
                log.error("  [FAIL] %s/%s — bad response", sign, topic)
                continue

            fortunes = [str(f) for f in data[:3]]
            if save_fortune_pool(db, target_date, sign, topic, fortunes):
                log.info("  [OK] %s/%s  (%d fortunes)", sign, topic, len(fortunes))
                generated += 1
            else:
                log.error("  [FAIL] %s/%s — DB error", sign, topic)

    log.info("Fortunes: %d/%d generated", generated, total_expected)
    return generated


def populate_compatibility(db, force: bool = False) -> int:
    generated = 0
    existing = compatibility_pairs_exist(db)
    total_expected = len(SIGN_PAIR_SCORES)

    log.info("Compatibility pairs in DB: %d/%d", len(existing), total_expected)

    for (s1, s2), score in SIGN_PAIR_SCORES.items():
        if (s1, s2) in existing and not force:
            continue

        log.info("  [GEN] %s × %s (score: %d) ...", s1, s2, score)

        if score >= 80:
            harmony = "natural harmony and powerful chemistry"
        elif score >= 60:
            harmony = "dynamic contrast and growth potential"
        else:
            harmony = "transformative tension that forges deep growth"

        prompt = (
            f"Write a compatibility profile for {s1} and {s2} (score: {score}/100, {harmony}).\n"
            "Return ONLY valid JSON with these exact keys:\n"
            '{"description":"2-3 sentences about their overall relationship dynamic (60-80 words)",'
            '"love_advice":"1-2 practical sentences of relationship advice",'
            '"strengths_together":"1-2 sentences about what works well between them",'
            '"challenges":"1-2 sentences about what to watch out for"}'
        )

        raw = _ollama_generate(prompt, max_tokens=500)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s × %s — bad response", s1, s2)
            continue

        compat_data = {
            "sign1": s1,
            "sign2": s2,
            "score": score,
            "description": data.get("description", ""),
            "love_advice": data.get("love_advice", ""),
            "strengths_together": data.get("strengths_together", data.get("strengths", "")),
            "challenges": data.get("challenges", ""),
        }

        if save_compatibility(db, compat_data):
            log.info("  [OK] %s × %s", s1, s2)
            generated += 1
        else:
            log.error("  [FAIL] %s × %s — DB error", s1, s2)

    log.info("Compatibility: %d/%d generated", generated, total_expected)
    return generated


STORY_CATEGORIES = ["Planetary", "Weekly", "Relationships", "Rituals", "Career", "Spiritual"]


def populate_stories(db, force: bool = False) -> int:
    generated = 0

    existing_count = story_count(db)
    log.info("Stories in DB: %d", existing_count)

    if existing_count >= len(STORY_CATEGORIES) and not force:
        log.info("Stories already populated — skipping (use --force to regenerate)")
        return 0

    if force:
        deleted = delete_all_stories(db)
        log.info("Deleted %d existing stories", deleted)

    for category in STORY_CATEGORIES:
        log.info("  [GEN] Story: %s ...", category)
        prompt = (
            f"You are an astrology writer for the CosmicGuide app. "
            f"Write an engaging {category} astrology article.\n\n"
            f"Category: {category}\n"
            "Requirements:\n"
            "- 300-400 words, educational yet mystical tone\n"
            "- Practical insights readers can act on\n"
            "- Reference current cosmic energy and planetary influences\n\n"
            "Return ONLY valid JSON with these exact keys:\n"
            '{"title":"Compelling headline (8-12 words)",'
            '"summary":"One-sentence teaser under 20 words",'
            '"content":"Full article text (300-400 words)",'
            '"read_time":"X min"}'
        )

        raw = _ollama_generate(prompt, max_tokens=1200)
        data = _parse_json(raw, log_error=False)
        if not isinstance(data, dict):
            data = _extract_story_fields(raw)
            if isinstance(data, dict):
                log.warning("  [RECOVER] Story %s — parsed via fallback field extraction", category)
            else:
                # Only emit hard parse error if we could not recover.
                _parse_json(raw, log_error=True)
        if not isinstance(data, dict):
            log.error("  [FAIL] Story %s — bad response", category)
            continue

        story_data = {
            "title": data.get("title", f"{category} Cosmic Insights"),
            "summary": data.get("summary", ""),
            "content": data.get("content", ""),
            "category": category,
            "read_time": data.get("read_time", "4 min"),
            "author": "CosmicGuide",
            "is_featured": category in ("Planetary", "Weekly"),
        }

        if save_story(db, story_data):
            log.info("  [OK] '%s'", story_data["title"])
            generated += 1
        else:
            log.error("  [FAIL] Story %s — DB error", category)

    log.info("Stories: %d/%d generated", generated, len(STORY_CATEGORIES))
    return generated


# ── Seed (static data, no LLM) ───────────────────────────────────────────────

def seed_tarot(db, force: bool = False) -> int:
    from database.models import TarotCard
    existing = db.query(TarotCard).count()
    if existing >= len(TAROT_CARDS) and not force:
        log.info("Tarot: already seeded (%d cards) — skip", existing)
        return 0
    if force:
        db.query(TarotCard).delete()
        db.flush()
    inserted = 0
    for card in TAROT_CARDS:
        try:
            db.add(TarotCard(
                name=card["name"], number=card["number"], meaning=card["meaning"],
                upright_interpretation=card["upright"], reversed_interpretation=card["reversed"],
            ))
            inserted += 1
        except Exception as exc:
            log.warning("Tarot skip '%s': %s", card["name"], exc)
    db.commit()
    log.info("Tarot: seeded %d cards", inserted)
    return inserted


def seed_compatibility(db, force: bool = False) -> int:
    from database.models import Compatibility
    existing = db.query(Compatibility).count()
    if existing >= len(SIGN_PAIR_SCORES) and not force:
        log.info("Compatibility: already seeded (%d pairs) — skip", existing)
        return 0
    if force:
        db.query(Compatibility).delete()
        db.flush()
    inserted = 0
    for (s1, s2), score in SIGN_PAIR_SCORES.items():
        try:
            db.add(Compatibility(
                sign1=s1, sign2=s2, score=score,
                description=f"{s1} and {s2} have a compatibility score of {score}/100.",
            ))
            inserted += 1
        except Exception as exc:
            log.warning("Compatibility skip %s/%s: %s", s1, s2, exc)
    db.commit()
    log.info("Compatibility: seeded %d pairs", inserted)
    return inserted


# ── Summary ───────────────────────────────────────────────────────────────────

def print_status(db, target_date: date):
    status = get_content_status(db, target_date)
    log.info("=" * 60)
    log.info("DB Content Status for %s", status["date"])
    log.info("-" * 60)
    log.info("  Horoscopes:     %d / %d", status["horoscopes"]["count"], status["horoscopes"]["expected"])
    log.info("  Fortune Pool:   %d / %d", status["fortune_pool"]["count"], status["fortune_pool"]["expected"])
    log.info("  Stories Today:  %d", status["stories_today"])
    log.info("  Compatibility:  %d / %d", status["compatibility_pairs"]["count"], status["compatibility_pairs"]["expected"])
    log.info("  Tarot Cards:    %d / %d", status["tarot_cards"]["count"], status["tarot_cards"]["expected"])
    log.info("-" * 60)
    log.info("  Fully populated: %s", "YES" if status["fully_populated"] else "NO")
    log.info("=" * 60)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Populate CosmicGuide DB with AI-generated content via Ollama"
    )
    parser.add_argument("--horoscopes", action="store_true", help="Generate horoscopes")
    parser.add_argument("--tarot", action="store_true", help="Generate tarot card interpretations")
    parser.add_argument("--fortunes", action="store_true", help="Generate fortune pools")
    parser.add_argument("--compatibility", action="store_true", help="Generate compatibility descriptions")
    parser.add_argument("--stories", action="store_true", help="Generate cosmic stories")
    parser.add_argument("--seed", action="store_true", help="Seed static data (tarot cards + compatibility scores)")
    parser.add_argument("--force", action="store_true", help="Regenerate even if data exists")
    parser.add_argument("--date", type=str, default=None,
                        help="Target date (YYYY-MM-DD), defaults to today")
    parser.add_argument("--status", action="store_true", help="Print DB content status and exit")
    args = parser.parse_args()

    target_date = date.fromisoformat(args.date) if args.date else date.today()
    run_all = not any([args.horoscopes, args.tarot, args.fortunes,
                       args.compatibility, args.stories, args.seed, args.status])

    db = SessionLocal()

    if args.status:
        print_status(db, target_date)
        db.close()
        return

    log.info("Database: %s", DATABASE_URL.split("@")[-1] if "@" in DATABASE_URL else DATABASE_URL)
    log.info("Checking Ollama at %s ...", OLLAMA_HOST)

    # Seed doesn't need Ollama
    if args.seed:
        log.info("━━━ SEED STATIC DATA ━━━")
        seed_tarot(db, args.force)
        seed_compatibility(db, args.force)
        log.info("Done!")
        print_status(db, target_date)
        db.close()
        return

    if not _check_ollama():
        log.error("Ollama is not reachable at %s — aborting", OLLAMA_HOST)
        db.close()
        sys.exit(1)

    log.info("Target date: %s  Model: %s  Force: %s",
             target_date.isoformat(), OLLAMA_MODEL, args.force)
    log.info("=" * 60)

    t0 = time.perf_counter()

    try:
        if run_all or args.horoscopes:
            log.info("━━━ HOROSCOPES ━━━")
            populate_horoscopes(db, target_date, args.force)
            log.info("")

        if run_all or args.tarot:
            log.info("━━━ TAROT CARDS ━━━")
            populate_tarot(db, args.force)
            log.info("")

        if run_all or args.fortunes:
            log.info("━━━ FORTUNE POOL ━━━")
            populate_fortunes(db, target_date, args.force)
            log.info("")

        if run_all or args.compatibility:
            log.info("━━━ COMPATIBILITY ━━━")
            populate_compatibility(db, args.force)
            log.info("")

        if run_all or args.stories:
            log.info("━━━ STORIES ━━━")
            populate_stories(db, args.force)
            log.info("")

        elapsed = time.perf_counter() - t0
        log.info("All done in %.1f seconds", elapsed)
        print_status(db, target_date)
    finally:
        db.close()


if __name__ == "__main__":
    main()
