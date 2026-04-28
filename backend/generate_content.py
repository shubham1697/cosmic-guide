#!/usr/bin/env python3
"""
Generate AI content for CosmicGuide using a local Ollama instance.

Generates content ONE item at a time (not in batches) to stay within
Ollama's response time limits. Uses the same working pattern as seed_stories.py.

What it generates:
  - Horoscopes: 12 signs, one at a time
  - Stories: 6 categories via story_service (already works)
  - Fortunes: 12 signs × 5 topics, one at a time
  - Compatibility descriptions: 78 pairs, one at a time

Usage:
    python generate_content.py                    # run everything
    python generate_content.py --horoscopes       # horoscopes only
    python generate_content.py --stories          # stories only
    python generate_content.py --fortunes         # fortune pool only
    python generate_content.py --compatibility    # compatibility descriptions only
    python generate_content.py --force            # regenerate even if data exists
"""
import sys
import os
import json
import argparse
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import logger
logger.configure_logging()
from logger import get_logger
log = get_logger("generate_content")

from config import settings
from db.database import engine, SessionLocal
from db.models import Base, Horoscope, FortunePool, Compatibility
from data.zodiac_data import ZODIAC_SIGNS
from data.fortune_options import FORTUNE_TOPICS
from data.compatibility_data import SIGN_PAIR_SCORES
from services.story_service import seed_stories_db

Base.metadata.create_all(engine)

# ── Ollama helper (same approach as seed_stories.py — works reliably) ─────────

def _ollama(prompt: str) -> str | None:
    """Call Ollama /api/chat with streaming and return the full reply, or None."""
    import http.client
    import socket

    payload = json.dumps({
        "model": settings.OLLAMA_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": True,
        "options": {"num_predict": 600, "temperature": 0.8},
    }).encode()

    url_parts = settings.OLLAMA_BASE_URL.rstrip("/")
    host = url_parts.replace("http://", "").replace("https://", "")
    try:
        conn = http.client.HTTPConnection(host, timeout=settings.OLLAMA_TIMEOUT)
        conn.request("POST", "/api/chat",
                     body=payload,
                     headers={"Content-Type": "application/json"})
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
        return "".join(parts).strip()
    except Exception as exc:
        log.error("Ollama error: %s", exc)
        return None


def _parse_json(raw: str) -> dict | list | None:
    """Strip markdown fences and parse JSON."""
    if not raw:
        return None
    raw = raw.strip()
    # Strip ```json ... ``` or ``` ... ```
    if raw.startswith("```"):
        raw = raw.split("```", 2)[-1] if raw.count("```") >= 2 else raw
        raw = raw.lstrip("json").strip()
        if raw.endswith("```"):
            raw = raw[:-3].strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        log.error("JSON parse error: %s | raw[:200]: %s", exc, raw[:200])
        return None


def _check_ollama() -> bool:
    """Verify Ollama is reachable before starting."""
    import http.client
    host = settings.OLLAMA_BASE_URL.rstrip("/").replace("http://", "").replace("https://", "")
    try:
        conn = http.client.HTTPConnection(host, timeout=5)
        conn.request("GET", "/api/tags")
        resp = conn.getresponse()
        conn.close()
        return resp.status == 200
    except Exception:
        return False


# ── Content generators ────────────────────────────────────────────────────────

def generate_horoscopes(db, today: date, force: bool = False) -> int:
    date_str = today.isoformat()
    day_name = today.strftime("%A, %B %d, %Y")
    generated = 0

    for sign in ZODIAC_SIGNS:
        exists = (
            db.query(Horoscope)
            .filter_by(date=date_str, zodiac_sign=sign)
            .first()
        )
        if exists and not force:
            log.info("  %s: exists, skipping", sign)
            continue

        log.info("  Generating horoscope for %s ...", sign)
        prompt = (
            f"Generate a daily horoscope for {sign} for {day_name}.\n"
            "Return ONLY valid JSON, no markdown fences, with these exact keys:\n"
            f'{{"zodiac_sign":"{sign}","date":"{date_str}","general":"2-3 uplifting sentences",'
            '"love":"1-2 sentences","career":"1-2 sentences","health":"1-2 sentences",'
            '"overall_score":<integer 65-95>,"lucky_number":<integer 1-99>,'
            '"lucky_color":"one color word","mood":"one positive word"}}'
        )

        raw = _ollama(prompt)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  %s: bad response", sign)
            continue

        try:
            if exists and force:
                db.delete(exists)
                db.flush()
            db.add(Horoscope(
                date=date_str,
                zodiac_sign=sign,
                general=data.get("general", ""),
                love=data.get("love", ""),
                career=data.get("career", ""),
                health=data.get("health", ""),
                overall_score=int(data.get("overall_score", 75)),
                lucky_number=int(data.get("lucky_number", 7)),
                lucky_color=str(data.get("lucky_color", "blue")),
                mood=str(data.get("mood", "positive")),
            ))
            db.commit()
            log.info("  %s: done", sign)
            generated += 1
        except Exception as exc:
            log.error("  %s: DB error: %s", sign, exc)
            db.rollback()

    log.info("Horoscopes: %d / %d generated", generated, len(ZODIAC_SIGNS))
    return generated


def generate_fortunes(db, today: date, force: bool = False) -> int:
    date_str = today.isoformat()
    generated = 0
    total = len(ZODIAC_SIGNS) * len(FORTUNE_TOPICS)

    for sign in ZODIAC_SIGNS:
        for topic in FORTUNE_TOPICS:
            exists = (
                db.query(FortunePool)
                .filter_by(date=date_str, zodiac_sign=sign, topic=topic)
                .first()
            )
            if exists and not force:
                continue

            log.info("  Fortune %s / %s ...", sign, topic)
            prompt = (
                f"Generate exactly 3 short {topic} fortune messages for {sign} today.\n"
                "Return ONLY a valid JSON array of 3 strings, each 10-20 words.\n"
                'Example: ["You will find joy in small things.", "Trust your instincts today.", "A new opportunity is near."]'
            )

            raw = _ollama(prompt)
            data = _parse_json(raw)
            if not isinstance(data, list) or len(data) < 1:
                log.error("  Fortune %s/%s: bad response", sign, topic)
                continue

            try:
                if exists and force:
                    db.delete(exists)
                    db.flush()
                db.add(FortunePool(
                    date=date_str,
                    zodiac_sign=sign,
                    topic=topic,
                    fortunes=[str(f) for f in data[:3]],
                ))
                db.commit()
                generated += 1
            except Exception as exc:
                log.error("  Fortune %s/%s DB error: %s", sign, topic, exc)
                db.rollback()

    log.info("Fortunes: %d / %d generated", generated, total)
    return generated


def generate_compatibility_descriptions(db, force: bool = False) -> int:
    generated = 0

    for (s1, s2), score in SIGN_PAIR_SCORES.items():
        exists = (
            db.query(Compatibility)
            .filter_by(sign1=s1, sign2=s2)
            .first()
        )
        # Skip if already has a real AI description (>50 chars)
        if exists and exists.description and len(exists.description) > 50 and not force:
            continue

        log.info("  Compatibility %s / %s ...", s1, s2)
        prompt = (
            f"Write a compatibility profile for {s1} and {s2} (score: {score}/100).\n"
            "Return ONLY valid JSON, no markdown fences:\n"
            '{"description":"2-3 sentences about their overall dynamic",'
            '"love_advice":"1-2 practical sentences of relationship advice",'
            '"strengths":"1-2 sentences about what works well",'
            '"challenges":"1-2 sentences about what to watch out for"}'
        )

        raw = _ollama(prompt)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  Compatibility %s/%s: bad response", s1, s2)
            continue

        try:
            if exists:
                exists.description = data.get("description", exists.description)
                exists.love_advice = data.get("love_advice", "")
                exists.strengths = data.get("strengths", "")
                exists.challenges = data.get("challenges", "")
            else:
                db.add(Compatibility(
                    sign1=s1, sign2=s2, score=score,
                    description=data.get("description", ""),
                    love_advice=data.get("love_advice", ""),
                    strengths=data.get("strengths", ""),
                    challenges=data.get("challenges", ""),
                ))
            db.commit()
            generated += 1
        except Exception as exc:
            log.error("  Compatibility %s/%s DB error: %s", s1, s2, exc)
            db.rollback()

    log.info("Compatibility: %d descriptions generated", generated)
    return generated


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate AI content for CosmicGuide via Ollama")
    parser.add_argument("--horoscopes", action="store_true", help="Generate horoscopes")
    parser.add_argument("--stories", action="store_true", help="Generate stories")
    parser.add_argument("--fortunes", action="store_true", help="Generate fortune pool")
    parser.add_argument("--compatibility", action="store_true", help="Generate compatibility descriptions")
    parser.add_argument("--force", action="store_true", help="Regenerate even if data already exists")
    args = parser.parse_args()

    run_all = not any([args.horoscopes, args.stories, args.fortunes, args.compatibility])

    log.info("Checking Ollama at %s ...", settings.OLLAMA_BASE_URL)
    if not _check_ollama():
        log.error("Ollama is not reachable at %s — aborting", settings.OLLAMA_BASE_URL)
        sys.exit(1)
    log.info("Ollama OK  model=%s", settings.OLLAMA_MODEL)

    today = date.today()
    db = SessionLocal()
    try:
        if run_all or args.horoscopes:
            log.info("--- Horoscopes ---")
            generate_horoscopes(db, today, args.force)

        if run_all or args.stories:
            log.info("--- Stories ---")
            if args.force:
                from db.models import Story
                db.query(Story).delete()
                db.commit()
            n = seed_stories_db(db)
            log.info("Stories: %d generated", n)

        if run_all or args.fortunes:
            log.info("--- Fortunes ---")
            generate_fortunes(db, today, args.force)

        if run_all or args.compatibility:
            log.info("--- Compatibility descriptions ---")
            generate_compatibility_descriptions(db, args.force)

    finally:
        db.close()

    log.info("All done!")


if __name__ == "__main__":
    main()
