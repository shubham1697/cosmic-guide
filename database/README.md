# CosmicGuide Database & Populator

Step-by-step guide to run the PostgreSQL database and populate it with AI-generated content via Ollama.

---

## Prerequisites

- **Docker & Docker Compose** installed
- **Ollama** running on `192.168.29.159:11434` with the `mistral:latest` model pulled
  ```bash
  # On the Ollama machine (192.168.29.159):
  ollama pull mistral:latest
  ollama serve   # should be listening on 0.0.0.0:11434
  ```

---

## Step 1 — Start the Database

```bash
cd astro-scope
docker compose up db -d
```

This starts a **PostgreSQL 16** container (`cosmicguide-db`) on port **5432**.

Verify it's healthy:

```bash
docker compose ps db
# STATE should be "running (healthy)"
```

Connection details:

| Key      | Value         |
|----------|---------------|
| Host     | localhost     |
| Port     | 5432          |
| User     | cosmicguide   |
| Password | cosmicguide   |
| Database | cosmicguide   |

---

## Step 2 — Run the Populator (Docker)

The populator is a one-shot container that connects to the DB, calls Ollama, and writes content.

### Populate everything (all categories):

```bash
docker compose --profile populate run --rm populate
```

./populate.sh              # everything
./populate.sh -h           # horoscopes only
./populate.sh -t           # tarot only
./populate.sh -f           # fortunes only
./populate.sh -c           # compatibility only
./populate.sh -s           # stories only
./populate.sh -S           # seed static data (no LLM)
./populate.sh -F           # force regenerate
./populate.sh -d 2026-04-28  # specific date
./populate.sh --status     # check DB status
./populate.sh -hf          # combine: horoscopes + fortunes
./populate.sh -hF          # horoscopes, force regenerate

### Populate specific categories only:

```bash
# Horoscopes for today (12 signs)
docker compose --profile populate run --rm populate --horoscopes

# Tarot cards (78 cards with AI interpretations)
docker compose --profile populate run --rm populate --tarot

# Fortune pool (12 signs × 5 topics)
docker compose --profile populate run --rm populate --fortunes

# Compatibility (78 sign pairs)
docker compose --profile populate run --rm populate --compatibility

# Stories (6 cosmic articles)
docker compose --profile populate run --rm populate --stories
```

### Useful flags:

```bash
# Force regenerate even if data already exists
docker compose --profile populate run --rm populate --force

# Generate for a specific date
docker compose --profile populate run --rm populate --horoscopes --date 2026-04-28

# Seed static data only (tarot + compatibility from built-in tables, no LLM)
docker compose --profile populate run --rm populate --seed

# Check what's already in the DB
docker compose --profile populate run --rm populate --status
```

---

## Step 3 — Verify the Data

### Option A: Via the populator's `--status` flag

```bash
docker compose --profile populate run --rm populate --status
```

### Option B: Connect with psql

```bash
docker compose exec db psql -U cosmicguide -d cosmicguide
```

```sql
SELECT COUNT(*) FROM horoscopes;        -- expect 12 per date
SELECT COUNT(*) FROM tarot_cards;       -- expect 78
SELECT COUNT(*) FROM fortune_pool;      -- expect 60 per date
SELECT COUNT(*) FROM compatibilities;   -- expect 78
SELECT COUNT(*) FROM stories;           -- expect 6+
```

### Option C: Via the backend API (if running)

```bash
curl -H "X-Admin-Key: $ADMIN_API_KEY" http://localhost:8000/admin/content-status
```

---

## Running Without Docker (locally)

If you want to run the populator directly on your machine:

```bash
cd astro-scope

# Install dependencies
pip install -r database/requirements.txt

# Make sure Postgres is reachable at localhost:5432
# (or set DATABASE_URL to point elsewhere)
export DATABASE_URL=postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide

# Run
python database/populate_db.py --status          # check current state
python database/populate_db.py                    # populate everything
python database/populate_db.py --horoscopes       # just horoscopes
```

### Environment variables

| Variable       | Default                                                    | Description                     |
|----------------|------------------------------------------------------------|---------------------------------|
| `DATABASE_URL` | `postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide` | PostgreSQL connection string    |
| `AI_PROVIDER`  | `auto`                                                     | LLM backend: `auto`/`gemini`/`ollama`/`iphone` |
| `OLLAMA_BASE_URL` | `http://192.168.29.159:11434`                           | Ollama base URL (overrides `OLLAMA_HOST`) |
| `OLLAMA_HOST`  | `192.168.29.159:11434`                                     | Ollama server `host:port`       |
| `OLLAMA_MODEL` | `gemma3:4b`                                                | Ollama model to use             |
| `OLLAMA_TIMEOUT` | `600`                                                    | HTTP timeout in seconds         |
| `IPHONE_LLM_BASE_URL` | `http://192.168.29.162:8080/v1`                     | iPhone LLM OpenAI-compatible endpoint |
| `IPHONE_LLM_MODEL` | `base`                                                 | iPhone LLM model name           |
| `IPHONE_LLM_API_KEY` | `not-needed`                                         | iPhone LLM API key (if required) |
| `GEMINI_API_KEY` | _(empty)_                                                | Google Gemini API key (enables Gemini) |
| `AI_MODEL`     | `gemini-2.5-flash-lite`                                    | Gemini model name               |
| `LOG_LEVEL`    | `INFO`                                                     | Logging level (`DEBUG`/`INFO`/`WARNING`) |

---

## Full Stack (DB + Backend + Populate)

```bash
# Start DB + backend
docker compose up -d

# Run populator once
docker compose --profile populate run --rm populate

# Tail backend logs
docker compose logs -f backend
```

---

## Resetting the Database

```bash
# Stop everything and delete the data volume
docker compose down -v

# Start fresh
docker compose up db -d
docker compose --profile populate run --rm populate
```
