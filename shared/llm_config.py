"""
Single source of truth for LLM connection configuration.

Both the backend API ([backend/config.py]) and the DB populator
([database/config.py]) import from here so provider selection, model names,
hosts, keys, and timeouts never drift between the two services.

This module is **pure standard library** — no third-party imports — so it can
be copied into the slim populate image without adding dependencies.

Environment variables always win; the constants below are only fallbacks, and
they are the one place to change a default connection value.
"""

import os
from dataclasses import dataclass

# ── Default connection values (the single place to change fallbacks) ──────────
DEFAULT_AI_PROVIDER = "auto"
DEFAULT_AI_MODEL = "gemini-2.5-flash-lite"
# Gemini is a hosted API, so it needs nothing like the local models' budget.
DEFAULT_GEMINI_TIMEOUT = 120

DEFAULT_OLLAMA_BASE_URL = "http://192.168.29.159:11434"
DEFAULT_OLLAMA_MODEL = "gemma3:4b"
DEFAULT_OLLAMA_TIMEOUT = 360
DEFAULT_OLLAMA_MAX_TOKENS = 2000

DEFAULT_IPHONE_LLM_BASE_URL = "http://192.168.29.162:8080/v1"
DEFAULT_IPHONE_LLM_MODEL = "base"
DEFAULT_IPHONE_LLM_API_KEY = "not-needed"
DEFAULT_IPHONE_LLM_TIMEOUT = 360
DEFAULT_IPHONE_LLM_MAX_TOKENS = 2000


@dataclass(frozen=True)
class LLMConfig:
    """Resolved LLM connection settings shared by every service."""

    ai_provider: str
    ai_model: str
    gemini_api_key: str
    gemini_timeout: int

    ollama_base_url: str   # full URL, e.g. http://host:11434  (requests / aiohttp)
    ollama_host: str       # bare host:port                    (stdlib http.client)
    ollama_model: str
    ollama_timeout: int
    ollama_max_tokens: int

    iphone_llm_base_url: str
    iphone_llm_model: str
    iphone_llm_api_key: str
    iphone_llm_timeout: int
    iphone_llm_max_tokens: int


def _host_from_url(base_url: str) -> str:
    """Strip scheme/path → bare ``host:port`` for stdlib http.client."""
    return base_url.split("://", 1)[-1].strip("/")


def _int_env(name: str, default: int) -> int:
    """Read an int env var, falling back to ``default`` on missing/invalid."""
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def load_llm_config() -> LLMConfig:
    """Build an :class:`LLMConfig` from the current environment.

    Env vars override the module defaults.  ``OLLAMA_HOST`` (bare host:port) is
    honored for backward compatibility but ``OLLAMA_BASE_URL`` is preferred.
    """
    ollama_base_url = os.getenv("OLLAMA_BASE_URL", DEFAULT_OLLAMA_BASE_URL)
    ollama_host = os.getenv("OLLAMA_HOST", "").strip() or _host_from_url(ollama_base_url)

    return LLMConfig(
        ai_provider=os.getenv("AI_PROVIDER", DEFAULT_AI_PROVIDER).lower(),
        ai_model=os.getenv("AI_MODEL", DEFAULT_AI_MODEL),
        gemini_api_key=os.getenv("GEMINI_API_KEY", ""),
        gemini_timeout=_int_env("GEMINI_TIMEOUT", DEFAULT_GEMINI_TIMEOUT),
        ollama_base_url=ollama_base_url,
        ollama_host=ollama_host,
        ollama_model=os.getenv("OLLAMA_MODEL", DEFAULT_OLLAMA_MODEL),
        ollama_timeout=_int_env("OLLAMA_TIMEOUT", DEFAULT_OLLAMA_TIMEOUT),
        ollama_max_tokens=_int_env("OLLAMA_MAX_TOKENS", DEFAULT_OLLAMA_MAX_TOKENS),
        iphone_llm_base_url=os.getenv("IPHONE_LLM_BASE_URL", DEFAULT_IPHONE_LLM_BASE_URL),
        iphone_llm_model=os.getenv("IPHONE_LLM_MODEL", DEFAULT_IPHONE_LLM_MODEL),
        iphone_llm_api_key=os.getenv("IPHONE_LLM_API_KEY", DEFAULT_IPHONE_LLM_API_KEY),
        iphone_llm_timeout=_int_env("IPHONE_LLM_TIMEOUT", DEFAULT_IPHONE_LLM_TIMEOUT),
        iphone_llm_max_tokens=_int_env("IPHONE_LLM_MAX_TOKENS", DEFAULT_IPHONE_LLM_MAX_TOKENS),
    )
