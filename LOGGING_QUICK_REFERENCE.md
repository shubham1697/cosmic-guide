# Backend Logging - Quick Reference

## What Gets Logged Now

### ✓ Frontend → Backend
```
→ POST /api/v1/compatibility/check | body: {"sign1":"Aries","sign2":"Leo"}
← POST /api/v1/compatibility/check | status=200 | score=85
```

### ✓ Backend → External Services  
```
→ Ollama POST /api/generate | model=gemma3:4b | prompt_preview="Generate compatibility..." | 1250ms
→ Gemini POST models.generateContent | model=gemini-1.5-flash | 500ms
```

### ✓ Backend → Database
```
🗄  SELECT horoscope where sign=Aries date=2026-04-28 | 1 rows 8ms
🗄  INSERT compatibility sign1=Aries sign2=Leo | 1 rows 5ms
```

### ✓ Service Layer
```
→ HoroscopeService.get_horoscope(Aries)
← HoroscopeService OK (42ms)
```

## How to View Logs

```bash
# All logs (default INFO level)
docker compose logs backend

# Follow logs in real-time
docker compose logs -f backend

# Get last 100 lines
docker compose logs --tail=100 backend

# Filter for API calls only
docker compose logs backend | grep "→ POST\|→ GET"

# Filter for Ollama/Gemini calls
docker compose logs backend | grep "Ollama\|Gemini"

# Filter for database queries (DEBUG level required)
docker compose logs backend | grep "🗄"

# Filter for errors
docker compose logs backend | grep "ERROR"

# Filter for slow requests (>5 seconds)
docker compose logs backend | grep "WARNING.*ms"
```

## Log Levels

```bash
# Maximum detail
export LOG_LEVEL=DEBUG

# Normal (default)
export LOG_LEVEL=INFO

# Only warnings/errors
export LOG_LEVEL=WARNING

# Errors only
export LOG_LEVEL=ERROR
```

## Testing Logging

1. Restart backend with fresh logs:
```bash
cd backend && ./server.sh restart
docker compose logs -f backend
```

2. Make API calls:
```bash
# Compatibility
curl -X POST http://localhost:8000/api/v1/compatibility/check \
  -H 'Content-Type: application/json' \
  -d '{"sign1":"Aries","sign2":"Leo"}'

# Horoscope
curl http://localhost:8000/api/v1/horoscope/today?zodiac_sign=Aries

# Fortune
curl -X POST http://localhost:8000/api/v1/fortune/generate \
  -H 'Content-Type: application/json' \
  -d '{"zodiac_sign":"Aries","topic":"love","mood":"hopeful"}'

# Stories
curl http://localhost:8000/api/v1/stories
```

3. Watch the logs appear in real-time

## Log Symbols

- `→` = Incoming request or outgoing call
- `←` = Response or result
- `🗄` = Database operation
- `⚠️` = Error or warning

## Files Modified

| File | Changes |
|------|---------|
| `logging_utils.py` | **NEW** - Centralized logging utilities |
| `main.py` | Request/response middleware, error handling |
| `db/database.py` | SQLAlchemy event listeners for queries |
| `services/ai_service.py` | Ollama & Gemini API call logging |
| `services/compatibility_service.py` | Service-level & DB query logging |
| `services/horoscope_service.py` | Service-level & DB query logging |
| `api/compatibility.py` | API endpoint request/response logging |
| `api/horoscope.py` | API endpoint request/response logging |
| `api/fortune.py` | API endpoint request/response logging |
| `api/stories.py` | API endpoint request/response logging |

## Common Log Patterns

### Cache Hit (Fast Response)
```
→ GET /horoscope/today?sign=Aries
🗄  SELECT horoscope where sign=Aries date=2026-04-28 | 1 rows 3ms
← GET /horoscope/today | status=200 | mood=optimistic
```
Total time: ~15ms

### Cache Miss (AI Generation)
```
→ POST /compatibility/check | body: {"sign1":"Virgo","sign2":"Pisces"}
🗄  SELECT compatibility where sign1=Pisces AND sign2=Virgo | 0 rows 2ms
→ Ollama POST /api/generate | model=gemma3:4b | prompt_preview="..." | 1500ms
🗄  INSERT compatibility sign1=Pisces sign2=Virgo | 1 rows 5ms
← POST /compatibility/check | status=200 | score=78
```
Total time: ~1550ms (dominated by AI generation)

### Error Cases
```
→ POST /compatibility/check | body: {"sign1":"Invalid","sign2":"Leo"}
← POST /compatibility/check | status=400 | invalid signs
```

```
→ GET /horoscope/today?sign=Aries
🗄  SELECT horoscope where sign=Aries date=2026-04-28 | ERROR after 50ms | Connection refused
← GET /horoscope/today | status=500
```

## Troubleshooting

**Problem**: Not seeing database queries in logs
- Solution: Set `LOG_LEVEL=DEBUG` to see 🗄 database symbols

**Problem**: Logs are too verbose
- Solution: Set `LOG_LEVEL=WARNING` to see only issues

**Problem**: Request bodies showing as "(no body)"
- Solution: This is normal for GET requests. POST/PUT requests show bodies.

**Problem**: Can't find a specific request
- Solution: Look for the timestamp in backend logs that matches the app action

## Performance Notes

- **INFO level**: Minimal overhead (~0.5%)
- **DEBUG level**: More overhead due to query logging (~2-3%)
- **Payload truncation**: Automatic at 200 chars to prevent log bloat
- **No performance degradation**: Even with full logging

## Integration with Docker

All backend logs automatically flow to `docker compose logs`. Environment variables persist across restarts:

```bash
# Set log level and restart
export LOG_LEVEL=DEBUG
docker compose restart backend

# Or in docker-compose.yml
environment:
  - LOG_LEVEL=DEBUG
```
