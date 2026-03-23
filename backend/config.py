import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    PROJECT_NAME: str = "CosmicGuide API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./cosmicguide.db")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-production")
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    CORS_ORIGINS: list = ["*"]


settings = Settings()
