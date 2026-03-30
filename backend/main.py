import logging
from datetime import date

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from db.database import engine, Base, get_db
from api import horoscope, tarot, fortune, compatibility, kundli, stories

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

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


# Global error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "An internal server error occurred."},
    )


# Health check
@app.get("/health", tags=["Health"])
def health_check():
    from services.ai_service import ai_available
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "ai_enabled": ai_available(),
    }


# ── Admin: refresh all daily AI content ──────────────────────────────────────
@app.post("/admin/refresh-daily", tags=["Admin"])
def refresh_daily_content(target_date: str = None):
    """
    Generate and cache AI content for all 12 zodiac signs for the given date
    (defaults to today).  Call this once daily — e.g. from a cron job at 00:05.

    Returns a summary of what was generated / skipped / failed.
    """
    from sqlalchemy.orm import Session
    from db.database import SessionLocal
    from db.models import Horoscope, Story
    from services.ai_service import generate_all_horoscopes, generate_daily_stories
    from services.zodiac_service import ZODIAC_SIGNS

    for_date = date.fromisoformat(target_date) if target_date else date.today()
    date_str = for_date.isoformat()
    db: Session = SessionLocal()

    result = {
        "date": date_str,
        "horoscopes": {"generated": [], "skipped": [], "failed": []},
        "stories": {"generated": 0, "failed": False},
    }

    try:
        # ── Horoscopes ──────────────────────────────────────────────────────
        # Check which signs already have content for today
        existing_signs = {
            row.zodiac_sign
            for row in db.query(Horoscope.zodiac_sign)
            .filter(Horoscope.date == date_str)
            .all()
        }
        signs_needed = [s for s in ZODIAC_SIGNS if s not in existing_signs]

        if not signs_needed:
            result["horoscopes"]["skipped"] = ZODIAC_SIGNS
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
                        row = Horoscope(
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
                        )
                        db.add(row)
                        result["horoscopes"]["generated"].append(sign)
                    except Exception as exc:
                        logger.error("Failed to save horoscope for %s: %s", sign, exc)
                        result["horoscopes"]["failed"].append(sign)
                db.commit()
            else:
                result["horoscopes"]["failed"] = signs_needed

        # ── Stories ─────────────────────────────────────────────────────────
        stories_data = generate_daily_stories(for_date, count=5)
        if stories_data:
            for story in stories_data:
                try:
                    row = Story(
                        title=story["title"],
                        summary=story["summary"],
                        content=story["content"],
                        category=story["category"],
                        read_time=story["read_time"],
                        author=story.get("author", "CosmicGuide"),
                    )
                    db.add(row)
                    result["stories"]["generated"] += 1
                except Exception as exc:
                    logger.error("Failed to save story: %s", exc)
            db.commit()
        else:
            result["stories"]["failed"] = True

    except Exception as exc:
        logger.error("refresh_daily_content error: %s", exc)
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


@app.get("/", tags=["Root"])
def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
    }
