import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

from .config import Settings
from .family_tools import FamilyTools, ToolContext, resolve_freshness
from .meta_client import ChatResult, MetaClient
from .models import (
    AssistanceSummary,
    DetectedLanguage,
    LocationFreshnessStatus,
    RecipientOption,
    RequestType,
)
from .recipient_matching import resolve_recipient

logger = logging.getLogger("caresignal.agent")

MAX_AGENT_ROUNDS = 5

BENGALI_MARKERS = re.compile(r"[\u0980-\u09FF]")
LATIN_MARKERS = re.compile(r"[A-Za-z]")

TOOL_DEFINITIONS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "get_current_user_identity",
            "description": "Get the authenticated user's account identity and linked device id.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_approved_family_contacts",
            "description": "List family members approved by the owner to receive help requests.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_own_device_sharing_status",
            "description": "Get whether the user's own device currently shares location.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_last_authorized_location",
            "description": "Get the last location the user already authorized to share.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_location_last_sync_time",
            "description": "Get when the device last synced location data.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_last_reported_battery",
            "description": "Get the last battery percentage reported by the device.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_connection_status",
            "description": "Get the device sharing and connectivity status.",
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    },
]

SYSTEM_PROMPT = (
    "You are CareSignal AI, a bilingual (Bengali and English) family safety assistant inside "
    "the AmarGuard app. You help a user who has asked for help by voice. "
    "Use the provided tools to read verified device data instead of guessing. "
    "Never invent GPS coordinates, addresses, battery levels, timestamps, or connectivity. "
    "Never claim the user is in danger, never give a medical diagnosis or risk score, "
    "and never contact emergency services. "
    "Never state that a location is live; call it the last known location. "
    "If a value is unavailable, say it is unavailable. "
    "Call get_approved_family_contacts to find who may be notified, "
    "get_last_authorized_location for the last known location, "
    "get_last_reported_battery for battery, and get_connection_status for connectivity. "
    "Call only the tools you need. "
    "When the transcript explicitly names an approved contact, suggest that contact's saved "
    "display name or alias in suggested_recipient; otherwise return null. Do not guess or "
    "choose a recipient when the wording is ambiguous. "
    "Respond with a single JSON object and nothing else. "
    "Schema: {\"request_type\": \"lost\"|\"emergency\"|\"check_in\"|\"general\"|\"unknown\", "
    "\"detected_language\": \"bn\"|\"en\"|\"bn-en\", "
    "\"assistance_summary\": string in the language the user spoke, "
    "\"suggested_safe_actions\": array of at most 3 short strings in the user's language, "
    "\"location_freshness_status\": \"fresh\"|\"stale\"|\"unavailable\"|\"paused\"|"
    "\"sharing_disabled\"|\"not_configured\"|\"permission_disabled\", "
    "\"suggested_recipient\": string|null}. "
    "The assistance_summary must be a factual restatement of what the user asked for "
    "plus the verified tool data. It must not contain claims that are not supported by the tool results."
)


class AgentService:
    def __init__(
        self,
        settings: Settings,
        client: MetaClient,
        tools: FamilyTools,
    ) -> None:
        self._settings = settings
        self._client = client
        self._tools = tools

    def process(
        self,
        *,
        transcript: str,
        original_transcript: str,
        language: str,
        context: ToolContext,
    ) -> tuple[AssistanceSummary, dict[str, Any]]:
        tool_log: list[dict[str, Any]] = []
        messages: list[dict[str, Any]] = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    f"Selected app language: {language}\n"
                    f"User said (use this exactly as the original statement): {transcript}"
                ),
            },
        ]

        contacts = self._tools.execute(
            "get_approved_family_contacts", {}, context
        )
        tool_log.append(
            {"tool": "get_approved_family_contacts", "payload": contacts}
        )
        model_contacts = [
            {
                "display_name": str(item.get("display_name") or ""),
                "alias": str(item.get("alias") or ""),
                "relationship": str(item.get("relationship") or "other"),
            }
            for item in (contacts.get("approved_contacts") or [])
        ]
        messages.append(
            {
                "role": "system",
                "content": (
                    "Approved family contact names and relationships for recipient "
                    "suggestion only (do not infer authorization beyond this list): "
                    + json.dumps(model_contacts, ensure_ascii=False)
                ),
            }
        )

        model_output: dict[str, Any] = {}
        usage: dict[str, Any] = {}
        model_identity = self._settings.meta_chat_model
        rounds = 0

        while rounds < MAX_AGENT_ROUNDS:
            rounds += 1
            result: ChatResult = self._client.chat(
                messages,
                tools=TOOL_DEFINITIONS,
                tool_choice="auto",
                temperature=0.1,
                max_tokens=self._settings.meta_agent_max_tokens,
            )
            model_identity = result.model
            usage = result.usage.as_dict()
            if not result.tool_calls:
                model_output = _parse_json_object(result.content)
                break
            messages.append(
                {
                    "role": "assistant",
                    "content": result.content or None,
                    "tool_calls": [
                        {
                            "id": call.id,
                            "type": "function",
                            "function": {
                                "name": call.name,
                                "arguments": json.dumps(call.arguments),
                            },
                        }
                        for call in result.tool_calls
                    ],
                }
            )
            for call in result.tool_calls:
                payload = self._execute_tool(call.name, call.arguments, context, tool_log)
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": call.id,
                        "name": call.name,
                        "content": json.dumps(payload, ensure_ascii=False, default=str),
                    }
                )
        else:
            model_output = {}

        summary = self._build_summary(
            model_output=model_output,
            transcript=transcript,
            original_transcript=original_transcript or transcript,
            language=language,
            tool_log=tool_log,
            ai_recipient_suggestion=(
                model_output.get("suggested_recipient")
                if isinstance(model_output.get("suggested_recipient"), str)
                else None
            ),
        )
        diagnostics = {
            "model": model_identity,
            "rounds": rounds,
            "tools_used": [entry["tool"] for entry in tool_log],
            "usage": usage,
        }
        return summary, diagnostics

    def _execute_tool(
        self,
        name: str,
        arguments: dict[str, Any],
        context: ToolContext,
        tool_log: list[dict[str, Any]],
    ) -> dict[str, Any]:
        try:
            payload = self._tools.execute(name, arguments, context)
        except Exception as error:
            logger.warning("Tool %s failed: %s", name, type(error).__name__)
            payload = {"error": "tool_unavailable"}
        tool_log.append({"tool": name, "payload": payload})
        return payload

    def _build_summary(
        self,
        *,
        model_output: dict[str, Any],
        transcript: str,
        original_transcript: str,
        language: str,
        tool_log: list[dict[str, Any]],
        ai_recipient_suggestion: str | None = None,
    ) -> AssistanceSummary:
        collected = _collect_tool_payloads(tool_log)
        location = collected.get("get_last_authorized_location", {})
        battery = collected.get("get_last_reported_battery", {})
        contacts = collected.get("get_approved_family_contacts", {})
        device = collected.get("get_own_device_sharing_status", {})
        connection = collected.get("get_connection_status", {})

        request_type = _parse_request_type(model_output.get("request_type"))
        detected_language = _parse_language(model_output.get("detected_language"), transcript)
        freshness = LocationFreshnessStatus(
            resolve_freshness(location, device, connection)
        )

        location_payload: dict[str, Any] | None = None
        location_accuracy: float | None = None
        location_timestamp: str | None = None
        if location.get("available") is True:
            location_payload = {
                "latitude": location.get("latitude"),
                "longitude": location.get("longitude"),
                "accuracy": location.get("accuracy"),
                "captured_at": location.get("captured_at"),
                "address_label": location.get("address_label"),
                "label": "last_known_location",
            }
            location_accuracy = _as_float(location.get("accuracy"))
            location_timestamp = location.get("captured_at") or location.get("synced_at")

        battery_payload: dict[str, Any] | None = None
        if battery.get("available") is True:
            battery_payload = {
                "level": battery.get("level"),
                "is_charging": battery.get("is_charging"),
                "observed_at": battery.get("observed_at"),
            }

        recipients = [
            RecipientOption(
                recipient_uid=str(item.get("recipient_uid") or ""),
                display_name=str(item.get("display_name") or ""),
                alias=str(item.get("alias") or ""),
                relationship=str(item.get("relationship") or "other"),
            )
            for item in (contacts.get("approved_contacts") or [])
            if item.get("recipient_uid")
        ]

        assistance_summary = str(model_output.get("assistance_summary") or "").strip()
        if not assistance_summary:
            assistance_summary = _fallback_summary(
                transcript=transcript,
                language=detected_language.value,
                request_type=request_type.value,
                location_available=location_payload is not None,
                freshness=freshness.value,
                battery=battery_payload,
            )

        actions = model_output.get("suggested_safe_actions")
        safe_actions: list[str] = []
        if isinstance(actions, list):
            for item in actions[:3]:
                text = str(item).strip()
                if text:
                    safe_actions.append(text)
        if not safe_actions:
            safe_actions = _fallback_actions(detected_language.value, request_type.value)

        recipient_uid, recipient_match_status = resolve_recipient(
            transcript,
            contacts.get("approved_contacts") or [],
            ai_recipient_suggestion,
        )

        return AssistanceSummary(
            request_type=request_type,
            detected_language=detected_language,
            original_transcript=original_transcript,
            user_confirmed_transcript=transcript,
            assistance_summary=assistance_summary,
            last_authorized_location=location_payload,
            location_accuracy=location_accuracy,
            location_timestamp=location_timestamp,
            location_freshness_status=freshness,
            last_reported_battery=battery_payload,
            approved_recipient_options=recipients,
            suggested_recipient_uid=recipient_uid,
            recipient_match_status=recipient_match_status,
            suggested_safe_actions=safe_actions,
            consent_required=True,
        )


def _collect_tool_payloads(tool_log: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    collected: dict[str, dict[str, Any]] = {}
    for entry in tool_log:
        payload = entry.get("payload")
        if isinstance(payload, dict):
            collected[entry["tool"]] = payload
    return collected


def _parse_json_object(text: str) -> dict[str, Any]:
    if not text.strip():
        return {}
    candidate = text.strip()
    if candidate.startswith("```"):
        candidate = re.sub(r"^```[a-zA-Z]*\n?", "", candidate)
        candidate = re.sub(r"\n?```$", "", candidate).strip()
    try:
        parsed = json.loads(candidate)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", candidate, re.DOTALL)
        if not match:
            return {}
        try:
            parsed = json.loads(match.group(0))
        except json.JSONDecodeError:
            return {}
    return parsed if isinstance(parsed, dict) else {}


def _parse_request_type(value: Any) -> RequestType:
    if isinstance(value, str):
        normalized = value.strip().lower()
        for item in RequestType:
            if item.value == normalized:
                return item
    return RequestType.unknown


def _parse_language(value: Any, transcript: str, requested_language: str = "") -> DetectedLanguage:
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"bn", "en", "bn-en", "mixed"}:
            return DetectedLanguage.mixed if normalized == "mixed" else DetectedLanguage(normalized)
    return detect_language(transcript, requested_language)


def detect_language(text: str, requested_language: str = "") -> DetectedLanguage:
    has_bengali = bool(BENGALI_MARKERS.search(text))
    has_latin = bool(LATIN_MARKERS.search(text))
    if has_bengali and has_latin:
        return DetectedLanguage.mixed
    if has_bengali:
        return DetectedLanguage.bengali
    if has_latin:
        if requested_language == "bn-en":
            return DetectedLanguage.mixed
        return DetectedLanguage.english
    return DetectedLanguage.english


def _as_float(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _fallback_summary(
    *,
    transcript: str,
    language: str,
    request_type: str,
    location_available: bool,
    freshness: str,
    battery: dict[str, Any] | None,
) -> str:
    if language == "bn":
        base = f"ব্যবহারকারী বলেছেন: \"{transcript}\""
        if location_available:
            base += f"। শেষ জানা অবস্থানের তথ্য পাওয়া গেছে (অবস্থা: {freshness})"
        else:
            base += "। বর্তমানে কোনো অনুমোদিত অবস্থানের তথ্য নেই"
        if battery:
            base += f"। শেষ জানা ব্যাটারি: {battery.get('level')}%"
        return base
    base = f'The user said: "{transcript}"'
    if location_available:
        base += f". Last known location data is available (status: {freshness})"
    else:
        base += ". No authorized location data is currently available"
    if battery:
        base += f". Last reported battery: {battery.get('level')}%"
    return base


def _fallback_actions(language: str, request_type: str) -> list[str]:
    if language == "bn":
        if request_type == RequestType.lost.value:
            return [
                "পরিবারের অনুমোদিত সদস্যের সাথে যোগাযোগ করুন",
                "আশপাশে পরিচিত কাউকে জানান",
                "নিরাপদ জায়গায় থাকুন এবং ফোনটি চালু রাখুন",
            ]
        return [
            "পরিবারের সদস্যকে জানান",
            "ফোনটি চার্জে রাখুন",
            "নিরাপদ জায়গায় থাকুন",
        ]
    if request_type == RequestType.lost.value:
        return [
            "Contact an approved family member",
            "Ask a nearby trusted person for help",
            "Stay in a safe place and keep the phone available",
        ]
    return [
        "Contact a family member",
        "Keep the phone charged",
        "Stay somewhere safe",
    ]
