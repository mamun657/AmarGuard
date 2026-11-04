import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.agent_service import AgentService
from app.config import get_settings
from app.errors import MetaApiError
from app.family_tools import FamilyTools, ToolContext
from app.meta_client import MetaClient

PROMPTS = [
    ("bn", "আমি পথ হারিয়ে ফেলেছি, আমার ছেলেকে জানাও।"),
    ("en", "I am lost. Please help me contact my family."),
    ("bn-en", "Ami lost hoye gesi, please amar family ke inform koro."),
]


class _StubFirestore:
    def collection(self, name):
        raise RuntimeError("live agent test does not read Firestore")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    settings = get_settings()
    if not settings.has_model_key:
        print("RESULT: BLOCKED")
        print("BLOCKER: MODEL_API_KEY is not configured in the backend environment.")
        return 2

    client = MetaClient(settings)
    service = AgentService(settings, client, FamilyTools(_StubFirestore()))
    failures = 0

    for language, prompt in PROMPTS:
        context = ToolContext(
            uid="test-owner",
            email="test@example.com",
            display_name="Test Owner",
            device_id="test-device",
            now=datetime.now(timezone.utc),
        )
        print(f"--- LANGUAGE={language} PROMPT={prompt}")
        try:
            summary, diagnostics = service.process(
                transcript=prompt,
                original_transcript=prompt,
                language=language,
                context=context,
            )
        except MetaApiError as error:
            failures += 1
            print(f"RESULT: FAILED CODE={error.code.value}")
            print(f"ERROR_MESSAGE={error.message}")
            continue

        payload = summary.model_dump(mode="json")
        print(f"MODEL={diagnostics['model']}")
        print(f"ROUNDS={diagnostics['rounds']}")
        print(f"TOOLS_USED={json.dumps(diagnostics['tools_used'])}")
        print(f"USAGE={json.dumps(diagnostics['usage'])}")
        print(f"REQUEST_TYPE={payload['request_type']}")
        print(f"DETECTED_LANGUAGE={payload['detected_language']}")
        print(f"SUMMARY={payload['assistance_summary']}")
        print(f"ACTIONS={json.dumps(payload['suggested_safe_actions'], ensure_ascii=False)}")
        print(f"LOCATION={json.dumps(payload['last_authorized_location'], ensure_ascii=False)}")
        print(f"BATTERY={json.dumps(payload['last_reported_battery'], ensure_ascii=False)}")
        print(f"CONSENT_REQUIRED={payload['consent_required']}")
        print(f"ORIGINAL_PRESERVED={payload['original_transcript'] == prompt}")
        if payload["request_type"] == "unknown":
            failures += 1
            print("RESULT: FAILED reason=request_type_not_detected")
        else:
            print("RESULT: SUCCESS")

    print(f"TOTAL_FAILURES={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
