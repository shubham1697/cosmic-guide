"""
Remote content database connection.

This connects to a separate PostgreSQL instance (running on another machine)
that holds pre-generated daily content.  The main API reads from this DB
so that most requests never hit the LLM directly.

The daily population script writes to this DB, and the API reads from it.

Usage:
    from db.content_db import get_content_db, content_engine

    # In a FastAPI dependency:
    def my_endpoint(db=Depends(get_content_db)):
        ...

If CONTENT_DB_ENABLED is False or CONTENT_DB_URL is empty, all functions
fall back to the local SQLite database transparently.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from config import settings
from logger import get_logger

logger = get_logger(__name__)

_content_engine = None
_ContentSessionLocal = None


def _init_content_db():
    """Lazily initialise the remote content DB engine."""
    global _content_engine, _ContentSessionLocal

    if _content_engine is not None:
        return

    if not settings.CONTENT_DB_ENABLED or not settings.CONTENT_DB_URL:
        logger.info("Content DB disabled — falling back to local DB")
        # Re-use the local engine
        from db.database import engine as local_engine, SessionLocal as local_session
        _content_engine = local_engine
        _ContentSessionLocal = local_session
        return

    logger.info("Connecting to remote content DB: %s",
                settings.CONTENT_DB_URL.split("@")[-1] if "@" in settings.CONTENT_DB_URL else "***")
    try:
        _content_engine = create_engine(
            settings.CONTENT_DB_URL,
            pool_size=5,
            max_overflow=10,
            pool_pre_ping=True,         # reconnect on stale connections
            pool_recycle=1800,          # recycle connections every 30 min
            connect_args={},
        )
        _ContentSessionLocal = sessionmaker(
            autocommit=False, autoflush=False, bind=_content_engine,
        )
        # Test the connection
        from sqlalchemy import text
        with _content_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        logger.info("Remote content DB connection OK")
    except Exception as exc:
        logger.error("Failed to connect to remote content DB: %s — falling back to local", exc)
        from db.database import engine as local_engine, SessionLocal as local_session
        _content_engine = local_engine
        _ContentSessionLocal = local_session


def get_content_engine():
    """Return the content DB engine (remote or local fallback)."""
    _init_content_db()
    return _content_engine


def get_content_db():
    """FastAPI dependency — yields a session to the content database."""
    _init_content_db()
    db = _ContentSessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_content_session():
    """Get a content DB session directly (for scripts, not FastAPI)."""
    _init_content_db()
    return _ContentSessionLocal()


def create_content_tables():
    """Create all content tables on the remote DB."""
    from db.database import Base
    _init_content_db()
    Base.metadata.create_all(bind=_content_engine)
    logger.info("Content DB tables created/verified")
