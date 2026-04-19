from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    debug: bool = False

    database_url: str

    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_hours: int = 24

    cors_origins: str = "http://localhost:7474,http://localhost:7575"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    anthropic_api_key: str = ""
    claude_chat_model: str = "claude-sonnet-4-6"
    claude_effort: str = "low"

    qubrid_api_key: str = ""
    qubrid_base_url: str = "https://platform.qubrid.com/api/v1/qubridai"
    qubrid_whisper_model: str = "openai/whisper-large-v3"


@lru_cache
def get_settings() -> Settings:
    return Settings()
