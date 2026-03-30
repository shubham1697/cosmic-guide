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


settings = Settings()
