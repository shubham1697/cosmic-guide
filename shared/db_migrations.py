"""Lightweight, idempotent schema migrations shared by the API backend and the
content populator.

SQLAlchemy's ``Base.metadata.create_all()`` only creates *missing tables* — it
never adds a newly-declared column to a table that already exists. When we add
a column to a model whose table may already live in a long-running database, we
patch the table here at startup instead of pulling in a full migration tool.

Each function inspects the live schema first and no-ops when the change is
already present, so it is safe to run on every boot.
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_horoscope_system_column(engine: Engine, logger=None) -> None:
    """Ensure ``horoscopes.system`` exists, backfilling legacy rows to 'western'.

    The daily ``horoscopes`` table originally stored only western (tropical
    Sun-sign) readings. Vedic (sidereal Moon-rashi) readings now share the same
    table, disambiguated by a ``system`` column. On databases created before
    that column existed we add it and tag every existing row as 'western'.
    """
    try:
        inspector = inspect(engine)
        if "horoscopes" not in inspector.get_table_names():
            # Fresh database — create_all() already built the table with `system`.
            return
        columns = {col["name"] for col in inspector.get_columns("horoscopes")}
        if "system" in columns:
            return
        if logger:
            logger.info("Schema migration: adding `system` column to `horoscopes`")
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE horoscopes ADD COLUMN system VARCHAR(10)"))
            conn.execute(
                text("UPDATE horoscopes SET system = 'western' WHERE system IS NULL")
            )
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("horoscopes.system migration skipped: %s", exc)
