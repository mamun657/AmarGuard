import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.errors import MetaApiError
from app.meta_client import MetaClient

PROMPT = "Reply with one short Bengali sentence explaining family safety."


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    settings = get_settings()
    if not settings.has_model_key:
        print("RESULT: BLOCKED")
        print("BLOCKER: MODEL_API_KEY is not configured in the backend environment.")
        print("ACTION: set MODEL_API_KEY in backend/.env or the process environment, then rerun.")
        return 2

    client = MetaClient(settings)
    print(f"ENDPOINT: {settings.meta_base_url}/chat/completions")
    print(f"MODEL_REQUESTED: {settings.meta_chat_model}")
    print(f"PROMPT: {PROMPT}")
    try:
        result = client.chat(
            [{"role": "user", "content": PROMPT}],
            temperature=0.2,
            max_tokens=800,
        )
    except MetaApiError as error:
        print("RESULT: FAILED")
        print(f"ERROR_CODE: {error.code.value}")
        print(f"ERROR_MESSAGE: {error.message}")
        print(f"RETRYABLE: {error.retryable}")
        return 1

    print("RESULT: SUCCESS")
    print(f"HTTP_STATUS: 200")
    print(f"MODEL_ACTUAL: {result.model}")
    print(f"MODEL_MATCHES_REQUEST: {result.model == settings.meta_chat_model}")
    print(f"FINISH_REASON: {result.finish_reason}")
    print(f"RESPONSE_TEXT: {result.content}")
    print(f"USAGE: {json.dumps(result.usage.as_dict())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
