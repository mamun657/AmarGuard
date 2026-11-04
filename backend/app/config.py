from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_PATH = Path(__file__).resolve().parents[1] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_ENV_PATH) if _ENV_PATH.exists() else ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    model_api_key: str = ""
    meta_base_url: str = "https://api.meta.ai/v1"
    meta_chat_model: str = "muse-spark-1.3"
    meta_transcribe_model: str = "muse-voice-transcribe-1.0"
    meta_agent_max_tokens: int = 1024

    firebase_project_id: str = "guard-ab0d3"
    firebase_credentials_path: str = ""
    google_application_credentials: str = ""

    allowed_origins: str = "*"
    max_audio_upload_bytes: int = 10 * 1024 * 1024
    max_audio_duration_seconds: int = 120
    require_https: bool = False

    @property
    def origins(self) -> list[str]:
        raw = self.allowed_origins.strip()
        if not raw or raw == "*":
            return ["*"]
        return [item.strip() for item in raw.split(",") if item.strip()]

    @property
    def has_model_key(self) -> bool:
        return self.model_api_key.strip() != ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
