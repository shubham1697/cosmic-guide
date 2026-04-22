#!/usr/bin/env python3
"""
Daily content population script for CosmicGuide.

This script generates all daily AI content and stores it in the content
database (local SQLite or remote PostgreSQL).  Run it once daily via cron.

What it generates:
  1. Horoscopes for all 12 zodiac signs        — 1 Gemini call  (batch)
  2. Fortune pool (12 signs × 5 topics × 3)    — 2 Gemini calls (6 signs each)
  3. Cosmic stories (5 articles)                — 1 Gemini call
  4. Compatibility pairs (78 unique, one-time)  — 4 Gemini calls (~20 pairs each)
  5. Tarot cards (78 cards, one-time)           — 0 calls (static data) + optional 3 AI calls

Total daily calls: ~4  |  One-time seeding: ~4-7 additional calls

Usage:
  # Generate today's content
  python populate_daily.py

  # Generate for a specific date
  python populate_daily.py --date 2026-04-23

  # Include one-time seeding (tarot + compatibility)
  python populate_daily.py --seed-oneshot

  # Dry run — show what would be generated
  python populate_daily.py --dry-run

  # Force regenerate even if data exists
  python populate_daily.py --force
"""

import argparse
import sys
import json
from datetime import date, datetime

# Ensure backend/ is on the path
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import settings
from logger import configure_logging, get_logger
from db.content_db import get_content_session, create_content_tables
from services.content_db_service import (
    horoscopes_exist, save_horoscope,
    fortune_pool_exists, save_fortune_pool,
    get_today_story_count, save_story,
    compatibility_pairs_exist, save_compatibility,
    tarot_count, get_content_status,
)
from services.ai_service import (
    generate_all_horoscopes,
    generate_fortune_pool,
    generate_daily_stories,
    generate_batch_compatibility,
    generate_batch_tarot_interpretations,
    ai_available,
)
from services.zodiac_service import ZODIAC_SIGNS
from services.ai_prompts import FORTUNE_TOPICS
from data.tarot_data import TAROT_CARDS
from data.compatibility_data import SIGN_PAIR_SCORES

configure_logging()
logger = get_logger("populate_daily")


def populate_horoscopes(db, for_date: date, force: bool = False) -> dict:
    """Generate and store horoscopes for all 12 signs."""
    result = {"generated": [], "skipped": [], "failed": []}
    date_str = for_date.isoformat()

    existing = horoscopes_exist(db, for_date)
    if not force:
        result["skipped"] = sorted(existing)
        signs_needed = [s for s in ZODIAC_SIGNS if s not in existing]
    else:
        signs_needed = list(ZODIAC_SIGNS)

    if not signs_needed:
        logger.info("Horoscopes: all 12 signs already exist for %s", date_str)
        return result

    logger.info("Generating horoscopes for %d signs on %s ...", len(signs_needed), date_str)
    all_data = generate_all_horoscopes(for_date)

    if not all_data:
        result["failed"] = signs_needed
        logger.error("Horoscope generation FAILED for %s", date_str)
        return result

    for sign in signs_needed:
        hdata = all_data.get(sign)
        if not hdata:
            result["failed"].append(sign)
            continue
        if save_horoscope(db, hdata):
            result["generated"].append(sign)
        else:
            result["failed"].append(sign)

    db.commit()
    logger.info("Horoscopes: generated=%d skipped=%d failed=%d",
                len(result["generated"]), len(result["skipped"]), len(result["failed"]))
    return result


def populate_fortune_pool(db, for_date: date, force: bool = False) -> dict:
    """Generate fortune pools for all 12 signs × 5 topics."""
    result = {"generated": 0, "skipped": 0, "failed": 0}

    existing = fortune_pool_exists(db, for_date) if not force else set()
    result["skipped"] = len(existing)

    signs_needing_pool = [
        s for s in ZODIAC_SIGNS
        if any((s, t) not in existing for t in FORTUNE_TOPICS)
    ]

    if not signs_needing_pool:
        logger.info("Fortune pool: all 60 combos already exist for %s", for_date.isoformat())
        return result

    # Split into 2 batches of 6 signs
    half = len(signs_needing_pool) // 2 or len(signs_needing_pool)
    batches = [signs_needing_pool[:half], signs_needing_pool[half:]]
    batches = [b for b in batches if b]

    for batch_num, batch in enumerate(batches, 1):
        logger.info("Fortune pool batch %d: signs=%s ...", batch_num, batch)
        pool_data = generate_fortune_pool(batch, for_date)

        if not pool_data:
            result["failed"] += len(batch) * len(FORTUNE_TOPICS)
            logger.error("Fortune pool batch %d FAILED", batch_num)
            continue

        for sign, topics in pool_data.items():
            for topic, fortunes in topics.items():
                if (sign, topic) in existing:
                    result["skipped"] += 1
                    continue
                if save_fortune_pool(db, for_date, sign, topic, fortunes):
                    result["generated"] += 1
                else:
                    result["failed"] += 1

    db.commit()
    logger.info("Fortune pool: generated=%d skipped=%d failed=%d",
                result["generated"], result["skipped"], result["failed"])
    return result


def populate_stories(db, for_date: date, count: int = 5, force: bool = False) -> dict:
    """Generate daily cosmic stories."""
    result = {"generated": 0, "failed": False}

    existing_count = get_today_story_count(db, for_date)
    if existing_count >= count and not force:
        logger.info("Stories: %d already exist for %s", existing_count, for_date.isoformat())
        result["skipped"] = existing_count
        return result

    logger.info("Generating %d stories for %s ...", count, for_date.isoformat())
    stories_data = generate_daily_stories(for_date, count=count)

    if not stories_data:
        result["failed"] = True
        logger.error("Story generation FAILED for %s", for_date.isoformat())
        return result

    for story in stories_data:
        if save_story(db, story):
            result["generated"] += 1

    db.commit()
    logger.info("Stories: generated=%d", result["generated"])
    return result


def seed_compatibility(db, force: bool = False) -> dict:
    """One-time: generate all 78 unique compatibility pairs via AI."""
    result = {"generated": 0, "skipped": 0, "failed": 0}

    existing = compatibility_pairs_exist(db) if not force else set()
    result["skipped"] = len(existing)

    # Build all unique pairs
    unique_pairs = []
    for i, s1 in enumerate(ZODIAC_SIGNS):
        for s2 in ZODIAC_SIGNS[i:]:
            unique_pairs.append((s1, s2))

    pairs_needed = [p for p in unique_pairs if p not in existing]
    if not pairs_needed:
        logger.info("Compatibility: all %d pairs already exist", len(existing))
        return result

    logger.info("Generating compatibility for %d pairs ...", len(pairs_needed))

    # Get scores from static data
    from services.compatibility_service import get_pair_score
    pair_dicts = [
        {"sign1": s1, "sign2": s2, "score": get_pair_score(s1, s2)}
        for s1, s2 in pairs_needed
    ]

    # Process in batches of 20
    batch_size = 20
    for i in range(0, len(pair_dicts), batch_size):
        batch = pair_dicts[i:i + batch_size]
        logger.info("Compatibility batch %d/%d (%d pairs) ...",
                     i // batch_size + 1, (len(pair_dicts) + batch_size - 1) // batch_size, len(batch))

        ai_results = generate_batch_compatibility(batch)
        if not ai_results:
            result["failed"] += len(batch)
            continue

        for item in ai_results:
            s1 = item.get("sign1", "")
            s2 = item.get("sign2", "")
            if not s1 or not s2:
                result["failed"] += 1
                continue
            sc = next((p["score"] for p in batch if p["sign1"] == s1 and p["sign2"] == s2), 70)
            item["score"] = sc
            if save_compatibility(db, item):
                result["generated"] += 1
            else:
                result["failed"] += 1

    db.commit()
    logger.info("Compatibility: generated=%d skipped=%d failed=%d",
                result["generated"], result["skipped"], result["failed"])
    return result


def seed_tarot(db, upgrade_with_ai: bool = False) -> dict:
    """One-time: seed tarot cards from static data, optionally AI-upgrade."""
    result = {"seeded": 0, "ai_upgraded": 0, "skipped": 0, "failed": 0}

    existing = tarot_count(db)
    if existing >= len(TAROT_CARDS):
        result["skipped"] = existing
        logger.info("Tarot: all %d cards already in DB", existing)
        return result

    logger.info("Seeding %d tarot cards from static data ...", len(TAROT_CARDS))
    from services.tarot_service import seed_tarot_db
    result["seeded"] = seed_tarot_db(db)

    if upgrade_with_ai:
        from db.models import TarotCard
        cards_in_db = {row.name: row for row in db.query(TarotCard).all()}
        chunk_size = 26
        cards_list = [{"name": c["name"], "number": c["number"], "meaning": c["meaning"]}
                      for c in TAROT_CARDS]

        for i in range(0, len(cards_list), chunk_size):
            chunk = cards_list[i:i + chunk_size]
            logger.info("AI-upgrading tarot batch %d/%d ...",
                         i // chunk_size + 1, (len(cards_list) + chunk_size - 1) // chunk_size)
            ai_results = generate_batch_tarot_interpretations(chunk)
            if not ai_results:
                result["failed"] += len(chunk)
                continue
            for item in ai_results:
                row = cards_in_db.get(item["name"])
                if row and item.get("upright_interpretation"):
                    row.upright_interpretation = item["upright_interpretation"]
                    row.reversed_interpretation = item["reversed_interpretation"]
                    result["ai_upgraded"] += 1

        db.commit()

    logger.info("Tarot: seeded=%d ai_upgraded=%d", result["seeded"], result["ai_upgraded"])
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Populate CosmicGuide content database with LLM-generated data"
    )
    parser.add_argument("--date", type=str, default=None,
                        help="Target date (YYYY-MM-DD). Defaults to today.")
    parser.add_argument("--seed-oneshot", action="store_true",
                        help="Also run one-time seeding (tarot + compatibility)")
    parser.add_argument("--upgrade-tarot-ai", action="store_true",
                        help="AI-upgrade tarot interpretations (requires --seed-oneshot)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be generated without doing it")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate even if data already exists")
    parser.add_argument("--stories-count", type=int, default=5,
                        help="Number of stories to generate (default: 5)")

    args = parser.parse_args()
    for_date = date.fromisoformat(args.date) if args.date else date.today()

    logger.info("=" * 60)
    logger.info("CosmicGuide Daily Content Population")
    logger.info("Date: %s  |  Force: %s  |  Seed: %s",
                for_date.isoformat(), args.force, args.seed_oneshot)
    logger.info("=" * 60)

    # Ensure tables exist
    create_content_tables()
    db = get_content_session()

    if args.dry_run:
        status = get_content_status(db, for_date)
        logger.info("Current content status:\n%s", json.dumps(status, indent=2))
        db.close()
        return

    # Check AI availability
    if not ai_available():
        logger.error("AI service is not available (check GEMINI_API_KEY). Aborting.")
        db.close()
        sys.exit(1)

    results = {}

    try:
        # ── Daily content ────────────────────────────────────────────────────
        results["horoscopes"] = populate_horoscopes(db, for_date, args.force)
        results["fortune_pool"] = populate_fortune_pool(db, for_date, args.force)
        results["stories"] = populate_stories(db, for_date, args.stories_count, args.force)

        # ── One-time seeding ─────────────────────────────────────────────────
        if args.seed_oneshot:
            results["tarot"] = seed_tarot(db, args.upgrade_tarot_ai)
            results["compatibility"] = seed_compatibility(db, args.force)

        # ── Final status ─────────────────────────────────────────────────────
        results["final_status"] = get_content_status(db, for_date)

    except Exception as exc:
        logger.error("Population failed: %s", exc, exc_info=True)
        db.rollback()
    finally:
        db.close()

    logger.info("=" * 60)
    logger.info("Population complete. Summary:")
    logger.info(json.dumps(results, indent=2, default=str))
    logger.info("=" * 60)

    # Exit with error code if anything critical failed
    horoscope_fails = len(results.get("horoscopes", {}).get("failed", []))
    if horoscope_fails > 6:  # more than half failed
        sys.exit(1)


if __name__ == "__main__":
    main()
