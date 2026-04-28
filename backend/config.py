import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    PROJECT_NAME: str = "CosmicGuide API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://cosmicguide:cosmicguide@localhost:5432/cosmicguide")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-production")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

    # Gemini model — gemini-2.5-flash-lite is fast, free-tier friendly
    AI_MODEL: str = os.getenv("AI_MODEL", "gemini-2.5-flash-lite")

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    CORS_ORIGINS: list = ["*"]

    # Local Ollama instance for content generation
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://192.168.29.159:11434")
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "gemma3:4b")
    OLLAMA_TIMEOUT: int = int(os.getenv("OLLAMA_TIMEOUT", "360"))
    OLLAMA_MAX_TOKENS: int = int(os.getenv("OLLAMA_MAX_TOKENS", "2000"))

    # Logging — set LOG_LEVEL env var on Render to control verbosity
    # Levels: DEBUG | INFO | WARNING | ERROR  (default: INFO)
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "DEBUG")


settings = Settings()
