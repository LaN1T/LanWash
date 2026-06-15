from functools import lru_cache
from typing import List, Literal, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings validated at startup."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",  # Allow extra env vars without error
    )

    # Environment
    environment: Literal["development", "testing", "production"] = "development"
    debug: bool = False

    # Database
    database_url: str

    # Security
    jwt_secret_key: str
    initial_admin_password: str

    # CORS
    allowed_origins: str = ""

    # Firebase (optional for tests)
    firebase_credentials_path: str = ""

    # App Check (optional)
    app_check_enforced: bool = False

    # Error tracking (optional)
    sentry_dsn: str = ""

    # Redis
    redis_url: str = ""

    # Telegram Bot (optional)
    telegram_bot_token: str = ""

    # AI providers (optional)
    gemini_api_key: Optional[str] = None
    groq_api_key: Optional[str] = None
    ai_provider: Literal["gemini", "groq"] = "groq"

    # Monitoring
    prometheus_api_token: str = ""
    disable_rate_limit: bool = False

    @property
    def cors_origins(self) -> List[str]:
        raw = self.allowed_origins
        if not raw:
            if self.is_production:
                raise ValueError(
                    "ALLOWED_ORIGINS must be set in production"
                )
            return [
                "http://localhost:8080",
                "http://localhost:3000",
                "http://localhost:5000",
                "http://127.0.0.1:8080",
                "http://127.0.0.1:3000",
                "http://127.0.0.1:5000",
            ]
        return [o.strip() for o in raw.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def is_testing(self) -> bool:
        return self.environment == "testing"


@lru_cache
def get_settings() -> Settings:
    return Settings()
