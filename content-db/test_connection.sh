#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Test connectivity to the content database.
# Run from the API server machine to verify the DB laptop is reachable.
#
# Usage:
#   ./content-db/test_connection.sh [host] [port] [user] [dbname]
# ──────────────────────────────────────────────────────────────

HOST="${1:-192.168.29.88}"
PORT="${2:-5432}"
USER="${3:-cosmicguide}"
DB="${4:-cosmicguide_content}"

echo "Testing connection to content DB at $HOST:$PORT ..."
echo ""

# 1. TCP connectivity
if nc -z -w3 "$HOST" "$PORT" 2>/dev/null; then
    echo "✅ TCP port $PORT is reachable"
else
    echo "❌ Cannot reach $HOST:$PORT — is Docker running on the other laptop?"
    echo "   Check: docker compose -f docker-compose.content-db.yml ps"
    exit 1
fi

# 2. PostgreSQL connectivity (if psql is available)
if command -v psql &>/dev/null; then
    echo ""
    echo "Testing PostgreSQL login ..."
    if psql "postgresql://$USER@$HOST:$PORT/$DB" -c "SELECT 1;" &>/dev/null; then
        echo "✅ PostgreSQL login OK"

        # 3. Check tables
        echo ""
        echo "Tables in $DB:"
        psql "postgresql://$USER@$HOST:$PORT/$DB" -c "\dt"

        # 4. Check content status
        echo ""
        echo "Content counts:"
        psql "postgresql://$USER@$HOST:$PORT/$DB" -c "
            SELECT 'horoscopes' AS table_name, COUNT(*) FROM horoscopes
            UNION ALL SELECT 'fortune_pool', COUNT(*) FROM fortune_pool
            UNION ALL SELECT 'stories', COUNT(*) FROM stories
            UNION ALL SELECT 'compatibility', COUNT(*) FROM compatibility
            UNION ALL SELECT 'tarot_cards', COUNT(*) FROM tarot_cards;
        "
    else
        echo "⚠️  TCP is open but PostgreSQL login failed."
        echo "   Check password: PGPASSWORD=your_pass psql postgresql://$USER@$HOST:$PORT/$DB"
    fi
else
    echo ""
    echo "ℹ️  psql not installed — skipping detailed DB checks."
    echo "   Install: brew install postgresql"
    echo "   Or test from Python:"
    echo "   CONTENT_DB_URL=postgresql://$USER:PASS@$HOST:$PORT/$DB python -c \\"
    echo "     'from db.content_db import get_content_session; print(\"OK\")'"
fi
