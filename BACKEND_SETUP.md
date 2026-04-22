# CosmicGuide Backend — Run & Test Instructions

## Prerequisites

- Docker & Docker Compose installed
- (Optional) `GEMINI_API_KEY` for AI-generated content

---

## 1. Start the backend

```bash
cd /Users/shubha.sharma/Documents/learn/app/astro-scope

# Start with Docker Compose
docker compose up --build

# Or run in background
docker compose up --build -d
```

The API will be available at **http://localhost:8000**

- Swagger docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

## 2. Set Gemini API key (optional)

```bash
# Option A: export before running
export GEMINI_API_KEY=your-key-here
docker compose up --build

# Option B: create a .env file in the project root
echo "GEMINI_API_KEY=your-key-here" > .env
docker compose up --build
```

Without the key, AI-generated content is disabled and static/template data is used instead.

---

## 3. Test API endpoints

### Health check
```bash
curl http://localhost:8000/health
```

### Horoscope
```bash
curl "http://localhost:8000/api/v1/horoscope/today?zodiac_sign=Aries"
```

### Birth Chart (Swiss Ephemeris)
```bash
curl -X POST http://localhost:8000/api/v1/chart/birth \
  -H "Content-Type: application/json" \
  -d '{
    "birthDate": "1995-06-15",
    "birthTime": "14:30",
    "birthPlace": "New Delhi, India"
  }'
```

### Current Transits
```bash
curl http://localhost:8000/api/v1/chart/transits
```

### Tarot Draw
```bash
curl http://localhost:8000/api/v1/tarot/draw
```

### Fortune
```bash
curl -X POST http://localhost:8000/api/v1/fortune/generate \
  -H "Content-Type: application/json" \
  -d '{"zodiacSign": "Leo", "topic": "Love", "mood": "Curious"}'
```

### Compatibility
```bash
curl -X POST http://localhost:8000/api/v1/compatibility/check \
  -H "Content-Type: application/json" \
  -d '{"sign1": "Aries", "sign2": "Leo"}'
```

### Kundli Matching
```bash
curl -X POST http://localhost:8000/api/v1/kundli/match \
  -H "Content-Type: application/json" \
  -d '{
    "person1": {"name": "Aarav", "birthDate": "1995-06-15", "birthTime": "14:30", "birthPlace": "New Delhi"},
    "person2": {"name": "Priya", "birthDate": "1997-03-22", "birthTime": "09:15", "birthPlace": "Mumbai"}
  }'
```

### Stories
```bash
curl http://localhost:8000/api/v1/stories
```

---

## 4. Stop the backend

```bash
docker compose down
```

---

## 5. Run without Docker (alternative)

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 6. Flutter frontend setup

The mobile app is configured to hit `http://localhost:8000/api/v1`.

- **iOS Simulator**: `localhost` works directly
- **Android Emulator**: change `_baseUrl` in `mobile-app/lib/services/api_service.dart` to `http://10.0.2.2:8000/api/v1`
- **Physical device**: use your machine's LAN IP (e.g. `http://192.168.x.x:8000/api/v1`)

```bash
cd mobile-app
flutter run
```

---

## 7. View logs

```bash
# Follow container logs
docker compose logs -f backend

# Or if running without Docker, logs print to stdout
```
