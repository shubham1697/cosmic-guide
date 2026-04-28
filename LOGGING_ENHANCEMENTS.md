# Backend Logging Enhancements

Comprehensive logging has been added throughout the CosmicGuide backend to track all API calls, from frontend requests to backend services, and from backend to external services.

## Overview

### What's Logged

1. **Frontend → Backend API Calls**
   - All incoming HTTP requests (GET, POST, PUT)
   - Request path, method, query parameters, and request body
   - Response status codes and response times
   - Slow requests (>5 seconds) logged at WARNING level

2. **Backend → External Services (Ollama, Gemini)**
   - All AI API calls with service name, endpoint, method
   - Request payloads (truncated for readability)
   - Response payloads and response times
   - Errors with full exception details

3. **Backend → Database**
   - All SQL queries (SELECT, INSERT, UPDATE, DELETE)
   - Query execution times
   - Rows affected
   - Query errors with stack traces

4. **Service Layer**
   - Service function calls with parameters
   - Cache hits vs misses (memory, DB)
   - AI generation requests and responses
   - Data persistence operations

## New Files

### `backend/logging_utils.py`
Centralized logging utilities providing:

- **`log_external_api_call()`** - Log external service calls (Ollama, Gemini, etc.)
  - Service name, endpoint, HTTP method
  - Request/response payloads (auto-truncated)
  - Elapsed time, status codes
  - Exception details on failure

- **`log_db_query()`** - Log database operations
  - Operation type (SELECT, INSERT, UPDATE, DELETE)
  - Table name and filter expressions
  - Rows affected, execution time
  - Errors with context

- **`service_call`** - Decorator for logging service function calls
  - Automatically logs function entry/exit
  - Captures parameters and return values
  - Tracks execution time
  - Logs exceptions

## Enhanced Files

### `backend/main.py`
- **Enhanced middleware** - Now captures and logs request bodies (for POST/PUT)
  - Parses JSON payloads and shows preview
  - Logs user-agent and accept headers
  - More detailed response logging

- **Better error handling** - Global exception handler now logs:
  - Exception type
  - Request method and path
  - Full stack trace
  - Marked with ⚠️ emoji for visibility

### `backend/db/database.py`
- **SQL event listeners** - All queries logged via SQLAlchemy events
  - Logs before each query executes
  - Shows SQL statement and parameters preview
  - Marked with 🗄 emoji for database operations

### `backend/services/ai_service.py`
- **Ollama API calls** - Enhanced `_call_ai_ollama()` with:
  - Model name and format (JSON/text)
  - Request preview (first 100 chars)
  - Response time in milliseconds
  - Uses `log_external_api_call()` utility

- **Gemini API calls** - Enhanced `_call_ai()` with:
  - Model name and request preview
  - Response time and length
  - Uses `log_external_api_call()` utility

### `backend/services/compatibility_service.py`
- **DB queries** - Now logged with:
  - Operation type (SELECT, INSERT)
  - Canonical sign pair names
  - Cache hit/miss status
  - Query execution time

### `backend/services/horoscope_service.py`
- **DB queries** - Now logged with:
  - Zodiac sign and date filter
  - In-memory cache hit/miss
  - DB cache hit/miss
  - Query execution time

### `backend/api/compatibility.py`
- Request logging - Log incoming sign pair
- Response logging - Log result score and status

### `backend/api/horoscope.py`
- Request logging - Log incoming sign and date
- Response logging - Log mood and status

### `backend/api/fortune.py`
- Request logging - Log zodiac sign, topic, mood
- Response logging - Log fortune text length and status

### `backend/api/stories.py`
- Request logging - Log pagination and category filter
- Response logging - Log returned count and total count

## Log Levels

Configure logging verbosity via `LOG_LEVEL` environment variable:

```bash
# DEBUG — Very verbose (all queries, prompts, cache operations)
export LOG_LEVEL=DEBUG

# INFO — Normal operation (requests, responses, cache hits, AI calls)  (default)
export LOG_LEVEL=INFO

# WARNING — Only issues (slow requests >5s, fallbacks, retries)
export LOG_LEVEL=WARNING

# ERROR — Only failures
export LOG_LEVEL=ERROR
```

### Example Log Output

**DEBUG level** (most detailed):
```
2026-04-28 14:32:15 | DEBUG   | main | → GET /horoscope/today?sign=Aries
2026-04-28 14:32:15 | DEBUG   | logging_utils | 🗄  SELECT horoscope where sign=Aries date=2026-04-28 | 12ms
2026-04-28 14:32:15 | INFO    | compatibility_service | → get_pair_score(Aries, Leo)
2026-04-28 14:32:15 | DEBUG   | logging_utils | → Ollama POST /api/generate | req={"model":"gemma3:4b"...} | resp={"sign1":"Aries"...}
2026-04-28 14:32:15 | INFO    | main | ← GET /horoscope/today  status=200  125ms
```

**INFO level** (default):
```
2026-04-28 14:32:15 | INFO    | main | → GET /horoscope/today?sign=Aries
2026-04-28 14:32:15 | INFO    | compatibility_service | get_compatibility  DB HIT  Aries x Leo
2026-04-28 14:32:15 | INFO    | main | ← GET /horoscope/today  status=200  125ms
```

**WARNING level** (only issues):
```
2026-04-28 14:32:15 | WARNING | main | ← GET /horoscope/today  status=200  5234ms
2026-04-28 14:32:15 | WARNING | ai_service | → Gemini POST models.generateContent | status=429 150ms
```

## Key Features

### Structured Logging
- Consistent format across all modules
- Easy to parse and filter
- Includes timestamps, log levels, module names

### Performance Monitoring
- All API calls timed (frontend requests, external services, DB queries)
- Slow requests flagged at WARNING level
- Helps identify bottlenecks

### Error Tracking
- Full stack traces for exceptions
- Service context (which API call, which operation)
- Parameter values for debugging

### Payload Truncation
- Large payloads automatically truncated (200 chars)
- Prevents log spam from huge responses
- Still shows enough context for debugging

### Cache Visibility
- Clear logs for cache hits vs misses
- Shows which caching layer (memory, DB, AI)
- Helps optimize caching strategy

## Debugging Tips

### To see all backend API calls:
```bash
export LOG_LEVEL=INFO
# Then run: docker compose logs backend | grep "→"
```

### To see all external API calls:
```bash
export LOG_LEVEL=DEBUG
# Then run: docker compose logs backend | grep "Ollama\|Gemini"
```

### To see all database queries:
```bash
export LOG_LEVEL=DEBUG
# Then run: docker compose logs backend | grep "🗄"
```

### To see slow requests:
```bash
export LOG_LEVEL=WARNING
# Then run: docker compose logs backend | grep "WARNING"
```

## Example: Full Request-Response Trace

Frontend calls `/api/v1/compatibility/check`:

```
→ POST /api/v1/compatibility/check | body: {"sign1":"Aries","sign2":"Leo"}
    → CompatibilityService.get_compatibility("Aries", "Leo")
        🗄  SELECT compatibility where sign1=Aries AND sign2=Leo | 5ms
        ← 1 row (DB HIT - cached result found)
    ← CompatibilityService OK (35ms)
← POST /api/v1/compatibility/check | status=200 35ms
```

If not cached, it would show:

```
→ POST /api/v1/compatibility/check | body: {"sign1":"Aries","sign2":"Leo"}
    → CompatibilityService.get_compatibility("Aries", "Leo")
        🗄  SELECT compatibility where sign1=Aries AND sign2=Leo | 3ms
        ← 0 rows (DB MISS - generating new content)
        → Ollama POST /api/generate | model=gemma3:4b | 1200ms
        ← Ollama OK (1200ms) resp={"love_advice":"..."}
        🗄  INSERT compatibility sign1=Aries sign2=Leo | 8ms
    ← CompatibilityService OK (1250ms)
← POST /api/v1/compatibility/check | status=200 1250ms
```

## Testing the Enhancements

1. **Restart the backend:**
   ```bash
   cd backend && ./server.sh restart
   ```

2. **Monitor logs in real-time:**
   ```bash
   docker compose logs -f backend
   ```

3. **Make API requests from the app or curl:**
   ```bash
   curl -X POST http://localhost:8000/api/v1/compatibility/check \
     -H 'Content-Type: application/json' \
     -d '{"sign1":"Aries","sign2":"Leo"}'
   ```

4. **Observe the logging output** showing the complete flow.

## Performance Considerations

- Logging adds minimal overhead (<1% in most cases)
- Payload truncation prevents memory issues with large responses
- Use WARNING level in production to reduce I/O
- SQLAlchemy event listeners are very efficient

## Future Enhancements

Possible additions:
- Request IDs for tracing across multiple services
- Structured JSON logging for easier parsing
- Metrics collection (response times, error rates)
- Log rotation and file storage
- Integration with log aggregation (ELK, CloudWatch, etc.)
