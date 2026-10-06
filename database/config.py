import os
import logging
import sys


def _ensure_shared_importable() -> None:
    """Add the directory that contains ``shared/`` to sys.path.

    Works both in Docker (database/ lives at /app/database, shared/ at
    /app/shared) and in local dev (config.py lives in <repo>/database/).
    """
    here = os.path.dirname(os.path.abspath(__file__))
    for _ in range(5):
        # Match the directory that actually CONTAINS the shared package (its
        # llm_config module), not just any empty ``shared/`` dir that could
        # shadow the real one.
        if os.path.isfile(os.path.join(here, "shared", "llm_config.py")):
            if here not in sys.path:
                sys.path.insert(0, here)
            return
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent


_ensure_shared_importable()
from shared.llm_config import load_llm_config  # noqa: E402

# ── Database settings ─────────────────────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide",
)

# ── LLM connection config (shared single source of truth) ─────────────
# Same provider selection + fallback chain as the backend:
#   auto → Gemini (if key) → Ollama → iPhone LLM
_llm = load_llm_config()

AI_PROVIDER = _llm.ai_provider
AI_MODEL = _llm.ai_model
GEMINI_API_KEY = _llm.gemini_api_key
GEMINI_TIMEOUT = _llm.gemini_timeout

# Ollama — the stdlib http.client used here needs a bare host:port
OLLAMA_HOST = _llm.ollama_host
OLLAMA_MODEL = _llm.ollama_model
OLLAMA_TIMEOUT = _llm.ollama_timeout

# iPhone-hosted LLM (OpenAI-compatible endpoint)
IPHONE_LLM_BASE_URL = _llm.iphone_llm_base_url
IPHONE_LLM_MODEL = _llm.iphone_llm_model
IPHONE_LLM_API_KEY = _llm.iphone_llm_api_key
IPHONE_LLM_TIMEOUT = _llm.iphone_llm_timeout

# ── Logging ───────────────────────────────────────────────────────────────────

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()


def configure_logging() -> None:
    level = getattr(logging, LOG_LEVEL, logging.INFO)
    fmt = (
        "%(asctime)s | %(levelname)-8s | %(name)-35s | %(message)s"
        if level <= logging.DEBUG
        else "%(asctime)s | %(levelname)-8s | %(message)s"
    )
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(fmt, datefmt="%Y-%m-%d %H:%M:%S"))
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
