import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    PROJECT_NAME: str = "CosmicGuide API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./cosmicguide.db")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-production")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

    # Gemini model — gemini-2.5-flash-lite is fast, free-tier friendly
    AI_MODEL: str = os.getenv("AI_MODEL", "gemini-2.5-flash-lite")

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    CORS_ORIGINS: list = ["*"]

    # Local Ollama instance for story generation
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://192.168.29.88:11434")
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "mistral:latest")

    # Remote content database (running on a different machine)
    # This DB holds pre-generated daily content (horoscopes, fortunes, stories, etc.)
    CONTENT_DB_URL: str = os.getenv("CONTENT_DB_URL", "")  # e.g. postgresql://user:pass@192.168.29.88:5432/cosmicguide_content
    CONTENT_DB_ENABLED: bool = os.getenv("CONTENT_DB_ENABLED", "false").lower() in ("true", "1", "yes")

    # Cron schedule for daily content generation (HH:MM in 24h format)
    DAILY_REFRESH_TIME: str = os.getenv("DAILY_REFRESH_TIME", "00:05")

    # Logging — set LOG_LEVEL env var on Render to control verbosity
    # Levels: DEBUG | INFO | WARNING | ERROR  (default: INFO)
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "DEBUG")


settings = Settings()
