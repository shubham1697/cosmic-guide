# Database Schema

This document reflects the current backend ORM schema and recommended next additions.

## Engine and Environment

- Default local database: SQLite at `sqlite:///./cosmicguide.db`.
- Production target: PostgreSQL via `DATABASE_URL`.
- ORM: SQLAlchemy (`declarative_base`, `SessionLocal`).
- Table creation currently uses `Base.metadata.create_all(...)` on app startup.

## Implemented Tables

### 1) users

Purpose: account profile and birth details.

Columns:
- `id` (PK, int)
- `name` (varchar(100), not null)
- `email` (varchar(255), unique, indexed, not null)
- `password_hash` (varchar(255), not null)
- `birth_date` (varchar(10), `YYYY-MM-DD`)
- `birth_time` (varchar(5), `HH:MM`)
- `birth_place` (varchar(255))
- `zodiac_sign` (varchar(20))
- `is_premium` (bool, default false)
- `created_at` (datetime, UTC)
- `updated_at` (datetime, UTC, auto-update)

Indexes and constraints:
- Primary key: `id`
- Unique index: `email`

### 2) horoscopes

Purpose: cached/generated horoscope content by date and sign.

Columns:
- `id` (PK, int)
- `date` (varchar(10), indexed, `YYYY-MM-DD`)
- `zodiac_sign` (varchar(20), indexed)
- `general` (text)
- `love` (text)
- `career` (text)
- `health` (text)
- `overall_score` (int)
- `lucky_number` (int)
- `lucky_color` (varchar(50))
- `mood` (varchar(50))
- `created_at` (datetime, UTC)

Indexes and constraints:
- Primary key: `id`
- Indexes: `date`, `zodiac_sign`

Recommended improvement:
- Add composite unique constraint on (`date`, `zodiac_sign`).

### 3) tarot_cards

Purpose: tarot master data.

Columns:
- `id` (PK, int)
- `name` (varchar(100), unique, not null)
- `number` (varchar(10))
- `meaning` (text)
- `upright_interpretation` (text)
- `reversed_interpretation` (text)

Indexes and constraints:
- Primary key: `id`
- Unique: `name`

### 4) compatibility

Purpose: cached sign-pair compatibility insights.

Columns:
- `id` (PK, int)
- `sign1` (varchar(20), indexed)
- `sign2` (varchar(20), indexed)
- `score` (int)
- `description` (text)
- `love_advice` (text)
- `strengths` (text)
- `challenges` (text)

Indexes and constraints:
- Primary key: `id`
- Indexes: `sign1`, `sign2`

Recommended improvement:
- Add composite unique constraint on (`sign1`, `sign2`).

### 5) fortune_history

Purpose: store user fortune generations.

Columns:
- `id` (PK, int)
- `user_id` (int, indexed)
- `zodiac_sign` (varchar(20))
- `topic` (varchar(50))
- `mood` (varchar(50))
- `fortune_text` (text)
- `created_at` (datetime, UTC)

Indexes and constraints:
- Primary key: `id`
- Index: `user_id`

Recommended improvement:
- Add FK `user_id -> users.id`.

### 6) stories

Purpose: editorial/AI-generated stories served to app users.

Columns:
- `id` (PK, int)
- `title` (varchar(255), not null)
- `summary` (text)
- `content` (text)
- `category` (varchar(50), indexed)
- `read_time` (varchar(20))
- `author` (varchar(100))
- `published_at` (datetime, UTC)
- `is_featured` (bool, default false)

Indexes and constraints:
- Primary key: `id`
- Index: `category`

Recommended improvements:
- Index on `published_at`.
- Optional dedupe rule: unique (`title`, `published_at`).
- Add `story_date` (date bucket used for daily generation and filtering).
- Add `status` (`draft`, `published`, `archived`) so generation and moderation are separated.
- Add `generation_source` (`ai`, `template`, `editorial`) for debugging and fallback tracking.
- Add nullable `zodiac_sign` for sign-specific stories.
- Add nullable `language` if multilingual content is planned.
- Add nullable `quality_score` for ranking and moderation.
- Add nullable `expires_at` if stories should rotate out after a recency window.

## Stories Strategy

Recommended v1 approach:
- Generate a batch of stories daily.
- Save them in the `stories` table.
- Serve users from the database only.
- Randomize selection from a filtered pool, not the entire table.

Why this is the correct default:
- lower AI cost because generation is batched rather than request-time
- faster API responses because reads come from the database
- higher reliability because the app can serve yesterday's content if generation fails
- better moderation and dedupe because content is reviewed before it reaches users

Recommended generation flow:
1. Run a scheduled job once per day.
2. Generate a fixed batch per category, and optionally per zodiac sign.
3. Write rows with `story_date`, `published_at`, `status`, and `generation_source`.
4. Deduplicate on insert using a deterministic key such as (`story_date`, `category`, `title`).
5. If AI generation fails, create fallback template stories and mark them with `generation_source = template`.

Recommended serving flow:
1. Query published stories for today.
2. Filter by category, sign, language, or featured flag when requested.
3. Randomize within the filtered pool.
4. If today's pool is too small, fall back to the previous 3 to 7 days.
5. Optionally exclude stories already seen by the user once user impressions are tracked.

### Stories Table: Target Shape For API-Backed Content

The current `stories` table is usable for a basic launch. For the planned daily-generated Stories API, the target shape should be:

- `id` (PK)
- `title`
- `summary`
- `content`
- `category`
- `zodiac_sign` (nullable)
- `read_time`
- `author`
- `story_date` (date used for daily selection)
- `published_at`
- `expires_at` (nullable)
- `is_featured`
- `status`
- `generation_source`
- `quality_score` (nullable)
- `language` (nullable)
- `created_at`
- `updated_at`

Recommended indexes for the target shape:
- (`story_date`, `status`)
- (`category`, `story_date`)
- (`zodiac_sign`, `story_date`) if sign-specific stories are used
- (`is_featured`, `story_date`)

Recommended uniqueness rules:
- (`story_date`, `category`, `title`)
- If sign-specific: (`story_date`, `category`, `zodiac_sign`, `title`)

### Stories Selection Rules

Default client experience:
- show a randomized list from today's published stories
- if category is provided, randomize inside that category only
- if not enough rows exist for today, include recent published rows from previous days

Do not:
- generate stories live on every request
- pick random rows from the entire historical table with no date filter
- overwrite yesterday's content in place

### Future Related Tables

Optional tables once personalization is added:

`story_impressions`
- `id`
- `user_id` nullable for guest users
- `story_id`
- `shown_at`
- `clicked_at` nullable
- `read_completed_at` nullable

Use case:
- avoid showing the same story repeatedly
- measure CTR and completion rate

`story_bookmarks`
- `id`
- `user_id`
- `story_id`
- `created_at`

Use case:
- user saved content library

`story_generation_runs`
- `id`
- `run_date`
- `source_model`
- `status`
- `generated_count`
- `fallback_count`
- `error_summary` nullable
- `created_at`

Use case:
- operational visibility into scheduled story generation

### 7) kundli_reports

Purpose: persist generated kundli matching reports.

Columns:
- `id` (PK, int)
- `user_id` (int, indexed)
- `person1_name` (varchar(100))
- `person1_birth_date` (varchar(10))
- `person1_birth_time` (varchar(5))
- `person1_birth_place` (varchar(255))
- `person2_name` (varchar(100))
- `person2_birth_date` (varchar(10))
- `person2_birth_time` (varchar(5))
- `person2_birth_place` (varchar(255))
- `total_score` (int)
- `max_score` (int, default 36)
- `koota_scores` (JSON)
- `compatibility` (varchar(50))
- `analysis` (text)
- `has_manglik_dosha` (bool, default false)
- `created_at` (datetime, UTC)

Indexes and constraints:
- Primary key: `id`
- Index: `user_id`

Recommended improvement:
- Add FK `user_id -> users.id`.

## Relationships (Recommended)

Current schema keeps `user_id` as plain integer in history/report tables.

Recommended foreign keys:
- `fortune_history.user_id -> users.id`
- `kundli_reports.user_id -> users.id`

Optional additional relation tables:
- `saved_charts` for multiple birth profiles per user.
- `bookmarks` for user-saved stories/readings.

## Data to Store vs Not Store

Store:
- user profile and birth details
- generated outputs needed for history/replay (fortune, kundli, horoscope snapshots)
- content catalog (stories, tarot metadata)
- subscription/entitlement state

Avoid storing:
- API keys and secrets
- raw internal LLM chain-of-thought
- large transient debug payloads

## Next Tables to Add

### auth_tokens (or refresh_tokens)

Purpose: secure session management.

Columns (suggested):
- `id` (PK)
- `user_id` (FK)
- `token_hash`
- `expires_at`
- `created_at`
- `revoked_at`

### subscriptions

Purpose: premium billing state and entitlement source of truth.

Columns (suggested):
- `id` (PK)
- `user_id` (FK)
- `provider` (apple/google/stripe)
- `product_id`
- `status`
- `started_at`
- `expires_at`
- `transaction_id` (unique)

### user_activity

Purpose: basic analytics and engagement tracking.

Columns (suggested):
- `id` (PK)
- `user_id` (FK, nullable for guest)
- `event_type`
- `event_payload` (JSON)
- `created_at`

## Migration Strategy

Current state uses auto table creation. For production-safe evolution, move to Alembic migrations:

1. Initialize Alembic and generate baseline from current models.
2. Add explicit constraints and foreign keys in versioned migrations.
3. Run migrations in CI/CD before app start.
4. Keep `create_all` only for local/dev bootstrap, not production rollout.

## Stories API Contract Notes

The current Pydantic response shape already supports a basic list/detail API:
- `StoryResponse`: `id`, `title`, `summary`, `content`, `category`, `read_time`, `author`, `published_at`
- `StoryListResponse`: `stories`, `total`, `page`, `per_page`

For the DB-backed Stories API, keep the response shape stable for v1 and add filtering/query behavior first. Once the schema grows, optional response fields can be added for `is_featured`, `zodiac_sign`, and `story_date`.
