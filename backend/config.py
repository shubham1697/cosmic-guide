import os
import sys
from dotenv import load_dotenv

load_dotenv()


def _ensure_shared_importable() -> None:
    """Add the directory that contains ``shared/`` to sys.path.

    Works both in Docker (backend/ is flattened into /app, so shared/ sits
    beside this file) and in local dev (config.py lives in <repo>/backend/).
    """
    here = os.path.dirname(os.path.abspath(__file__))
    for _ in range(5):
        if os.path.isdir(os.path.join(here, "shared")):
            if here not in sys.path:
                sys.path.insert(0, here)
            return
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent


_ensure_shared_importable()
from shared.llm_config import load_llm_config  # noqa: E402

_llm = load_llm_config()


class Settings:
    PROJECT_NAME: str = "CosmicGuide API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-production")
    GEMINI_API_KEY: str = _llm.gemini_api_key

    # Gemini model — gemini-2.5-flash-lite is fast, free-tier friendly
    AI_MODEL: str = _llm.ai_model

    # Preferred LLM backend for content generation.
    #   auto   → Gemini (if key set) → Ollama → iPhone LLM
    #   gemini → force Google Gemini
    #   ollama → force local Ollama
    #   iphone → force iPhone-hosted LLM
    AI_PROVIDER: str = _llm.ai_provider

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    CORS_ORIGINS: list = ["*"]

    # Local Ollama instance for content generation
    OLLAMA_BASE_URL: str = _llm.ollama_base_url
    OLLAMA_MODEL: str = _llm.ollama_model
    OLLAMA_TIMEOUT: int = _llm.ollama_timeout
    OLLAMA_MAX_TOKENS: int = _llm.ollama_max_tokens

    # iPhone-hosted LLM — OpenAI-compatible endpoint (see iphone_llm/iphone-llm.py)
    IPHONE_LLM_BASE_URL: str = _llm.iphone_llm_base_url
    IPHONE_LLM_MODEL: str = _llm.iphone_llm_model
    IPHONE_LLM_API_KEY: str = _llm.iphone_llm_api_key
    IPHONE_LLM_TIMEOUT: int = _llm.iphone_llm_timeout
    IPHONE_LLM_MAX_TOKENS: int = _llm.iphone_llm_max_tokens

    # ── Push notifications (Firebase Cloud Messaging) ──
    # Absolute path to a Firebase service-account JSON. When unset, notification
    # endpoints still work but sends are no-ops (safe for local dev / CI).
    FCM_CREDENTIALS_PATH: str = os.getenv("FCM_CREDENTIALS_PATH", "")
    # Hour of day (0-23, server/container timezone) to send the daily reminder.
    DAILY_REMINDER_HOUR: int = int(os.getenv("DAILY_REMINDER_HOUR", "8"))
    # Master switch for the in-process scheduler (turn off in tests/multi-worker).
    ENABLE_SCHEDULER: bool = os.getenv("ENABLE_SCHEDULER", "true").lower() == "true"

    # Logging — set LOG_LEVEL env var on Render to control verbosity
    # Levels: DEBUG | INFO | WARNING | ERROR  (default: INFO)
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "DEBUG")


settings = Settings()
