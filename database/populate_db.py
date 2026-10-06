#!/usr/bin/env python3
"""
populate_db.py — Generate ALL content for CosmicGuide via Ollama and populate the DB.

Connects to Ollama at 192.168.29.159 and generates content one item at a time:
  - Horoscopes:     12 signs  (today's date)
  - Tarot Cards:    78 cards  (AI-quality upright + reversed interpretations)
  - Fortune Pool:   12 signs × 5 topics = 60 entries  (3 fortunes each)
  - Compatibility:  78 sign pairs  (full descriptions)
  - Stories:        6 categories  (cosmic articles)
    - Vedic content:  reference guidance for panchang, dasha, dosha, remedies, festivals, muhurta

Usage:
    python populate_db.py                      # run everything
    python populate_db.py --horoscopes         # horoscopes only
    python populate_db.py --fortunes           # fortune pool only
    python populate_db.py --compatibility      # compatibility only
    python populate_db.py --stories            # stories only
    python populate_db.py --vedic              # Vedic AI reference content only
    python populate_db.py --force              # regenerate even if data exists
    python populate_db.py --date 2026-04-28    # generate for a specific date
    python populate_db.py --days 7             # populate next 7 days from today
    python populate_db.py --horoscopes --days 3  # horoscopes for next 3 days
"""

import sys
import os
import json
import argparse
import http.client
import time
import re
from datetime import date, timedelta

# Ensure the project root is on sys.path so `database.*` imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.config import (
    configure_logging, get_logger,
    DATABASE_URL, AI_PROVIDER, AI_MODEL, GEMINI_API_KEY,
    OLLAMA_HOST, OLLAMA_MODEL, OLLAMA_TIMEOUT,
    GEMINI_TIMEOUT,
    IPHONE_LLM_BASE_URL, IPHONE_LLM_MODEL, IPHONE_LLM_API_KEY, IPHONE_LLM_TIMEOUT,
)

configure_logging()
log = get_logger("populate_db")

from database.connection import engine, SessionLocal, Base
from database.models import *  # noqa: F401,F403  — ensure all models are registered
from database.data.zodiac_data import ZODIAC_SIGNS
from database.data.fortune_options import FORTUNE_TOPICS
from database.data.compatibility_data import SIGN_PAIR_SCORES
from database.data.tarot_data import TAROT_CARDS
from database.db_service import (
    save_horoscope, delete_horoscope, horoscopes_exist,
    save_periodic_horoscope, periodic_horoscopes_exist, delete_periodic_horoscope,
    save_tarot_card, tarot_names_in_db, tarot_count,
    save_fortune_pool, delete_fortune_pool, fortune_pool_exists,
    save_compatibility, compatibility_pairs_exist,
    save_story, story_count,
    get_content_status,
)

VEDIC_MOCK_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "backend",
    "data",
    "mock",
    "vedic_content_data.py",
)

# Ensure all tables exist on the target DB
Base.metadata.create_all(engine)

# Patch pre-existing tables for columns added after first creation (create_all
# never alters an existing table). Keeps the populator safe if it runs before
# the API backend has migrated the shared database.
from shared.db_migrations import (  # noqa: E402
    ensure_horoscope_system_column,
    ensure_compatibility_canonical,
    ensure_horoscope_lucky_number_string,
    ensure_cache_unique_indexes,
)
ensure_horoscope_system_column(engine, log)
ensure_compatibility_canonical(engine, log)
ensure_horoscope_lucky_number_string(engine, log)
ensure_cache_unique_indexes(engine, log)


# ── Ollama helpers ────────────────────────────────────────────────────────────

def _ollama_generate(prompt: str, expect_json: bool = True,
                     max_tokens: int = 800) -> str | None:
    """Call Ollama /api/chat with streaming and return the full reply, or None."""
    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": True,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.8,
        },
    }).encode()

    t0 = time.perf_counter()
    try:
        conn = http.client.HTTPConnection(OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)
        conn.request(
            "POST", "/api/chat",
            body=payload,
            headers={"Content-Type": "application/json"},
        )
        resp = conn.getresponse()
        if resp.status != 200:
            body = resp.read().decode(errors="replace")[:300]
            log.error("Ollama HTTP %d: %s", resp.status, body)
            conn.close()
            # Signal unrecoverable errors so callers can abort early
            if "more system memory" in body or "not found" in body:
                raise RuntimeError(f"Ollama fatal: {body[:200]}")
            return None
        parts = []
        for raw_line in resp:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            chunk = json.loads(raw_line)
            content = chunk.get("message", {}).get("content", "")
            parts.append(content)
            if chunk.get("done"):
                break
        conn.close()
        elapsed = time.perf_counter() - t0
        text = "".join(parts).strip()
        log.debug("Ollama response in %.1fs  len=%d", elapsed, len(text))
        return text
    except Exception as exc:
        elapsed = time.perf_counter() - t0
        log.error("Ollama error after %.1fs: %s", elapsed, exc)
        return None


def _iphone_generate(prompt: str, expect_json: bool = True,
                     max_tokens: int = 800) -> str | None:
    """Call the iPhone-hosted, OpenAI-compatible LLM. Returns text or None."""
    scheme, _, rest = IPHONE_LLM_BASE_URL.partition("://")
    host_port, _, prefix = rest.partition("/")
    path = "/" + (prefix.rstrip("/") + "/chat/completions").lstrip("/")

    body = {
        "model": IPHONE_LLM_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0.8,
    }
    if expect_json:
        body["response_format"] = {"type": "json_object"}
    headers = {"Content-Type": "application/json"}
    if IPHONE_LLM_API_KEY and IPHONE_LLM_API_KEY != "not-needed":
        headers["Authorization"] = f"Bearer {IPHONE_LLM_API_KEY}"

    t0 = time.perf_counter()
    try:
        conn_cls = (http.client.HTTPSConnection if scheme == "https"
                    else http.client.HTTPConnection)
        conn = conn_cls(host_port, timeout=IPHONE_LLM_TIMEOUT)
        conn.request("POST", path, body=json.dumps(body).encode(), headers=headers)
        resp = conn.getresponse()
        raw = resp.read().decode(errors="replace")
        conn.close()
        if resp.status != 200:
            log.error("iPhone LLM HTTP %d: %s", resp.status, raw[:300])
            return None
        data = json.loads(raw)
        text = (data.get("choices", [{}])[0]
                .get("message", {}).get("content", "") or "").strip()
        log.debug("iPhone LLM response in %.1fs  len=%d",
                  time.perf_counter() - t0, len(text))
        return text or None
    except Exception as exc:
        log.error("iPhone LLM error after %.1fs: %s", time.perf_counter() - t0, exc)
        return None


def _gemini_generate(prompt: str, expect_json: bool = True,
                     max_tokens: int = 800) -> str | None:
    """Call Google Gemini via its REST API. Returns text or None."""
    if not GEMINI_API_KEY:
        return None
    path = f"/v1beta/models/{AI_MODEL}:generateContent?key={GEMINI_API_KEY}"
    gen_cfg = {"maxOutputTokens": max_tokens, "temperature": 0.8}
    if expect_json:
        gen_cfg["responseMimeType"] = "application/json"
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": gen_cfg,
    }

    t0 = time.perf_counter()
    try:
        conn = http.client.HTTPSConnection("generativelanguage.googleapis.com",
                                           timeout=GEMINI_TIMEOUT)
        conn.request("POST", path, body=json.dumps(body).encode(),
                     headers={"Content-Type": "application/json"})
        resp = conn.getresponse()
        raw = resp.read().decode(errors="replace")
        conn.close()
        if resp.status != 200:
            log.error("Gemini HTTP %d: %s", resp.status, raw[:300])
            return None
        cands = json.loads(raw).get("candidates", [])
        if not cands:
            return None
        parts = cands[0].get("content", {}).get("parts", [])
        text = "".join(p.get("text", "") for p in parts).strip()
        log.debug("Gemini response in %.1fs  len=%d", time.perf_counter() - t0, len(text))
        return text or None
    except Exception as exc:
        log.error("Gemini error after %.1fs: %s", time.perf_counter() - t0, exc)
        return None


# Provider registry — one generator function per backend.
_PROVIDER_FUNCS = {
    "gemini": _gemini_generate,
    "ollama": _ollama_generate,
    "iphone": _iphone_generate,
}


# Set once by main() after the preflight reachability check to the providers
# that actually responded, so per-item generation skips known-dead backends.
_runtime_providers: list | None = None


def _active_providers() -> list:
    """Return the ordered providers to try, honoring AI_PROVIDER.

    A specific value (gemini/ollama/iphone) forces just that backend; ``auto``
    tries Gemini (only if a key is set), then Ollama, then the iPhone LLM.
    """
    if AI_PROVIDER in _PROVIDER_FUNCS:
        return [AI_PROVIDER]
    order = []
    if GEMINI_API_KEY:
        order.append("gemini")
    order.extend(["ollama", "iphone"])
    return order


def _generation_providers() -> list:
    """Providers to try for each generation call.

    After preflight, ``main()`` narrows this to the reachable subset so we don't
    retry a backend already known to be down on every single item.
    """
    return _runtime_providers if _runtime_providers is not None else _active_providers()


def _llm_generate(prompt: str, expect_json: bool = True,
                  max_tokens: int = 800) -> str | None:
    """Generate content using the configured provider(s), with auto-fallback."""
    for name in _generation_providers():
        try:
            text = _PROVIDER_FUNCS[name](prompt, expect_json=expect_json,
                                         max_tokens=max_tokens)
        except Exception as exc:  # provider blew up — try the next one
            log.warning("Provider '%s' failed: %s", name, exc)
            continue
        if text:
            return text
        log.warning("Provider '%s' returned no content — trying next", name)
    return None


def _parse_json(raw: str, log_error: bool = True) -> dict | list | None:
    """Strip markdown fences and parse JSON."""
    if not raw:
        return None
    raw = raw.strip()
    if raw.startswith("```"):
        lines = raw.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        raw = "\n".join(lines).strip()

    def _escape_controls_inside_strings(text: str) -> str:
        """Escape literal control chars that appear inside quoted JSON strings."""
        out = []
        in_string = False
        escaped = False
        for ch in text:
            if escaped:
                out.append(ch)
                escaped = False
                continue
            if ch == "\\":
                out.append(ch)
                if in_string:
                    escaped = True
                continue
            if ch == '"':
                out.append(ch)
                in_string = not in_string
                continue
            if in_string and ch == "\n":
                out.append("\\n")
                continue
            if in_string and ch == "\r":
                out.append("\\r")
                continue
            if in_string and ch == "\t":
                out.append("\\t")
                continue
            out.append(ch)
        return "".join(out)

    def _repair_single_quotes(text: str) -> str:
        """
        Replace single-quoted strings with double-quoted strings in JSON arrays/objects.
        Handles mixed quote styles from LLM output, including apostrophes in text.
        """
        import ast
        try:
            result = ast.literal_eval(text)
            return json.dumps(result)
        except Exception:
            pass
        # Fallback: split on delimiter patterns for arrays of single-quoted strings
        stripped = text.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            inner = stripped[1:-1].strip()
            # Remove wrapping double-quotes if the LLM wrapped everything in one string
            if inner.startswith('"') and inner.endswith('"'):
                inner = inner[1:-1]
            # Split on ',\n  ' or "',\n  '" patterns (item boundaries)
            parts = re.split(r"'\s*,\s*[\n\r]*\s*'", inner)
            if len(parts) >= 2:
                # Clean leading/trailing quotes and whitespace from each part
                cleaned = [p.strip().strip("'\"").strip() for p in parts]
                cleaned = [c for c in cleaned if c]
                if cleaned:
                    return json.dumps(cleaned)
        return text

    def _repair_common_json_issues(text: str) -> str:
        """
        Repair frequent LLM JSON mistakes:
        - trailing commas before ] or }
        - unterminated final string (missing quote before ] or })
        """
        import re

        fixed = re.sub(r",\s*([\]}])", r"\1", text)

        # If quote count is odd, try closing the final string before terminal ] or }.
        quote_count = 0
        escaped = False
        for ch in fixed:
            if escaped:
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                continue
            if ch == '"':
                quote_count += 1

        if quote_count % 2 == 1:
            tail = fixed.rstrip()
            if tail.endswith("]") or tail.endswith("}"):
                fixed = tail[:-1] + '"' + tail[-1]
            else:
                fixed = tail + '"'

        return fixed

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        fixed = _escape_controls_inside_strings(raw)
        fixed = _repair_common_json_issues(fixed)
        try:
            return json.loads(fixed)
        except json.JSONDecodeError:
            pass
        # Try single-quote repair (common LLM mistake)
        fixed = _repair_single_quotes(raw)
        fixed = _escape_controls_inside_strings(fixed)
        fixed = _repair_common_json_issues(fixed)
        try:
            return json.loads(fixed)
        except json.JSONDecodeError as exc:
            if log_error:
                log.error("JSON parse error: %s | raw[:300]: %s", exc, raw[:300])
            return None


def _extract_story_fields(raw: str) -> dict | None:
    """Best-effort field extraction for malformed story JSON responses."""
    if not raw:
        return None

    text = raw.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    def _grab(key: str, next_keys: list[str]) -> str:
        next_group = "|".join(re.escape(k) for k in next_keys)
        pattern = (
            rf'"{re.escape(key)}"\s*:\s*"(.*?)"\s*'
            rf'(?=\s*,?\s*"(?:{next_group})"\s*:|\s*\}}|\s*\Z)'
        )
        m = re.search(pattern, text, re.DOTALL)
        if not m:
            return ""
        value = m.group(1)
        return (
            value
            .replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\r", "")
            .replace("\\t", "\t")
            .strip()
        )

    title = _grab("title", ["summary", "content", "read_time"])
    summary = _grab("summary", ["content", "read_time"])
    content = _grab("content", ["read_time"])
    read_time = _grab("read_time", []) or "4 min"

    if not title and not content:
        return None

    return {
        "title": title or "Cosmic Insights",
        "summary": summary,
        "content": content,
        "read_time": read_time,
    }


_HOROSCOPE_STR_KEYS = ("zodiac_sign", "date", "general", "love", "career",
                       "health", "lucky_color", "mood")
_HOROSCOPE_INT_KEYS = ("overall_score", "lucky_number")
_HOROSCOPE_KEYS = _HOROSCOPE_STR_KEYS + _HOROSCOPE_INT_KEYS


def _extract_horoscope_fields(raw: str) -> dict | None:
    """Best-effort field extraction for malformed horoscope JSON responses.

    Grabs each known key independently with regex, so a single missing comma or
    stray character elsewhere in the response can't sink the whole horoscope.
    """
    if not raw:
        return None

    text = raw.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    def _clean(v: str) -> str:
        return (
            v.replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\r", "")
            .replace("\\t", "\t")
            .strip()
        )

    def _grab_str(key: str) -> str:
        others = "|".join(re.escape(k) for k in _HOROSCOPE_KEYS if k != key)
        pattern = (
            rf'"{re.escape(key)}"\s*:\s*"(.*?)"\s*'
            rf'(?=\s*,?\s*"(?:{others})"\s*:|\s*\}}|\s*\Z)'
        )
        m = re.search(pattern, text, re.DOTALL)
        return _clean(m.group(1)) if m else ""

    def _grab_int(key: str):
        m = re.search(rf'"{re.escape(key)}"\s*:\s*"?(\d+)"?', text)
        return int(m.group(1)) if m else None

    def _grab_general() -> str:
        # Strict grab first (value cleanly closed before the next key/brace).
        val = _grab_str("general")
        if val:
            return val
        # Truncation-tolerant: the model often rambles a long, multi-paragraph
        # "general" and gets cut off mid-string. Capture from the opening quote
        # to the next known-key boundary, or to end-of-text, then tidy + cap it.
        m = re.search(r'"general"\s*:\s*"(.*)$', text, re.DOTALL)
        if not m:
            return ""
        rest = m.group(1)
        others = "|".join(re.escape(k) for k in _HOROSCOPE_KEYS if k != "general")
        boundary = re.search(rf'"\s*,?\s*"(?:{others})"\s*:', rest)
        if boundary:
            rest = rest[:boundary.start()]
        rest = _clean(rest.rstrip('"').rstrip())
        if len(rest) > 600:  # trim a runaway essay back to a whole sentence
            rest = rest[:600]
            cut = max(rest.rfind("."), rest.rfind("!"), rest.rfind("?"))
            if cut > 200:
                rest = rest[:cut + 1]
        return rest.strip()

    general = _grab_general()
    if not general:
        # Nothing usable recovered — let the caller emit the real parse error.
        return None

    data: dict = {"general": general}
    for key in _HOROSCOPE_STR_KEYS:
        if key == "general":
            continue
        val = _grab_str(key)
        if val:
            data[key] = val
    for key in _HOROSCOPE_INT_KEYS:
        val = _grab_int(key)
        if val is not None:
            data[key] = val
    return data


def _check_ollama() -> bool:
    """Verify Ollama is reachable."""
    try:
        conn = http.client.HTTPConnection(OLLAMA_HOST, timeout=10)
        conn.request("GET", "/api/tags")
        resp = conn.getresponse()
        data = json.loads(resp.read())
        conn.close()
        models = [m.get("name", "") for m in data.get("models", [])]
        log.info("Ollama OK at %s  models=%s", OLLAMA_HOST, models)
        return resp.status == 200
    except Exception as exc:
        log.error("Cannot reach Ollama at %s: %s", OLLAMA_HOST, exc)
        return False


def _check_iphone() -> bool:
    """Verify the iPhone LLM endpoint is reachable (GET {base}/models)."""
    scheme, _, rest = IPHONE_LLM_BASE_URL.partition("://")
    host_port, _, prefix = rest.partition("/")
    path = "/" + (prefix.rstrip("/") + "/models").lstrip("/")
    try:
        conn_cls = (http.client.HTTPSConnection if scheme == "https"
                    else http.client.HTTPConnection)
        conn = conn_cls(host_port, timeout=10)
        conn.request("GET", path)
        resp = conn.getresponse()
        resp.read()
        conn.close()
        if resp.status == 200:
            log.info("iPhone LLM OK at %s  model=%s", IPHONE_LLM_BASE_URL, IPHONE_LLM_MODEL)
            return True
        log.error("iPhone LLM HTTP %d at %s", resp.status, IPHONE_LLM_BASE_URL)
        return False
    except Exception as exc:
        log.error("Cannot reach iPhone LLM at %s: %s", IPHONE_LLM_BASE_URL, exc)
        return False


def _reachable_providers() -> list:
    """Ping each active provider; return those that respond, in priority order."""
    reachable = []
    for name in _active_providers():
        if name == "ollama" and _check_ollama():
            reachable.append(name)
        elif name == "iphone" and _check_iphone():
            reachable.append(name)
        elif name == "gemini":
            if GEMINI_API_KEY:
                log.info("Gemini configured  model=%s", AI_MODEL)
                reachable.append(name)
            else:
                log.warning("Gemini selected but GEMINI_API_KEY is empty — skipping")
    return reachable


# ── Content generators ────────────────────────────────────────────────────────

def populate_horoscopes(db, target_date: date, force: bool = False) -> int:
    date_str = target_date.isoformat()
    day_label = target_date.strftime("%A, %B %d, %Y")
    generated = 0

    existing = horoscopes_exist(db, target_date)
    log.info("Horoscopes for %s: %d/12 already exist", date_str, len(existing))

    for sign in ZODIAC_SIGNS:
        if sign in existing and not force:
            log.info("  [SKIP] %s — already exists", sign)
            continue

        log.info("  [GEN] %s ...", sign)
        prompt = (
            f"Generate a daily horoscope for {sign} for {day_label}.\n"
            "Respond with ONLY a single-line, compact, valid JSON object. "
            "No markdown, no code fences, and no line breaks inside any value. "
            "Keep every field brief — the \"general\" field must be 2-3 sentences "
            "(60-80 words maximum). Use exactly these keys:\n"
            f'{{"zodiac_sign":"{sign}","date":"{date_str}",'
            '"general":"2-3 uplifting sentences (60-80 words)",'
            '"love":"1 short sentence on romance",'
            '"career":"1 short sentence on work",'
            '"health":"1 short sentence on wellness",'
            '"overall_score": <integer 65-95>,'
            '"lucky_number": <integer 1-99>,'
            '"lucky_color":"one color word",'
            '"mood":"one positive word"}'
        )

        try:
            raw = _llm_generate(prompt, max_tokens=500)
        except RuntimeError as exc:
            log.error("  [ABORT] LLM fatal error — stopping: %s", exc)
            break
        if not raw:
            log.error("  [FAIL] %s — empty LLM response", sign)
            continue
        data = _parse_json(raw, log_error=False)
        if not isinstance(data, dict):
            data = _extract_horoscope_fields(raw)
            if isinstance(data, dict):
                log.warning("  [RECOVER] %s — parsed via fallback field extraction", sign)
            else:
                # Only emit the hard parse error if we could not recover.
                _parse_json(raw, log_error=True)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s — bad response | raw[:200]: %s", sign, raw[:200])
            continue

        data.setdefault("zodiac_sign", sign)
        data.setdefault("date", date_str)

        # Replace only once the new reading is in hand: deleting first meant a
        # --force run against a flaky LLM destroyed the existing horoscope and
        # left nothing in its place.
        if sign in existing:
            delete_horoscope(db, sign, target_date)

        if save_horoscope(db, data):
            log.info("  [OK] %s  score=%s  mood=%s",
                      sign, data.get("overall_score"), data.get("mood"))
            generated += 1
        else:
            log.error("  [FAIL] %s — DB error", sign)

    log.info("Horoscopes: %d/%d generated", generated, len(ZODIAC_SIGNS))
    return generated


def _period_bounds(period: str, today: date):
    """Return (period_key, start_date, end_date) for the week or month of `today`.

    Mirrors backend horoscope_service._period_bounds so the keys match exactly:
      weekly  -> 'YYYY-Www' (ISO week, Monday-Sunday)
      monthly -> 'YYYY-MM'  (calendar month)
    """
    if period == "monthly":
        start = today.replace(day=1)
        if start.month == 12:
            nxt = start.replace(year=start.year + 1, month=1)
        else:
            nxt = start.replace(month=start.month + 1)
        end = nxt - timedelta(days=1)
        return f"{today.year}-{today.month:02d}", start, end
    iso_year, iso_week, _ = today.isocalendar()
    start = today - timedelta(days=today.weekday())
    end = start + timedelta(days=6)
    return f"{iso_year}-W{iso_week:02d}", start, end


def _period_prompt(zodiac_sign: str, period: str, start: date, end: date) -> str:
    """Weekly/monthly Western Sun-sign prompt — mirrors the backend period prompt."""
    if period == "monthly":
        cadence = "month"
        span = start.strftime("%B %Y")
        arc = "Cover the month's overall arc and how the energy shifts across its weeks."
    else:
        cadence = "week"
        span = f"{start.strftime('%b %d')} - {end.strftime('%b %d, %Y')}"
        arc = "Cover the week's arc from start to finish and note a couple of standout days."
    return (
        f"Generate a complete {cadence}ly horoscope for {zodiac_sign} for the {cadence} of {span}.\n"
        "Respond with ONLY a single-line, compact, valid JSON object. "
        "No markdown, no code fences, and no line breaks inside any value. "
        f"Speak to the {cadence} as a whole, not a single day. Use exactly these keys:\n"
        f'{{"zodiac_sign":"{zodiac_sign}",'
        f'"general":"overall {cadence} theme in 70-100 words. {arc}",'
        f'"love":"romantic and relationship outlook for the {cadence}, 70-100 words",'
        f'"career":"professional and financial guidance for the {cadence}, 70-100 words",'
        f'"health":"physical and mental wellness for the {cadence}, 70-100 words",'
        '"overall_score": <integer 60-95>,'
        '"lucky_number":"a single lucky number as a string",'
        f'"lucky_color":"one color for {zodiac_sign} this {cadence}",'
        f'"mood":"one word for the {cadence} tone"}}'
    )


def populate_periodic(db, target_date: date, period: str, force: bool = False) -> int:
    """Generate weekly or monthly (Western) horoscopes for the period of target_date."""
    period_key, start, end = _period_bounds(period, target_date)
    system = "western"
    generated = 0

    existing = periodic_horoscopes_exist(db, period, period_key, system)
    log.info("%s horoscopes for %s: %d/12 already exist",
             period.capitalize(), period_key, len(existing))

    for sign in ZODIAC_SIGNS:
        if sign in existing and not force:
            log.info("  [SKIP] %s — already exists", sign)
            continue

        log.info("  [GEN] %s %s ...", period, sign)
        prompt = _period_prompt(sign, period, start, end)

        try:
            raw = _llm_generate(prompt, max_tokens=700)
        except RuntimeError as exc:
            log.error("  [ABORT] LLM fatal error — stopping: %s", exc)
            break
        if not raw:
            log.error("  [FAIL] %s — empty LLM response", sign)
            continue
        data = _parse_json(raw, log_error=False)
        if not isinstance(data, dict):
            data = _extract_horoscope_fields(raw)
            if isinstance(data, dict):
                log.warning("  [RECOVER] %s — parsed via fallback field extraction", sign)
            else:
                _parse_json(raw, log_error=True)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s — bad response | raw[:200]: %s", sign, raw[:200])
            continue

        data["zodiac_sign"] = sign
        data["period"] = period
        data["period_key"] = period_key
        data["system"] = system

        # Replace only once the new reading is in hand (see populate_horoscopes).
        if sign in existing:
            delete_periodic_horoscope(db, sign, period, period_key, system)

        if save_periodic_horoscope(db, data):
            log.info("  [OK] %s  score=%s  mood=%s",
                      sign, data.get("overall_score"), data.get("mood"))
            generated += 1
        else:
            log.error("  [FAIL] %s — DB error", sign)

    log.info("%s horoscopes: %d/%d generated", period.capitalize(), generated, len(ZODIAC_SIGNS))
    return generated


def populate_tarot(db, force: bool = False) -> int:
    existing_names = tarot_names_in_db(db)
    generated = 0

    log.info("Tarot cards in DB: %d/%d", len(existing_names), len(TAROT_CARDS))

    for card in TAROT_CARDS:
        name = card["name"]
        if name in existing_names and not force:
            log.info("  [SKIP] %s — already exists", name)
            continue

        log.info("  [GEN] %s (%s) ...", name, card["number"])
        prompt = (
            f'Generate mystical tarot interpretations for "{name}" '
            f'(card {card["number"]}). Core meaning: {card["meaning"]}.\n\n'
            "Return ONLY valid JSON with these exact keys:\n"
            '{"upright_interpretation":"3-4 evocative sentences (70-90 words) about what this card '
            'means when drawn upright. Reference the card\'s symbolism and archetype. '
            'End with an actionable insight.",'
            '"reversed_interpretation":"3-4 sentences (70-90 words) about the reversed meaning. '
            'Acknowledge the shadow aspect, then pivot to empowerment. End with guidance."}'
        )

        raw = _llm_generate(prompt, max_tokens=600)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s — bad response", name)
            continue

        card_data = {
            "name": name,
            "number": card["number"],
            "meaning": card["meaning"],
            "upright_interpretation": data.get("upright_interpretation", card["upright"]),
            "reversed_interpretation": data.get("reversed_interpretation", card["reversed"]),
        }

        if save_tarot_card(db, card_data):
            log.info("  [OK] %s", name)
            generated += 1
        else:
            log.error("  [FAIL] %s — DB error", name)

    log.info("Tarot: %d/%d generated", generated, len(TAROT_CARDS))
    return generated


def populate_fortunes(db, target_date: date, force: bool = False) -> int:
    date_str = target_date.isoformat()
    total_expected = len(ZODIAC_SIGNS) * len(FORTUNE_TOPICS)
    generated = 0

    existing = fortune_pool_exists(db, target_date)
    log.info("Fortune pools for %s: %d/%d already exist", date_str, len(existing), total_expected)

    for sign in ZODIAC_SIGNS:
        for topic in FORTUNE_TOPICS:
            if (sign, topic) in existing and not force:
                continue
            if (sign, topic) in existing and force:
                delete_fortune_pool(db, sign, topic, target_date)

            log.info("  [GEN] %s / %s ...", sign, topic)
            prompt = (
                f"Generate exactly 3 short {topic} fortune messages for {sign} today ({date_str}).\n"
                "Each fortune should be 1-2 mystical sentences (15-25 words), referencing "
                "celestial imagery. Speak directly using 'you' and 'your'.\n"
                "Return ONLY a valid JSON array of 3 strings.\n"
                'Example: ["A cosmic wind carries new opportunities your way.", '
                '"The stars align to brighten your path forward.", '
                '"Trust the celestial rhythm guiding your heart."]'
            )

            try:
                raw = _llm_generate(prompt, max_tokens=300)
            except RuntimeError as exc:
                log.error("  [ABORT] LLM fatal error — stopping: %s", exc)
                return generated
            data = _parse_json(raw)

            if isinstance(data, dict) and any(isinstance(v, list) for v in data.values()):
                for v in data.values():
                    if isinstance(v, list):
                        data = v
                        break

            if not isinstance(data, list) or len(data) < 1:
                log.error("  [FAIL] %s/%s — bad response", sign, topic)
                continue

            fortunes = [str(f) for f in data[:3]]
            if save_fortune_pool(db, target_date, sign, topic, fortunes):
                log.info("  [OK] %s/%s  (%d fortunes)", sign, topic, len(fortunes))
                generated += 1
            else:
                log.error("  [FAIL] %s/%s — DB error", sign, topic)

    log.info("Fortunes: %d/%d generated", generated, total_expected)
    return generated


def populate_compatibility(db, force: bool = False) -> int:
    generated = 0
    existing = compatibility_pairs_exist(db)
    total_expected = len(SIGN_PAIR_SCORES)

    log.info("Compatibility pairs in DB: %d/%d", len(existing), total_expected)

    for (s1, s2), score in SIGN_PAIR_SCORES.items():
        if (s1, s2) in existing and not force:
            continue

        log.info("  [GEN] %s × %s (score: %d) ...", s1, s2, score)

        if score >= 80:
            harmony = "natural harmony and powerful chemistry"
        elif score >= 60:
            harmony = "dynamic contrast and growth potential"
        else:
            harmony = "transformative tension that forges deep growth"

        prompt = (
            f"Write a compatibility profile for {s1} and {s2} (score: {score}/100, {harmony}).\n"
            "Return ONLY valid JSON with these exact keys:\n"
            '{"description":"2-3 sentences about their overall relationship dynamic (60-80 words)",'
            '"love_advice":"1-2 practical sentences of relationship advice",'
            '"strengths_together":"1-2 sentences about what works well between them",'
            '"challenges":"1-2 sentences about what to watch out for"}'
        )

        raw = _llm_generate(prompt, max_tokens=500)
        data = _parse_json(raw)
        if not isinstance(data, dict):
            log.error("  [FAIL] %s × %s — bad response", s1, s2)
            continue

        compat_data = {
            "sign1": s1,
            "sign2": s2,
            "score": score,
            "description": data.get("description", ""),
            "love_advice": data.get("love_advice", ""),
            "strengths_together": data.get("strengths_together", data.get("strengths", "")),
            "challenges": data.get("challenges", ""),
        }

        if save_compatibility(db, compat_data):
            log.info("  [OK] %s × %s", s1, s2)
            generated += 1
        else:
            log.error("  [FAIL] %s × %s — DB error", s1, s2)

    log.info("Compatibility: %d/%d generated", generated, total_expected)
    return generated


STORY_CATEGORIES = ["Planetary", "Weekly", "Relationships", "Rituals", "Career", "Spiritual"]


def populate_stories(db, force: bool = False) -> int:
    from database.models import Story

    generated = 0

    existing_count = story_count(db)
    log.info("Stories in DB: %d", existing_count)

    if existing_count >= len(STORY_CATEGORIES) and not force:
        log.info("Stories already populated — skipping (use --force to regenerate)")
        return 0

    # Retired only once replacements are committed, so a failed run never
    # empties the feed and repeated --force runs don't grow the table forever.
    previous_ids = [row.id for row in db.query(Story.id).all()] if force else []
    if force:
        log.info("Force mode — regenerating; %d existing stories retire once new ones land", len(previous_ids))

    for category in STORY_CATEGORIES:
        log.info("  [GEN] Story: %s ...", category)
        prompt = (
            f"You are an astrology writer for the CosmicGuide app. "
            f"Write an engaging {category} astrology article.\n\n"
            f"Category: {category}\n"
            "Requirements:\n"
            "- 300-400 words, educational yet mystical tone\n"
            "- Practical insights readers can act on\n"
            "- Reference current cosmic energy and planetary influences\n\n"
            "Return ONLY valid JSON with these exact keys:\n"
            '{"title":"Compelling headline (8-12 words)",'
            '"summary":"One-sentence teaser under 20 words",'
            '"content":"Full article text (300-400 words)",'
            '"read_time":"X min"}'
        )

        raw = _llm_generate(prompt, max_tokens=1200)
        data = _parse_json(raw, log_error=False)
        if not isinstance(data, dict):
            data = _extract_story_fields(raw)
            if isinstance(data, dict):
                log.warning("  [RECOVER] Story %s — parsed via fallback field extraction", category)
            else:
                # Only emit hard parse error if we could not recover.
                _parse_json(raw, log_error=True)
        if not isinstance(data, dict):
            log.error("  [FAIL] Story %s — bad response", category)
            continue

        story_data = {
            "title": data.get("title", f"{category} Cosmic Insights"),
            "summary": data.get("summary", ""),
            "content": data.get("content", ""),
            "category": category,
            "read_time": data.get("read_time", "4 min"),
            "author": "CosmicGuide",
            "is_featured": category in ("Planetary", "Weekly"),
        }

        if save_story(db, story_data):
            log.info("  [OK] '%s'", story_data["title"])
            generated += 1
        else:
            log.error("  [FAIL] Story %s — DB error", category)

    if previous_ids:
        if generated:
            db.query(Story).filter(Story.id.in_(previous_ids)).delete(synchronize_session=False)
            db.commit()
            log.info("Stories: retired %d previous stories", len(previous_ids))
        else:
            log.warning("Stories: nothing generated (LLM down?) — keeping %d existing", len(previous_ids))

    log.info("Stories: %d/%d generated", generated, len(STORY_CATEGORIES))
    return generated


def _write_vedic_mock_file(content: dict) -> None:
    lines = [
        '"""Mock AI-enhanced Vedic guidance content.',
        '',
        'This file can be regenerated by database/populate_db.py --vedic.',
        '"""',
        '',
        f"VEDIC_CONTENT = {json.dumps(content, indent=2, ensure_ascii=True)}",
        '',
    ]
    os.makedirs(os.path.dirname(VEDIC_MOCK_FILE), exist_ok=True)
    with open(VEDIC_MOCK_FILE, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def populate_vedic_content(force: bool = False) -> int:
    if os.path.exists(VEDIC_MOCK_FILE) and not force:
        log.info("Vedic content mock already exists — skipping (use --force to regenerate)")
        return 0

    prompt = (
        "Generate concise Vedic astrology reference guidance as JSON. "
        "Return ONLY valid JSON with this exact shape:\n"
        '{'
        '"panchang":{"default":"one short paragraph under 30 words"},'
        '"dasha_lords":{'
        '"Sun":"...","Moon":"...","Mars":"...","Mercury":"...",'
        '"Jupiter":"...","Venus":"...","Saturn":"...","Rahu":"...","Ketu":"..."},'
        '"doshas":{'
        '"Manglik Dosha":"...","Kaal Sarp Dosha":"...","Sade Sati":"...","clear":"..."},'
        '"remedies":{'
        '"default":"...","Manglik Dosha":"..."},'
        '"festivals":{'
        '"Akshaya Tritiya":"...","Guru Purnima":"...","Janmashtami":"...",'
        '"Navratri Begins":"...","Dussehra":"...","Diwali":"...",'
        '"Makar Sankranti":"...","Mahashivratri":"...","Holi":"..."},'
        '"muhurta":{"default":"..."}'
        '}'
    )

    raw = _llm_generate(prompt, max_tokens=1200)
    data = _parse_json(raw)
    if not isinstance(data, dict):
        log.error("[FAIL] Vedic content — bad response")
        return 0

    _write_vedic_mock_file(data)
    log.info("[OK] Vedic content mock written to %s", VEDIC_MOCK_FILE)
    return 1


# ── Seed (static data, no LLM) ───────────────────────────────────────────────

def seed_tarot(db, force: bool = False) -> int:
    from database.models import TarotCard
    existing = db.query(TarotCard).count()
    if existing >= len(TAROT_CARDS) and not force:
        log.info("Tarot: already seeded (%d cards) — skip", existing)
        return 0
    if force:
        db.query(TarotCard).delete()
        db.flush()
    inserted = 0
    for card in TAROT_CARDS:
        try:
            db.add(TarotCard(
                name=card["name"], number=card["number"], meaning=card["meaning"],
                upright_interpretation=card["upright"], reversed_interpretation=card["reversed"],
            ))
            inserted += 1
        except Exception as exc:
            log.warning("Tarot skip '%s': %s", card["name"], exc)
    db.commit()
    log.info("Tarot: seeded %d cards", inserted)
    return inserted


def seed_compatibility(db, force: bool = False) -> int:
    from database.models import Compatibility
    existing = {(r.sign1, r.sign2) for r in db.query(Compatibility.sign1, Compatibility.sign2).all()}
    if len(existing) >= len(SIGN_PAIR_SCORES) and not force:
        log.info("Compatibility: already seeded (%d pairs) — skip", len(existing))
        return 0
    if force:
        db.query(Compatibility).delete()
        db.flush()
        existing = set()
    inserted = 0
    for (s1, s2), score in SIGN_PAIR_SCORES.items():
        if (s1, s2) in existing:   # SIGN_PAIR_SCORES keys are already canonical (alphabetical)
            continue
        try:
            db.add(Compatibility(
                sign1=s1, sign2=s2, score=score,
                description=f"{s1} and {s2} have a compatibility score of {score}/100.",
            ))
            inserted += 1
        except Exception as exc:
            log.warning("Compatibility skip %s/%s: %s", s1, s2, exc)
    db.commit()
    log.info("Compatibility: seeded %d pairs", inserted)
    return inserted


# ── Summary ───────────────────────────────────────────────────────────────────

def print_status(db, target_date: date):
    status = get_content_status(db, target_date)
    log.info("=" * 60)
    log.info("DB Content Status for %s", status["date"])
    log.info("-" * 60)
    log.info("  Horoscopes:     %d / %d", status["horoscopes"]["count"], status["horoscopes"]["expected"])
    log.info("  Fortune Pool:   %d / %d", status["fortune_pool"]["count"], status["fortune_pool"]["expected"])
    log.info("  Stories Today:  %d", status["stories_today"])
    log.info("  Compatibility:  %d / %d", status["compatibility_pairs"]["count"], status["compatibility_pairs"]["expected"])
    log.info("  Tarot Cards:    %d / %d", status["tarot_cards"]["count"], status["tarot_cards"]["expected"])
    log.info("-" * 60)
    log.info("  Fully populated: %s", "YES" if status["fully_populated"] else "NO")
    log.info("=" * 60)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Populate CosmicGuide DB with AI-generated content via Ollama"
    )
    parser.add_argument("--horoscopes", action="store_true", help="Generate horoscopes")
    parser.add_argument("--tarot", action="store_true", help="Generate tarot card interpretations")
    parser.add_argument("--fortunes", action="store_true", help="Generate fortune pools")
    parser.add_argument("--compatibility", action="store_true", help="Generate compatibility descriptions")
    parser.add_argument("--stories", action="store_true", help="Generate cosmic stories")
    parser.add_argument("--weekly", action="store_true", help="Generate weekly horoscopes (current week)")
    parser.add_argument("--monthly", action="store_true", help="Generate monthly horoscopes (current month)")
    parser.add_argument("--vedic", action="store_true", help="Generate AI Vedic reference mock content")
    parser.add_argument("--seed", action="store_true", help="Seed static data (tarot cards + compatibility scores)")
    parser.add_argument("--force", action="store_true", help="Regenerate even if data exists")
    parser.add_argument("--date", type=str, default=None,
                        help="Target date (YYYY-MM-DD), defaults to today")
    parser.add_argument("--days", type=int, default=1,
                        help="Number of days to populate (starting from --date or today)")
    parser.add_argument("--status", action="store_true", help="Print DB content status and exit")
    args = parser.parse_args()

    target_date = date.fromisoformat(args.date) if args.date else date.today()
    num_days = max(1, args.days)
    run_all = not any([args.horoscopes, args.tarot, args.fortunes,
                       args.compatibility, args.stories, args.weekly, args.monthly,
                       args.vedic, args.seed, args.status])

    db = SessionLocal()

    if args.status:
        print_status(db, target_date)
        db.close()
        return

    log.info("Database: %s", DATABASE_URL.split("@")[-1] if "@" in DATABASE_URL else DATABASE_URL)

    # Seed doesn't need an LLM
    if args.seed:
        log.info("━━━ SEED STATIC DATA ━━━")
        seed_tarot(db, args.force)
        seed_compatibility(db, args.force)
        log.info("Done!")
        print_status(db, target_date)
        db.close()
        return

    log.info("LLM provider: %s — checking connectivity ...", AI_PROVIDER)
    reachable = _reachable_providers()
    if not reachable:
        log.error("No configured LLM provider is reachable (tried: %s) — aborting",
                  ", ".join(_active_providers()))
        db.close()
        sys.exit(1)
    log.info("LLM ready — provider order: %s", " → ".join(reachable))

    # Narrow subsequent per-item generation to the providers that responded, so
    # we don't retry a known-dead backend (e.g. Ollama) on every single call.
    global _runtime_providers
    _runtime_providers = reachable

    log.info("Target date: %s  Days: %d  Force: %s",
             target_date.isoformat(), num_days, args.force)
    log.info("=" * 60)

    t0 = time.perf_counter()

    try:
        # Date-sensitive content: loop over each day
        dates_to_populate = [target_date + timedelta(days=i) for i in range(num_days)]

        for day in dates_to_populate:
            if num_days > 1:
                log.info("━━━ DAY: %s ━━━", day.isoformat())

            if run_all or args.horoscopes:
                log.info("━━━ HOROSCOPES (%s) ━━━", day.isoformat())
                populate_horoscopes(db, day, args.force)
                log.info("")

            if run_all or args.fortunes:
                log.info("━━━ FORTUNE POOL (%s) ━━━", day.isoformat())
                populate_fortunes(db, day, args.force)
                log.info("")

        # Non-date-sensitive content: run once
        if run_all or args.weekly:
            log.info("━━━ WEEKLY HOROSCOPES ━━━")
            populate_periodic(db, target_date, "weekly", args.force)
            log.info("")

        if run_all or args.monthly:
            log.info("━━━ MONTHLY HOROSCOPES ━━━")
            populate_periodic(db, target_date, "monthly", args.force)
            log.info("")

        if run_all or args.tarot:
            log.info("━━━ TAROT CARDS ━━━")
            populate_tarot(db, args.force)
            log.info("")

        if run_all or args.compatibility:
            log.info("━━━ COMPATIBILITY ━━━")
            populate_compatibility(db, args.force)
            log.info("")

        if run_all or args.stories:
            log.info("━━━ STORIES ━━━")
            populate_stories(db, args.force)
            log.info("")

        if run_all or args.vedic:
            log.info("━━━ VEDIC CONTENT ━━━")
            populate_vedic_content(args.force)
            log.info("")

        elapsed = time.perf_counter() - t0
        log.info("All done in %.1f seconds", elapsed)
        print_status(db, target_date)
    finally:
        db.close()


if __name__ == "__main__":
    main()
