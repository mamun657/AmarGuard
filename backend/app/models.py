from datetime import datetime, timezone
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class DetectedLanguage(str, Enum):
    bengali = "bn"
    english = "en"
    mixed = "bn-en"


class RequestType(str, Enum):
    lost = "lost"
    emergency = "emergency"
    check_in = "check_in"
    general = "general"
    unknown = "unknown"


class LocationFreshnessStatus(str, Enum):
    fresh = "fresh"
    stale = "stale"
    unavailable = "unavailable"
    paused = "paused"
    sharing_disabled = "sharing_disabled"
    not_configured = "not_configured"
    permission_disabled = "permission_disabled"


class RecipientOption(BaseModel):
    recipient_uid: str = Field(min_length=1, max_length=128)
    display_name: str = Field(default="", max_length=120)
    alias: str = Field(default="", max_length=120)
    relationship: str = Field(default="other", max_length=40)


class TranscribeRequest(BaseModel):
    language: Literal["bn", "en", "bn-en"] = "bn-en"
    consent_to_process: bool = False

    @field_validator("consent_to_process")
    @classmethod
    def require_consent(cls, value: bool) -> bool:
        if not value:
            raise ValueError("Explicit consent is required to process voice data.")
        return value


class AgentProcessRequest(BaseModel):
    transcript: str = Field(min_length=1, max_length=4000)
    original_transcript: str = Field(default="", max_length=4000)
    language: Literal["bn", "en", "bn-en"] = "bn-en"
    device_id: str = Field(min_length=1, max_length=128)

    @field_validator("transcript")
    @classmethod
    def strip_transcript(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Transcript cannot be empty.")
        return cleaned


class AssistanceSummary(BaseModel):
    request_type: RequestType = RequestType.unknown
    detected_language: DetectedLanguage = DetectedLanguage.bengali
    original_transcript: str = ""
    user_confirmed_transcript: str = ""
    assistance_summary: str = ""
    last_authorized_location: dict[str, Any] | None = None
    location_accuracy: float | None = None
    location_timestamp: str | None = None
    location_freshness_status: LocationFreshnessStatus = LocationFreshnessStatus.unavailable
    last_reported_battery: dict[str, Any] | None = None
    approved_recipient_options: list[RecipientOption] = Field(default_factory=list)
    suggested_recipient_uid: str | None = None
    recipient_match_status: Literal["matched", "manual_selection"] = "manual_selection"
    suggested_safe_actions: list[str] = Field(default_factory=list)
    consent_required: bool = True


class HelpRequestCreate(BaseModel):
    recipient_uid: str = Field(min_length=1, max_length=128)
    language: Literal["bn", "en", "bn-en"] = "bn-en"
    original_message: str = Field(min_length=1, max_length=4000)
    original_transcript: str = Field(default="", max_length=4000)
    generated_summary: str = Field(min_length=1, max_length=4000)
    verified_data_snapshot: dict[str, Any] = Field(default_factory=dict)
    sender_device_id: str = Field(min_length=1, max_length=128)
    idempotency_key: str = Field(min_length=8, max_length=200)
    request_type: RequestType = RequestType.unknown
    detected_language: DetectedLanguage = DetectedLanguage.bengali
    suggested_safe_actions: list[str] = Field(default_factory=list)
    include_location: bool = True


class HelpRequestRecord(BaseModel):
    request_id: str
    sender_uid: str
    sender_device_id: str
    recipient_uid: str
    requested_at: datetime | None = None
    language: str
    original_message: str
    original_transcript: str
    verified_data_snapshot: dict[str, Any]
    generated_summary: str
    status: str
    notification_status: str = "pending"
    acknowledged_at: datetime | None = None


class FcmTokenRequest(BaseModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android"] = "android"


class ConnectivityCheck(BaseModel):
    status: Literal["success", "failed"]
    model: str | None = None
    response_text: str | None = None
    usage: dict[str, Any] | None = None
    error_code: str | None = None
    error_message: str | None = None
    checked_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
