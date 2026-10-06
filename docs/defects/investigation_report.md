Investigation complete
I treated the repo as hostile-until-proven-correct: read all 53 files line by line, then booted the service in a sandbox (SQLite, no network) and reproduced every major claim with a runnable experiment before recording it. Full write-up with file/line references and the remediation plan is in /workspace/investigation/FINDINGS.md. Here's what matters most:

P0 — It doesn't boot, and it can destroy data
The repository cannot start. config.py:27 and main.py:14 import a shared package (shared.llm_config, shared.db_migrations) that exists nowhere in the repo or its git history. Production evidently depends on an untracked directory dropped in at deploy time — which also silently carries all LLM timeouts/defaults. I reconstructed a clearly-marked shim (backend/shared/) from the call-site interface to proceed. Related deploy debt: server.sh references a docker-compose.yml that isn't in the repo, and requirements.txt omits requests (used directly by ai_service.py; only installed transitively today).

POST /stories/generate wipes production content on failure. It commits DELETE FROM stories before calling the LLM. Reproduced: 3 stories → LLM unreachable → 202 Accepted → 0 stories. It also reuses the request-scoped DB session in a background task after FastAPI has closed it (works only by SQLAlchemy accident).

P1 — Wrong answers served to users (all reproduced)
Compatibility seeding vs. lookup disagree on pair ordering. /admin/seed-oneshot stores pairs in zodiac order; reads canonicalize alphabetically — 32 of 78 pairs permanently miss the cache, quietly re-triggering paid LLM calls and inserting duplicate rows. (The CLI seeder uses the other ordering.)

Kundli (Gun Milan) math is wrong in five independent ways: the Nadi table (worth 8/36 — the traditional marriage veto) is wrong for 6 of 27 nakshatras; Rohini's Gana is wrong; the Varna comparison is inverted (Brahmin groom + Shudra bride scores 0, the reverse scores 1); Leo's Vashya class is wrong; and Yoni is scored by a meaningless "animal index distance" while the real compatibility matrix is imported and never used. Tara and Graha Maitri are silently over-simplified (Maitri can never detect enemy lords).

Every antardasha ever returned is wrong. _current_dasha starts the sub-period cycle at Ketu instead of the mahadasha lord. Reproduced: 10 days into a Rahu mahadasha → API says antardasha = Ketu; it must be Rahu.

The nightly refresh skips content it should generate. existing_signs ignores the system column — one vedic row for a sign blocks that sign's western horoscope for the whole day; content-status over-reports readiness the same way. The job also inserts 5 new stories on every run (no dedup).

Malformed input → 500s: 2023-02-31 on /chart/birth, any garbage date on /kundli/match and /vedic/home-summary return 500 instead of 4xx, while /horoscope/forecast swallows the same error into an empty 200. Fortune accepts sign "Aardvark".

Smaller correctness items: weekly/monthly LLM fallback serves daily copy ("Today is a day of bold moves…" under 2026-W32); every Vedic chart contains a synthetic exact Rahu–Ketu "opposition"; Western charts for polar-latitude births crash (uncaught swe.houses error — the sidereal path guards this, the tropical path doesn't).

P2 — Reliability & security (all reproduced except where noted)
Race + no uniqueness: 3 concurrent first requests created 3 duplicate horoscope rows (and 3 paid LLM calls); no unique constraints on any cache table.
/health blocks 10s when LLM hosts stall (two sequential 5s probes) — a liveness-probe killer.
6 identical Nominatim geocoding calls per /vedic/home-summary request, zero caching, against a 1-req/s free service with a 10s timeout each.
Unauthenticated admin surface: anyone can wipe all stories, trigger paid LLM batch jobs, or spam pushes.
CORS reflects any origin with allow_credentials=true (verified against a hostile origin) — a time bomb for the staged-but-unshipped auth.
auto AI provider doesn't actually fall back when a Gemini call fails (only when the key is absent) — contradicting its own docs; quota blips degrade the product to static templates despite a healthy local LLM.
Notifications: a partial re-register nulls the user's zodiac sign/tradition; unknown-token preference updates return 200 not_found.
Unbounded per-day in-memory caches never evicted, and /admin/clear-cache ("All caches cleared") misses two of the four caches.
Horoscope.lucky_number is Integer while two writers store strings (works on SQLite affinity, latent failure on the production Postgres; the periodic table was already converted to String — this one was missed).
Prod logging defaults to DEBUG despite docs saying INFO; birth data (PII) lands in request/audit/SQL logs; error responses drop the X-Request-ID correlation header.




Top findings (severity-ordered)
P0 — will not run / core data is wrong

#0 App can't import. main.py and config.py both depend on a shared/ package that does not exist anywhere in the repo (from shared.llm_config import load_llm_config, from shared.db_migrations import ensure_horoscope_system_column). python -m main fails immediately with ModuleNotFoundError.
#1 Compatibility cache is broken for 32/78 pairs (41%). Two incompatible canonical orderings exist: seed_oneshot_content in main.py stores pairs in ZODIAC_SIGNS order (astrological), but the lookup in compatibility_service._canonical() uses alphabetical order. Reproduced live with TestClient: a seeded (Taurus, Sagittarius) row is invisible to a query for (Sagittarius, Taurus) → falls through to mock data. Also: the AI-batch score-lookup silently defaults to 70 when the LLM reorders sign1/sign2, and there's no UniqueConstraint on (sign1, sign2).
P1 — functional or astrological correctness

#2 Horoscope.lucky_number is an Integer column but every writer passes a string (ai_service normalises to str(...)). SQLite silently tolerates "7, 14" in an Integer column (confirmed). Postgres (production) will raise DataError, swallow the exception, and skip the DB persist — the cache never populates.
#3 Vimshottari antardasha starts from the wrong lord. vedic_service._current_dasha iterates DASHA_SEQUENCE from its first entry (Ketu) regardless of the active mahadasha. Reproduced with a Venus maha: it reports the first antardasha as Ketu instead of Venus.
#4 Ashta-Koota scoring is astrologically invalid. Yoni Koota uses abs(index1 - index2) on an arbitrary animal list (classical uses a 14×14 friend/neutral/enemy table; YONI_COMPAT is imported but never used). Gana Manushya-Rakshasa returns 3 instead of 1. Varna is gender-unaware (the API has no gender field). Manglik check includes house 2 (non-standard). vedic_service uses TRUE_NODE while birth_chart_service uses MEAN_NODE — same response ships two different ayanamsa pictures.
#5 Swiss Ephemeris global state race. swe.set_sid_mode(...) is mutated from multiple call sites during a request; under FastAPI's thread pool, concurrent tropical+sidereal requests race on ayanamsa state. calculate_current_transits also iterates all 10 tropical planets even for sidereal callers, and omits Rahu/Ketu.
#6 geocode_place hits public Nominatim on every chart request. No cache, no rate limit, 10-s synchronous call blocking a worker thread. Used 2× per request in Vedic summary flow and 2–4× in Kundli match. Violates Nominatim's terms of service for production.
#7 /stories/generate background task reuses a closed request-scoped db session, and deletes all existing stories before regeneration — data loss when Ollama is down.
#8 Missing UniqueConstraints on horoscopes, compatibility, fortune_pool, periodic_horoscopes. Retries & races silently insert duplicates.
#9 DB read failures return mock data and skip the LLM. A transient Postgres hiccup degrades the product to static templates even when the LLM is healthy.
#10 Unbounded in-memory caches (_horoscope_cache, _periodic_cache, _personalized_cache, _forecast_cache). _personalized_cache grows linearly with DAU forever.
P2 — hygiene, but serious

#11 get_compatibility logs "raising 503" but actually returns mock content with 200 — a log that will mislead every future on-call engineer.
#12 /admin/refresh-daily has a failed-insert-poisons-the-session pattern (no db.flush() in the try, commit outside the loop) — one bad row kills the whole batch.
#13 story_service._call_ollama ignores its own timeout arg and hard-codes 3600 s.
#14–20 Nakshatra pada boundary float issues, aspect-iteration order assumption, _hindu_month_name load-bearing init, static FESTIVAL_DATES runs out in March 2027 (then always shows "Holi 2027"), inconsistent Vedic sign naming (Mesha vs Aries in two different screens for the same planet).
#22–24 CORS_ORIGINS=["*"] with allow_credentials=True (Starlette silently ignores it, but intent is dangerous), SECRET_KEY default is a literal string, default LOG_LEVEL=DEBUG ships SQL statements with parameters (including password hashes once an auth route exists).
#25 Audit log is mirrored to stdout and rotated to disk — every request logged ~4-6× in docker logs.
#26–28 Input validation gaps (BirthDetails.birth_date has no pattern while BirthChartRequest.birth_date does; /fortune/generate never validates sign; personalised reading doesn't sanity-check that the supplied zodiac_sign matches the birth date).
#29 /stories/generate deletes before regenerating — data-loss antipattern.
#30 generate_content.py is a parallel re-implementation of services/ai_service.py that uses a different canonical ordering for compatibility, so the two seeding paths write incompatible rows.
#31 Grab-bag: data/mock/stories_data.py import cache vs runtime rewrite, missing engine.dispose() at shutdown, orphaned User model with no routes, dead imports.