# CosmicGuide – Production Architecture (Render-Based, Python Backend)

This document defines the **final production-ready architecture** for the CosmicGuide astrology application using:

* **Backend:** Python (FastAPI)
* **Hosting:** Render (Web Service + optional Worker)
* **Database:** Render PostgreSQL
* **AI:** OpenAI / Gemini
* **Notifications:** Firebase

This setup is optimized for:

* fast MVP launch
* minimal cost (free → low cost)
* clean scalability

---

# High-Level Architecture

```
                ┌──────────────────────────┐
                │     Mobile App (Flutter) │
                └────────────┬─────────────┘
                             │ HTTPS
                             ▼
                ┌──────────────────────────┐
                │   Render Web Service     │
                │   (FastAPI Backend)      │
                └───────┬─────────┬────────┘
                        │         │
                        │         │
        ┌───────────────▼───┐     ▼
        │ Astrology Engine  │   AI Service Layer
        │ (Deterministic)   │   (OpenAI / Gemini)
        └──────────┬────────┘     │
                   │              │
                   └──────┬───────┘
                          ▼
                ┌──────────────────────┐
                │ Render PostgreSQL DB │
                └──────────┬───────────┘
                           ▼
                ┌──────────────────────┐
                │ Firebase Notifications│
                └──────────────────────┘
```

---

# Core Components

## 1. Mobile App (Frontend)

**Technology:** Flutter

Responsibilities:

* onboarding (DOB, time, place)
* display horoscope
* trigger fortune generation
* tarot UI
* compatibility UI
* kundli input

Communicates only via HTTPS APIs.

---

## 2. Backend (Render Web Service)

**Technology:** FastAPI (Python)

This is the main backend service.

### Folder Structure

```
backend/
├── main.py
├── api/
│   ├── horoscope.py
│   ├── fortune.py
│   ├── tarot.py
│   ├── compatibility.py
│   ├── kundli.py
│   └── user.py
├── services/
│   ├── ai_service.py
│   ├── astrology_service.py
│   └── notification_service.py
├── db/
│   ├── models.py
│   └── database.py
├── utils/
└── config.py
```

---

## 3. API Layer

### Endpoints

```
GET  /horoscope/today
POST /fortune/generate
GET  /tarot/draw
POST /compatibility/check
POST /kundli/match
GET  /user/profile
```

---

## 4. Astrology Engine

Pure Python logic (no AI).

### Responsibilities

* zodiac calculation
* compatibility scoring
* kundli matching (Gun Milan)
* tarot randomizer

### Example Output

```
Gun Milan Score: 26/36
Compatibility: Good
```

---

## 5. AI Service Layer

Handles all AI-generated content.

### Use Cases

* fortune generation
* personality insights
* compatibility explanation
* tarot interpretation
* astrology stories

### Flow

```
API → AI Service → OpenAI → Response → Return
```

---

## 6. Database (Render PostgreSQL)

Primary database hosted on Render.

### Core Tables

```
users
horoscopes
tarot_cards
compatibility
kundli_reports
fortune_history
subscriptions
```

### Example Connection

```
DATABASE_URL=postgresql://user:password@host:port/dbname
```

---

## 7. Notifications (Firebase)

Used for:

* daily horoscope alerts
* engagement reminders
* premium feature notifications

---

# Background Jobs (Optional – Render Worker)

Add later when scaling.

### Worker Responsibilities

* generate daily horoscopes
* send push notifications
* precompute AI content
* clean old data

---

# Request Flows

## Daily Horoscope

```
App → API
     → DB query
     → Return response
```

---

## Fortune Generation

```
App → API
     → AI Service
     → OpenAI
     → Return response
```

---

## Kundli Matching

```
App → API
     → Astrology Engine
     → Optional DB save
     → Return result
```

---

# Deployment Setup

## Render Services

### 1. Web Service

* FastAPI backend
* auto-deploy from GitHub

### 2. PostgreSQL

* managed database
* connected via DATABASE_URL

### 3. Worker Service (optional)

* background jobs

---

# Environment Variables

```
DATABASE_URL
OPENAI_API_KEY
FIREBASE_SERVER_KEY
SECRET_KEY
```

---

# Scaling Plan

## Stage 1 (0–10k users)

* Render free web service
* Render free PostgreSQL
* no caching

---

## Stage 2 (10k–100k users)

* upgrade Render instance
* add Redis (optional external)
* add worker service

---

## Stage 3 (100k+ users)

* multiple backend instances
* load balancing
* DB read replicas
* CDN for content

---

# Design Principles

* keep backend simple (monolith first)
* deterministic astrology logic
* AI only for content generation
* minimal infrastructure early
* scale only when needed

---

# Final Stack

```
Frontend: Flutter
Backend: FastAPI (Python)
Hosting: Render
Database: Render PostgreSQL
AI: OpenAI / Gemini
Notifications: Firebase
```

---

# Conclusion

This architecture is:

* extremely simple to start
* free / low-cost initially
* easy to deploy
* scalable to real production

---

End of Document
