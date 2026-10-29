import asyncio
import logging
import time
from contextlib import asynccontextmanager
from datetime import date

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from logger import configure_logging, get_logger
from security import require_admin
from rate_limit import client_identity, rate_limit_middleware
from audit import audit_inbound, new_request_id, redact_query, set_request_id
from sqlalchemy.exc import IntegrityError
from db.database import engine, Base, get_db
from db import models  # noqa: F401 — register ORM models on Base.metadata before create_all
from shared.db_migrations import (
    ensure_horoscope_system_column,
    ensure_compatibility_canonical,
    ensure_horoscope_lucky_number_string,
    ensure_cache_unique_indexes,
    ensure_users_firebase_shape,
    ensure_device_token_owner_column,
    ensure_tradition_is_binary,
    ensure_story_title_unique,
    drop_unused_tables,
)
from api import horoscope, tarot, fortune, compatibility, kundli, stories, chart, vedic, notifications, users

# Boot logging before anything else
configure_logging()
logger = get_logger(__name__)

logger.info("CosmicGuide API starting up — log_level=%s  ai_model=%s",
            settings.LOG_LEVEL, settings.AI_MODEL)
if not settings.ADMIN_API_KEY:
    logger.warning(
        "ADMIN_API_KEY is not set — /admin/* and the notification broadcast "
        "routes are DISABLED (503). Set ADMIN_API_KEY to enable them."
    )

# Set once schema preparation has succeeded; /ready reports it.
_schema_ready = False
_SCHEMA_ATTEMPTS = 5


def prepare_schema() -> None:
    """Create missing tables and patch the ones that already exist.

    ``create_all()`` only creates missing tables — it never alters an existing
    one — so every column or constraint added after a table shipped needs its
    own idempotent helper here.
    """
    # Runs before create_all so the replacement table is built in the same pass.
    ensure_users_firebase_shape(engine, logger)
    Base.metadata.create_all(bind=engine)
    ensure_horoscope_system_column(engine, logger)
    ensure_compatibility_canonical(engine, logger)
    ensure_horoscope_lucky_number_string(engine, logger)
    ensure_cache_unique_indexes(engine, logger)
    ensure_device_token_owner_column(engine, logger)
    ensure_tradition_is_binary(engine, logger)
    ensure_story_title_unique(engine, logger)
    drop_unused_tables(engine, logger)


async def _prepare_schema_with_retry() -> None:
    """Prepare the schema, retrying with backoff.

    A transient database blip at boot used to abort the import and crash-loop
    the container; the app now starts degraded instead and ``/ready`` reports
    it, so the orchestrator keeps traffic away without killing the process.
    """
    global _schema_ready
    delay = 1.0
    for attempt in range(1, _SCHEMA_ATTEMPTS + 1):
        try:
            await asyncio.to_thread(prepare_schema)
            _schema_ready = True
            return
        except Exception as exc:
            if attempt == _SCHEMA_ATTEMPTS:
                logger.error(
                    "Schema preparation failed after %d attempts (%s) — starting "
                    "degraded; /ready will report not-ready.", attempt, exc,
                )
                return
            logger.warning(
                "Schema preparation attempt %d/%d failed (%s); retrying in %.0fs.",
                attempt, _SCHEMA_ATTEMPTS, exc, delay,
            )
            await asyncio.sleep(delay)
            delay = min(delay * 2, 30.0)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await _prepare_schema_with_retry()
    from services.scheduler import start_scheduler
    start_scheduler()
    try:
        yield
    finally:
        from services.scheduler import shutdown_scheduler
        shutdown_scheduler()
        engine.dispose()   # release pooled DB connections on shutdown


# Initialize FastAPI app
_docs_enabled = settings.ENABLE_DOCS
if not _docs_enabled:
    logger.info("OpenAPI docs are disabled (set ENABLE_DOCS=true to publish them).")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    # The schema advertises every route, parameter and admin path to anonymous
    # callers, so it stays off unless an operator opts in.
    docs_url="/docs" if _docs_enabled else None,
    redoc_url="/redoc" if _docs_enabled else None,
    openapi_url="/openapi.json" if _docs_enabled else None,
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    # Wildcard origins + credentials is spec-invalid and unsafe; the app uses no
    # cookies/credentialed requests, so keep credentials off (set an explicit
    # origin allow-list before enabling credentials for a future auth flow).
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Added before the logging middleware so logging stays outermost and still
# records the requests this rejects.
app.middleware("http")(rate_limit_middleware)
if settings.RATE_LIMIT_ENABLED:
    logger.info(
        "Rate limiting on — %d/min default, %d/min for LLM routes, trust_proxy=%s",
        settings.RATE_LIMIT_DEFAULT, settings.RATE_LIMIT_LLM, settings.TRUST_PROXY_HEADERS,
    )
else:
    logger.warning("Rate limiting is DISABLED (RATE_LIMIT_ENABLED=false).")


# ── Request / response logging middleware ─────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    method = request.method
    path = request.url.path
    # Birth date/time/place travel as query parameters; never log them raw.
    query = redact_query(str(request.url.query))

    # Correlation id — reuse an inbound X-Request-ID if the caller supplied one.
    request_id = request.headers.get("x-request-id") or new_request_id()
    set_request_id(request_id)

    # Same rule as the rate limiter: X-Forwarded-For is only believed behind a
    # proxy we control, otherwise any caller could forge the audit attribution.
    client_ip = client_identity(request)
    user_agent = request.headers.get("user-agent", "")
    req_len = request.headers.get("content-length")
    request_bytes = int(req_len) if req_len and req_len.isdigit() else None

    logger.info("→ %s %s%s", method, path, f"?{query}" if query else "")
    logger.debug("  client=%s  request_id=%s", client_ip, request_id)

    status_code = 500
    response = None
    audit_error = None
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception as exc:
        audit_error = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        elapsed_ms = (time.perf_counter() - start) * 1000
        resp_len = response.headers.get("content-length") if response else None
        response_bytes = int(resp_len) if resp_len and resp_len.isdigit() else None

        if response is not None:
            response.headers["X-Request-ID"] = request_id

        level = logging.WARNING if elapsed_ms > 5000 else logging.INFO
        logger.log(
            level,
            "← %s %s  status=%d  %.0fms  request_id=%s",
            method, path, status_code, elapsed_ms, request_id,
        )

        audit_inbound(
            request_id=request_id,
            method=method,
            path=path,
            query=query,
            client_ip=client_ip,
            user_agent=user_agent,
            status_code=status_code,
            duration_ms=elapsed_ms,
            request_bytes=request_bytes,
            response_bytes=response_bytes,
            error=audit_error,
        )


# ── Security headers ─────────────────────────────────────────────────────────
# Added last so it is the outermost layer and also stamps rate-limit rejections.
_SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Cross-Origin-Opener-Policy": "same-origin",
}


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    for header, value in _SECURITY_HEADERS.items():
        response.headers.setdefault(header, value)
    # Only meaningful once TLS terminates in front of the app.
    if request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https":
        response.headers.setdefault(
            "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
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
    """Liveness: is the process up? Always cheap — never touches a dependency."""
    from services.ai_service import ai_available
    ai = ai_available()
    logger.debug("Health check — ai_enabled=%s", ai)
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "log_level": settings.LOG_LEVEL,
        "ai_enabled": ai,
    }


@app.get("/ready", tags=["Health"])
def readiness_check():
    """Readiness: can this instance actually serve? Checks the database and the
    schema/scheduler state, and answers 503 when it cannot."""
    from sqlalchemy import text
    from services.scheduler import is_running as scheduler_running

    database_ok = True
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        database_ok = False
        logger.warning("Readiness check — database unreachable: %s", exc)

    body = {
        "status": "ready" if (database_ok and _schema_ready) else "not_ready",
        "database": "ok" if database_ok else "unreachable",
        "schema": "ready" if _schema_ready else "not_ready",
        "scheduler": (
            "running" if scheduler_running()
            else ("disabled" if not settings.ENABLE_SCHEDULER else "stopped")
        ),
    }
    if body["status"] != "ready":
        return JSONResponse(status_code=503, content=body)
    return body


# Content status endpoint — check what's pre-populated
def _parse_admin_date(target_date: str | None) -> date:
    """Parse an optional ?target_date=YYYY-MM-DD; 400 (not 500) on malformed input."""
    if not target_date:
        return date.today()
    try:
        return date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="target_date must be a valid YYYY-MM-DD date")


@app.get("/admin/content-status", tags=["Admin"], dependencies=[Depends(require_admin)])
def content_status(target_date: str | None = None):
    """Check what content is available in the DB for the given date."""
    from db.database import SessionLocal
    from db.models import Horoscope, FortunePool, Story, Compatibility, TarotCard

    for_date = _parse_admin_date(target_date)
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


# ── Admin: clear in-memory caches ────────────────────────────────────────────
@app.post("/admin/clear-cache", tags=["Admin"], dependencies=[Depends(require_admin)])
def clear_caches():
    """Clear all in-memory caches so the backend re-fetches from DB."""
    from services.horoscope_service import clear_horoscope_cache
    clear_horoscope_cache()
    logger.info("All in-memory caches cleared via admin endpoint")
    return {"status": "ok", "message": "All caches cleared"}


# ── Admin: refresh all daily AI content ──────────────────────────────────────
@app.post("/admin/refresh-daily", tags=["Admin"], dependencies=[Depends(require_admin)])
def refresh_daily_content(target_date: str | None = None):
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

    for_date = _parse_admin_date(target_date)
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
                        with db.begin_nested():
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
                    with db.begin_nested():
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
                            with db.begin_nested():
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
@app.post("/admin/seed-oneshot", tags=["Admin"], dependencies=[Depends(require_admin)])
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
    from services.compatibility_service import ELEMENT_COMPATIBILITY, get_pair_score, canonical_pair
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
                unique_pairs.append(canonical_pair(s1, s2))

        # Check which pairs already exist (compare in the same canonical ordering)
        existing_pairs = {
            canonical_pair(row.sign1, row.sign2)
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
                    s1, s2 = canonical_pair(s1, s2)   # store in the reader's ordering
                    sc = get_pair_score(s1, s2)       # deterministic, order-independent
                    try:
                        with db.begin_nested():       # SAVEPOINT: one bad row can't poison the batch
                            db.add(Compatibility(
                                sign1=s1, sign2=s2, score=sc,
                                description=item.get("description", ""),
                                love_advice=item.get("love_advice", ""),
                                strengths=item.get("strengths_together", ""),
                                challenges=item.get("challenges", ""),
                            ))
                        result["compatibility"]["generated"] += 1
                    except IntegrityError:
                        result["compatibility"]["skipped"] += 1   # pair already present (race/re-run)
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
app.include_router(notifications.router, prefix=settings.API_PREFIX)
app.include_router(users.router, prefix=settings.API_PREFIX)


@app.get("/", tags=["Root"])
def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
    }
