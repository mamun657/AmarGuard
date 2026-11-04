import logging

from .config import Settings
from .meta_client import MetaClient, TranscriptionResult

logger = logging.getLogger("caresignal.voice")

LANGUAGE_BIAS = {
    "bn": ["Bengali"],
    "en": ["English"],
    "bn-en": ["Bengali", "English"],
}


class VoiceService:
    def __init__(self, settings: Settings, client: MetaClient) -> None:
        self._settings = settings
        self._client = client

    def transcribe(
        self,
        audio_bytes: bytes,
        *,
        language: str,
        keywords: list[str] | None = None,
    ) -> TranscriptionResult:
        bias = LANGUAGE_BIAS.get(language)
        if not bias:
            bias = None
        result = self._client.transcribe(
            audio_bytes,
            language_bias=bias,
            keywords=keywords,
        )
        logger.info(
            "Transcription completed duration_ms=%s session=%s",
            result.audio_duration_ms,
            result.session_id,
        )
        return result
