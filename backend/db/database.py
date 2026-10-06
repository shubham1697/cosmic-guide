from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from config import settings
from logger import get_logger

logger = get_logger(__name__)

_is_sqlite = "sqlite" in settings.DATABASE_URL

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if _is_sqlite else {},
    poolclass=NullPool if _is_sqlite else None,
    echo=False,  # Disable SQLAlchemy's default echo to use our own logging
    # Postgres connections go stale across DB restarts, idle timeouts and
    # NAT/proxy reaping; verify before handing one out and retire old ones.
    **({} if _is_sqlite else {"pool_pre_ping": True, "pool_recycle": 1800}),
)

# Log outgoing SQL statements. Bound parameters are deliberately NOT logged:
# they carry birth dates/times/places and device tokens.
@event.listens_for(engine, "before_cursor_execute")
def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """Log outgoing SQL statements (without their bound parameters)."""
    logger.debug("🗄  SQL: %s", statement.replace("\n", " ")[:100])

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
