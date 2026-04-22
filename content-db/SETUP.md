# CosmicGuide Content Database — Setup Guide

> Deploy a PostgreSQL database + daily LLM populator on a separate laptop.
> Your API backend reads from this DB — zero LLM latency for users.

## Architecture

```
┌─────────────┐      ┌──────────────────┐      ┌─────────────────────────────┐
│  Flutter App │─────▶│  Backend API      │─────▶│  DB Laptop (Docker)         │
│  (phone)     │      │  (your Mac)       │      │  ┌───────────────────────┐  │
└─────────────┘      └──────────────────┘      │  │ PostgreSQL :5432      │  │
                                                │  └───────────────────────┘  │
                                                │  ┌───────────────────────┐  │
                                                │  │ Populator (cron)      │  │
                                                │  │ → Gemini API daily    │  │
                                                │  └───────────────────────┘  │
                                                └─────────────────────────────┘
```

## Prerequisites

- Docker & Docker Compose installed on the DB laptop
- A Gemini API key (free tier works fine)
- Both laptops on the same network

---

## Step 1 — Get the files onto the DB laptop

From your main Mac:

```bash
scp -r content-db/ docker-compose.content-db.yml backend/ user@192.168.29.88:~/cosmicguide/
```

Or if using git, just `git pull` on the DB laptop.

## Step 2 — Configure environment

```bash
cd ~/cosmicguide
cp content-db/.env.example .env
```

Edit `.env` — only 2 things are required:

```
POSTGRES_PASSWORD=pick_a_strong_password
GEMINI_API_KEY=your-actual-gemini-key
```

## Step 3 — Start the database

```bash
docker compose -f docker-compose.content-db.yml up -d
```

First boot:
- PostgreSQL creates the DB + all tables from `init.sql` automatically
- The populator container detects empty content and runs `populate_daily.py` on startup

Watch the logs:

```bash
docker compose -f docker-compose.content-db.yml logs -f
```

## Step 4 — One-time seeding (tarot + compatibility)

This needs to run only once. It makes ~8 Gemini API calls to fill:
- 78 tarot card interpretations
- 78 zodiac compatibility pair analyses

```bash
docker compose -f docker-compose.content-db.yml exec populator \
  python populate_daily.py --seed-oneshot
```

## Step 5 — Configure the API backend (your Mac)

Add to your backend `.env`:

```
CONTENT_DB_URL=postgresql://cosmicguide:pick_a_strong_password@192.168.29.88:5432/cosmicguide_content
CONTENT_DB_ENABLED=true
```

Test connectivity:

```bash
./content-db/test_connection.sh 192.168.29.88
```

Restart the backend — it now reads from the remote DB.

---

## What happens automatically

| Time | What |
|------|------|
| 00:05 daily | Populator generates horoscopes (12 signs) + fortune pool (60 combos) + 5 stories via Gemini → stores in PostgreSQL |
| Any time | Your API reads from PostgreSQL — no LLM calls needed |
| DB laptop offline? | Backend falls back to local SQLite automatically |

---

## Useful commands

```bash
# Check container status
docker compose -f docker-compose.content-db.yml ps

# See what's populated (dry run)
docker compose -f docker-compose.content-db.yml exec populator \
  python populate_daily.py --dry-run

# Force regenerate today's content
docker compose -f docker-compose.content-db.yml exec populator \
  python populate_daily.py --force

# Generate for a specific date
docker compose -f docker-compose.content-db.yml exec populator \
  python populate_daily.py --date 2026-04-23

# Query DB directly
docker compose -f docker-compose.content-db.yml exec content-db \
  psql -U cosmicguide cosmicguide_content -c \
  "SELECT zodiac_sign, date, mood FROM horoscopes ORDER BY date DESC LIMIT 12;"

# Check content counts
docker compose -f docker-compose.content-db.yml exec content-db \
  psql -U cosmicguide cosmicguide_content -c \
  "SELECT 'horoscopes' AS t, COUNT(*) FROM horoscopes
   UNION ALL SELECT 'fortune_pool', COUNT(*) FROM fortune_pool
   UNION ALL SELECT 'stories', COUNT(*) FROM stories
   UNION ALL SELECT 'compatibility', COUNT(*) FROM compatibility
   UNION ALL SELECT 'tarot_cards', COUNT(*) FROM tarot_cards;"

# Clean up old content (keep last 30 days)
docker compose -f docker-compose.content-db.yml exec content-db \
  psql -U cosmicguide cosmicguide_content -c \
  "SELECT * FROM cleanup_old_content(30);"

# Launch pgAdmin web UI (optional, http://192.168.29.88:5050)
docker compose -f docker-compose.content-db.yml --profile admin up -d

# Stop everything
docker compose -f docker-compose.content-db.yml down

# Stop and delete all data (fresh start)
docker compose -f docker-compose.content-db.yml down -v
```

---

## Troubleshooting

### Can't connect from API machine

```bash
# On the DB laptop, check PostgreSQL is listening
docker compose -f docker-compose.content-db.yml exec content-db \
  pg_isready -U cosmicguide

# Check firewall isn't blocking port 5432
# macOS: System Settings → Network → Firewall
# Linux: sudo ufw allow 5432/tcp
```

### Populator fails to generate content

```bash
# Check logs
docker compose -f docker-compose.content-db.yml logs populator --tail 50

# Common issues:
# - GEMINI_API_KEY not set or invalid
# - Rate limited (free tier = 15 RPM) — populator retries automatically
# - Network issue — check internet connectivity
```

### Content not showing up in the app

1. Check content exists: `python populate_daily.py --dry-run`
2. Check API can reach DB: `./content-db/test_connection.sh`
3. Check `CONTENT_DB_ENABLED=true` in the backend `.env`
4. Check the `/admin/content-status` endpoint on your API

---

## Files reference

```
content-db/
├── .env.example           ← Template — copy to .env
├── init.sql               ← PostgreSQL schema (auto-runs on first boot)
├── Dockerfile.populator   ← Image for the cron/populator container
├── test_connection.sh     ← Connectivity test script
└── SETUP.md               ← This file

docker-compose.content-db.yml  ← Docker Compose for DB laptop

backend/
├── db/content_db.py            ← Remote DB connection layer
├── services/content_db_service.py  ← Read/write API for content
├── populate_daily.py           ← Content generation script
└── cron_runner.py              ← Scheduler daemon
```
