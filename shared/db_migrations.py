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


def ensure_compatibility_canonical(engine: Engine, logger=None) -> None:
    """Repair the ``compatibility`` table to one canonical row per unordered pair.

    Historically the admin seeder stored pairs in astrological (zodiac) order
    while the lookup canonicalized alphabetically, so ~41% of pairs were
    unreachable and the live path inserted a second row in the other order.
    This swaps every non-canonical row to ``sign1 <= sign2``, drops duplicate
    pairs (keeping the richest description), then adds a UNIQUE index so the two
    orderings can never diverge again. Idempotent — safe on every boot.
    """
    try:
        inspector = inspect(engine)
        if "compatibility" not in inspector.get_table_names():
            return  # fresh DB — create_all() already added the UniqueConstraint

        with engine.begin() as conn:
            rows = conn.execute(
                text("SELECT id, sign1, sign2, description FROM compatibility")
            ).fetchall()

            keep: dict = {}       # canonical (a, b) -> (id, description length)
            delete_ids: list = []
            for row in rows:
                a, b = row.sign1, row.sign2
                canon = (a, b) if (a or "") <= (b or "") else (b, a)
                dlen = len(row.description or "")
                if canon not in keep:
                    keep[canon] = (row.id, dlen)
                elif dlen > keep[canon][1]:
                    delete_ids.append(keep[canon][0])   # replace with the richer row
                    keep[canon] = (row.id, dlen)
                else:
                    delete_ids.append(row.id)

            for rid in delete_ids:                       # drop duplicates BEFORE swapping
                conn.execute(text("DELETE FROM compatibility WHERE id = :id"), {"id": rid})

            for (a, b), (rid, _dlen) in keep.items():     # normalise survivors to a <= b
                conn.execute(
                    text("UPDATE compatibility SET sign1 = :a, sign2 = :b "
                         "WHERE id = :id AND (sign1 <> :a OR sign2 <> :b)"),
                    {"a": a, "b": b, "id": rid},
                )

            conn.execute(
                text("CREATE UNIQUE INDEX IF NOT EXISTS uq_compatibility_pair "
                     "ON compatibility (sign1, sign2)")
            )

        if logger and rows:
            logger.info(
                "Schema migration: compatibility canonicalized "
                "(rows=%d, duplicates removed=%d, uq_compatibility_pair ensured)",
                len(rows), len(delete_ids),
            )
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("compatibility canonical migration skipped: %s", exc)


def ensure_horoscope_lucky_number_string(engine: Engine, logger=None) -> None:
    """Widen ``horoscopes.lucky_number`` from INTEGER to VARCHAR(10).

    Every writer and the API schema treat ``lucky_number`` as a string (the LLM
    may return "7" or "7, 14"); the daily table alone kept it INTEGER, so on
    Postgres a non-integer value aborts the insert and the reading is never
    cached (SQLite hides this via type affinity). The periodic table is already
    VARCHAR — this brings the daily table in line. Idempotent.
    """
    try:
        inspector = inspect(engine)
        if "horoscopes" not in inspector.get_table_names():
            return  # fresh DB — create_all() already built it as VARCHAR
        col = next((c for c in inspector.get_columns("horoscopes")
                    if c["name"] == "lucky_number"), None)
        if col is None:
            return
        type_str = str(col["type"]).upper()
        if "CHAR" in type_str or "TEXT" in type_str:
            return  # already a string type
        if engine.dialect.name != "postgresql":
            return  # SQLite & friends: dynamic affinity already stores strings fine
        if logger:
            logger.info("Schema migration: widening `horoscopes.lucky_number` to VARCHAR(10)")
        with engine.begin() as conn:
            conn.execute(text(
                "ALTER TABLE horoscopes ALTER COLUMN lucky_number "
                "TYPE VARCHAR(10) USING lucky_number::varchar"
            ))
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("horoscopes.lucky_number migration skipped: %s", exc)


def _ensure_unique_index(engine: Engine, table: str, cols: list, index_name: str, logger=None) -> None:
    """Dedupe ``table`` on ``cols`` (keep the lowest id per group) then add a UNIQUE index.

    These cache tables (horoscopes / periodic_horoscopes / fortune_pool) had no
    uniqueness, so retries and concurrent requests could insert duplicate rows for
    the same cache key. This collapses any existing duplicates and enforces one row
    per key going forward. Idempotent and portable (SQLite + Postgres).
    """
    try:
        inspector = inspect(engine)
        if table not in inspector.get_table_names():
            return  # fresh DB — create_all() already added the UniqueConstraint
        if not set(cols).issubset({c["name"] for c in inspector.get_columns(table)}):
            return  # a keyed column is missing on this (older) schema
        group = ", ".join(cols)
        with engine.begin() as conn:
            conn.execute(text(
                f"DELETE FROM {table} WHERE id NOT IN "
                f"(SELECT MIN(id) FROM {table} GROUP BY {group})"
            ))
            conn.execute(text(
                f"CREATE UNIQUE INDEX IF NOT EXISTS {index_name} ON {table} ({group})"
            ))
        if logger:
            logger.info("Schema migration: unique index %s ensured on %s(%s)", index_name, table, group)
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("%s migration skipped: %s", index_name, exc)


def ensure_cache_unique_indexes(engine: Engine, logger=None) -> None:
    """Enforce one row per cache key on the daily/periodic/fortune tables.

    Call AFTER ``ensure_horoscope_system_column`` so ``horoscopes.system`` is
    already backfilled (no NULLs in the dedupe key).
    """
    _ensure_unique_index(engine, "horoscopes",
                         ["date", "zodiac_sign", "system"], "uq_horoscope_day", logger)
    _ensure_unique_index(engine, "periodic_horoscopes",
                         ["period", "period_key", "system", "zodiac_sign"], "uq_periodic_horoscope", logger)
    _ensure_unique_index(engine, "fortune_pool",
                         ["date", "zodiac_sign", "topic"], "uq_fortune_pool", logger)


def ensure_users_firebase_shape(engine: Engine, logger=None) -> None:
    """Reshape a legacy ``users`` table for Firebase-backed sign-in.

    The original table was designed for self-managed credentials
    (``password_hash NOT NULL``, ``email`` required) and was never written to —
    auth shipped on Firebase instead, where credentials never reach this
    database. The legacy NOT NULL columns would reject every new row, so an
    empty legacy table is rebuilt. A table with rows is left untouched and
    reported, because dropping real accounts must never be automatic.
    """
    try:
        inspector = inspect(engine)
        if "users" not in inspector.get_table_names():
            return  # fresh database — create_all() built the current shape

        columns = {col["name"] for col in inspector.get_columns("users")}
        if "firebase_uid" in columns:
            return  # already migrated

        with engine.begin() as conn:
            row_count = conn.execute(text("SELECT COUNT(*) FROM users")).scalar() or 0

        if row_count:
            if logger:
                logger.error(
                    "users table has the pre-Firebase shape but holds %d row(s); "
                    "refusing to rebuild it automatically. Migrate manually.",
                    row_count,
                )
            return

        if logger:
            logger.info("Schema migration: rebuilding empty legacy `users` table for Firebase sign-in")
        with engine.begin() as conn:
            conn.execute(text("DROP TABLE users"))
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("users table migration skipped: %s", exc)


def ensure_device_token_owner_column(engine: Engine, logger=None) -> None:
    """Ensure ``device_tokens.firebase_uid`` exists.

    Device tokens predate sign-in, so rows created then have no owner. Without
    this column an account deletion cannot find and remove the user's push
    registrations. Legacy rows keep a NULL owner and are cleaned up by the
    usual invalid-token pruning instead.
    """
    try:
        inspector = inspect(engine)
        if "device_tokens" not in inspector.get_table_names():
            return
        columns = {col["name"] for col in inspector.get_columns("device_tokens")}
        if "firebase_uid" in columns:
            return
        if logger:
            logger.info("Schema migration: adding `firebase_uid` column to `device_tokens`")
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE device_tokens ADD COLUMN firebase_uid VARCHAR(128)"))
    except Exception as exc:  # best-effort: never block startup on a schema patch
        if logger:
            logger.warning("device_tokens.firebase_uid migration skipped: %s", exc)


def ensure_tradition_is_binary(engine: Engine, logger=None) -> None:
    """Collapse the retired "both" reading style to "western".

    The app once offered Western, Vedic *and* both. "Both" was removed, so any
    stored value would be unreachable by the pickers — the user could never see
    or change it. Western is the replacement default.
    """
    for table in ("users", "device_tokens"):
        try:
            inspector = inspect(engine)
            if table not in inspector.get_table_names():
                continue
            if "tradition" not in {c["name"] for c in inspector.get_columns(table)}:
                continue
            with engine.begin() as conn:
                result = conn.execute(
                    text(f"UPDATE {table} SET tradition = 'western' WHERE tradition = 'both'")
                )
            if logger and result.rowcount:
                logger.info(
                    "Schema migration: moved %d %s row(s) from tradition 'both' to 'western'",
                    result.rowcount, table,
                )
        except Exception as exc:  # best-effort: never block startup on a schema patch
            if logger:
                logger.warning("%s.tradition migration skipped: %s", table, exc)


def ensure_story_title_unique(engine: Engine, logger=None) -> None:
    """Enforce one story per (title, category).

    The populator inserts generated articles without checking for an existing
    one, so a re-run could put visible duplicates in the Discover feed.
    """
    _ensure_unique_index(engine, "stories", ["title", "category"], "uq_story_title", logger)


# Tables that were designed but never wired up. ``kundli_reports`` is the
# important one: it was shaped to hold a *partner's* full name, birth date,
# birth time and birth place — personal data for someone who never consented
# and has no account — and create_all() recreated it on every boot.
_UNUSED_TABLES = ("kundli_reports", "fortune_history")


def drop_unused_tables(engine: Engine, logger=None) -> None:
    """Drop the dead tables, but only while they are still empty.

    Refusing to drop a populated table means an operator who started using one
    of them does not silently lose the data; they get a log line instead.
    """
    for table in _UNUSED_TABLES:
        try:
            inspector = inspect(engine)
            if table not in inspector.get_table_names():
                continue
            with engine.begin() as conn:
                rows = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar() or 0
                if rows:
                    if logger:
                        logger.error(
                            "Table %s is unused by the application but holds %d row(s); "
                            "leaving it in place. Drop it manually once reviewed.",
                            table, rows,
                        )
                    continue
                conn.execute(text(f"DROP TABLE {table}"))
            if logger:
                logger.info("Schema migration: dropped unused empty table `%s`", table)
        except Exception as exc:  # best-effort: never block startup on a schema patch
            if logger:
                logger.warning("%s drop skipped: %s", table, exc)
