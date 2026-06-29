from functools import lru_cache
from typing import List, Literal, Optional

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings validated at startup."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",  # Allow extra env vars without error
    )

    @field_validator("jwt_secret_key", mode="after")
    @classmethod
    def _validate_jwt_secret_key(cls, value: str) -> str:
        if len(value) < 43:
            raise ValueError(
                "jwt_secret_key must be at least 43 characters (256 bits url-safe)"
            )
        lower = value.lower()
        exact_placeholders = {
            "change_me_min_32_chars_use_secrets_token_urlsafe",
            "change_me_to_something_secure",
            "replace_with_43_plus_random_urlsafe_chars",
            "placeholder",
        }
        if lower in exact_placeholders:
            raise ValueError("jwt_secret_key looks like a placeholder")
        return value

    # Environment
    environment: Literal["development", "testing", "production"] = "development"
    debug: bool = False

    # Database
    database_url: str

    # Security
    jwt_secret_key: str
    jwt_refresh_token_expire_days: int = 7
    jwt_issuer: str = "lanwash"
    jwt_audience: str = "lanwash-api"
    initial_admin_password: str

    # CORS
    allowed_origins: str = ""

    # Firebase (optional for tests)
    firebase_credentials_path: str = ""

    # App Check (optional)
    app_check_enforced: bool = False
    firebase_app_id: str = ""

    # Error tracking (optional)
    sentry_dsn: str = ""
    sentry_traces_sample_rate: float = 0.1

    # Redis
    redis_url: str = ""

    # Telegram Bot (optional)
    telegram_bot_token: str = ""
    telegram_webhook_secret: str = ""
    telegram_mini_app_url: str = ""

    # Firebase / FCM
    firebase_project_id: str = ""
    firebase_private_key_id: str = ""
    firebase_private_key: str = ""
    firebase_client_email: str = ""
    firebase_client_id: str = ""
    firebase_auth_uri: str = "https://accounts.google.com/o/oauth2/auth"
    firebase_token_uri: str = "https://oauth2.googleapis.com/token"
    firebase_auth_provider_x509_cert_url: str = "https://www.googleapis.com/oauth2/v1/certs"
    firebase_client_x509_cert_url: str = ""

    # AI providers (optional)
    gemini_api_key: Optional[str] = None
    groq_api_key: Optional[str] = None
    ai_provider: Literal["gemini", "groq"] = "groq"

    # Monitoring
    prometheus_api_token: str = ""
    disable_rate_limit: bool = False

    # Reports
    washer_weekly_target_minutes: int = 40 * 60

    @property
    def cors_origins(self) -> List[str]:
        raw = self.allowed_origins
        if not raw:
            if self.is_production:
                raise ValueError("ALLOWED_ORIGINS must be set in production")
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
