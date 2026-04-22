"""
Story generation service for CosmicGuide.

Uses a local Ollama instance (mistral:latest) to generate astrology stories.
Generated stories are:
  1. Persisted in the `stories` DB table.
  2. Written back to data/mock/stories_data.py so a static copy is always available.
"""

import json
import os
import re
import urllib.request
import urllib.error
from datetime import datetime, timezone
from typing import Optional

from config import settings
from logger import get_logger

logger = get_logger(__name__)

_MOCK_FILE = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "data", "mock", "stories_data.py")
)

# ── Story categories & generation prompts ────────────────────────────────────

STORY_CATEGORIES = [
    "Planetary",
    "Weekly",
    "Relationships",
    "Rituals",
    "Career",
    "Spiritual",
]

_PROMPTS: dict[str, str] = {
    "Planetary": (
        "You are an astrology writer. Write an engaging article about a significant "
        "current planetary event (e.g. a retrograde, conjunction, or transit) and how "
        "it affects people. The article should be practical and uplifting, 300-400 words."
    ),
    "Weekly": (
        "You are an astrology writer. Write a weekly cosmic forecast article covering "
        "what the stars have in store for all 12 zodiac signs this week. "
        "Keep it positive, insightful, and actionable, 300-400 words."
    ),
    "Relationships": (
        "You are an astrology writer. Write an article exploring how astrology shapes "
        "romantic compatibility, attachment styles, or communication between signs. "
        "Make it relatable and practical, 300-400 words."
    ),
    "Rituals": (
        "You are an astrology writer. Write an article describing a powerful moon ritual "
        "or cosmic practice tailored to a recent lunar event (new moon, full moon, eclipse). "
        "Include step-by-step guidance, 300-400 words."
    ),
    "Career": (
        "You are an astrology writer. Write an article about using astrology to guide "
        "career decisions, professional strengths by sign, or how current planetary "
        "energy affects ambition and work. Keep it empowering, 300-400 words."
    ),
    "Spiritual": (
        "You are an astrology writer. Write an article about spiritual growth, intuition, "
        "or mindfulness through an astrological lens. Connect cosmic cycles to inner "
        "development and everyday awareness, 300-400 words."
    ),
}

_JSON_INSTRUCTION = (
    "\n\nRespond ONLY with a valid JSON object — no markdown fences, no extra text.\n"
    "Schema:\n"
    '{"title": "...", "summary": "one-sentence teaser under 20 words", '
    '"content": "full article text", "read_time": "X min"}'
)


# ── Ollama helper ─────────────────────────────────────────────────────────────

def _call_ollama(prompt: str, timeout: int = 600) -> Optional[str]:
    """
    Call the local Ollama /api/chat endpoint with mistral and return the
    assistant's reply text, or None on any error.
    """
    payload = json.dumps({
        "model": settings.OLLAMA_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
        "options": {"num_predict": 600, "temperature": 0.8},
    }).encode()

    url = f"{settings.OLLAMA_BASE_URL}/api/chat"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=3600) as resp:
            data = json.loads(resp.read())
            return data["message"]["content"]
    except urllib.error.URLError as exc:
        logger.error("Ollama unreachable (%s) — check OLLAMA_BASE_URL=%s", exc, settings.OLLAMA_BASE_URL)
        return None
    except Exception as exc:
        logger.error("Ollama call failed: %s", exc)
        return None


def _parse_story_json(raw: str) -> Optional[dict]:
    """Extract the JSON object from the model's reply."""
    logger.debug("Ollama raw response:\n%s", raw)

    # Strip markdown code fences
    text = re.sub(r"```(?:json)?", "", raw).strip()
    text = re.sub(r"```\s*$", "", text).strip()

    # Find the first {...} block
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        logger.warning("No JSON object found in Ollama response. Raw (first 500 chars):\n%s", raw[:500])
        return None

    json_str = match.group()

    # Fix literal newlines inside JSON string values (Ollama often emits these)
    # Replace unescaped newlines/tabs that appear inside quoted strings
    json_str = _fix_literal_newlines(json_str)

    try:
        return json.loads(json_str)
    except json.JSONDecodeError as exc:
        logger.warning("JSON parse failed: %s\nExtracted text:\n%s", exc, json_str[:500])
        return _extract_fields_fallback(raw)


def _fix_literal_newlines(s: str) -> str:
    """
    Replace literal newline/tab characters that appear inside JSON string values
    with their escaped equivalents, so json.loads() can parse them.
    """
    result = []
    in_string = False
    escaped = False
    for ch in s:
        if escaped:
            result.append(ch)
            escaped = False
        elif ch == "\\" and in_string:
            result.append(ch)
            escaped = True
        elif ch == '"':
            result.append(ch)
            in_string = not in_string
        elif in_string and ch == "\n":
            result.append("\\n")
        elif in_string and ch == "\r":
            result.append("\\r")
        elif in_string and ch == "\t":
            result.append("\\t")
        else:
            result.append(ch)
    return "".join(result)


def _extract_fields_fallback(raw: str) -> Optional[dict]:
    """Last-resort field extraction using regex when JSON parsing fails."""
    def _grab(key: str) -> str:
        m = re.search(rf'"{key}"\s*:\s*"(.*?)"(?=\s*[,}}])', raw, re.DOTALL)
        return m.group(1).replace('\\"', '"') if m else ""

    title = _grab("title")
    if not title:
        logger.warning("_extract_fields_fallback: could not find title — giving up")
        return None

    return {
        "title": title,
        "summary": _grab("summary"),
        "content": _grab("content"),
        "read_time": _grab("read_time") or "5 min",
    }


# ── Story generation ──────────────────────────────────────────────────────────

def generate_story(category: str) -> Optional[dict]:
    """
    Generate a single story for the given category using Ollama.
    Returns a dict with keys: title, summary, content, category, read_time.
    """
    base_prompt = _PROMPTS.get(category, _PROMPTS["Spiritual"])
    full_prompt = base_prompt + _JSON_INSTRUCTION

    logger.info("generate_story  category=%s  model=%s", category, settings.OLLAMA_MODEL)
    raw = _call_ollama(full_prompt)
    if raw is None:
        return None

    parsed = _parse_story_json(raw)
    if parsed is None:
        return None

    # Normalise & fill defaults
    return {
        "title": str(parsed.get("title", f"{category} Cosmic Insight")).strip(),
        "summary": str(parsed.get("summary", "")).strip(),
        "content": str(parsed.get("content", "")).strip(),
        "category": category,
        "read_time": str(parsed.get("read_time", "5 min")).strip(),
        "author": "CosmicGuide AI",
    }


# ── DB seeding ────────────────────────────────────────────────────────────────

def seed_stories_db(db) -> int:
    """
    Generate one story per category and persist them in the DB.
    Also writes the results to data/mock/stories_data.py.
    Returns the number of stories successfully created.
    """
    from db.models import Story as StoryModel  # noqa: PLC0415

    created: list[StoryModel] = []
    raw_stories: list[dict] = []

    for category in STORY_CATEGORIES:
        story_data = generate_story(category)
        if story_data is None:
            logger.warning("seed_stories_db  skipped category=%s (generation failed)", category)
            continue

        row = StoryModel(
            title=story_data["title"],
            summary=story_data["summary"],
            content=story_data["content"],
            category=story_data["category"],
            read_time=story_data["read_time"],
            author=story_data["author"],
            published_at=datetime.now(timezone.utc),
            is_featured=False,
        )
        db.add(row)
        db.flush()  # populate row.id before commit
        created.append(row)

        raw_stories.append({
            "id": row.id,
            "title": story_data["title"],
            "summary": story_data["summary"],
            "content": story_data["content"],
            "category": story_data["category"],
            "read_time": story_data["read_time"],
            "author": story_data["author"],
        })

    if created:
        db.commit()
        logger.info("seed_stories_db  committed=%d stories", len(created))
        _write_mock_file(raw_stories)
    else:
        db.rollback()

    return len(created)


# ── Mock file writer ──────────────────────────────────────────────────────────

def _write_mock_file(stories: list[dict]) -> None:
    """Overwrite data/mock/stories_data.py with the latest generated stories."""
    lines = [
        '"""Auto-generated stories — do not edit manually.',
        "Re-generate via POST /api/v1/stories/generate",
        '"""',
        "",
        "STORIES = [",
    ]

    for s in stories:
        lines.append("    {")
        lines.append(f'        "id": {s["id"]},')
        lines.append(f'        "title": {json.dumps(s["title"])},')
        lines.append(f'        "summary": {json.dumps(s["summary"])},')
        lines.append(f'        "category": {json.dumps(s["category"])},')
        lines.append(f'        "read_time": {json.dumps(s["read_time"])},')
        lines.append(f'        "author": {json.dumps(s["author"])},')
        lines.append(f'        "content": {json.dumps(s["content"])},')
        lines.append("    },")

    lines.append("]")
    lines.append("")

    try:
        os.makedirs(os.path.dirname(_MOCK_FILE), exist_ok=True)
        with open(_MOCK_FILE, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
        logger.info("_write_mock_file  wrote %d stories → %s", len(stories), _MOCK_FILE)
    except OSError as exc:
        logger.error("_write_mock_file  failed: %s", exc)
