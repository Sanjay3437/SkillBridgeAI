"""Application configuration loaded from environment variables."""

from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "postgresql+asyncpg://skillbridge:skillbridge@localhost:5432/skillbridge"
    database_url_sync: str = (
        "postgresql+psycopg://skillbridge:skillbridge@localhost:5432/skillbridge"
    )

    # Auth
    jwt_secret: str = "change-me-to-a-long-random-string"
    jwt_algorithm: str = "HS256"
    jwt_access_ttl_minutes: int = 15
    jwt_refresh_ttl_days: int = 30

    # AI
    llm_provider: str = "mock"
    llm_api_key: str = ""
    llm_model: str = "gpt-4o-mini"
    llm_timeout_seconds: int = 60

    embeddings_enabled: bool = False
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    embedding_match_threshold: float = 0.82

    # Storage
    storage_backend: str = "local"
    storage_local_dir: str = "./uploads"
    storage_bucket: str = ""
    storage_endpoint: str = ""
    storage_access_key: str = ""
    storage_secret_key: str = ""

    # App
    app_env: str = "development"
    cors_allowed_origins: str = "http://localhost:3000,http://localhost:8080"
    max_resume_bytes: int = 5 * 1024 * 1024
    max_resume_pages: int = 5

    @field_validator("jwt_secret")
    @classmethod
    def warn_weak_secret(cls, value: str) -> str:
        if len(value) < 16:
            raise ValueError("JWT_SECRET must be at least 16 characters")
        return value

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        return self.app_env.lower() == "production"

    @property
    def storage_path(self) -> Path:
        return Path(self.storage_local_dir).resolve()


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
