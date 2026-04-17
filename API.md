# API Documentation

---

## User APIs

POST /users/create
Create new user

GET /users/profile
Retrieve user profile

---

## Horoscope APIs

GET /horoscope/today

Parameters:

zodiac_sign

---

## Fortune API

POST /fortune/generate

Body:

zodiac_sign
topic
mood

---

## Tarot API

GET /tarot/draw

Returns random tarot card.

---

## Compatibility API

POST /compatibility/check

Body:

sign1
sign2

---

## Kundli API

POST /kundli/match

Body:

person1_birth_details
person2_birth_details

Returns Gun Milan score and compatibility insights.

---

## Stories API

GET /stories

Purpose:

Return a paginated list of stories from the database.

Query parameters:

- `page` default `1`
- `per_page` default `10`, max `50`
- `category` optional
- `featured` optional boolean
- `zodiac_sign` optional
- `date` optional, format `YYYY-MM-DD`
- `randomize` optional boolean, default `true`

Behavior:

- Read from the `stories` table only.
- Default to published stories for today.
- If there are too few stories for today, include recent published stories from previous days.
- If `category` is present, filter before randomization.
- If `zodiac_sign` is present, prefer sign-specific stories and fall back to general stories.

Response shape:

- `stories`
- `total`
- `page`
- `per_page`

Each story item contains:

- `id`
- `title`
- `summary`
- `content`
- `category`
- `read_time`
- `author`
- `published_at`

GET /stories/{story_id}

Purpose:

Return one story by id from the database.

Response shape:

- `id`
- `title`
- `summary`
- `content`
- `category`
- `read_time`
- `author`
- `published_at`

Recommended admin/internal endpoints:

POST /admin/stories/generate-daily

Purpose:

Generate the daily story batch, store it in the database, and mark rows as published if generation succeeds.

POST /admin/stories/regenerate

Purpose:

Regenerate stories for a given date, category, or zodiac sign without changing public API behavior.
