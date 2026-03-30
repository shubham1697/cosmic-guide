# Backend Deployment Guide

## Deploy to Render (Recommended)

### Prerequisites
1. GitHub account with the code pushed
2. Render account (free at [render.com](https://render.com))
3. Gemini API key (optional but recommended for AI features)

### Step-by-step Deployment

#### 1. Connect GitHub to Render
1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Click **New +** → **Web Service**
3. Select **Connect a repository**
4. Authorize GitHub and select your `astro-scope` repository
5. Click **Connect**

#### 2. Configure the Web Service
**Basic Settings:**
- **Name:** `cosmicguide-api`
- **Environment:** `Python 3`
- **Build Command:** `pip install -r backend/requirements.txt`
- **Start Command:** `cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Branch:** `master` (or your main branch)

**Advanced Settings:**
- **Auto-deploy:** ON (redeploy on git push)

#### 3. Add Environment Variables
Click **Environment** and add:

| Key | Value | Notes |
|-----|-------|-------|
| `DATABASE_URL` | `sqlite:///./cosmicguide.db` | SQLite works initially. Can upgrade to PostgreSQL later |
| `SECRET_KEY` | Generate a strong random string (e.g., using `openssl rand -hex 32`) | Used for JWT signing |
| `GEMINI_API_KEY` | Your Google Gemini API key | Get it from [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `AI_MODEL` | `gemini-2.5-flash-lite` | Free & fast tier. Change to `gemini-2.5-flash` for higher quality |

#### 4. Deploy
Click **Deploy**. Render will:
1. Clone your repo
2. Install Python dependencies
3. Start the uvicorn server
4. Assign a URL like `https://cosmicguide-api.onrender.com`

This typically takes 2-3 minutes.

#### 5. Verify Deployment
Once live, test:
```bash
curl https://cosmicguide-api.onrender.com/health
```

Expected response:
```json
{"status":"healthy","version":"1.0.0","ai_enabled":true}
```

### Using Your Live API in Flutter

Update `lib/services/api_service.dart`:
```dart
const String baseUrl = 'https://cosmicguide-api.onrender.com/api/v1';
```

Then rebuild and test on Android/iOS.

---

## Upgrade to PostgreSQL (Optional)

Once you need persistent user data:

1. **Create a PostgreSQL database on Render**
   - Dashboard → New + → PostgreSQL
   - Copy the connection string

2. **Update environment variable**
   - `DATABASE_URL`: Set to your PostgreSQL connection string
   - Remove `?schema=public` if it's appended

3. **Run migrations** (if using Alembic)
   - Add migration command to deploy pipeline

4. **Commit & push**
   - Render redeploys automatically

---

## Troubleshooting

### "ModuleNotFoundError: No module named 'fastapi'"
- Check Python version (must be 3.8+)
- Verify `requirements.txt` is in backend/ folder
- Build command should be: `pip install -r backend/requirements.txt`

### "Import Error: cannot import name 'app' from main"
- Ensure `main.py` exports `app = FastAPI(...)`
- Check file syntax (Ctrl+Shift+B to format)

### AI features say "ai_enabled": false
- `GEMINI_API_KEY` is missing or invalid
- Check at [aistudio.google.com](https://aistudio.google.com/app/apikey)
- Add the key to Render environment and redeploy

### Slow deployments
- Free tier can be slow on first deploy (cold start)
- Renders spins down after 15 min of inactivity (use Render Plus for always-on)

---

## Cost Estimate (Free Tier)

- **Web Service:** Free (with cold-start delays)
- **SQLite Database:** Free (limited to 5GB)
- **Gemini API:** Free tier (up to 15 requests/minute, limited tokens)

**Recommended for MVP:** Free tier is totally fine. Upgrade only when you scale.

---

## Next Steps

Once deployed:
1. ✅ Update Flutter app API base URL
2. ✅ Test endpoints from mobile app
3. ✅ Add user authentication (optional for MVP)
4. ✅ Set up database seeding with initial data
5. ✅ Monitor logs in Render dashboard
