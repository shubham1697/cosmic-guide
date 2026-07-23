"""
AI content generation service for CosmicGuide.

Uses Google Gemini (gemini-1.5-flash by default) to generate fresh daily
content.  Results are cached in the database to minimise API costs — each
piece of content is generated at most once per day per entity.

Fallback behaviour:
  If GEMINI_API_KEY is not set, or the API call fails, the caller receives
  None and should fall back to its own static/template data.
"""

import json
import re
import time
from datetime import date
from typing import Optional

import requests

from config import settings
from logger import get_logger
from services.ai_prompts import (
    SYSTEM_PROMPT,
    horoscope_prompt,
    batch_horoscope_prompt,
    fortune_prompt,
    batch_fortune_pool_prompt,
    tarot_prompt,
    batch_tarot_group_prompt,
    compatibility_prompt,
    batch_compatibility_pairs_prompt,
    daily_stories_prompt,
    kundli_personality_prompt,
    FORTUNE_TOPICS,
)

logger = get_logger(__name__)

# ── lazy-initialise the Gemini client so the app starts even without the key ──
_gemini_client = None


def _get_client():
    """Return a cached google.genai.Client, or None if the key is missing."""
    global _gemini_client
    if _gemini_client is not None:
        return _gemini_client
    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY is not set — AI generation disabled")
        return None
    try:
        from google import genai  # noqa: PLC0415
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
        logger.info("Gemini client initialised  model=%s", settings.AI_MODEL)
        return _gemini_client
    except ImportError:
        logger.error("google-genai is not installed. Run: pip install google-genai")
        return None


# ── lazy-initialise the iPhone LLM client (OpenAI-compatible endpoint) ────────
_iphone_client = None


def _get_iphone_client():
    """Return a cached OpenAI client pointed at the iPhone LLM, or None."""
    global _iphone_client
    if _iphone_client is not None:
        return _iphone_client
    try:
        from openai import OpenAI  # noqa: PLC0415
        _iphone_client = OpenAI(
            base_url=settings.IPHONE_LLM_BASE_URL,
            api_key=settings.IPHONE_LLM_API_KEY or "not-needed",
        )
        logger.info(
            "iPhone LLM client initialised  base_url=%s  model=%s",
            settings.IPHONE_LLM_BASE_URL, settings.IPHONE_LLM_MODEL,
        )
        return _iphone_client
    except ImportError:
        logger.error("openai is not installed. Run: pip install openai")
        return None


def _call_ai_iphone(user_prompt: str, expect_json: bool = True,
                    max_tokens: int = 2000) -> Optional[str]:
    """Call the iPhone-hosted LLM via its OpenAI-compatible API."""
    from logging_utils import log_external_api_call

    client = _get_iphone_client()
    if client is None:
        return None

    model = settings.IPHONE_LLM_MODEL
    endpoint_url = f"{settings.IPHONE_LLM_BASE_URL.rstrip('/')}/chat/completions"
    prompt_preview = user_prompt[:120].replace("\n", " ")

    logger.debug(
        "_call_ai_iphone  model=%s  max_tokens=%d  json=%s  prompt_preview='%s…'",
        model, max_tokens, expect_json, prompt_preview,
    )

    kwargs = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        "max_tokens": min(max_tokens, settings.IPHONE_LLM_MAX_TOKENS),
        "temperature": 0.85,
    }
    if expect_json:
        kwargs["response_format"] = {"type": "json_object"}

    t0 = time.perf_counter()
    try:
        response = client.chat.completions.create(
            timeout=settings.IPHONE_LLM_TIMEOUT,
            **kwargs,
        )
        elapsed_ms = (time.perf_counter() - t0) * 1000
        text = (response.choices[0].message.content or "").strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

        log_external_api_call(
            service_name="iPhoneLLM",
            endpoint=endpoint_url,
            method="POST",
            request_data={"model": model, "format": "json" if expect_json else "text"},
            response_text=text,
            elapsed_ms=elapsed_ms,
        )
        return text
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - t0) * 1000
        log_external_api_call(
            service_name="iPhoneLLM",
            endpoint=endpoint_url,
            method="POST",
            request_data={"model": model},
            elapsed_ms=elapsed_ms,
            error=exc,
        )
        return None


def _call_ai_ollama(user_prompt: str, expect_json: bool = True,
                    max_tokens: int = 2000) -> Optional[str]:
    """Call the local Ollama instance and return the raw text response."""
    from logging_utils import log_external_api_call
    
    base_url = settings.OLLAMA_BASE_URL.rstrip("/")
    model = settings.OLLAMA_MODEL
    endpoint = f"{base_url}/api/generate"
    prompt_preview = user_prompt[:120].replace("\n", " ")
    
    logger.debug(
        "_call_ai_ollama  model=%s  max_tokens=%d  json=%s  prompt_preview='%s…'",
        model, max_tokens, expect_json, prompt_preview,
    )
    
    payload = {
        "model": model,
        "system": SYSTEM_PROMPT[:100] + "…",  # Truncate for logging
        "prompt": prompt_preview,
        "stream": True,
        "options": {"num_predict": min(max_tokens, settings.OLLAMA_MAX_TOKENS), "temperature": 0.85},
    }
    if expect_json:
        payload["format"] = "json"

    t0 = time.perf_counter()
    try:
        resp = requests.post(
            endpoint,
            json=payload,
            timeout=settings.OLLAMA_TIMEOUT,
            stream=True,
        )
        resp.raise_for_status()
        parts = []
        for raw_line in resp.iter_lines():
            if not raw_line:
                continue
            chunk = json.loads(raw_line)
            parts.append(chunk.get("response", ""))
            if chunk.get("done"):
                break
        elapsed_ms = (time.perf_counter() - t0) * 1000
        text = "".join(parts).strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        
        log_external_api_call(
            service_name="Ollama",
            endpoint=endpoint,
            method="POST",
            request_data={"model": model, "format": "json" if expect_json else "text"},
            response_text=text,
            elapsed_ms=elapsed_ms,
            status_code=resp.status_code,
        )
        return text
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - t0) * 1000
        log_external_api_call(
            service_name="Ollama",
            endpoint=endpoint,
            method="POST",
            request_data=payload,
            elapsed_ms=elapsed_ms,
            error=exc,
        )
        return None


# ─────────────────────────────────────────────────────────────────────────────
#  Core completion helper
# ─────────────────────────────────────────────────────────────────────────────

def _call_ai(user_prompt: str, expect_json: bool = True,
             model: str = None, max_tokens: int = 2000) -> Optional[str]:
    """
    Send a generation request — Gemini if key is set, Ollama otherwise.

    Returns None on any error so callers can fall back gracefully.
    """
    from logging_utils import log_external_api_call

    provider = settings.AI_PROVIDER

    # Explicit backend selection via AI_PROVIDER
    if provider == "ollama":
        return _call_ai_ollama(user_prompt, expect_json=expect_json, max_tokens=max_tokens)
    if provider == "iphone":
        return _call_ai_iphone(user_prompt, expect_json=expect_json, max_tokens=max_tokens)

    client = _get_client()
    if client is None:
        if provider == "gemini":
            logger.warning("AI_PROVIDER=gemini but GEMINI_API_KEY is not set — no content generated")
            return None
        # auto mode with no Gemini key — fall back to local providers
        result = _call_ai_ollama(user_prompt, expect_json=expect_json, max_tokens=max_tokens)
        if result is None:
            result = _call_ai_iphone(user_prompt, expect_json=expect_json, max_tokens=max_tokens)
        return result

    from google import genai  # noqa: PLC0415
    from google.genai import types  # noqa: PLC0415

    effective_model = model or settings.AI_MODEL
    endpoint_url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{effective_model}:generateContent"
    )
    prompt_preview = user_prompt[:120].replace("\n", " ")
    logger.debug(
        "_call_ai  model=%s  max_tokens=%d  json=%s  prompt_preview='%s…'",
        effective_model, max_tokens, expect_json, prompt_preview,
    )

    config = types.GenerateContentConfig(
        system_instruction=SYSTEM_PROMPT,
        max_output_tokens=max_tokens,
        temperature=0.85,
        response_mime_type="application/json" if expect_json else "text/plain",
    )

    t0 = time.perf_counter()
    try:
        response = client.models.generate_content(
            model=effective_model,
            contents=user_prompt,
            config=config,
        )
        elapsed_ms = (time.perf_counter() - t0) * 1000
        text = response.text.strip()
        # Strip any accidental markdown code fences Gemini may add
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        
        log_external_api_call(
            service_name="Gemini",
            endpoint=endpoint_url,
            method="POST",
            request_data={"model": effective_model, "prompt_preview": prompt_preview},
            response_text=text,
            elapsed_ms=elapsed_ms,
        )
        return text
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - t0) * 1000
        log_external_api_call(
            service_name="Gemini",
            endpoint=endpoint_url,
            method="POST",
            request_data={"model": effective_model},
            elapsed_ms=elapsed_ms,
            error=exc,
        )
        return None


def _parse_json(raw: Optional[str]) -> Optional[dict]:
    """Safely parse a JSON string returned by the AI."""
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("Failed to parse AI JSON response: %s | raw=%s", exc, raw[:200])
        return None


def _parse_json_array(raw: Optional[str]) -> Optional[list]:
    """Safely parse a JSON array string returned by the AI."""
    if not raw:
        return None
    try:
        result = json.loads(raw)
        # Batch prompt might return {"stories": [...]} or just [...]
        if isinstance(result, list):
            return result
        # Try common wrapper keys
        for key in ("stories", "items", "data"):
            if key in result and isinstance(result[key], list):
                return result[key]
        return None
    except json.JSONDecodeError as exc:
        logger.error("Failed to parse AI JSON array: %s | raw=%s", exc, raw[:200])
        return None


# ─────────────────────────────────────────────────────────────────────────────
#  Horoscope generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_daily_horoscope(zodiac_sign: str,
                              for_date: date = None) -> Optional[dict]:
    """
    Generate an AI horoscope for one zodiac sign on the given date.

    Returns a dict matching the Horoscope DB model fields, or None on failure.
    """
    if for_date is None:
        for_date = date.today()

    logger.debug("generate_daily_horoscope  sign=%s  date=%s", zodiac_sign, for_date)
    prompt = horoscope_prompt(zodiac_sign, for_date)
    raw = _call_ai(prompt, expect_json=True, max_tokens=800)
    data = _parse_json(raw)

    if not data:
        logger.warning("generate_daily_horoscope  FAILED  sign=%s  date=%s", zodiac_sign, for_date)
        return None

    score = int(data.get("overall_score", 75))
    logger.info(
        "generate_daily_horoscope  OK  sign=%s  date=%s  score=%d  mood=%s",
        zodiac_sign, for_date, score, data.get("mood", "?"),
    )
    # Normalise and validate required fields
    return {
        "zodiac_sign":   zodiac_sign,
        "date":          for_date.isoformat(),
        "general":       data.get("general", ""),
        "love":          data.get("love", ""),
        "career":        data.get("career", ""),
        "health":        data.get("health", ""),
        "overall_score": score,
        "lucky_number":  str(data.get("lucky_number", "7")),
        "lucky_color":   data.get("lucky_color", "Violet"),
        "mood":          data.get("mood", "Thoughtful"),
    }


def generate_all_horoscopes(for_date: date = None) -> Optional[dict]:
    """
    Generate horoscopes for all 12 signs in a single API call (batch mode).

    Returns a dict keyed by sign name, or None on failure.
    Each value is a horoscope dict matching the DB model fields.
    """
    if for_date is None:
        for_date = date.today()

    logger.debug("generate_all_horoscopes  date=%s", for_date)
    prompt = batch_horoscope_prompt(for_date)
    raw = _call_ai(prompt, expect_json=True, max_tokens=4000)
    data = _parse_json(raw)

    if not data or not isinstance(data, dict):
        logger.warning("generate_all_horoscopes  FAILED  date=%s", for_date)
        return None

    result = {}
    for sign, hdata in data.items():
        if not isinstance(hdata, dict):
            continue
        result[sign] = {
            "zodiac_sign":   sign,
            "date":          for_date.isoformat(),
            "general":       hdata.get("general", ""),
            "love":          hdata.get("love", ""),
            "career":        hdata.get("career", ""),
            "health":        hdata.get("health", ""),
            "overall_score": int(hdata.get("overall_score", 75)),
            "lucky_number":  str(hdata.get("lucky_number", "7")),
            "lucky_color":   hdata.get("lucky_color", "Violet"),
            "mood":          hdata.get("mood", "Thoughtful"),
        }
    if result:
        logger.info("generate_all_horoscopes  OK  date=%s  signs=%d", for_date, len(result))
    return result if result else None


# ─────────────────────────────────────────────────────────────────────────────
#  Fortune generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_fortune(zodiac_sign: str, topic: str, mood: str) -> Optional[str]:
    """
    Generate a personalised fortune as plain text.

    Returns the fortune string or None on failure.
    """
    logger.debug("generate_fortune  sign=%s  topic=%s  mood=%s", zodiac_sign, topic, mood)
    result = _call_ai(fortune_prompt(zodiac_sign, topic, mood), expect_json=False, max_tokens=200)
    if result:
        logger.info("generate_fortune  OK  sign=%s  topic=%s  len=%d", zodiac_sign, topic, len(result))
    else:
        logger.warning("generate_fortune  FAILED  sign=%s  topic=%s", zodiac_sign, topic)
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  Tarot interpretation
# ─────────────────────────────────────────────────────────────────────────────

def generate_tarot_interpretation(card_name: str, card_number: str,
                                   is_reversed: bool,
                                   zodiac_sign: str = None) -> Optional[str]:
    """
    Generate a contextual tarot interpretation as plain text.

    Returns the interpretation string or None on failure.
    """
    logger.debug(
        "generate_tarot_interpretation  card=%s  reversed=%s  sign=%s",
        card_name, is_reversed, zodiac_sign,
    )
    result = _call_ai(
        tarot_prompt(card_name, card_number, is_reversed, zodiac_sign),
        expect_json=False, max_tokens=300,
    )
    if result:
        logger.info("generate_tarot_interpretation  OK  card=%s  len=%d", card_name, len(result))
    else:
        logger.warning("generate_tarot_interpretation  FAILED  card=%s", card_name)
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  Compatibility analysis
# ─────────────────────────────────────────────────────────────────────────────

def generate_compatibility(sign1: str, sign2: str, base_score: int) -> Optional[dict]:
    """
    Generate a full AI compatibility analysis for two signs.

    Returns dict with description / love_advice / strengths_together / challenges,
    or None on failure.
    """
    logger.debug("generate_compatibility  sign1=%s  sign2=%s  base_score=%d", sign1, sign2, base_score)
    raw = _call_ai(compatibility_prompt(sign1, sign2, base_score), expect_json=True, max_tokens=600)
    data = _parse_json(raw)

    if not data:
        logger.warning("generate_compatibility  FAILED  %s x %s", sign1, sign2)
        return None

    logger.info("generate_compatibility  OK  %s x %s", sign1, sign2)
    return {
        "description":        data.get("description", ""),
        "love_advice":        data.get("love_advice", ""),
        "strengths_together": data.get("strengths_together", ""),
        "challenges":         data.get("challenges", ""),
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Cosmic stories
# ─────────────────────────────────────────────────────────────────────────────

def generate_daily_stories(for_date: date = None, count: int = 5) -> Optional[list]:
    """
    Generate a batch of daily cosmic stories.

    Returns a list of story dicts or None on failure.
    Each dict has: title, summary, content, category, read_time, tags, author.
    """
    if for_date is None:
        for_date = date.today()

    prompt = daily_stories_prompt(for_date, count)
    # Stories are an array; use json_object mode and wrap manually
    raw = _call_ai(prompt, expect_json=True, max_tokens=4000)
    stories = _parse_json_array(raw)

    if not stories:
        # Fallback: try parsing as top-level object with a "stories" key
        data = _parse_json(raw)
        if data:
            for key in ("stories", "items", "articles", "data"):
                if key in data and isinstance(data[key], list):
                    stories = data[key]
                    break

    if not stories:
        return None

    # Ensure required fields on each story
    cleaned = []
    for s in stories:
        if not isinstance(s, dict):
            continue
        cleaned.append({
            "title":     s.get("title", "Cosmic Insight"),
            "summary":   s.get("summary", ""),
            "content":   s.get("content", ""),
            "category":  s.get("category", "Planetary"),
            "read_time": s.get("read_time", "4 min"),
            "tags":      s.get("tags", []),
            "author":    s.get("author", "CosmicGuide"),
        })
    return cleaned if cleaned else None


# ─────────────────────────────────────────────────────────────────────────────
#  Kundli / birth chart personality reading
# ─────────────────────────────────────────────────────────────────────────────

def generate_kundli_reading(zodiac_sign: str, birth_date: str,
                             birth_time: str = None,
                             birth_place: str = None) -> Optional[dict]:
    """
    Generate a personalised birth chart personality reading.

    Returns dict with personality_summary / life_path / strengths /
    growth_areas / cosmic_purpose, or None on failure.
    """
    prompt = kundli_personality_prompt(zodiac_sign, birth_date, birth_time, birth_place)
    raw = _call_ai(prompt, expect_json=True, max_tokens=800)
    data = _parse_json(raw)

    if not data:
        return None

    return {
        "personality_summary": data.get("personality_summary", ""),
        "life_path":           data.get("life_path", ""),
        "strengths":           data.get("strengths", []),
        "growth_areas":        data.get("growth_areas", []),
        "cosmic_purpose":      data.get("cosmic_purpose", ""),
    }


# ─────────────────────────────────────────────────────────────────────────────
#  Fortune pool generation  (batch — 6 signs per call)
# ─────────────────────────────────────────────────────────────────────────────

def generate_fortune_pool(signs: list, for_date: date = None) -> Optional[dict]:
    """
    Generate a pool of 3 fortunes for each sign × topic combination.

    signs: a list of 6 zodiac sign names (call twice for all 12).
    Returns dict: { sign: { topic: ["f1","f2","f3"], ... }, ... } or None.
    """
    if for_date is None:
        for_date = date.today()

    logger.debug("generate_fortune_pool  signs=%s  date=%s", signs, for_date)
    prompt = batch_fortune_pool_prompt(signs, for_date)
    raw = _call_ai(prompt, expect_json=True, max_tokens=8000)
    data = _parse_json(raw)

    if not data or not isinstance(data, dict):
        logger.warning("generate_fortune_pool  FAILED  signs=%s", signs)
        return None

    # Validate and normalise
    result = {}
    for sign in signs:
        sign_data = data.get(sign)
        if not isinstance(sign_data, dict):
            logger.warning("generate_fortune_pool  missing sign=%s", sign)
            continue
        result[sign] = {}
        for topic in FORTUNE_TOPICS:
            pool = sign_data.get(topic)
            if isinstance(pool, list) and pool:
                result[sign][topic] = [str(f) for f in pool[:3]]
            else:
                logger.warning("generate_fortune_pool  missing topic=%s for sign=%s", topic, sign)

    if result:
        logger.info("generate_fortune_pool  OK  signs=%d", len(result))
    return result if result else None


# ─────────────────────────────────────────────────────────────────────────────
#  Batch compatibility generation  (~20 pairs per call)
# ─────────────────────────────────────────────────────────────────────────────

def generate_batch_compatibility(pairs: list) -> Optional[list]:
    """
    Generate compatibility analyses for a batch of sign pairs.

    pairs: list of dicts {"sign1": str, "sign2": str, "score": int}
    Returns list of dicts with sign1, sign2, description, love_advice,
    strengths_together, challenges — or None on failure.
    """
    if not pairs:
        return None

    logger.debug("generate_batch_compatibility  pairs=%d", len(pairs))
    prompt = batch_compatibility_pairs_prompt(pairs)
    raw = _call_ai(prompt, expect_json=True, max_tokens=8000)
    items = _parse_json_array(raw)

    if not items:
        data = _parse_json(raw)
        if data:
            for key in ("compatibility", "pairs", "results", "data"):
                if key in data and isinstance(data[key], list):
                    items = data[key]
                    break

    if not items:
        logger.warning("generate_batch_compatibility  FAILED  pairs=%d", len(pairs))
        return None

    cleaned = []
    for item in items:
        if not isinstance(item, dict):
            continue
        cleaned.append({
            "sign1":             item.get("sign1", ""),
            "sign2":             item.get("sign2", ""),
            "description":       item.get("description", ""),
            "love_advice":       item.get("love_advice", ""),
            "strengths_together":item.get("strengths_together", ""),
            "challenges":        item.get("challenges", ""),
        })
    logger.info("generate_batch_compatibility  OK  returned=%d", len(cleaned))
    return cleaned if cleaned else None


# ─────────────────────────────────────────────────────────────────────────────
#  Batch tarot interpretation generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_batch_tarot_interpretations(cards: list) -> Optional[list]:
    """
    Generate AI-quality upright + reversed interpretations for a batch of cards.

    cards: list of dicts {"name": str, "number": str, "meaning": str}
    Returns list of dicts with name, upright_interpretation, reversed_interpretation.
    """
    if not cards:
        return None

    logger.debug("generate_batch_tarot_interpretations  cards=%d", len(cards))
    prompt = batch_tarot_group_prompt(cards)
    raw = _call_ai(prompt, expect_json=True, max_tokens=8000)
    items = _parse_json_array(raw)

    if not items:
        data = _parse_json(raw)
        if data:
            for key in ("cards", "tarot", "items", "data"):
                if key in data and isinstance(data[key], list):
                    items = data[key]
                    break

    if not items:
        logger.warning("generate_batch_tarot_interpretations  FAILED  cards=%d", len(cards))
        return None

    cleaned = []
    for item in items:
        if not isinstance(item, dict):
            continue
        cleaned.append({
            "name":                   item.get("name", ""),
            "upright_interpretation": item.get("upright_interpretation", ""),
            "reversed_interpretation":item.get("reversed_interpretation", ""),
        })
    logger.info("generate_batch_tarot_interpretations  OK  returned=%d", len(cleaned))
    return cleaned if cleaned else None


# ─────────────────────────────────────────────────────────────────────────────
#  Health check
# ─────────────────────────────────────────────────────────────────────────────

def ai_available() -> bool:
    """Returns True if Gemini key is set, or a local LLM backend is reachable."""
    if _get_client() is not None:
        return True
    # Check Ollama
    try:
        resp = requests.get(
            f"{settings.OLLAMA_BASE_URL.rstrip('/')}/api/tags",
            timeout=5,
        )
        if resp.status_code == 200:
            return True
    except Exception:
        pass
    # Check iPhone LLM (OpenAI-compatible /models endpoint)
    try:
        resp = requests.get(
            f"{settings.IPHONE_LLM_BASE_URL.rstrip('/')}/models",
            timeout=5,
        )
        return resp.status_code == 200
    except Exception:
        return False
