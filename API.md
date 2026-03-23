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
