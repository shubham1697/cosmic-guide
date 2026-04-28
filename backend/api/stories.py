from fastapi import APIRouter, Query, Depends, HTTPException, BackgroundTasks
from schemas import StoryResponse, StoryListResponse
from db.database import get_db
from logger import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/stories", tags=["Stories"])


def _mock_story_list(page: int, per_page: int, category: str | None):
    from data.mock.stories_data import STORIES

    if category:
        filtered = [s for s in STORIES if str(s.get("category", "")).lower() == category.lower()]
    else:
        filtered = list(STORIES)

    total = len(filtered)
    offset = (page - 1) * per_page
    rows = filtered[offset: offset + per_page]
    return StoryListResponse(
        stories=[
            StoryResponse(
                id=int(r.get("id", 0)),
                title=str(r.get("title", "")),
                summary=str(r.get("summary", "")),
                content=str(r.get("content", "")),
                category=str(r.get("category", "Spiritual")),
                read_time=str(r.get("read_time", "5 min")),
                author=str(r.get("author", "CosmicGuide")),
                published_at=None,
            )
            for r in rows
        ],
        total=total,
        page=page,
        per_page=per_page,
    )


def _mock_story_by_id(story_id: int):
    from data.mock.stories_data import STORIES

    for item in STORIES:
        if int(item.get("id", 0)) == story_id:
            return StoryResponse(
                id=int(item.get("id", 0)),
                title=str(item.get("title", "")),
                summary=str(item.get("summary", "")),
                content=str(item.get("content", "")),
                category=str(item.get("category", "Spiritual")),
                read_time=str(item.get("read_time", "5 min")),
                author=str(item.get("author", "CosmicGuide")),
                published_at=None,
            )
    return None


@router.get("", response_model=StoryListResponse)
def list_stories(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, ge=1, le=50),
    category: str = Query(None, description="Filter by category"),
    db=Depends(get_db),
):
    """Return stories from DB (AI-generated). Auto-seeds via Ollama if DB is empty."""
    from db.models import Story as StoryModel
    generated_via_llm = False
    
    logger.info("→ GET /stories | page=%d per_page=%d category=%s", page, per_page, category or "all")

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
            generated_via_llm = n > 0
            # Re-query after seeding
            query = db.query(StoryModel).order_by(StoryModel.published_at.desc())
            total = query.count()

        if total > 0:
            offset = (page - 1) * per_page
            rows = query.offset(offset).limit(per_page).all()
            logger.info("list_stories  source=%s  returned=%d total=%d", "llm" if generated_via_llm else "db", len(rows), total)
            logger.info("← GET /stories | status=200 | returned=%d total=%d", len(rows), total)
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
        logger.warning("list_stories  source=mock  reason=db_fetch_failed")
        return _mock_story_list(page=page, per_page=per_page, category=category)

    if total == 0:
        logger.warning("list_stories  source=mock  reason=db_empty")
        return _mock_story_list(page=page, per_page=per_page, category=category)

    return StoryListResponse(stories=[], total=0, page=page, per_page=per_page)


@router.get("/{story_id}", response_model=StoryResponse)
def get_story(story_id: int, db=Depends(get_db)):
    """Return a single story by ID from DB."""
    from db.models import Story as StoryModel

    try:
        row = db.query(StoryModel).filter(StoryModel.id == story_id).first()
        if row:
            logger.info("get_story  source=db  id=%d", story_id)
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
        logger.warning("get_story  source=mock  id=%d  reason=db_fetch_failed", story_id)
        fallback = _mock_story_by_id(story_id)
        if fallback:
            return fallback
        raise HTTPException(status_code=404, detail="Story not found")

    fallback = _mock_story_by_id(story_id)
    if fallback:
        logger.warning("get_story  source=mock  id=%d  reason=db_miss", story_id)
        return fallback

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
