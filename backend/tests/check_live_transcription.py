import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.audio_utils import ensure_wav
from app.config import get_settings
from app.errors import MetaApiError
from app.meta_client import MetaClient
from app.voice_service import VoiceService

SAMPLES = [
    ("sample_bn.wav", "bn"),
    ("sample_en.wav", "en"),
    ("sample_mixed.wav", "bn-en"),
]

REPORT = Path(__file__).resolve().parent / "transcription_report.json"


def main() -> int:
    settings = get_settings()
    if not settings.has_model_key:
        print("RESULT: BLOCKED")
        print("BLOCKER: MODEL_API_KEY is not configured in the backend environment.")
        return 2

    base = Path(__file__).resolve().parent
    client = MetaClient(settings)
    service = VoiceService(settings, client)
    report = []
    failures = 0

    for name, language in SAMPLES:
        path = base / name
        if not path.exists():
            failures += 1
            report.append({"file": name, "status": "failed", "reason": "missing_sample"})
            continue
        normalized = ensure_wav(
            path.read_bytes(),
            max_bytes=settings.max_audio_upload_bytes,
            max_seconds=settings.max_audio_duration_seconds,
        )
        entry = {
            "file": name,
            "language": language,
            "sample_rate": normalized.sample_rate,
            "channels": normalized.channels,
            "duration_ms": normalized.duration_ms,
            "converted": normalized.converted,
        }
        try:
            result = service.transcribe(normalized.wav_bytes, language=language)
        except MetaApiError as error:
            failures += 1
            entry["status"] = "failed"
            entry["error_code"] = error.code.value
            entry["error_message"] = error.message
            report.append(entry)
            continue
        entry["status"] = "success" if result.transcript else "failed"
        entry["transcript"] = result.transcript
        entry["session_id"] = result.session_id
        entry["audio_duration_ms"] = result.audio_duration_ms
        if not result.transcript:
            failures += 1
        report.append(entry)

    REPORT.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"REPORT_WRITTEN={REPORT}")
    print(f"TOTAL_FAILURES={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
