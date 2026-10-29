# CosmicGuide — Deep Application, Backend & Database Audit

**Date:** 2026-10-07
**Scope:** Flutter client (`mobile-app/`), FastAPI backend (`backend/`), populator (`database/`), shared migrations (`shared/`), deployment (`Dockerfile`, `docker-compose*.yml`), CI.
**Method:** Full-codebase exploration followed by targeted verification of every claim against the actual source and git history. Findings that could not be reproduced from the code are marked as such or excluded.

> **Note on corrections.** Two commonly-assumed findings were investigated and **disproven**, and are deliberately *not* listed as issues:
> - *"Secrets are committed to git."* **False.** `git ls-files` and `git log --all --diff-filter=A` both return nothing for `.env`, `backend/secrets/`, `fcm.json`, `google-services*.json`, `GoogleService-Info*.plist`, `*.jks`, `key.properties`, or `firebase_options.dart`. Only `backend/.env.example` is tracked. No secret has ever been committed.
> - *"Settings / Help / Premium / Glossary screens are orphaned."* **False.** All four are reachable from [profile_screen.dart](mobile-app/lib/screens/profile_screen.dart#L546) (Premium), [#L766](mobile-app/lib/screens/profile_screen.dart#L766) (Glossary), [#L795](mobile-app/lib/screens/profile_screen.dart#L795) (Settings), [#L806](mobile-app/lib/screens/profile_screen.dart#L806) (Help).

---

# 0. Remediation status (updated 2026-10-07)

Every finding below carries a **Status** line. Summary:

| | Count | IDs |
|---|---|---|
| ✅ **Fixed** | 24 | P0-2, P0-3, P1-1, P1-2, P1-3, P1-4, P1-5, P1-6, P1-7, P1-12, P2-1, P2-3, P2-5, P2-6, P2-7, P2-8, P2-12, P2-13, P2-14, P3-2, P3-4, P3-6, P3-7, P3-10 |
| 🟡 **Partly fixed** | 7 | P0-1, P1-8, P1-9, P1-10, P2-2, P2-10, P2-11 |
| ⛔ **Needs you** | 3 | P1-11 (privacy policy / Data Safety / deletion URL), P3-1 (support mailbox), and the two build secrets inside P0-1 / P0-2 (TLS host, upload keystore) |
| ⬜ **Deferred** | 6 | P2-4, P2-9, P3-3, P3-5, P3-8, P3-9 |

Verification: all **22 backend test scripts** pass, **10 new Flutter tests** pass, `flutter analyze` is clean, and the running container was probed live for PII redaction, readiness, docs gating and the new auth boundaries.

**The two remaining release blockers are both secrets only you can produce:** a TLS hostname for `API_BASE_URL`, and an upload keystore + `android/key.properties`. Both now *fail loudly* instead of falling back silently.

---

# 1. Product & Architecture Understanding

## 1.1 What the product is

CosmicGuide is a **consumer astrology companion app**. It gives a user a daily horoscope that is genuinely computed from their birth chart, plus Vedic (Jyotish) readings, relationship compatibility, tarot, and short-form astrology articles.

The differentiator versus the large field of astrology apps is that the astronomy is **real**, not canned: [birth_chart_service.py](backend/services/birth_chart_service.py) drives Swiss Ephemeris (`pyswisseph`) for actual planetary longitudes, Placidus/whole-sign houses, nakshatras, and transit-to-natal aspects, and [vedic_service.py](backend/services/vedic_service.py) computes real sunrise/sunset, Panchang, Vimshottari Dasha and dosha detection.

## 1.2 Intended users

- **Western astrology readers** — want a Sun-sign daily reading, birth chart wheel, sign compatibility.
- **Vedic / Jyotish readers** — want Panchang, Kundli, Gun Milan matching, Dasha periods, remedies.
- Both are casual consumers, not practitioners. There is no professional/astrologer tier, no admin UI, and no B2B surface.

## 1.3 Account types

| Type | How identified | Capabilities |
|---|---|---|
| Anonymous | none | Can call every content endpoint directly (all public). Cannot use the app — login is gated. |
| Signed-in user | Firebase ID token → `require_user` | Own profile CRUD, device registration |
| Operator / admin | `X-Admin-Key` header → `require_admin` | `/admin/*`, notification broadcast, test push |

There is **no role column, no privilege hierarchy, and no admin UI** — `is_premium` exists on the `User` model but is never read anywhere.

## 1.4 Major features and their completeness

| Feature | Client | API | Service | DB | Verdict |
|---|---|---|---|---|---|
| Daily horoscope (generic) | ✅ | ✅ | ✅ | ✅ cached | **Complete** |
| Daily horoscope (personalised transit-to-natal) | ✅ | ✅ | ✅ | ⚠️ memory-only | **Complete** but uncacheable in DB |
| Weekly / monthly horoscope | ✅ | ✅ | ✅ | ✅ | **Complete** (text is sign-keyed only, no chart maths) |
| Energy forecast (30-day) | ✅ | ✅ | ✅ | ⚠️ memory-only | **Complete**, pure maths, no LLM |
| Birth chart (Western + Vedic) | ✅ | ✅ | ✅ | ❌ never persisted | **Complete**, recomputed every call |
| Vedic home (Panchang/Dasha/Dosha) | ✅ | ✅ | ✅ | ❌ | **Complete** |
| Compatibility (Western) | ✅ | ✅ | ✅ | ✅ | **Complete** |
| Kundli / Gun Milan | ✅ | ✅ | ✅ | ❌ `kundli_reports` table is dead | **Complete**, results discarded |
| Tarot (single + 3-card) | ✅ | ✅ | ✅ | ✅ | **Complete** |
| Fortune | ✅ | ✅ | ✅ | ✅ pool | **Complete** |
| Stories / Discover | ✅ | ✅ | batch-only | ✅ | **Complete** |
| Auth (email + Google) | ✅ | ✅ | Firebase | ✅ `users` | **Complete** |
| Profile sync | ✅ | ✅ | ✅ | ✅ | **Partial** — cannot clear a field |
| Reading history / streak | ✅ local-only | ❌ | ❌ | ❌ | **Device-local only** |
| Daily reminder | ✅ local | ✅ FCM | ✅ APScheduler | ✅ `device_tokens` | **Conflicting — two systems both fire** |
| Premium | ✅ "coming soon" | ❌ | ❌ | `is_premium` unused | **Not implemented (honest placeholder)** |

## 1.5 Data the application manages

Personal data collected: **name, email, exact birth date, exact birth time, birth place**, plus derived zodiac sign and tradition preference. Birth time + place is effectively a precise identity/location datum. Device push tokens are also stored, linked to `firebase_uid`.

## 1.6 System map

```
Flutter client (Firebase Auth)
   │  ID token on /users/* and /notifications/* only
   │  content routes sent ANONYMOUSLY, birth data in query string
   ▼
FastAPI  (single uvicorn worker — enforced by in-process APScheduler)
   ├── rate_limit middleware (in-memory fixed window, per IP)
   ├── log_requests middleware → audit.log + stdout (logs full query string)
   ├── api/*  (ALL handlers are sync `def` → run on the 40-slot anyio threadpool)
   ├── services/* → Swiss Ephemeris (CPU), Nominatim (network, 1 req/s GLOBAL lock)
   │                └→ LLM: Gemini → Ollama → iPhone LLM → static mock
   └── SQLAlchemy → PostgreSQL 16 (no FKs, no migration tool — hand-rolled ALTERs)

Out-of-band: database/populate_db.py (batch LLM pre-generation, run manually)
External: Firebase Auth + FCM, Google Gemini, OpenStreetMap Nominatim
```

## 1.7 Sync vs async

**Everything user-facing is synchronous.** The only asynchronous work is the APScheduler daily reminder job. There is no queue, no worker, no retry infrastructure. A personalised daily horoscope on a cold cache performs — inline, holding a threadpool slot — a geocode (up to 1s queue + 10s timeout), a full ephemeris chart, 30 days of transit maths, and an LLM call (up to 360s on local backends).

---

# 2. Findings

## P0 — Release Blockers

### [P0-1] Release builds point at a domain that does not exist

**Category:** Bug / Operational · **Severity:** P0 · **Confidence:** Confirmed
**Location:** [api_service.dart#L17-19](mobile-app/lib/services/api_service.dart#L17-L19), [#L33-35](mobile-app/lib/services/api_service.dart#L33-L35)

**Evidence:**
```dart
/// Edit this once the backend has a real hostname, or keep passing
/// --dart-define=API_BASE_URL at build time.
static const String _fallbackProdBaseUrl = 'https://api.cosmicguide.app/api/v1';
...
if (kReleaseMode) { return _fallbackProdBaseUrl; }
```

**Problem:** Any `flutter build apk|appbundle` issued without `--dart-define=API_BASE_URL=...` compiles a binary hardcoded to a placeholder hostname. There is no deployed backend at that address, and no compile-time or runtime guard that detects it.

**Scenario:** Release build is produced from a normal command line → uploaded to Play → every user sees "Unable to load your reading" on every screen forever. Because all client errors are swallowed (see [P1-6]), there is no diagnostic.

**Impact:** 100% of functionality dead for 100% of users. The app still *launches* (Firebase Auth is a separate SDK and works), so sign-up succeeds and the failure looks like a backend outage rather than a misbuild.

**Expected:** A release build must either resolve a real host or fail to compile.

**Recommendation:** Deploy the backend behind TLS, replace the constant with the real hostname, and add a `assert(!kReleaseMode || _apiBaseUrlOverride.isNotEmpty)` or a CI check that greps the built artifact. Add a visible "cannot reach server" banner (see [P1-6]).

**Status: 🟡 PARTLY FIXED — the silent fallback is gone; the hostname is still yours to supply.**
- `ApiService.isUsingPlaceholderHost` + `assertReleaseConfig()` (called first thing in `main()`) now trip an assertion in debug/profile builds.
- A new `release-config` CI job warns when `_fallbackProdBaseUrl` is still the placeholder.
- Failures are no longer invisible: [P1-6] is fixed, so a dead host surfaces as "Can't reach CosmicGuide. Check your connection."
- **Needs you:** deploy the backend behind TLS, then either edit `_fallbackProdBaseUrl` or build with `--dart-define=API_BASE_URL=https://<host>/api/v1`.

---

### [P0-2] Release APK/AAB is signed with the Android debug key

**Category:** Operational · **Severity:** P0 · **Confidence:** Confirmed
**Location:** `mobile-app/android/key.properties` (absent), [android/app/build.gradle.kts](mobile-app/android/app/build.gradle.kts)

**Evidence:** `ls mobile-app/android/key.properties` → absent. The `signingConfigs` block falls back to the debug keystore when the properties file is missing, silently. Prior verification recorded `Signer #1 certificate DN: C=US, O=Android, CN=Android Debug`.

**Problem:** A debug-signed artifact is produced with no error, only a fallback.

**Scenario:** `flutter build appbundle` → upload to Play Console → **rejected**. Worse, if a debug-signed APK is sideloaded for a beta, its SHA-1 differs from the release SHA-1, so Google Sign-In silently breaks for those testers.

**Impact:** Cannot publish. Also a key-management trap: once a release *is* signed with a real upload key, the new SHA-1 must be registered in Firebase or Google Sign-In breaks in production while working in debug.

**Expected:** Missing release signing config should fail the release build.

**Recommendation:** Generate the upload keystore, create `android/key.properties` (gitignored), register **both** the upload SHA-1 and the Play App Signing SHA-1 in Firebase, re-download `google-services.json`, and make the Gradle fallback `throw GradleException` for `release` rather than silently using debug keys.

**Status: ✅ FIXED (the silent fallback) — ⛔ the keystore itself is yours to generate.**
- `android/app/build.gradle.kts` now throws `GradleException` when `key.properties` is absent instead of quietly selecting the debug keystore. `-PALLOW_DEBUG_SIGNED_RELEASE=true` opts into an explicitly-unpublishable local test build (and logs a warning).
- The `release-config` CI job flags the missing file.
- **Needs you:** generate the upload keystore, write `android/key.properties`, and register the upload **and** Play App Signing SHA-1s in Firebase before re-downloading `google-services.json`.

---

### [P0-3] Two independent daily-reminder systems both fire

**Category:** Bug / UX · **Severity:** P0 · **Confidence:** Confirmed
**Location:** [notification_service.dart#L105-124](mobile-app/lib/services/notification_service.dart#L105-L124), [scheduler.py#L48-60](backend/services/scheduler.py#L48-L60), [config.py#L88-91](backend/config.py#L88-L91)

**Evidence:** `NotificationService.setEnabled(enabled: true)` does **both**:
```dart
await LocalNotificationService.scheduleDaily(hour: ..., minute: ...);   // device-local time
unawaited(_syncFcm(enabled: true, ...));                                 // registers for server push
```
and `_syncFcm` calls `ApiService.registerDeviceToken(...)` which writes `device_tokens.daily_horoscope_enabled = true`. Independently, the backend scheduler runs:
```python
scheduler.add_job(_run_daily_reminders, trigger="cron",
                  hour=settings.DAILY_REMINDER_HOUR, minute=0, ...)
```
with `DAILY_REMINDER_HOUR` defaulting to 8 **in the container's timezone** (UTC in Docker — the docstring says so explicitly). The Firebase service account is present at `backend/secrets/fcm.json`, so sends are live, not no-ops.

**Problem:** A user who enables the reminder gets a local notification at their chosen local time *and* a server push at 08:00 UTC. For a user in IST that is 08:00 local + 13:30 local. For US Eastern it is 08:00 local + 04:00 local — **a push in the middle of the night**.

**Impact:** Duplicate and badly-timed notifications are among the fastest routes to uninstalls and 1-star reviews. The 04:00 push is actively harmful.

**Expected:** One reminder, at the user's chosen local time.

**Recommendation:** The product already chose on-device local notifications. Either (a) set `ENABLE_SCHEDULER=false` in production and stop calling `_syncFcm` on enable, or (b) delete the local path and store per-user IANA timezone + reminder minute on `device_tokens`, then have the job run hourly and select only devices whose local time matches. Option (a) is one config change and should ship for v1.

**Status: ✅ FIXED — option (a), belt and braces.**
- `config.ENABLE_SCHEDULER` now defaults to **false**, so the server job does not run unless an operator deliberately turns it on. Verified live: `/ready` reports `"scheduler":"disabled"`.
- `NotificationService.setEnabled()` no longer touches the server's reminder flag at all — `_syncFcm` was deleted.
- `_registerCurrent()` now always registers with `dailyHoroscopeEnabled: false`, so even if an operator enables the scheduler later, a device that schedules its own reminder is never also pushed to.

---

## P1 — High Priority

### [P1-1] Birth date, time and place are logged to disk and stdout on every request

**Category:** Security / Privacy · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [main.py#L109](backend/main.py#L109), [#L140-152](backend/main.py#L140-L152), [audit.py#L123-142](backend/audit.py#L123-L142)

**Evidence:** `/horoscope/today`, `/horoscope/forecast` and `/vedic/home-summary` take `birthDate`, `birthTime`, `birthPlace` as **GET query parameters** ([horoscope.py#L23-33](backend/api/horoscope.py#L23-L33)). The logging middleware captures the raw query string and emits it twice:
```python
logger.info("→ %s %s%s", method, path, f"?{query}" if query else "")
...
audit_inbound(..., query=query, client_ip=client_ip, user_agent=user_agent, ...)
```
`audit.py` writes `"query": query` verbatim into `logs/audit.log` **and** mirrors to stdout (`AUDIT_LOG_STDOUT` defaults to `"true"`). Header redaction exists (`_SENSITIVE_HEADERS`) but there is **no query-parameter redaction**.

**Problem:** Exact birth date + exact birth time + birth city, correlated with client IP and User-Agent, is written in plaintext to a rotating file (10 MB × 5) and to the container log stream, which in any managed host is shipped to a third-party log aggregator and retained.

**Scenario:** Any log export, any support engineer with container access, any log-retention vendor, or any backup of `backend/logs/` now holds a precise identity dataset for every user. Under GDPR this is personal data processed without a stated basis; the app has no privacy policy (see [P1-11]).

**Impact:** Privacy breach, regulatory exposure, and a Play Data Safety declaration that would be inaccurate.

**Expected:** PII never reaches logs; sensitive parameters are redacted or the payload moves out of the URL.

**Recommendation:** (1) Add a `_SENSITIVE_QUERY_PARAMS = {"birthDate","birthTime","birthPlace"}` redactor in `audit.py` and apply it in `main.py` before logging. (2) Longer term, move personalised reads to `POST` with a JSON body so the data is never in a URL (URLs also leak into proxy logs, browser history and `Referer`). (3) Document log retention.

**Status: ✅ FIXED.**
- `audit.py` gained `_SENSITIVE_QUERY_PARAMS` (birth date/time/place in both casings, plus `email` and `token`) and an idempotent `redact_query()`.
- `main.py`'s logging middleware redacts **once, up front**, so the human-readable line and the audit record both get the masked string; `audit_inbound()` also re-applies it so no future caller can leak by passing the raw query.
- `docker-compose.prod.yml` now defaults `AUDIT_LOG_STDOUT=false`, keeping the trail in the rotated file instead of shipping it to whatever aggregates container logs.
- Verified live: `"query": "zodiac_sign=Leo&birthDate=***REDACTED***&birthTime=***REDACTED***&birthPlace=***REDACTED***"` in both `logs/audit.log` and stdout.
- Not done: moving personalised reads to POST, and a written retention policy.

---

### [P1-2] `client_ip` is taken from unvalidated `X-Forwarded-For`

**Category:** Security · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [main.py#L99-105](backend/main.py#L99-L105) vs [rate_limit.py#L88-98](backend/rate_limit.py#L88-L98)

**Evidence:** The rate limiter correctly gates the header:
```python
if settings.TRUST_PROXY_HEADERS:
    forwarded = request.headers.get("x-forwarded-for")
```
The audit middleware does **not**:
```python
forwarded_for = request.headers.get("x-forwarded-for")
client_ip = forwarded_for.split(",")[0].strip() if forwarded_for else ...
```

**Problem:** Two components disagree about whether the header is trustworthy. Any caller can set `X-Forwarded-For: 8.8.8.8` and every audit record attributes their traffic to that address.

**Impact:** The audit trail — the one artifact you would use to investigate abuse or a cost spike — is attacker-controlled. Abuse becomes unattributable and incident forensics are unreliable.

**Recommendation:** Reuse `rate_limit.client_identity(request)` in the logging middleware so both honour `TRUST_PROXY_HEADERS`. Optionally log both `peer_ip` and `forwarded_for` as separate fields.

**Status: ✅ FIXED.** `main.py` now calls `client_identity(request)`, the same helper the limiter uses, so a forged `X-Forwarded-For` can no longer rewrite the audit attribution unless `TRUST_PROXY_HEADERS` is deliberately on.

---

### [P1-3] Sign-out leaves the previous user's daily notification scheduled and their device registered

**Category:** Bug / Privacy · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [profile_screen.dart#L591-603](mobile-app/lib/screens/profile_screen.dart#L591-L603), [main.dart#L136-140](mobile-app/lib/main.dart#L136-L140)

**Evidence:** Sign-out is:
```dart
await AuthService.signOut();
// AppEntry's auth listener clears local data and returns to sign-in.
```
and the listener does only:
```dart
Future<void> _clearLocalProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  ApiService.clearCache();
}
```
There is **no** `LocalNotificationService.cancelDaily()` and **no** `unregisterDeviceToken()`. By contrast, Settings' "Delete all app data" *does* call `cancelDaily()` ([settings_screen.dart#L115](mobile-app/lib/screens/settings_screen.dart#L115)) — so the correct behaviour exists, just not on this path.

**Problem:** The OS-level scheduled notification survives `prefs.clear()` because it lives in the Android AlarmManager / iOS UNUserNotificationCenter, not in SharedPreferences. Its body is baked in at schedule time: `'$sign, the stars have something to say today…'` ([local_notification_service.dart#L153-156](mobile-app/lib/services/local_notification_service.dart#L153-L156)). The `device_tokens` row also keeps `firebase_uid` and `zodiac_sign` of the departed user.

**Scenario:** Alice signs out on a shared device. Bob signs in. Every morning Bob's phone displays *"Scorpio, the stars have something to say today"* — Alice's sign — and the backend keeps pushing to that token under Alice's uid. Worse, `prefs.clear()` removed `notifications_enabled`, so the Notifications screen shows the reminder as **off** while it is demonstrably firing. There is no way to turn it off short of toggling on then off, or reinstalling.

**Impact:** Leaks one user's astrological identity to the next, and presents an un-cancellable notification — a top-tier app-store complaint and a plausible privacy report.

**Recommendation:** In `_clearLocalProfile()`, `await LocalNotificationService.cancelDaily()` and `await ApiService.unregisterDeviceToken(token)` **before** `prefs.clear()` (the token is needed from prefs). Add a test asserting no scheduled notification remains after sign-out.

**Status: ✅ FIXED.** `main.dart::_clearLocalProfile()` now cancels the OS-scheduled reminder and unregisters the device token (read from prefs while it is still there) *before* `prefs.clear()`. `/notifications/unregister` is deliberately still callable without a session, because sign-out can happen after the session is already gone.

---

### [P1-4] `/notifications/unregister` and `/notifications/preferences` are unauthenticated

**Category:** Security (Broken Access Control / IDOR) · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [notifications.py#L70-95](backend/api/notifications.py#L70-L95)

**Evidence:**
```python
@router.post("/unregister")
def unregister_device(payload: TokenRef, db: Session = Depends(get_db)):
    deleted = db.query(DeviceToken).filter(DeviceToken.token == payload.token).delete(...)

@router.put("/preferences")
def update_preferences(payload: NotificationPreferences, db: Session = Depends(get_db)):
    device = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
```
Neither has `Depends(require_user)`. `/register` *does* ([#L24-29](backend/api/notifications.py#L24-L29)), and `/test` and `/run-daily` are admin-gated — so the inconsistency is within a single file.

**Problem:** Authorisation is "knowledge of the device token", and the handler never checks that the token belongs to the caller. There is no ownership check against `caller.uid`, which is already stored on the row.

**Scenario:** An attacker holding a token (e.g. harvested from a shared device, a logged token, or an intercepted request on cleartext dev builds) can permanently disable another user's push, or silently flip `daily_horoscope_enabled = false`. `/unregister` additionally returns `{"deleted": 0|1}`, which is a **token-existence oracle** usable for enumeration confirmation.

**Impact:** Targeted denial of notifications; information disclosure. Mitigated in practice because FCM tokens are long opaque strings and not guessable — this is why it is P1 rather than P0.

**Expected:** Mutating another device's state requires proof of ownership.

**Recommendation:** Add `caller: AuthedUser = Depends(require_user)` to `/preferences` and filter `DeviceToken.firebase_uid == caller.uid`. For `/unregister`, keep it open only if sign-out-after-revocation genuinely needs it; if so, make it return a constant `{"status":"ok"}` with no `deleted` count to close the oracle. Better: call unregister *before* `signOut()` while the token is still valid, and then require auth.

**Status: ✅ FIXED, exactly as recommended.**
- `/preferences` takes `Depends(require_user)` and filters on `DeviceToken.firebase_uid == caller.uid`; a token belonging to someone else returns the same `not_found` as an unknown one.
- `/unregister` stays open but now returns a constant `{"status": "ok"}` — the count is logged server-side only. The client also calls it *before* signing out (see [P1-3]), while the token is still valid.
- Covered by `test_admin_auth.py::test_preferences_requires_sign_in` and `::test_unregister_is_not_a_token_oracle`.

---

### [P1-5] A signed-in user can never clear a profile field

**Category:** Bug / Data Integrity / Privacy · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [users.py#L66](backend/api/users.py#L66)

**Evidence:**
```python
changes = payload.model_dump(exclude_unset=True, exclude_none=True)
```

**Problem:** `exclude_none=True` drops every explicitly-null field. `exclude_unset` alone correctly implements PATCH semantics; adding `exclude_none` makes `null` indistinguishable from "omitted".

**Scenario:** A user who entered an incorrect birth time, or who decides they no longer want their birth place stored, sends `{"birthTime": null}`. The server returns **200 with the old value still set**. On the next device sync, `_hydrateFromServer` writes the stale value back into local prefs, so the client-side change is also reverted. The user sees their edit silently undone.

**Impact:** Users cannot correct or minimise their most sensitive stored data. This is both a functional defect and a data-subject-rights problem (right to rectification/erasure of a specific field). It also produces a confusing "my edit didn't save" bug report.

**Expected:** `null` means "clear this field".

**Recommendation:** Drop `exclude_none=True`. Keep `exclude_unset=True`. Add a test that `PUT {"birthTime": null}` results in `birth_time IS NULL`.

**Status: ✅ FIXED.** `exclude_none=True` is gone, so an explicit `null` clears the column while an omitted key is still left alone. The Flutter `updateProfile()` was the other half of the problem — it dropped empty strings from the payload entirely — and now maps `''` to `null`. Test: `test_user_auth.py::test_null_clears_a_field`.

---

### [P1-6] The client has no HTTP error handling at all — every failure becomes `null`

**Category:** Bug / UX · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [api_service.dart](mobile-app/lib/services/api_service.dart) — every public method

**Evidence:** Each method follows the shape `try { if (res.statusCode == 200) {...} } catch (_) {}` → `return null` (or `false`, or `[]`). There is no inspection of `statusCode` for 401, 403, 429 or 5xx anywhere in the file, and no retry.

**Problem:** Seven materially different conditions collapse into one indistinguishable value:
| Real cause | What the client knows |
|---|---|
| No network | `null` |
| Wrong base URL ([P0-1]) | `null` |
| 401 — token expired/revoked | `null` |
| 429 — rate limited | `null` |
| 500 — backend bug | `null` |
| 503 — Firebase creds missing | `null` |
| Genuinely empty result | `null` / `[]` |

**Scenario A (token revocation):** A user changes their password on another device, or an admin disables the account. Firebase revokes the session. `AuthService.idToken()` catches the failure and returns `null` ([auth_service.dart#L60-67](mobile-app/lib/services/auth_service.dart#L60-L67)), so `_authHeaders()` simply omits the `Authorization` header and the server replies 401. The client shows "Unable to load" and **leaves the user apparently signed in forever**. There is no forced sign-out, no re-auth prompt.

**Scenario B (rate limit):** The limiter returns 429 with a `Retry-After` header ([rate_limit.py#L112-118](backend/rate_limit.py#L112-L118)). The client ignores both, shows a generic failure, and the user taps retry — immediately re-triggering the limit.

**Impact:** Unrecoverable sessions, misleading error copy, support load that cannot be diagnosed, and `Retry-After` guidance thrown away.

**Expected:** Distinguish auth failure (sign out + prompt), throttling (back off, show the wait), and server/network failure (retryable, show a retry affordance).

**Recommendation:** Introduce an `ApiResult<T>` (or a typed `ApiException` with a `kind` enum) returned by a single `_request()` helper. On 401 → `AuthService.signOut()`. On 429 → surface `Retry-After`. Everywhere else → distinguish network vs server. This is a contained refactor of one file plus the call sites' error branches.

**Status: ✅ FIXED.**
- New `ApiErrorKind { network, timeout, unauthorized, rateLimited, server, unavailable, badResponse }` and `ApiException` (with `statusCode`, `retryAfter`, user-facing `message`, `isRetryable`).
- Every method now goes through one `_send()` helper that attaches credentials, applies the timeout and classifies the status code. The raw `http.get/post` calls and their `catch (_) {}` blocks are gone.
- **401/403 → `ApiService.onUnauthorized`**, wired in `main()` to `AuthService.signOut()`. Scenario A (stuck in a dead session forever) no longer happens.
- **429 → `Retry-After` is parsed** and surfaced in the message ("Try again in 37s").
- `ApiService.lastError` is a `ValueNotifier<ApiException?>`, cleared on any success; the Home daily card now shows that message instead of a fixed "Unable to load your reading".
- `ApiService.client` is injectable, and `test/api_service_test.dart` asserts all six classifications (7 tests).

---

### [P1-7] Signing in while the server is unreachable silently restarts onboarding and can overwrite the saved profile

**Category:** Data Integrity · **Severity:** P1 · **Confidence:** High
**Location:** [main.dart#L83-96](mobile-app/lib/main.dart#L83-L96), [#L100-134](mobile-app/lib/main.dart#L100-L134)

**Evidence:**
```dart
Future<void> _hydrateFromServer(User user) async {
  final profile = await ApiService.fetchProfile();
  ...
  if (profile == null) return;          // ← silent
  ...
  if (sign.isNotEmpty && birthDate.isNotEmpty) {
    await prefs.setBool('onboarded', true);
  }
}
```
combined with the fact that sign-out already ran `prefs.clear()`.

**Problem:** Local prefs are the only record that onboarding was completed, and they were wiped at sign-out. If `fetchProfile()` returns `null` for *any* reason — offline, 401, 503 from missing Firebase creds, or the dead base URL of [P0-1] — the `onboarded` flag is never restored and `AppEntry` routes the user to `OnboardingScreen` as if they were brand new. No error is shown.

**Scenario:** A returning user on a train with flaky signal signs in. They are asked to re-enter name, birth date, birth time, birth place and tradition. On completion the client fires `unawaited(ApiService.updateProfile(...))`. Two bad outcomes:
1. Connectivity is still down → the write is also lost (fire-and-forget, result discarded), so local and server now disagree and nothing warns anyone.
2. Connectivity returns mid-flow → a hastily re-entered (possibly less accurate, e.g. "I don't remember the exact time") profile **overwrites the carefully-entered original**, with no undo and no history.

**Impact:** Silent corruption of the single most important record in the product. Every reading is derived from birth data, so a degraded profile degrades every feature, permanently and invisibly.

**Expected:** A hydration failure must be distinguished from "new user".

**Recommendation:** Make `_hydrateFromServer` return a tri-state (`loaded` / `newUser` / `failed`). On `failed`, show a retry screen rather than onboarding. Never write `onboarded=false` into a flow that can overwrite server state. Additionally, `await` the onboarding `updateProfile` and block completion on its success, or queue it for retry.

**Status: ✅ FIXED (the dangerous part).**
- `ApiService.fetchProfile()` now *throws* `ApiException` instead of returning `null`, so "this account has no profile" and "we could not reach the server" are different outcomes.
- `_hydrateFromServer()` returns the failure; `AppEntry` stores it and renders a new `_HydrationFailedScreen` (Try again / Sign out) instead of routing a returning user into onboarding. The profile-overwriting path is closed.
- Still `unawaited()`: the onboarding/profile-save write. It can no longer clobber a good server profile (you cannot reach onboarding on a failed hydration), but a dropped write is still silent. A retry queue remains future work.

---

### [P1-8] Unauthenticated, uncapped LLM and geocode cost amplification

**Category:** Security / Operational · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [horoscope.py#L15-53](backend/api/horoscope.py#L15-L53), [rate_limit.py#L36-42](backend/rate_limit.py#L36-L42), [horoscope_service.py](backend/services/horoscope_service.py)

**Evidence:** Every content route is public. `GET /api/v1/horoscope/today?zodiac_sign=Leo&birthDate=…&birthTime=…&birthPlace=…` takes the personalised path, whose cache key is `(sign, system, date, sha256(birth)[:12])`. **A unique birth triple is a guaranteed cache miss**, and each miss costs one geocode plus one LLM generation. The only control is the limiter: `RATE_LIMIT_LLM = 20` requests/minute **per IP**.

**Problem:** The cost per request is attacker-chosen and the identity is attacker-rotatable.
- 20/min × 60 × 24 = **28,800 paid LLM generations per day from a single IP**.
- The limiter state is in-process (`dict` in `FixedWindowLimiter`), so it resets on every deploy/restart.
- With `TRUST_PROXY_HEADERS=true` (required if you deploy behind any load balancer, which you must for TLS), a forged `X-Forwarded-For` mints a **new bucket per request** — the code comment says so explicitly — making the limit zero.

**Scenario:** A trivial script iterating `birthPlace` values drains the Gemini quota/billing overnight, and simultaneously poisons `_personalized_cache` (capped at 4096 entries, LRU) so real users are evicted and pay the cold-start penalty on every request.

**Impact:** Direct financial loss, plus degraded service for legitimate users.

**Expected:** Expensive operations are not available to anonymous callers.

**Recommendation:** The app already requires login. Put `Depends(require_user)` on the *personalised* paths (`birthDate` present), `/forecast`, `/chart/*`, `/kundli/match` and `/vedic/home-summary`, and key the limiter on `uid` for authenticated routes. Keep generic sign-only reads public and cheap. Add a hard daily LLM-call budget with a circuit breaker to static content.

**Status: 🟡 PARTLY FIXED — anonymous access is closed; the limiter is still keyed on IP.**
- New `security.optional_user` (absent header → anonymous; *present but invalid* → still 401). `/horoscope/today` returns **401** when `birthDate` is supplied without a session, so the expensive per-birth-triple path is no longer anonymous.
- `Depends(require_user)` added to `/horoscope/forecast`, `/chart/birth`, `/chart/vedic`, the whole `/kundli` router and the whole `/vedic` router. `/chart/transits` stays public (same sky for everyone, no geocode).
- Generic sign-only reads, tarot, fortune, compatibility and stories stay public and cheap. Verified live: `401` for anonymous personalised and vedic calls, `200` for the generic one.
- **Not done — deliberately:** keying the limiter on `uid`. The limiter runs in middleware, before dependency resolution, so it would have to key on an *unverified* bearer token — which an attacker can rotate freely, making it a bypass rather than a fix. Doing it properly means verifying the token in middleware (or moving to Redis with a post-auth counter).
- **Not done:** a hard daily LLM budget with a circuit breaker.

---

### [P1-9] Global 1 req/s geocode lock on synchronous handlers is a trivial DoS

**Category:** Performance / Operational · **Severity:** P1 · **Confidence:** High
**Location:** [birth_chart_service.py](backend/services/birth_chart_service.py) `geocode_place` / `_get_geocode_fn`, all handlers in `backend/api/`

**Evidence:** `geocode_place` wraps Nominatim in `RateLimiter(..., min_delay_seconds=1.0)` — a **process-global serialising throttle** — and every API handler is a sync `def`, so FastAPI dispatches them onto the anyio threadpool (default **40** workers).

**Problem:** A cache-missing geocode blocks its thread for ≥1s of queue plus up to the 10s Nominatim timeout. These are additive across concurrent requests because the rate limiter is global.

**Scenario:** 40 concurrent requests with distinct, uncached `birthPlace` values occupy all 40 threadpool slots. The 40th waits ~40 s behind the geocode lock. While they are held, **every other endpoint in the application — including `/tarot/draw` and `/stories` — cannot be served**, because they are sync too. The health check is exempt from rate limiting and doesn't touch the DB, so the orchestrator still reports the container healthy while it serves nothing.

**Impact:** Full API stall from ~40 cheap requests, well inside the 20/min/IP budget if spread over 2–3 IPs. No autoscaling can help: the scheduler pins you to one worker.

**Expected:** A slow external dependency degrades one feature, not the whole API.

**Recommendation:** (1) Convert geocoding to `async def` + `run_in_threadpool` with a bounded semaphore so it cannot consume all slots, or move it behind a small async client. (2) Pre-seed a local city→lat/lon table for common cities and treat Nominatim as a fallback — the autocomplete field already implies a city list. (3) Make `/health` check the DB so a stalled container is actually detected. (4) Shorten the Nominatim timeout to ~3 s.

**Status: 🟡 PARTLY FIXED — the API can no longer be stalled by geocoding.**
- `geocode_place()` now acquires a `BoundedSemaphore(_GEOCODE_MAX_INFLIGHT = 8)` with a 2 s wait. At most 8 of the ~40 threadpool slots can ever sit behind the ToS lock; overflow returns `None`, which the chart code already handles as "place not resolved".
- Nominatim timeout cut from **10 s → 3 s**.
- Readiness now checks the database (see [P2-14]) and the container `HEALTHCHECK` points at `/ready`, so a stalled or DB-less instance is actually detected.
- Combined with [P1-8] these routes are no longer anonymous, so the attack needs real accounts.
- **Not done:** a pre-seeded city→coordinates table, and converting the handlers to `async def`.

---

### [P1-10] Startup performs schema work at import time — DB outage becomes a crash loop

**Category:** Operational · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [main.py#L40-53](backend/main.py#L40-L53)

**Evidence:** Seven schema operations run at **module import**, not inside a startup event:
```python
ensure_users_firebase_shape(engine, logger)
Base.metadata.create_all(bind=engine)
ensure_horoscope_system_column(engine, logger)
... 4 more ...
```

**Problem:** If PostgreSQL is unavailable or slow when the container starts, the import raises, uvicorn exits, the orchestrator restarts it, and it fails again — a crash loop that takes the API down for a transient DB blip rather than starting degraded. It also means `import main` in any test or tool connects to a live database (already a known constraint on the test suite).

**Secondary problem:** This is a hand-rolled migration system. `create_all()` plus seven bespoke idempotent `ALTER` helpers has no version table, no ordering guarantee beyond call order, no down-migration, and no way to tell which migrations a given database has seen. Every future schema change adds another permanent `ensure_*` function that runs on every boot forever.

**Impact:** Fragile startup; unmaintainable schema evolution; untestable without a database.

**Recommendation:** Move all of it into an explicit startup path with retry/backoff, and adopt **Alembic** before the next schema change. Convert the existing `ensure_*` helpers into a baseline revision.

**Status: 🟡 PARTLY FIXED — the crash loop is gone; Alembic is not adopted.**
- All schema work moved out of module scope into `main.prepare_schema()`, called from a FastAPI `lifespan` (which also replaces the deprecated `@app.on_event` handlers — see [P3-2]).
- `_prepare_schema_with_retry()` retries 5 times with exponential backoff (1→16 s) and, if it still fails, logs an error and **starts degraded** rather than exiting. `/ready` then reports `"schema": "not_ready"` and answers 503, so the orchestrator keeps traffic away without killing the process.
- `import main` no longer touches a database. The TestClient-based tests call `main.prepare_schema()` explicitly.
- **Not done:** Alembic. The hand-rolled `ensure_*` helpers (now nine) still run on every boot with no version table.

---

### [P1-11] No privacy policy, no data export, no documented retention

**Category:** Missing Feature / Compliance · **Severity:** P1 · **Confidence:** Confirmed
**Location:** product-wide; [help_screen.dart](mobile-app/lib/screens/help_screen.dart) has a privacy FAQ entry but no policy URL

**Evidence:** The app collects name, email, exact birth date, exact birth time and birth place. There is no privacy policy URL anywhere in the repo, no in-app policy screen, no data-export function, and `kSupportEmail = 'support@cosmicguide.app'` is a documented placeholder.

**Problem:** Google Play **requires** a privacy policy URL and an accurate Data Safety declaration for any app collecting personal data, and requires a web-accessible account-deletion route now that accounts exist. None of these exist.

**Impact:** Play listing will be rejected. Independently, GDPR/DPDP obligations (lawful basis, retention, access, portability, erasure) are unmet while PII sits in logs ([P1-1]).

**Recommendation:** Before submission: publish a privacy policy covering birth data specifically; add a web deletion page; complete the Data Safety form honestly (it must say you collect DOB and approximate location); register a real support mailbox; define and implement log retention.

**Status: ⛔ NOT FIXED — this one is entirely yours.** None of it can be produced from the codebase: it needs a published URL, a real mailbox and a submitted Play form. The one engineering prerequisite is now done — birth data no longer sits in plaintext logs ([P1-1]) — so the Data Safety declaration you file can at least be accurate.

---

### [P1-12] Deleting an account can destroy server data while leaving the account live

**Category:** Data Integrity · **Severity:** P1 · **Confidence:** Confirmed
**Location:** [profile_screen.dart#L636-653](mobile-app/lib/screens/profile_screen.dart#L636-L653), [users.py#L82-112](backend/api/users.py#L82-L112)

**Evidence:**
```dart
final serverDeleted = await ApiService.deleteProfile();
if (!serverDeleted) { ...return; }
final result = await AuthService.deleteAccount();
if (!result.ok && result.error != null) {
  messenger.showSnackBar(SnackBar(content: Text(result.error!)));
  return;                                    // ← server row already gone
}
```
The ordering was deliberately chosen (and documented) to avoid stranding data, but the failure branch is unhandled. Server-side, `delete_me` commits the row deletion and only then attempts `fb_auth.delete_user`, returning **HTTP 200** with `credentialRemoved: false` if that fails — a value the client never reads ([api_service.dart](mobile-app/lib/services/api_service.dart) `deleteProfile` only checks `statusCode == 200`).

**Problem:** Two steps, no transaction, no compensation, no idempotent retry.

**Scenario:** Network drops between the server delete and the Firebase delete. The user's profile, birth details and device tokens are gone. Their login still works. Next launch, `_get_or_create` silently creates a **fresh empty row**, and they are routed through onboarding. They believe their account was deleted; it was not. If they were relying on deletion for a privacy request, the request was not honoured.

**Impact:** Irreversible data loss combined with a false deletion confirmation — the worst combination for a user-rights operation.

**Expected:** Deletion is atomic or safely resumable, and the user is told the true outcome.

**Recommendation:** Make deletion server-driven and idempotent: mark the row `pending_deletion`, delete the Firebase credential, then hard-delete; a background sweep finishes any row left pending. Have the client read `credentialRemoved` and show an accurate message. At minimum, retry the credential delete and never report success unless both steps completed.

**Status: ✅ FIXED — server-driven, atomic in the common case, and honest.**
- `DELETE /users/me` now deletes the profile row and the device tokens inside an **uncommitted** transaction (`flush()`), removes the Firebase credential, and only then commits. If the credential delete fails it rolls back and returns **502** — nothing was removed and the call can simply be retried. No schema change or sweeper needed.
- `_remove_firebase_credential()` treats `UserNotFoundError` as success, so a retried deletion can finish instead of failing forever.
- The client no longer runs a second, uncompensated step: `AuthService.deleteAccount()` was deleted, and `ApiService.deleteProfile()` returns the server's real `credentialRemoved` flag. The snackbar now says *"Nothing was removed — please try again"* instead of implying partial success.
- The route also uses `require_fresh_user` (see [P2-8]), so a revoked session cannot delete an account.
- Tests: `test_user_auth.py::test_delete_removes_the_profile_row` and `::test_delete_keeps_everything_when_the_credential_cannot_be_removed`.

---

## P2 — Medium Priority

### [P2-1] Mock fallbacks return HTTP 200 with fabricated content

**Category:** Architecture / UX · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [horoscope_service.py](backend/services/horoscope_service.py) `_mock_horoscope`, [compatibility_service.py](backend/services/compatibility_service.py), [fortune_service.py#L96-99](backend/services/fortune_service.py#L96-L99), [vedic_home_screen.dart#L55](mobile-app/lib/screens/vedic_home_screen.dart#L55)

**Evidence:** When the LLM and DB both fail, the service returns static per-sign text with a fixed score and a 200 status. The client mirrors this: `_summary = summary ?? vedicHomeMockData`.

**Problem:** An outage is indistinguishable from normal operation — to the user *and* to monitoring. The response schema carries no `source` field, so nothing downstream can tell real content from canned content.

**Impact:** Silent quality collapse. Users receive identical "readings" day after day and conclude the product is fake. Operators see 200s and no alerts. For an astrology product, serving fabricated content under the guise of a computed reading is also a trust and arguably a consumer-protection issue.

**Recommendation:** Add `source: "chart" | "ai" | "cache" | "fallback"` to the response schema, emit a metric/alert when `fallback` is served, and have the client show an honest "showing a general reading — personalised reading unavailable right now" note. Note the deterministic chart score/band already survives LLM failure, which is good — surface that distinction.

**Status: ✅ FIXED (schema + client); alerting still needs an observability stack.**
- `HoroscopeResponse` and `CompatibilityResponse` gained `source: chart | ai | cache | fallback`, set at every return site in `horoscope_service` (daily, personalised, weekly/monthly) and `compatibility_service`.
- `HoroscopeData.source` / `.isFallback` on the client, and the Home daily card now renders *"Showing a general reading — today's personalised text isn't available right now."* instead of passing filler off as today's reading.
- A `fallback` in the logs is now machine-detectable; wiring it to an alert depends on [P2-9].

---

### [P2-2] No foreign keys anywhere; two dead tables holding third-party PII

**Category:** Data Integrity · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [db/models.py](backend/db/models.py)

**Evidence:** Not one `ForeignKey` in the file. `FortuneHistory.user_id` and `KundliReport.user_id` are bare `Integer`; `DeviceToken.firebase_uid` is a bare `String(128)`. A repo-wide grep for `FortuneHistory|KundliReport` returns **only the model definitions** — nothing reads or writes them.

**Problem:**
- No referential integrity, no `ON DELETE` behaviour. `delete_me` cleans `users` and `device_tokens` by hand; anything added later will be forgotten.
- `kundli_reports` is designed to store **both partners'** full name, birth date, birth time and birth place — PII for a second person who never consented and has no account. It is created by `create_all()` on every boot. It is currently empty only because nothing writes to it.
- Timestamp columns are inconsistent: `Story.published_at` has no `onupdate`; `Horoscope`/`Compatibility` have no `updated_at` at all.
- `Story` has no unique constraint on `title` or `(title, category)`, so the populator can create visible duplicates.

**Impact:** Guaranteed orphans as the schema grows; a dormant PII liability; duplicate stories in the feed.

**Recommendation:** Drop `fortune_history` and `kundli_reports` (nothing depends on them) — or, if Kundli history is a real roadmap item, redesign it to store only derived scores, never the partner's raw birth data. Add real `ForeignKey(..., ondelete="CASCADE")` to `device_tokens.firebase_uid`. Add a unique constraint to `stories`.

**Status: 🟡 PARTLY FIXED — the PII liability and the duplicate risk are gone; foreign keys are not.**
- Both dead models deleted from `backend/db/models.py` **and** `database/models.py`, along with the never-called `save_fortune_history`/`get_fortune_history` helpers in `database/db_service.py`.
- New `shared/db_migrations.py::drop_unused_tables()` drops them from existing databases, but **only while they are empty** — a populated table is left alone and logged, so an operator who started using one does not silently lose data. Verified live: `kundli_reports` and `fortune_history` are gone from the running Postgres.
- `Story` gained `UniqueConstraint("title", "category")` plus `ensure_story_title_unique()` (dedupes then creates the index). Verified live.
- **Not done:** real `ForeignKey(... ondelete="CASCADE")` on `device_tokens.firebase_uid`. Adding one to a live table would fail on any legacy row with a NULL/stale owner, so it needs a data-cleanup migration first.

---

### [P2-3] Rate limiter fails open under the exact conditions it exists for

**Category:** Security · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [rate_limit.py#L68-82](backend/rate_limit.py#L68-L82)

**Evidence:**
```python
if not stale:
    self._hits.clear()
    logger.warning("Rate limiter tracking table exceeded %d live keys — cleared.", ...)
```

**Problem:** When more than 20,000 distinct clients are active inside one 60-second window, the limiter **discards every counter**, resetting all attackers to zero. The comment frames this as bounding memory, but the behaviour is fail-open precisely during a distributed flood.

**Impact:** The limiter stops limiting at the moment it matters. Combined with [P1-8], a modest botnet (or any `X-Forwarded-For` rotation when `TRUST_PROXY_HEADERS=true`) walks straight past it.

**Recommendation:** Evict LRU rather than clearing, and when the table is saturated apply a conservative global cap instead of allowing everything. Move to Redis before scaling beyond one process — the current design cannot survive a second instance.

**Status: ✅ FIXED (single-process); Redis is still needed to scale out.**
- `_hits` is now an `OrderedDict` with `move_to_end` on every hit, so eviction is true LRU.
- Saturation evicts least-recently-seen keys down to the cap and sets `_saturated_until`, which clamps **every** client to `_SATURATION_LIMIT = 10/min` for the remainder of the window. The table no longer resets attackers to zero.
- Test: `test_rate_limit.py::test_saturation_tightens_instead_of_failing_open` floods 20,500 distinct clients and asserts a client at its budget stays blocked.

---

### [P2-4] Single worker is architecturally mandated — no horizontal scale, no HA

**Category:** Architecture / Operational · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [Dockerfile](Dockerfile) `UVICORN_WORKERS` default 1, [scheduler.py](backend/services/scheduler.py), [rate_limit.py#L6-10](backend/rate_limit.py#L6-L10)

**Evidence:** Three separate pieces of in-process state force one worker: the APScheduler job (fires N times with N workers), the rate-limiter dict, and the four `_BoundedCache` instances in `horoscope_service`.

**Problem:** Capacity is capped at one Python process (≈40 concurrent sync requests, see [P1-9]), and there is no redundancy — a restart is a full outage.

**Impact:** The app cannot scale past a few hundred concurrent users, and every deploy is downtime.

**Recommendation:** Extract the scheduler into a separate one-replica service or an external cron hitting `/notifications/run-daily`; move the limiter and caches to Redis. Then `UVICORN_WORKERS` becomes a dial and the API can run ≥2 replicas behind the proxy.

**Status: ⬜ DEFERRED — architectural, and not a launch blocker.** One of the three pins is now loose: the scheduler is off by default ([P0-3]), so an operator who moves the limiter and caches to Redis can raise `UVICORN_WORKERS`. Doing that properly is a Redis dependency plus an external cron, which is Phase 4 work rather than something to change before a first release.

---

### [P2-5] Client response cache is unbounded and never expires entries

**Category:** Performance · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [api_service.dart#L76-105](mobile-app/lib/services/api_service.dart#L76-L105)

**Evidence:** `_responseCache` is a plain `Map` keyed by full URL. The 2-minute TTL is only consulted on *read*; stale entries are never evicted, and nothing caps the map. `clearCache()` is the only removal path.

**Problem:** Keys accumulate for the lifetime of the process — every date navigated in the horoscope screen, every forecast window, every story query. Each value holds a parsed model object.

**Impact:** Monotonic memory growth in a long-lived session; on low-end Android this contributes to background eviction. Modest in practice, but unbounded by construction.

**Recommendation:** Prune expired entries on write and cap the map (LRU, ~100 entries) — mirroring `_BoundedCache` on the backend.

**Status: ✅ FIXED.** `_storeInCache()` re-inserts the key (so iteration order tracks recency), drops anything older than 10 minutes, and evicts the oldest entries beyond `_responseCacheMax = 100`.

---

### [P2-6] Rapid-tap double submission on several network actions

**Category:** Bug / UX · **Severity:** P2 · **Confidence:** High
**Location:** [tarot_screen.dart#L133](mobile-app/lib/screens/tarot_screen.dart#L133), [profile_screen.dart#L605-653](mobile-app/lib/screens/profile_screen.dart#L605-L653)

**Evidence:** Compatibility, fortune, auth and profile-save all correctly gate on a busy flag (`onPressed: !_isChecking ? _check : null`). **Tarot draw does not** — `onPressed: _drawCard` with no guard — and tarot is deliberately excluded from `_dedup`. The delete-account confirm dialog likewise has no in-flight guard.

**Problem:** Each tap issues an independent request and an independent `HistoryService.record()`.

**Impact:** Duplicate history entries inflating the streak/reading stats shown on Profile; multiple concurrent draws racing to set `_drawnCard`. For delete-account, a double tap can issue two delete sequences, the second of which fails confusingly after the first succeeded.

**Recommendation:** Add `_isDrawing` / `_isDeleting` flags and disable the control while in flight — matching the pattern already used correctly elsewhere.

**Status: ✅ FIXED.** `tarot_screen.dart` gained `_isDrawing` (button disabled, spinner shown, guard at the top of `_drawCard`), and `profile_screen.dart` gained `_deleting` around the account-deletion sequence.

---

### [P2-7] `/docs`, `/redoc` and `/openapi.json` are publicly exposed and rate-limit-exempt

**Category:** Security · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [main.py#L55-60](backend/main.py#L55-L60), [rate_limit.py#L31-33](backend/rate_limit.py#L31-L33)

**Evidence:** `docs_url="/docs", redoc_url="/redoc"` unconditionally, and `_EXEMPT_PATHS` includes all three.

**Problem:** The complete API surface — every path, parameter name, validation rule and response shape — is published to anonymous callers, including the `/admin/*` routes. It is also the ideal reconnaissance target and is explicitly exempt from throttling.

**Impact:** Hands an attacker the map (notably: that birth parameters are accepted on GET, and that admin routes sit outside `/api/v1`). Low direct harm, meaningful uplift to everything else.

**Recommendation:** `docs_url=None` unless an `ENABLE_DOCS` env var is set, or gate them behind `require_admin`. Remove them from the exemption list.

**Status: ✅ FIXED.** New `settings.ENABLE_DOCS` (default **false**) gates `docs_url`, `redoc_url` *and* `openapi_url`; `/docs`, `/redoc` and `/openapi.json` were removed from `_EXEMPT_PATHS` so they are throttled like anything else. The dev compose sets `ENABLE_DOCS=true`; production leaves it off.

---

### [P2-8] Firebase token revocation is never checked

**Category:** Security · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [security.py](backend/security.py) `require_user`

**Evidence:** `fb_auth.verify_id_token(token, app=app)` is called without `check_revoked=True`.

**Problem:** A revoked session (password change, admin disable, explicit revocation) continues to be accepted until the ID token's natural ~1-hour expiry.

**Scenario:** A user signs out a stolen device, or changes their password after a compromise. The attacker's existing token keeps working for up to an hour against `/users/me` — including `DELETE /users/me`.

**Impact:** Up to a one-hour window in which account deletion and profile modification are available to a session the user believes they killed.

**Recommendation:** Pass `check_revoked=True` for the mutating routes (`PUT`/`DELETE /users/me`, `/notifications/register`) at minimum. It costs a Firebase round trip, so keep reads on the cheap path if latency matters.

**Status: ✅ FIXED, exactly as scoped.** `security.py` was refactored into `_verify_bearer(..., check_revoked)` with three entry points: `require_user` (signature only), `require_fresh_user` (`check_revoked=True`) and `optional_user`. `PUT /users/me` and `DELETE /users/me` — the routes that modify or destroy an account — use `require_fresh_user`; reads stay on the cheap path.

---

### [P2-9] No crash reporting, metrics, or alerting

**Category:** Operational · **Severity:** P2 · **Confidence:** Confirmed
**Location:** product-wide

**Evidence:** `firebase_core` is present but Crashlytics is not in `pubspec.yaml`. No Sentry, no analytics, no Prometheus/OpenTelemetry, no `/metrics`. Observability consists of `logs/audit.log` plus stdout.

**Problem:** There is no way to learn that something is broken. Client crashes are invisible. Backend failure rates, LLM fallback rates, latency percentiles and cost per day are all unmeasured.

**Impact:** You will find out about [P0-1] and [P0-3] from app-store reviews.

**Recommendation:** Add `firebase_crashlytics` (zero extra vendor, Firebase is already there) and a minimal server-side error reporter. Emit counters for: LLM calls, fallback-served responses, geocode calls, 429s, 5xxs.

**Status: ⬜ DEFERRED — needs a new dependency plus iOS/Android platform config, which is not safe to add blind.** Adding `firebase_crashlytics` means a Gradle plugin, a `pod install`, and a dSYM upload step; it should be done and then verified on a real device. Two prerequisites are now in place: the client has a typed error channel (`ApiService.lastError`, [P1-6]) and the server labels degraded responses (`source`, [P2-1]), so both are ready to be reported once a sink exists.

---

### [P2-10] Essentially no automated testing of the client, and backend tests need a live database

**Category:** Testing · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [mobile-app/test/widget_test.dart](mobile-app/test/widget_test.dart), `backend/tests/` (22 files), [backend/requirements.txt](backend/requirements.txt)

**Evidence:** The entire Flutter test suite is:
```dart
testWidgets('App launches', (WidgetTester tester) async {
  await tester.pumpWidget(const CosmicGuideApp());
  await tester.pumpAndSettle();
  expect(find.text('CosmicGuide'), findsOneWidget);
});
```
This pumps the real app (Firebase, splash animation) and is likely failing or flaky. On the backend, 22 standalone scripts exist and are genuinely good — but `pytest` is **not a dependency**, so they are run by a `for` loop in [.github/workflows/ci.yml](.github/workflows/ci.yml), with no fixtures, parametrisation, isolation or coverage. And `import main` executes `create_all()` against a real engine ([P1-10]), so API-level tests must pre-set `DATABASE_URL` to a throwaway SQLite file.

**Highest-risk untested areas** (ranked by consequence × likelihood):
1. **Auth lifecycle end-to-end** — token expiry mid-session, revocation, offline sign-in ([P1-6], [P1-7]). Zero coverage. This is where the two worst data-integrity bugs live.
2. **Sign-out / account-deletion cleanup** — [P1-3] and [P1-12] would both have been caught by one test each.
3. **Client API error paths** — no test asserts behaviour on 401/429/500/timeout.
4. **Notification scheduling** — the duplicate-reminder bug [P0-3] is a pure integration gap between two subsystems neither of which is tested together.
5. **Concurrency** — no test exercises simultaneous `_get_or_create` for the same uid, duplicate POSTs, or the threadpool-exhaustion path.
6. **Rate limiter under saturation** — `test_rate_limit.py` exists but the fail-open clear path ([P2-3]) is untested.

**Recommendation:** Add `pytest` and convert the scripts (they are already well-factored, this is mostly mechanical). Add client unit tests for `ApiService` against a mocked `http.Client`, and widget tests for the auth gate's three states. Delete or fix the template smoke test.

**Status: 🟡 PARTLY FIXED — the client is no longer untested; the pytest migration is not done.**
- The failing template `widget_test.dart` was **deleted**.
- New `test/api_service_test.dart` (7 tests) drives `ApiService` against a `MockClient` via the new injectable `ApiService.client`, asserting the 401-signs-out, 429-keeps-`Retry-After`, 503-is-not-an-auth-problem, 500-vs-empty, transport-failure and `source: fallback` behaviours — untested areas #3 and part of #1.
- New `test/accessibility_test.dart` (3 tests) asserts the semantic labels from [P2-11].
- CI now runs `flutter test` and has a new `release-config` job for untested area #6.
- Backend coverage grew with the fixes: `test_user_auth.py` gained null-clears-a-field, both deletion outcomes and the personalised-route auth gate; `test_admin_auth.py` gained the preferences gate and the unregister oracle; `test_rate_limit.py` gained the saturation case (untested area #5, partly).
- **Not done:** adding `pytest` and converting the 22 standalone scripts; widget tests for the auth gate's three states (they need Firebase stubbing).

---

### [P2-11] Accessibility is effectively absent

**Category:** Accessibility · **Severity:** P2 · **Confidence:** High
**Location:** client-wide; [chart_screen.dart](mobile-app/lib/screens/chart_screen.dart), [energy_forecast_chart.dart](mobile-app/lib/widgets/energy_forecast_chart.dart), [score_ring.dart](mobile-app/lib/widgets/score_ring.dart)

**Evidence:** No `Semantics`, `MergeSemantics`, `ExcludeSemantics` or `semanticLabel` usage anywhere in `lib/`. The three data visualisations are `CustomPaint` with no textual equivalent.

**Problem:** A screen-reader user gets nothing from the birth chart wheel, the energy forecast, or the compatibility score ring — these are the product's signature outputs. Decorative icons are unlabelled, so TalkBack/VoiceOver announces them as unnamed buttons.

**Impact:** The app is unusable for blind and low-vision users. Depending on jurisdiction and distribution this may also be a legal exposure.

**Recommendation:** Wrap each `CustomPaint` in `Semantics(label: ...)` with a generated summary ("Energy forecast: today 54, mixed; best day 14 October at 81"). Label every bare `IconButton`. Audit touch targets to 48×48 dp. This is a few hours of work and disproportionately improves the product.

**Status: 🟡 PARTLY FIXED — the signature outputs now speak; touch targets were not audited.**
- `ScoreRing` wraps its painter in `Semantics(label: "<caption>: <label>")` + `ExcludeSemantics` (so the inner text is not announced twice).
- `EnergyForecastChart` generates *"Energy forecast over 30 days. Today 54, mixed. Best day 14/10 at 81."*
- The birth-chart wheel in `chart_screen.dart` announces the first five placements and the total count.
- Tooltips added to the six unlabelled `IconButton`s (Discover back, horoscope prev/next day, story-detail back, password visibility, city-field clear).
- Covered by `test/accessibility_test.dart`.
- **Not done:** the 48×48 dp touch-target audit, and semantics for the Kundli chart painters.

---

### [P2-12] Dev compose publishes PostgreSQL and Adminer with static credentials

**Category:** Security · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [docker-compose.yml#L5-9](docker-compose.yml#L5-L9), [#L29-36](docker-compose.yml#L29-L36), [#L78-81](docker-compose.yml#L78-L81)

**Evidence:** `POSTGRES_PASSWORD: cosmicguide`, `SECRET_KEY=local-dev-secret-key`, published `ports:` on the database, plus an `adminer:latest` web console on 8080.

**Problem:** This is correctly a *dev* file — [docker-compose.prod.yml](docker-compose.prod.yml) properly binds to `127.0.0.1:${API_PORT:-8000}`, ships no Adminer, and uses `${VAR:?}` required-variable syntax so it refuses to start without real secrets. **That part is well done.** The risk is purely that the dev file is one `docker compose up` away from being used on a host with a public interface.

**Impact:** If ever run on an internet-reachable machine: unauthenticated database admin console and a Postgres with a guessable password.

**Recommendation:** Bind the dev ports to `127.0.0.1:` explicitly, and add a one-line README warning. No change needed to the prod file.

**Status: ✅ FIXED.** All three published ports in `docker-compose.yml` are now bound to `127.0.0.1` (`5432`, `8000`, `8080`), and the file opens with a header stating it is local-development-only and must never run on an internet-reachable host. The dead `SECRET_KEY=local-dev-secret-key` was removed with [P3-4].

---

### [P2-13] API naming and pagination are inconsistent; client ignores pagination entirely

**Category:** Architecture · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [stories.py](backend/api/stories.py), [api_service.dart](mobile-app/lib/services/api_service.dart) `getStories`

**Evidence:** `/stories` accepts `per_page` (snake_case) while every other parameter and the whole response layer is camelCase (`birthDate`, `moodSummary`, `bestDay`). `getStories` sends no pagination parameters at all and `DiscoverScreen` renders whatever the default page returns.

**Problem:** `/stories` is the only paginated endpoint and its pagination is unused; the casing break will bite the next client author.

**Impact:** Low today (the story set is ~6 rows). Becomes a correctness issue the moment the catalogue exceeds one page — users will silently never see older stories.

**Recommendation:** Alias `per_page` → `perPage`, and either wire up infinite scroll in Discover or remove the pagination parameters until needed.

**Status: ✅ FIXED (the naming).** `/stories` now takes `perPage`, matching every other query parameter and the camelCase response layer. Safe to change outright because no client sends pagination today. Infinite scroll in Discover is still unimplemented, which is fine while the catalogue is ~6 rows.

---

### [P2-14] `/health` is not a health check

**Category:** Operational · **Severity:** P2 · **Confidence:** Confirmed
**Location:** [main.py#L170-181](backend/main.py#L170-L181)

**Evidence:** Returns `{"status": "healthy", ...}` plus a memoised AI probe. It never touches the database.

**Problem:** The Docker `HEALTHCHECK` and any load balancer will report healthy while the DB is unreachable, the threadpool is exhausted ([P1-9]), or the scheduler has died.

**Impact:** Broken instances stay in rotation; real outages are not detected.

**Recommendation:** Execute `SELECT 1` with a short timeout, report scheduler liveness, and distinguish `/health` (liveness, always cheap) from `/ready` (readiness, checks dependencies).

**Status: ✅ FIXED.** `/health` stays cheap liveness. New **`GET /ready`** runs `SELECT 1`, reports schema readiness (see [P1-10]) and scheduler state, and answers **503** when any of them is wrong. The Docker `HEALTHCHECK` now targets `/ready`, so a container with an unreachable database is actually taken out of rotation. `/ready` is exempt from rate limiting. Verified live: `{"status":"ready","database":"ok","schema":"ready","scheduler":"disabled"}`.

---

## P3 — Low Priority

| ID | Finding | Location | Status |
|---|---|---|---|
| P3-1 | Support email is a placeholder (`support@cosmicguide.app`) with no mailbox | [help_screen.dart](mobile-app/lib/screens/help_screen.dart) | ⛔ **Needs you** — register a real mailbox, then update `kSupportEmail` |
| P3-2 | `@app.on_event("startup"/"shutdown")` is deprecated in modern FastAPI | [main.py](backend/main.py) | ✅ **Fixed** — replaced by an `asynccontextmanager` `lifespan` that also owns schema prep, scheduler start/stop and `engine.dispose()` |
| P3-3 | `ShimmerLoading` widget is fully implemented but never used | [shimmer_loading.dart](mobile-app/lib/widgets/shimmer_loading.dart) | ⬜ **Deferred** — purely cosmetic, and wiring it needs visual verification on each loading surface |
| P3-4 | `SECRET_KEY` is defined but never consumed | [config.py](backend/config.py) | ✅ **Fixed** — removed from `config.py`, both compose files and `.env.example`; `docker-compose.prod.yml` no longer demands it |
| P3-5 | `User.is_premium` column is never read | [db/models.py](backend/db/models.py) | ⬜ **Deferred** — kept on purpose; Premium is a declared roadmap item, unlike the two tables dropped in [P2-2] |
| P3-6 | `ACCESS_TOKEN_EXPIRE_MINUTES` is dead config | [config.py](backend/config.py) | ✅ **Fixed** — removed |
| P3-7 | No security headers (HSTS, `X-Content-Type-Options`, `X-Frame-Options`) | [main.py](backend/main.py) | ✅ **Fixed** — outermost middleware sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Cross-Origin-Opener-Policy`, plus HSTS when the request arrived over TLS. Verified live |
| P3-8 | Unbounded text fields on LLM-generated response models | [schemas.py](backend/schemas.py) | ⬜ **Deferred** — no practical injection path was found; a response-size cap remains cheap insurance |
| P3-9 | Dependencies pinned loosely (`google-genai>=1.0,<2`), no lock file | [requirements.txt](backend/requirements.txt) | ⬜ **Deferred** — adding `pip-compile`/`uv lock` changes the build pipeline and should be done deliberately |
| P3-10 | Repository memory file is corrupted (duplicated from line 472) | `/memories/repo/astro-scope.md` | ✅ **Fixed** — duplicate half removed |

---

# 3. Failure-Mode Analysis

## 3.1 "Client thinks it succeeded, backend didn't"

| Operation | Current behaviour | Risk |
|---|---|---|
| Onboarding completion | `unawaited(ApiService.updateProfile(...))` — result discarded | **Profile silently never reaches the server.** Combined with [P1-7], the next device sees nothing. |
| Profile edit save | Same fire-and-forget pattern | Local and server diverge with no reconciliation or conflict detection |
| Clearing a field | Returns 200, field unchanged ([P1-5]) | User's edit is reverted on next sync |
| Account deletion | Returns 200 even when `credentialRemoved: false` ([P1-12]) | False confirmation of an irreversible user-rights action |
| Notification enable | `unawaited(_syncFcm(...))` | Device registration silently fails; user is unaware |

**Root cause:** `unawaited(...)` is used as the standard pattern for writes. There is no outbox, no retry queue, and no "unsaved changes" indicator.

## 3.2 "Backend succeeded, client never got the response"

- All GETs are idempotent → safe.
- `PUT /users/me` is idempotent (last-write-wins, no version/ETag) → safe but **lost-update prone**: two devices editing concurrently silently overwrite each other with no detection.
- `DELETE /users/me` is **not** safely repeatable — the second call recreates an empty row via `_get_or_create` before deleting it, returning `rows=0`.
- `POST /notifications/register` is an upsert keyed on token → safe.
- `POST /compatibility/check`, `/kundli/match`, `/fortune/generate`, `/tarot/draw` create no durable state → safe to repeat, but each repeat may cost an LLM call.

**Assessment:** Idempotency is adequate because the API is overwhelmingly read-only. The gap is concentrated in the profile/account lifecycle.

## 3.3 Concurrency

- `_get_or_create` handles the duplicate-insert race correctly (rollback + re-query) — **good**, and the `users.firebase_uid` unique index backs it.
- Content caches rely on read-before-write plus unique constraints (`uq_horoscope_day`, `uq_periodic_horoscope`, `uq_fortune_pool`, `uq_compatibility_pair`) with `IntegrityError` absorbed — **good**.
- No row-level locking anywhere, but no operation requires it (no counters, no balances, no state machines).
- The `_BoundedCache` instances are plain `OrderedDict` mutated without a lock from multiple threadpool threads. CPython's GIL makes individual operations atomic enough in practice; the read-modify-write in `__setitem__`'s eviction loop is theoretically racy but can at worst evict an extra entry. **Not worth fixing.**

---

# 4. Summary Sections

## A. Executive Summary

**Score at the time of the audit: 61 / 100. After the remediation pass below: ~82 / 100** — held short of the 90s only by the two build secrets, the compliance paperwork and the absence of observability.

CosmicGuide is a **substantially more serious piece of engineering than its category average**, undermined by a thin but critical layer of release and lifecycle defects.

**What is genuinely strong:**
- The astrology engine is real. Swiss Ephemeris, correct Lahiri sidereal handling, whole-sign vs Placidus houses, Vimshottari Dasha, and a corrected 36-point Ashta Koota implementation. The deterministic transit-to-natal day score is computed from actual aspect geometry, not invented by an LLM — a meaningfully honest design choice that most competitors do not make.
- Backend defect hygiene is excellent. Roughly 40 previously-identified defects have been reproduced, fixed and regression-tested, with 22 test files covering migrations, caching, fallbacks and auth boundaries. The LLM fallback chain degrades in the right order, the chart-derived score survives an LLM outage, and generate-then-delete ordering is applied consistently to every batch path.
- Security fundamentals are mostly right where they were addressed: admin auth fails closed, `require_user` fails closed, `secrets.compare_digest` is used, no secrets have ever been committed, the production compose file refuses to start without real secrets, and the container runs non-root from a compiler-free multi-stage image.

**What blocks release:**
- A release build **cannot work**: it is debug-signed (Play will reject it) and points at a hostname that does not exist.
- Two independent notification systems both fire, one of them at 04:00 for US users.
- There is no privacy policy, no Data Safety declaration and no web deletion route — all mandatory for an app collecting exact birth date, time and place.
- That same PII is written in plaintext to disk and stdout on every single request.

> **After remediation:** the notification duplicate and the PII logging are **fixed**. The two build problems no longer fail silently — a release build without `key.properties` now *fails*, and a placeholder host trips an assertion and a CI warning — but they still need a TLS hostname and an upload keystore from you. The compliance surface is untouched and remains the single largest blocker.

**Biggest technical weaknesses:** uniform error swallowing in the client (one `catch (_)` idiom defeats all error handling), fire-and-forget writes with no retry, a hand-rolled migration system that runs at import time, and an architecture pinned to a single process by three separate pieces of in-process state.

> **After remediation:** the error swallowing is **fixed** (typed `ApiException`, 401 signs out, 429 honours `Retry-After`); schema work moved into a retrying `lifespan` so a DB blip no longer crash-loops the container. Still open: Alembic, the `unawaited()` write pattern, and the single-process pins.

**Biggest missing functionality:** server-side reading history (sign-out destroys it permanently), any form of observability, and the legal/compliance surface.

**Why 61 and not higher:** the astrology core, backend correctness and test discipline would support a score in the high 70s. It is pulled down by the three P0s — each of which independently prevents shipping — plus the absence of compliance artifacts and client-side error handling.

**Why 61 and not lower:** nothing here is architecturally unsalvageable. There is no SQL injection, no IDOR on user data, no broken crypto, no credential leak, and no evidence of fake functionality. Most findings are a few hours of work each.

## B. Critical Issues (P0)

1. **[P0-1]** Release builds point at the nonexistent placeholder `https://api.cosmicguide.app/api/v1`. — 🟡 *silent fallback removed (assert + CI guard); still needs a real host*
2. **[P0-2]** Release APK/AAB is debug-signed because `key.properties` is absent and the Gradle fallback is silent. — ✅ *the build now fails instead; still needs the upload keystore*
3. **[P0-3]** Local reminders and server FCM pushes both fire — duplicate notifications, one at 08:00 UTC regardless of user timezone. — ✅ *fixed*

## C. High Priority (P1)

4. **[P1-1]** Birth date/time/place logged to `audit.log` and stdout on every request. — ✅ *fixed*
5. **[P1-2]** `client_ip` derived from unvalidated `X-Forwarded-For`, contradicting the rate limiter. — ✅ *fixed*
6. **[P1-3]** Sign-out leaves the previous user's notification scheduled and device registered. — ✅ *fixed*
7. **[P1-4]** `/notifications/unregister` and `/preferences` unauthenticated (IDOR + token oracle). — ✅ *fixed*
8. **[P1-5]** `exclude_none=True` makes profile fields impossible to clear. — ✅ *fixed*
9. **[P1-6]** No HTTP status handling in the client; 401/429/500 are indistinguishable from empty. — ✅ *fixed*
10. **[P1-7]** Offline sign-in restarts onboarding and can overwrite the saved profile. — ✅ *fixed*
11. **[P1-8]** Unauthenticated LLM/geocode cost amplification (28,800 generations/day/IP). — 🟡 *expensive routes now require sign-in; limiter still keyed on IP*
12. **[P1-9]** Global 1 req/s geocode lock on sync handlers stalls the entire API from ~40 requests. — 🟡 *concurrency bounded to 8 slots, timeout 10s→3s; handlers still sync*
13. **[P1-10]** Schema work at import time turns a DB blip into a crash loop; no migration tool. — 🟡 *moved into a retrying lifespan; Alembic still not adopted*
14. **[P1-11]** No privacy policy, Data Safety declaration, data export, or web deletion route. — ⛔ *needs you*
15. **[P1-12]** Account deletion can destroy server data while leaving the login alive. — ✅ *fixed*

## D. Medium Priority (P2)

16–29: see [P2-1] … [P2-14]. **Fixed:** mock fallbacks now carry a `source` and the client labels them; the rate limiter no longer fails open; the client cache is bounded; rapid-tap double submission guarded; OpenAPI docs gated and throttled; token revocation checked on mutating routes; dev compose bound to loopback; pagination renamed to `perPage`; `/health` split from a real `/ready`. **Partly fixed:** dead PII tables dropped and a `stories` unique constraint added (foreign keys still missing); client and accessibility tests added (pytest migration and the touch-target audit still pending). **Deferred:** the single-worker architecture and crash reporting/metrics.

## E. Low Priority (P3)

30–39: see the P3 table — placeholder support email, deprecated `on_event`, unused shimmer widget, three dead config values, missing security headers, unbounded response strings, no dependency lock file, corrupted memory file.

## F. Security Findings

| # | Finding | Classification |
|---|---|---|
| S1 | PII (birth date/time/place) in URLs → logs → stdout → log aggregator | **Confirmed** |
| S2 | `X-Forwarded-For` trusted for audit attribution | **Confirmed** |
| S3 | Unauthenticated mutation of another device's notification state | **Confirmed** |
| S4 | Unauthenticated expensive LLM/geocode operations | **Confirmed** |
| S5 | Rate limiter fails open above 20k live keys; bypassable via XFF when proxy headers are trusted | **Confirmed** |
| S6 | Token revocation not checked — up to 1 h of validity after sign-out/password change | **Confirmed** |
| S7 | OpenAPI schema public and exempt from rate limiting | **Confirmed** |
| S8 | Threadpool exhaustion via geocode lock (availability) | **High confidence** |
| S9 | Dev compose exposes Postgres + Adminer with static credentials | **Confirmed** (dev file only) |
| S10 | No security headers | **Confirmed**, low impact for a mobile-only API |

**Explicitly checked and NOT found:** SQL injection (SQLAlchemy ORM throughout, no raw string interpolation into queries); command injection; path traversal; SSRF (no user-controlled URLs); XSS (no web surface); credentials in source control (verified against full git history); IDOR on user profile data (`/users/me` is correctly keyed on `caller.uid` with no client-supplied identifier); privilege escalation (no role model to escalate within); insecure deserialization.

**Positive security controls observed:** admin and user auth both fail closed; `secrets.compare_digest` for the admin key; header redaction in the audit log; SQL parameter logging deliberately removed; `allow_credentials=False` with wildcard CORS (the valid combination); production compose requires every secret; non-root container from a compiler-free image; cleartext traffic permitted only in the debug Android manifest.

## G. Data Integrity Risks

| Risk | Mechanism | Severity |
|---|---|---|
| **Profile silently overwritten** | Offline sign-in → prefs empty → re-onboarding → fire-and-forget write ([P1-7]) | **Highest** — corrupts the input to every feature |
| **Reading history permanently destroyed** | `prefs.clear()` on sign-out; history exists only on-device, never on the server | **High** — no backup, no warning beyond one dialog line |
| **Account deleted server-side but still live** | Two-step delete with no compensation ([P1-12]) | **High** |
| **Fields impossible to clear** | `exclude_none=True` ([P1-5]) | **High** |
| **Lost updates between devices** | `PUT /users/me` is last-write-wins with no version/ETag | Medium |
| **Orphaned rows** | No foreign keys; cleanup is hand-written per table ([P2-2]) | Medium |
| **Duplicate history entries** | Unguarded tarot draw ([P2-6]) inflates streak/stats | Low |
| **Duplicate stories** | No unique constraint on `stories` | Low |
| **Third-party PII table** | `kundli_reports` stores a partner's full birth data; dormant but created every boot | Medium (latent) |

**Well-handled already:** every content cache table has a unique constraint with `IntegrityError` absorbed; batch jobs generate-then-delete so an LLM outage never empties a table; per-row `SAVEPOINT` isolation in the admin seeders; the first-request user-creation race is handled correctly.

## H. Missing Features

| Feature | Why it matters | What happens today | Priority | Complexity |
|---|---|---|---|---|
| **Privacy policy + Data Safety + web deletion URL** | Mandatory for Play with accounts + personal data | Listing is rejected | **P0 (for launch)** | Small |
| **Server-side reading history** | The app sells a "streak"; sign-out or device loss erases it with no recovery. Users on a new phone lose everything. | Local-only, destroyed on sign-out | **P1** | Medium |
| **Error/offline UX with retry** | Every failure currently reads "Unable to load" with no cause and no retry affordance | Dead ends ([P1-6]) | **P1** | Medium |
| **Crash reporting** | No way to learn about client failures | Discovered via store reviews | **P1** | Small |
| **Per-user timezone for reminders** | Server push fires at 08:00 UTC for everyone ([P0-3]) | 04:00 notifications in the US | **P1** | Small (or delete the server path) |
| **Last-reading offline cache** | Users open the app on the subway; today's reading is already fetched and discarded | Blank card | **P2** | Small |
| **Email verification enforcement** | Account recovery and abuse prevention both depend on a real address | `email_verified` is parsed into `AuthedUser` but never enforced | **P2** | Small |
| **Data export** | GDPR portability; also a trust signal for birth data | None | **P2** | Small |
| **Search / filter in Discover** | Only category chips; a growing catalogue becomes unbrowsable | Flat grid | **P3** | Small |
| **Saved compatibility / Kundli results** | Users re-enter a partner's full birth details every time; `kundli_reports` was clearly designed for this | Discarded | **P3** | Medium |

**Deliberately NOT recommended:** in-app purchases (Premium is an honest "coming soon"; monetisation is a business decision, not a gap); social feed/UGC (would add moderation obligations with no product rationale); multi-language (no evidence of a non-English audience); dark/light theming (the dark cosmic theme is the brand).

## I. Incomplete Implementations

1. **Premium** — [premium_screen.dart](mobile-app/lib/screens/premium_screen.dart) lists five perks, has an opt-in switch persisted to `premium_notify_optin`, and no prices or purchase path. `User.is_premium` exists and is never read. *This is honest and correctly scoped — not a defect.*
2. **FCM server push** — fully built end-to-end (model, endpoints, scheduler, service account, client registration) but functionally superseded by local notifications. Currently causes [P0-3] rather than adding value.
3. **`fortune_history` and `kundli_reports` tables** — complete schemas, zero code paths. Created on every boot.
4. **Weekly/monthly horoscopes** — work, but are keyed only on the sign name with no chart maths, unlike the daily reading. A user with full birth details gets a genuinely personal daily reading and a generic weekly one, with no indication of the difference.
5. **`ShimmerLoading`** — a complete skeleton-loader widget set, never used, while several screens show blank space during load.
6. **Vedic periodic readings** — the populator cannot pre-generate them (no rashi map), so weekly/monthly Vedic is live-LLM-only and first-request-slow.
7. **`syncRegistration`** — documented as dead in the service's own comments.

## J. Highest-Risk Untested Areas

Ranked by (probability of a defect) × (consequence):

1. **Auth session lifecycle** — expiry, revocation, offline sign-in. Zero tests. Contains [P1-6] and [P1-7], the two most damaging findings in this report.
2. **Sign-out / deletion cleanup** — zero tests. [P1-3] and [P1-12] are each a single assertion away from being caught.
3. **Client-side API error paths** — zero tests. The entire client has one template widget test.
4. **Cross-subsystem notification behaviour** — [P0-3] exists precisely because local notifications and server push are each individually plausible and never tested together.
5. **Concurrency and saturation** — no test covers threadpool exhaustion ([P1-9]) or the limiter's fail-open clear ([P2-3]).
6. **Release build configuration** — no CI check that a release artifact is correctly signed or points at a real host; both P0 build defects would be caught by two shell assertions.

## K. Technical Debt (meaningful only)

1. **Hand-rolled migrations** ([P1-10]) — seven `ensure_*` functions running at import on every boot, with no version table. Compounds with every schema change. **Adopt Alembic.**
2. **Model duplication** — `backend/db/models.py` and `database/models.py` are maintained as column-identical copies by hand, with drift explicitly tracked as a hazard in project notes. **Extract to `shared/`.**
3. **Uniform `catch (_)`** in the client ([P1-6]) — a single idiom that defeats all error handling, retry, and observability at once. **Highest-leverage client refactor.**
4. **`unawaited()` as the standard write pattern** — no outbox, no retry, no user feedback. Root cause of most of §3.1.
5. **Three pieces of in-process state pinning the app to one worker** ([P2-4]) — scheduler, limiter, caches. Blocks all horizontal scaling.
6. **All handlers synchronous** — every external call (geocode, LLM, DB) occupies a threadpool slot for its full duration. The architectural cause of [P1-9].

## L. Recommended Roadmap

### Phase 1 — Must fix before release
1. ~~Deploy the backend with TLS; set the real `API_BASE_URL` and add a CI guard against the placeholder.~~ **[P0-1]** — 🟡 guard added; **deployment + hostname still needed**
2. ~~Create the upload keystore and `key.properties`; make a missing release signing config fail the build; register both release SHA-1s in Firebase.~~ **[P0-2]** — ✅ the build now fails; **keystore + SHA-1 registration still needed**
3. ~~Pick one reminder system — set `ENABLE_SCHEDULER=false` and stop calling `_syncFcm` on enable.~~ **[P0-3]** — ✅ done
4. ~~Redact birth parameters from all logs.~~ **[P1-1]** — ✅ done
5. Publish the privacy policy, complete Data Safety, add a web deletion page, register a support mailbox. **[P1-11]** — ⛔ **still outstanding, and now the largest blocker**
6. ~~Cancel the daily notification and unregister the device on sign-out.~~ **[P1-3]** — ✅ done
7. ~~Remove `exclude_none=True`.~~ **[P1-5]** — ✅ done
8. ~~Require auth on `/notifications/preferences`; close the `/unregister` oracle.~~ **[P1-4]** — ✅ done
9. ~~Make account deletion idempotent and report the true outcome.~~ **[P1-12]** — ✅ done
10. ~~Require auth on the personalised/expensive routes~~ and key the limiter on `uid`. **[P1-8]** — 🟡 auth done; limiter keying deferred (see the finding for why)

**Phase 1 remaining: items 1, 2 and 5 — all three are things only you can provide (a TLS host, an upload keystore, published legal pages).**

### Phase 2 — Production hardening
11. ~~Introduce typed `ApiResult`/`ApiException`; handle 401 (sign out), 429 (honour `Retry-After`), 5xx (retry affordance).~~ **[P1-6]** — ✅ done
12. ~~Make `_hydrateFromServer` tri-state; never route a failed hydration into onboarding.~~ **[P1-7]** — ✅ done
13. Move schema work into a `lifespan` startup with retry; adopt Alembic. **[P1-10]** — 🟡 lifespan done, Alembic outstanding
14. ~~`/health` → `SELECT 1`; add `/ready`.~~ **[P2-14]** — ✅ done
15. Bound the geocode concurrency; pre-seed common cities; shorten the timeout. **[P1-9]** — 🟡 bounded + timeout shortened; city table outstanding
16. Add Crashlytics + server error reporting + counters for LLM calls, fallbacks, 429s, 5xxs. **[P2-9]** — ⬜ outstanding; the data is now labelled and ready to report
17. ~~Add `source` to responses; alert on fallback; tell the user honestly.~~ **[P2-1]** — ✅ schema + client done; alerting waits on 16
18. ~~Align `client_ip` with `TRUST_PROXY_HEADERS`.~~ **[P1-2]** — ✅ done
19. ~~Disable public docs; `check_revoked=True` on mutating routes.~~ **[P2-7] [P2-8]** — ✅ done
20. Add `pytest`; convert the 22 scripts; add `ApiService` and auth-gate tests. **[P2-10]** — 🟡 `ApiService` + accessibility tests added and wired into CI; pytest migration outstanding

### Phase 3 — Product completeness
21. Server-side reading history so a sign-out or a new phone does not erase the streak.
22. Offline cache of the last reading.
23. Accessibility pass: semantic labels on charts, labelled icon buttons, 48 dp targets. **[P2-11]** — 🟡 labels and icon tooltips done; touch-target audit outstanding
24. Data export; enforce email verification.
25. Drop the dead tables; add foreign keys and a `stories` unique constraint. **[P2-2]** — 🟡 tables dropped and constraint added; foreign keys outstanding
26. Either personalise weekly/monthly or label them clearly as general.

### Phase 4 — Optimisation
27. Externalise scheduler, limiter and caches to Redis; allow >1 worker and ≥2 replicas. **[P2-4]**
28. Convert I/O-bound handlers to `async def`.
29. Deduplicate the two model files into `shared/`.
30. Bound the client response cache; guard rapid taps. **[P2-5] [P2-6]** — ✅ both done
31. Add a dependency lock file. **[P3-9]**

---

# 5. Final Question

> **Would you personally be comfortable releasing this application to 1,000 real users tomorrow?**

## **NO.**

Not because the product is bad — the astrology engine is the best part of this codebase and genuinely differentiated — but because **the artifact you would ship tomorrow cannot function**, and shipping it would create obligations you are not currently meeting.

**Top 5 reasons:**

1. **The release build is non-functional and unpublishable.** It is signed with the Android debug key, so Play rejects the upload; and if sideloaded, it points at `https://api.cosmicguide.app`, which does not resolve. Every screen would fail, and because all client errors are swallowed into `null`, neither the user nor you would be told why. These are two independent blockers, both silent fallbacks rather than build failures.

2. **You would be shipping a privacy liability.** Exact birth date, exact birth time and birth place — correlated with IP and User-Agent — are written in plaintext to `audit.log` and to stdout on every request. Simultaneously there is no privacy policy, no Data Safety declaration and no web-accessible deletion route, all three of which Play requires for an app with accounts and personal data. That is a rejected listing in the best case and a regulatory problem in the worst.

3. **Notifications would actively damage retention from day one.** Enabling the daily reminder schedules both an on-device notification at the user's chosen time and a server FCM push at 08:00 UTC — 04:00 for US Eastern users. And because sign-out never cancels the schedule or unregisters the device, a shared or resold phone keeps announcing the previous owner's zodiac sign, with the in-app toggle showing "off" and no way to stop it.

4. **The profile — the input to every single feature — can be silently corrupted.** Sign-out wipes all local state; if the next sign-in cannot reach the server for any reason, the user is routed through onboarding again as though new, and the hurriedly re-entered birth data is written over the original via a fire-and-forget call whose result is discarded. There is no versioning, no conflict detection, no undo, and no error shown. With 1,000 users on real mobile networks this is not hypothetical.

5. **You would be flying blind.** There is no crash reporting, no metrics, no alerting, and the health check does not check anything — so a dead database still reports healthy. Combined with mock fallbacks that return HTTP 200 with fabricated readings, an outage is invisible to your monitoring *and* indistinguishable from normal operation to your users. You would learn about every one of the problems above from store reviews.

**What would change the answer to YES:** all ten Phase 1 items. Realistically that is a focused effort, not a rewrite — nine of the ten are small, contained changes, and the tenth (deploying the backend with TLS) is infrastructure you need regardless. The engineering foundation underneath is sound; it is the last mile that is missing.

---

## Verdict after the remediation pass (2026-10-07)

### **NOT YET — but it is now a short, well-defined list rather than a long one.**

Of the five reasons above, **three are closed**:

2. **The privacy liability in the logs is gone.** Birth date, time and place are redacted before anything writes them, in the file *and* in stdout, and production keeps the audit trail off the log stream entirely. (The *paperwork* — reason 2's other half — is untouched and is now the single biggest blocker.)
3. **Notifications are fixed.** Exactly one reminder fires, on-device, at the user's chosen local time; the server job is off by default and devices register opted-out of it. Sign-out cancels the schedule and unregisters the device, so a shared phone no longer announces the previous owner's sign.
4. **The profile can no longer be silently corrupted.** A hydration failure now shows a retry screen instead of routing a returning user into onboarding, because `fetchProfile()` distinguishes "no profile" from "no connection". Account deletion is a single staged server operation that commits nothing unless the sign-in credential is actually gone.

**Reason 1 is half-closed.** Both build defects were *silent fallbacks*; neither is silent any more. A release build without `android/key.properties` **fails** with an explanatory `GradleException`, and a build still pointing at the placeholder host trips an assertion in debug/profile plus a CI warning. But the artifact still cannot be published until you produce the two secrets: **a TLS hostname** and **an upload keystore**.

**Reason 5 is unchanged.** There is still no crash reporting, no metrics and no alerting. What *has* changed is that the signals now exist to report: the client has a typed error channel and the server labels every degraded response with `source: fallback`. Adding a sink is a contained next step.

**The remaining list before 1,000 users:**

1. Deploy the backend behind TLS and build with the real `API_BASE_URL`.
2. Generate the upload keystore, write `android/key.properties`, and register the upload **and** Play App Signing SHA-1s in Firebase.
3. Publish a privacy policy covering birth data, complete the Data Safety form, add a web-accessible deletion page, and register a real support mailbox.
4. Add crash reporting and a minimal metrics/alerting path (strongly recommended, not strictly blocking).

Items 1–3 are all things only you can do. Nothing else on the original list stands between this app and a first release.

