import logging
import time
from datetime import date

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from logger import configure_logging, get_logger
from db.database import engine, Base, get_db
from api import horoscope, tarot, fortune, compatibility, kundli, stories, chart, vedic

# Boot logging before anything else
configure_logging()
logger = get_logger(__name__)

logger.info("CosmicGuide API starting up — log_level=%s  ai_model=%s",
            settings.LOG_LEVEL, settings.AI_MODEL)

# Create database tables
Base.metadata.create_all(bind=engine)

# Initialize FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / response logging middleware ─────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    method = request.method
    path = request.url.path
    query = str(request.url.query)

    logger.info("→ %s %s%s", method, path, f"?{query}" if query else "")
    logger.debug("  client=%s", request.client.host if request.client else "unknown")

    response = await call_next(request)

    elapsed_ms = (time.perf_counter() - start) * 1000
    level = logging.WARNING if elapsed_ms > 5000 else logging.INFO
    logger.log(
        level,
        "← %s %s  status=%d  %.0fms",
        method, path, response.status_code, elapsed_ms,
    )
    return response


# Global error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        "⚠️  Unhandled error on %s %s: %s | exc_type=%s",
        request.method, request.url.path, exc, type(exc).__name__,
        exc_info=True,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "An internal server error occurred."},
    )


# Health check
@app.get("/health", tags=["Health"])
def health_check():
    from services.ai_service import ai_available
    ai = ai_available()
    logger.debug("Health check — ai_enabled=%s", ai)
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "log_level": settings.LOG_LEVEL,
        "ai_enabled": ai,
    }


# Content status endpoint — check what's pre-populated
@app.get("/admin/content-status", tags=["Admin"])
def content_status(target_date: str = None):
    """Check what content is available in the DB for the given date."""
    from db.database import SessionLocal
    from db.models import Horoscope, FortunePool, Story, Compatibility, TarotCard

    for_date = date.fromisoformat(target_date) if target_date else date.today()
    date_str = for_date.isoformat()
    db = SessionLocal()
    try:
        horoscope_signs = {
            r.zodiac_sign for r in
            db.query(Horoscope.zodiac_sign).filter(Horoscope.date == date_str).all()
        }
        pool_combos = {
            (r.zodiac_sign, r.topic) for r in
            db.query(FortunePool.zodiac_sign, FortunePool.topic).filter(FortunePool.date == date_str).all()
        }
        story_count = db.query(Story).count()
        compat_count = db.query(Compatibility).count()
        tarot_ct = db.query(TarotCard).count()

        return {
            "date": date_str,
            "horoscopes": {"count": len(horoscope_signs), "expected": 12, "signs": sorted(horoscope_signs)},
            "fortune_pool": {"count": len(pool_combos), "expected": 60},
            "stories": story_count,
            "compatibility_pairs": {"count": compat_count, "expected": 78},
            "tarot_cards": {"count": tarot_ct, "expected": 78},
            "fully_populated": (
                len(horoscope_signs) >= 12
                and len(pool_combos) >= 60
                and story_count >= 3
                and compat_count >= 78
                and tarot_ct >= 78
            ),
        }
    finally:
        db.close()


# ── Admin: refresh all daily AI content ──────────────────────────────────────
@app.post("/admin/refresh-daily", tags=["Admin"])
def refresh_daily_content(target_date: str = None):
    """
    Generate and cache AI content for the given date (defaults to today).
    Call this once daily — e.g. from a cron job at 00:05.

    LLM calls made (4 total):
      1. All 12 horoscopes        — 1 call (batch_horoscope_prompt)
      2. 5 cosmic stories         — 1 call (daily_stories_prompt)
      3. Fortune pool signs 1-6   — 1 call (batch_fortune_pool_prompt)
      4. Fortune pool signs 7-12  — 1 call (batch_fortune_pool_prompt)

    Returns a summary of what was generated / skipped / failed.
    """
    from sqlalchemy.orm import Session
    from db.database import SessionLocal
    from db.models import Horoscope, Story, FortunePool
    from services.ai_service import (
        generate_all_horoscopes,
        generate_daily_stories,
        generate_fortune_pool,
    )
    from services.zodiac_service import ZODIAC_SIGNS
    from services.ai_prompts import FORTUNE_TOPICS

    for_date = date.fromisoformat(target_date) if target_date else date.today()
    date_str = for_date.isoformat()
    db: Session = SessionLocal()

    result = {
        "date": date_str,
        "horoscopes": {"generated": [], "skipped": [], "failed": []},
        "stories": {"generated": 0, "failed": False},
        "fortune_pool": {"generated": 0, "skipped": 0, "failed": 0},
    }

    try:
        # ── 1. Horoscopes (1 LLM call for all 12 signs) ─────────────────────
        existing_signs = {
            row.zodiac_sign
            for row in db.query(Horoscope.zodiac_sign)
            .filter(Horoscope.date == date_str)
            .all()
        }
        signs_needed = [s for s in ZODIAC_SIGNS if s not in existing_signs]

        if not signs_needed:
            result["horoscopes"]["skipped"] = list(ZODIAC_SIGNS)
        else:
            result["horoscopes"]["skipped"] = list(existing_signs)
            all_data = generate_all_horoscopes(for_date)
            if all_data:
                for sign in signs_needed:
                    hdata = all_data.get(sign)
                    if not hdata:
                        result["horoscopes"]["failed"].append(sign)
                        continue
                    try:
                        db.add(Horoscope(
                            date=date_str,
                            zodiac_sign=sign,
                            general=hdata["general"],
                            love=hdata["love"],
                            career=hdata["career"],
                            health=hdata["health"],
                            overall_score=hdata["overall_score"],
                            lucky_number=hdata["lucky_number"],
                            lucky_color=hdata["lucky_color"],
                            mood=hdata["mood"],
                        ))
                        result["horoscopes"]["generated"].append(sign)
                    except Exception as exc:
                        logger.error("Failed to save horoscope for %s: %s", sign, exc)
                        result["horoscopes"]["failed"].append(sign)
                db.commit()
            else:
                result["horoscopes"]["failed"] = signs_needed

        # ── 2. Stories (1 LLM call for 5 articles) ──────────────────────────
        stories_data = generate_daily_stories(for_date, count=5)
        if stories_data:
            for story in stories_data:
                try:
                    db.add(Story(
                        title=story["title"],
                        summary=story["summary"],
                        content=story["content"],
                        category=story["category"],
                        read_time=story["read_time"],
                        author=story.get("author", "CosmicGuide"),
                    ))
                    result["stories"]["generated"] += 1
                except Exception as exc:
                    logger.error("Failed to save story: %s", exc)
            db.commit()
        else:
            result["stories"]["failed"] = True

        # ── 3 & 4. Fortune pool (2 LLM calls — 6 signs each) ────────────────
        # Check which sign+topic combos already have a pool for today
        existing_pool = {
            (row.zodiac_sign, row.topic)
            for row in db.query(FortunePool.zodiac_sign, FortunePool.topic)
            .filter(FortunePool.date == date_str)
            .all()
        }
        signs_needing_pool = [
            s for s in ZODIAC_SIGNS
            if any((s, t) not in existing_pool for t in FORTUNE_TOPICS)
        ]

        if not signs_needing_pool:
            result["fortune_pool"]["skipped"] = len(ZODIAC_SIGNS) * len(FORTUNE_TOPICS)
        else:
            # Split into 2 batches of 6 signs
            half = len(signs_needing_pool) // 2 or len(signs_needing_pool)
            batches = [signs_needing_pool[:half], signs_needing_pool[half:]]
            batches = [b for b in batches if b]  # drop empty

            for batch in batches:
                pool_data = generate_fortune_pool(batch, for_date)
                if not pool_data:
                    result["fortune_pool"]["failed"] += len(batch) * len(FORTUNE_TOPICS)
                    continue
                for sign, topics in pool_data.items():
                    for topic, fortunes in topics.items():
                        if (sign, topic) in existing_pool:
                            result["fortune_pool"]["skipped"] += 1
                            continue
                        try:
                            db.add(FortunePool(
                                date=date_str,
                                zodiac_sign=sign,
                                topic=topic,
                                fortunes=fortunes,
                            ))
                            result["fortune_pool"]["generated"] += 1
                        except Exception as exc:
                            logger.error("Failed to save fortune pool %s/%s: %s", sign, topic, exc)
                            result["fortune_pool"]["failed"] += 1
            db.commit()

    except Exception as exc:
        logger.error("refresh_daily_content error: %s", exc)
        db.rollback()
    finally:
        db.close()

    return result


# ── Admin: one-shot seeding (tarot + all compatibility pairs) ─────────────────
@app.post("/admin/seed-oneshot", tags=["Admin"])
def seed_oneshot_content(upgrade_tarot_with_ai: bool = False):
    """
    Seed permanent content that only needs to be generated once:

    - Tarot cards: seeded from static data instantly (no LLM).
      Set upgrade_tarot_with_ai=true to queue AI-quality interpretations
      (adds ~3 LLM calls for all 78 cards in groups of 26).

    - Compatibility pairs: generates all 78 unique sign pairs via AI
      (4 LLM calls of ~20 pairs each).

    Safe to call multiple times — already-seeded data is skipped.
    """
    from sqlalchemy.orm import Session
    from db.database import SessionLocal
    from db.models import TarotCard, Compatibility
    from services.tarot_service import seed_tarot_db, TAROT_CARDS
    from services.compatibility_service import ELEMENT_COMPATIBILITY, get_pair_score
    from services.zodiac_service import ZODIAC_SIGNS, ZODIAC_ELEMENTS
    from services.ai_service import generate_batch_compatibility, generate_batch_tarot_interpretations

    db: Session = SessionLocal()
    result = {
        "tarot": {"seeded": 0, "ai_upgraded": 0, "skipped": 0, "failed": 0},
        "compatibility": {"generated": 0, "skipped": 0, "failed": 0},
    }

    try:
        # ── Tarot: seed from static list ─────────────────────────────────────
        existing_tarot = db.query(TarotCard).count()
        if existing_tarot >= len(TAROT_CARDS):
            result["tarot"]["skipped"] = existing_tarot
        else:
            result["tarot"]["seeded"] = seed_tarot_db(db)

        # Optional AI upgrade of tarot interpretations (3 calls)
        if upgrade_tarot_with_ai:
            cards_in_db = {row.name: row for row in db.query(TarotCard).all()}
            # Process in 3 groups of ~26 cards
            chunk_size = 26
            cards_list = [{"name": c["name"], "number": c["number"], "meaning": c["meaning"]}
                          for c in TAROT_CARDS]
            for i in range(0, len(cards_list), chunk_size):
                chunk = cards_list[i:i + chunk_size]
                ai_results = generate_batch_tarot_interpretations(chunk)
                if not ai_results:
                    result["tarot"]["failed"] += len(chunk)
                    continue
                for item in ai_results:
                    row = cards_in_db.get(item["name"])
                    if row and item.get("upright_interpretation"):
                        row.upright_interpretation = item["upright_interpretation"]
                        row.reversed_interpretation = item["reversed_interpretation"]
                        result["tarot"]["ai_upgraded"] += 1
                db.commit()

        # ── Compatibility: generate all 78 unique pairs (4 LLM calls) ────────
        # Build canonical unique pairs list
        signs = ZODIAC_SIGNS
        unique_pairs = []
        for i, s1 in enumerate(signs):
            for s2 in signs[i:]:  # includes same sign
                unique_pairs.append((s1, s2))

        # Check which pairs already exist
        existing_pairs = {
            (row.sign1, row.sign2)
            for row in db.query(Compatibility.sign1, Compatibility.sign2).all()
        }
        pairs_needed = [
            p for p in unique_pairs if p not in existing_pairs
        ]
        result["compatibility"]["skipped"] = len(existing_pairs)

        if not pairs_needed:
            pass  # all done
        else:
            # Build pair dicts with sign-specific scores
            from services.compatibility_service import get_pair_score
            pair_dicts = [{"sign1": s1, "sign2": s2, "score": get_pair_score(s1, s2)}
                          for s1, s2 in pairs_needed]

            # Process in batches of 20 (~4 LLM calls for 78 pairs)
            batch_size = 20
            for i in range(0, len(pair_dicts), batch_size):
                batch = pair_dicts[i:i + batch_size]
                ai_results = generate_batch_compatibility(batch)
                if not ai_results:
                    result["compatibility"]["failed"] += len(batch)
                    continue
                for item in ai_results:
                    s1 = item.get("sign1", "")
                    s2 = item.get("sign2", "")
                    if not s1 or not s2:
                        result["compatibility"]["failed"] += 1
                        continue
                    # Use canonical ordering from pair_dicts (already canonical)
                    sc = next((p["score"] for p in batch
                               if p["sign1"] == s1 and p["sign2"] == s2), 70)
                    try:
                        db.add(Compatibility(
                            sign1=s1, sign2=s2, score=sc,
                            description=item.get("description", ""),
                            love_advice=item.get("love_advice", ""),
                            strengths=item.get("strengths_together", ""),
                            challenges=item.get("challenges", ""),
                        ))
                        result["compatibility"]["generated"] += 1
                    except Exception as exc:
                        logger.error("Failed to save compatibility %s x %s: %s", s1, s2, exc)
                        result["compatibility"]["failed"] += 1
                db.commit()

    except Exception as exc:
        logger.error("seed_oneshot_content error: %s", exc)
        db.rollback()
    finally:
        db.close()

    return result


# Register API routers
app.include_router(horoscope.router, prefix=settings.API_PREFIX)
app.include_router(tarot.router, prefix=settings.API_PREFIX)
app.include_router(fortune.router, prefix=settings.API_PREFIX)
app.include_router(compatibility.router, prefix=settings.API_PREFIX)
app.include_router(kundli.router, prefix=settings.API_PREFIX)
app.include_router(stories.router, prefix=settings.API_PREFIX)
app.include_router(chart.router, prefix=settings.API_PREFIX)
app.include_router(vedic.router, prefix=settings.API_PREFIX)


@app.get("/", tags=["Root"])
def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
    }
