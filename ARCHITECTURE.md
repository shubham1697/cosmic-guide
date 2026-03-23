# System Architecture

This document describes the technical architecture of the CosmicGuide application.

---

## High-Level Architecture

Mobile App
↓
API Layer
↓
Astrology Engine + AI Content Generator
↓
Database
↓
Notification Service

---

## Architecture Components

### Mobile Client

Responsibilities:

* User interface
* Input collection
* Display horoscope
* Trigger API requests
* Handle notifications

Recommended frameworks:

* Flutter
* React Native

---

### API Layer

Handles:

* authentication
* business logic
* API endpoints
* communication with database
* AI requests

Recommended technologies:

* Node.js + Express
* Python FastAPI

---

### Astrology Logic Engine

Responsible for deterministic astrology calculations.

Includes:

* zodiac sign detection
* kundli matching
* compatibility scoring
* tarot randomizer

---

### AI Content Engine

Responsible for generating dynamic astrology content.

AI generated features:

* fortune messages
* personality insights
* compatibility explanations
* tarot interpretations
* astrology stories

---

### Database

Primary storage for:

* users
* birth details
* horoscopes
* tarot cards
* compatibility tables
* premium reports

Recommended database:

PostgreSQL (Supabase)

---

### Notification Service

Push notifications delivered using Firebase Cloud Messaging.

Examples:

"Your horoscope for today is ready."

---

## Scalability

Architecture supports:

* 100k+ users
* AI content caching
* horizontal API scaling
* CDN for content delivery
