from fastapi import APIRouter, Query, Depends, HTTPException, BackgroundTasks
from schemas import StoryResponse, StoryListResponse
from db.database import get_db
from logger import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/stories", tags=["Stories"])


@router.get("", response_model=StoryListResponse)
def list_stories(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, ge=1, le=50),
    category: str = Query(None, description="Filter by category"),
    db=Depends(get_db),
):
    """Return stories from DB (AI-generated). Auto-seeds via Ollama if DB is empty."""
    from db.models import Story as StoryModel

    try:
        query = db.query(StoryModel).order_by(StoryModel.published_at.desc())
        if category:
            query = query.filter(StoryModel.category.ilike(category))
        total = query.count()

        # Auto-seed from Ollama when DB is empty
        if total == 0 and not category:
            logger.info("list_stories  DB empty — triggering Ollama story generation")
            from services.story_service import seed_stories_db
            n = seed_stories_db(db)
            logger.info("list_stories  auto-seed generated %d stories", n)
            # Re-query after seeding
            query = db.query(StoryModel).order_by(StoryModel.published_at.desc())
            total = query.count()

        if total > 0:
            offset = (page - 1) * per_page
            rows = query.offset(offset).limit(per_page).all()
            return StoryListResponse(
                stories=[
                    StoryResponse(
                        id=r.id,
                        title=r.title,
                        summary=r.summary or "",
                        content=r.content or "",
                        category=r.category,
                        read_time=r.read_time or "5 min",
                        author=r.author or "CosmicGuide",
                        published_at=r.published_at,
                    )
                    for r in rows
                ],
                total=total,
                page=page,
                per_page=per_page,
            )
    except Exception as exc:
        logger.warning("list_stories  DB query failed (%s)", exc)
        raise HTTPException(status_code=503, detail="Stories service temporarily unavailable.")

    return StoryListResponse(stories=[], total=0, page=page, per_page=per_page)


@router.get("/{story_id}", response_model=StoryResponse)
def get_story(story_id: int, db=Depends(get_db)):
    """Return a single story by ID from DB."""
    from db.models import Story as StoryModel

    try:
        row = db.query(StoryModel).filter(StoryModel.id == story_id).first()
        if row:
            return StoryResponse(
                id=row.id,
                title=row.title,
                summary=row.summary or "",
                content=row.content or "",
                category=row.category,
                read_time=row.read_time or "5 min",
                author=row.author or "CosmicGuide",
                published_at=row.published_at,
            )
    except Exception as exc:
        logger.warning("get_story  DB query failed (%s)", exc)
        raise HTTPException(status_code=503, detail="Stories service temporarily unavailable.")

    raise HTTPException(status_code=404, detail="Story not found")


@router.post("/generate", status_code=202)
def generate_stories(background_tasks: BackgroundTasks, db=Depends(get_db)):
    """
    Trigger Ollama story generation in the background.
    Generates one story per category, overwrites existing stories, and
    writes results to data/mock/stories_data.py.
    Returns immediately with 202 Accepted.
    """
    from db.models import Story as StoryModel
    from services.story_service import seed_stories_db

    def _run(db_session):
        try:
            # Clear existing stories before regenerating
            db_session.query(StoryModel).delete()
            db_session.commit()
            n = seed_stories_db(db_session)
            logger.info("generate_stories  background task completed  stories=%d", n)
        except Exception as exc:
            logger.error("generate_stories  background task failed: %s", exc)
            db_session.rollback()

    background_tasks.add_task(_run, db)
    return {"status": "accepted", "message": "Story generation started. Check /api/v1/stories in a minute."}
