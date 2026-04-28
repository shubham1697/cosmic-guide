from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from config import settings
from logger import get_logger

logger = get_logger(__name__)

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {},
    poolclass=NullPool if "sqlite" in settings.DATABASE_URL else None,
    echo=False,  # Disable SQLAlchemy's default echo to use our own logging
)

# Log all SQL queries
@event.listens_for(engine, "before_cursor_execute")
def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """Log outgoing SQL queries with parameters."""
    stmt_preview = statement.replace("\n", " ")[:100]
    params_preview = str(parameters)[:80] if parameters else ""
    logger.debug("🗄  SQL: %s %s", stmt_preview, f"| params={params_preview}" if params_preview else "")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
