# 🚀 Deploy to Render in 5 Minutes

## Your Backend is Ready! ✅

The code is now on GitHub at: `github.com/shubham1697/cosmic-guide`

---

## **Step 1: Create Render Account** (2 min)

1. Go to **https://dashboard.render.com/**
2. Click **Sign Up** → Use GitHub to sign in
3. Authorize Render to access your GitHub repositories
4. ✅ Done!

---

## **Step 2: Deploy Web Service** (3 min)

### From Render Dashboard:

1. Click **New +** → **Web Service**
2. Click **Connect a repository** 
3. Find and select `cosmic-guide` repo
4. Click **Connect**

### Configure Service:

Fill in these values:

| Field | Value |
|-------|-------|
| **Name** | `cosmicguide-api` |
| **Environment** | `Python 3` |
| **Python Version** | `3.12.3` |
| **Region** | `Singapore` (or closest to you) |
| **Branch** | `master` |
| **Build Command** | `pip install -r backend/requirements.txt` |
| **Start Command** | `cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT` |

**Important:** Make sure **Build Command** points to `backend/requirements.txt`

If Render selects Python 3.14 by default, set the Python version to 3.12.3 to avoid `pydantic-core` Rust build errors.

### Environment Variables:

Click **Advanced** → **Add Environment Variable**

| Key | Value | Example |
|-----|-------|---------|
| `DATABASE_URL` | `sqlite:///./cosmicguide.db` | (leave as-is for MVP) |
| `SECRET_KEY` | Random 32-char string | `aB3dE9fG2hI5jK8lM1nO4pQ7rS0tUvW` |
| `GEMINI_API_KEY` | Your API key (optional) | Get from [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `AI_MODEL` | `gemini-2.5-flash-lite` | (free tier) |

**To generate a random SECRET_KEY** in terminal:
```bash
openssl rand -hex 16
```

### Deploy

1. Click **Create Web Service**
2. Watch the build logs (takes 2-3 minutes)
3. ✅ Once it says "Live", your backend is deployed!

---

## **Step 3: Get Your Live URL** (30 sec)

Once deployment is complete, you'll see:
```
Your web service is live at: https://cosmicguide-api.onrender.com
```

**Test it:** Open in your browser:
```
https://cosmicguide-api.onrender.com/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "ai_enabled": true
}
```

---

## **Step 4: Update Flutter App** 

Once your live URL is deployed, update the mobile app:

### Edit: `lib/services/api_service.dart`

Change:
```dart
static String get _baseUrl {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000/api/v1';
  }
  return 'http://localhost:8000/api/v1';
}
```

To:
```dart
static String get _baseUrl {
  return 'https://cosmicguide-api.onrender.com/api/v1';
}
```

Rebuild the app and test! 🎉

---

## ✅ Quick Checklist

- [ ] Render account created at https://dashboard.render.com
- [ ] Web Service connected to GitHub repo `cosmic-guide`
- [ ] Build Command: `pip install -r backend/requirements.txt`
- [ ] Start Command: `cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT`
- [ ] Environment variables added (SECRET_KEY, DATABASE_URL, GEMINI_API_KEY)
- [ ] Deployment is "Live" (shows green dot in Render dashboard)
- [ ] Health check returns `{"status":"healthy", ...}`
- [ ] Flutter app updated with new API base URL

---

## 🆘 Troubleshooting

### Build Fails: "No such file or directory: backend/requirements.txt"
**Fix:** Build command should be exactly:
```
pip install -r backend/requirements.txt
```

### Service won't start: "ModuleNotFoundError"
1. Check if requirements.txt is missing packages
2. Go to **Logs** tab in Render dashboard to see full error
3. Likely need to add the missing package and redeploy

### Build fails at `pydantic-core` / `maturin` / Rust
This usually means Render is using Python 3.14 and trying to compile from source.

Fix:
1. In Render service settings, set Python version to `3.12.3`
2. Ensure the repo has `runtime.txt` with `python-3.12.3`
3. Click **Manual Deploy** -> **Deploy latest commit**

### "Application startup failed"
1. Check main.py syntax (save file in VS Code = format check)
2. Verify GEMINI_API_KEY is either valid or empty (not invalid)
3. Watch logs in Render for full error details

### API returns 502 Bad Gateway
- Free tier is cold-starting (may take 30 seconds on first request)
- Wait 10 seconds and try again
- Upgrade to Render Plus for always-on instances

---

## 🎉 You're Live!

Your backend is now accessible 24/7 from your Android app!

### Next Steps:
1. ✅ Test all API endpoints from Flutter app
2. ✅ Add database seeding (populate tarot cards, stories, etc.)
3. ✅ Monitor logs in Render dashboard
4. ✅ Consider upgrading to PostgreSQL database when you add user accounts

---

## Costs

**Free Tier:**
- ✅ Web service with cold start delays
- ✅ SQLite database (5GB limit) 
- ✅ Gemini API free tier (limited)

**Estimated Monthly Cost:** $0 (free tier) → $7 (if upgraded to Plus)

