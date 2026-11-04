import json
import logging
from dataclasses import dataclass, field
from typing import Any

import httpx
from openai import APIConnectionError, APITimeoutError, OpenAI, RateLimitError

from .config import Settings
from .errors import (
    AudioFormatError,
    ForbiddenError,
    InvalidRequestError,
    MetaApiError,
    MetaApiErrorCode,
    MissingApiKeyError,
    PayloadTooLargeError,
    RateLimitedError,
    ServerError,
    TimeoutError,
    UnauthorizedError,
)

logger = logging.getLogger("caresignal.meta")


@dataclass
class ChatUsage:
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    total_tokens: int | None = None

    def as_dict(self) -> dict[str, int | None]:
        return {
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
            "total_tokens": self.total_tokens,
        }


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any] = field(default_factory=dict)


@dataclass
class ChatResult:
    content: str
    model: str
    tool_calls: list[ToolCall] = field(default_factory=list)
    finish_reason: str | None = None
    usage: ChatUsage = field(default_factory=ChatUsage)
    raw: Any = None


@dataclass
class TranscriptionResult:
    transcript: str
    session_id: str
    audio_duration_ms: int | None = None
    turns: list[dict[str, Any]] = field(default_factory=list)


class MetaClient:
    def __init__(self, settings: Settings, http_client: httpx.Client | None = None) -> None:
        self._settings = settings
        self._http_client = http_client
        self._openai: OpenAI | None = None

    @property
    def base_url(self) -> str:
        return self._settings.meta_base_url.rstrip("/")

    def _require_key(self) -> str:
        key = self._settings.model_api_key.strip()
        if not key:
            raise MissingApiKeyError()
        return key

    def _client(self) -> OpenAI:
        if self._openai is None:
            self._openai = OpenAI(
                base_url=self.base_url,
                api_key=self._require_key(),
                timeout=httpx.Timeout(60.0, connect=15.0),
                max_retries=0,
            )
        return self._openai

    def chat(
        self,
        messages: list[dict[str, Any]],
        *,
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str | dict[str, Any] | None = None,
        temperature: float | None = None,
        response_format: dict[str, Any] | None = None,
        max_tokens: int | None = None,
    ) -> ChatResult:
        payload: dict[str, Any] = {
            "model": self._settings.meta_chat_model,
            "messages": messages,
        }
        if tools:
            payload["tools"] = tools
        if tool_choice is not None:
            payload["tool_choice"] = tool_choice
        if temperature is not None:
            payload["temperature"] = temperature
        if response_format is not None:
            payload["response_format"] = response_format
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        try:
            response = self._client().chat.completions.create(**payload)
        except RateLimitError as error:
            raise RateLimitedError() from error
        except APITimeoutError as error:
            raise TimeoutError() from error
        except APIConnectionError as error:
            raise ServerError() from error
        except Exception as error:
            raise self._map_http_error(error) from error

        choice = response.choices[0] if response.choices else None
        content = ""
        tool_calls: list[ToolCall] = []
        finish_reason = None
        if choice is not None:
            finish_reason = choice.finish_reason
            message = choice.message
            content = (message.content or "").strip()
            for raw_call in message.tool_calls or []:
                tool_calls.append(
                    ToolCall(
                        id=raw_call.id,
                        name=raw_call.function.name,
                        arguments=_safe_json_object(raw_call.function.arguments),
                    )
                )

        usage_payload = getattr(response, "usage", None)
        usage = ChatUsage(
            prompt_tokens=getattr(usage_payload, "prompt_tokens", None),
            completion_tokens=getattr(usage_payload, "completion_tokens", None),
            total_tokens=getattr(usage_payload, "total_tokens", None),
        )
        return ChatResult(
            content=content,
            model=getattr(response, "model", self._settings.meta_chat_model),
            tool_calls=tool_calls,
            finish_reason=finish_reason,
            usage=usage,
            raw=response,
        )

    def transcribe(
        self,
        audio_bytes: bytes,
        *,
        filename: str = "recording.wav",
        language_bias: list[str] | None = None,
        keywords: list[str] | None = None,
    ) -> TranscriptionResult:
        key = self._require_key()
        request_body: dict[str, Any] = {
            "model": self._settings.meta_transcribe_model,
            "audioEncoding": "WAV",
            "mode": "PUSH_TO_TALK",
        }
        if language_bias:
            request_body["languageBias"] = language_bias
        if keywords:
            request_body["keywords"] = keywords

        files = {
            "request": (
                None,
                json.dumps(request_body),
                "application/json",
            ),
            "audio": (filename, audio_bytes, "audio/wav"),
        }

        client = self._http_client
        if client is None:
            with httpx.Client(timeout=httpx.Timeout(120.0, connect=15.0)) as owned:
                return self._transcribe_with(owned, key, files)
        return self._transcribe_with(client, key, files)

    def _transcribe_with(
        self,
        client: httpx.Client,
        key: str,
        files: dict[str, Any],
    ) -> TranscriptionResult:
        try:
            response = client.post(
                f"{self.base_url}/asr/transcribe",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Accept": "application/json",
                },
                files=files,
            )
        except httpx.TimeoutException as error:
            raise TimeoutError() from error
        except httpx.HTTPError as error:
            raise ServerError() from error

        if response.status_code >= 400:
            raise self._map_transcribe_error(response)

        payload = response.json()
        return TranscriptionResult(
            transcript=str(payload.get("transcript") or "").strip(),
            session_id=str(payload.get("sessionId") or ""),
            audio_duration_ms=payload.get("audioDurationMs"),
            turns=list(payload.get("turns") or []),
        )

    def _map_transcribe_error(self, response: httpx.Response) -> MetaApiError:
        detail = _extract_error_detail(response)
        if response.status_code == 400:
            if "wav" in detail.lower() or "audio" in detail.lower():
                return AudioFormatError(detail)
            return InvalidRequestError(detail)
        if response.status_code == 401:
            return UnauthorizedError()
        if response.status_code == 403:
            return ForbiddenError()
        if response.status_code == 413:
            return PayloadTooLargeError(detail)
        if response.status_code == 429:
            return RateLimitedError()
        if response.status_code >= 500:
            return ServerError()
        return MetaApiError(MetaApiErrorCode.UNKNOWN, detail, status_code=response.status_code)

    def _map_http_error(self, error: Exception) -> MetaApiError:
        status_code = getattr(error, "status_code", None)
        if status_code == 401:
            return UnauthorizedError()
        if status_code == 403:
            return ForbiddenError()
        if status_code == 429:
            return RateLimitedError()
        if status_code == 400:
            return InvalidRequestError(_extract_error_detail(getattr(error, "response", None)))
        if status_code is not None and status_code >= 500:
            return ServerError()
        return MetaApiError(
            MetaApiErrorCode.UNKNOWN,
            "Meta Model API request failed.",
            status_code=502,
        )


def _safe_json_object(raw: Any) -> dict[str, Any]:
    if isinstance(raw, dict):
        return raw
    if not isinstance(raw, str) or not raw.strip():
        return {}
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _extract_error_detail(source: Any) -> str:
    if source is None:
        return "Meta Model API request failed."
    text = ""
    if isinstance(source, httpx.Response):
        try:
            payload = source.json()
            text = _extract_message(payload)
        except Exception:
            text = source.text[:300]
    else:
        text = _extract_message(getattr(source, "body", None)) or str(source)[:300]
    return text or "Meta Model API request failed."


def _extract_message(payload: Any) -> str:
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict):
            return str(error.get("message") or "")
        if isinstance(error, str):
            return error
        message = payload.get("message")
        if isinstance(message, str):
            return message
    return ""
