from datetime import datetime, timezone
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.errors import (
    AudioFormatError,
    ForbiddenError,
    MetaApiError,
    MetaApiErrorCode,
    MissingApiKeyError,
    RateLimitedError,
    UnauthorizedError,
)
from app.main import create_app
from app.models import AssistanceSummary, DetectedLanguage, LocationFreshnessStatus, RequestType
from app.routes import get_client, get_firestore, get_settings, require_user
from app.routes import get_fcm_service
from app.auth import AuthenticatedUser, TokenVerifier, get_token_verifier
from app.fcm_service import FcmService

from .fakes import FakeFirestore


class _FakeMetaClient:
    def __init__(self, error: MetaApiError | None = None) -> None:
        self.error = error
        self.transcribe_calls: list[dict[str, Any]] = []
        self.chat_calls: list[dict[str, Any]] = []

    def transcribe(self, audio_bytes: bytes, **kwargs: Any):
        self.transcribe_calls.append({"bytes": audio_bytes, **kwargs})
        if self.error is not None:
            raise self.error
        from app.meta_client import TranscriptionResult

        return TranscriptionResult(
            transcript="আমি পথ হারিয়ে ফেলেছি",
            session_id="session-1",
            audio_duration_ms=1200,
        )

    def chat(self, messages, **kwargs: Any):
        self.chat_calls.append({"messages": messages, **kwargs})
        if self.error is not None:
            raise self.error
        from app.meta_client import ChatResult

        return ChatResult(
            content='{"request_type": "lost"}',
            model="muse-spark-1.3",
        )


def _settings(**overrides):
    base = {
        "model_api_key": "",
        "meta_base_url": "https://api.meta.ai/v1",
        "meta_chat_model": "muse-spark-1.3",
        "meta_transcribe_model": "muse-voice-transcribe-1.0",
        "firebase_project_id": "",
        "firebase_credentials_path": "",
        "allowed_origins": "*",
        "max_audio_upload_bytes": 1024 * 1024,
        "max_audio_duration_seconds": 120,
        "require_https": False,
    }
    base.update(overrides)
    return Settings(**base)


def _wav_bytes(*, frames: int = 16000) -> bytes:
    import io
    import wave

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(16000)
        writer.writeframes(b"\x00\x01" * frames)
    return buffer.getvalue()


def _client(
    *,
    firestore: FakeFirestore | None = None,
    meta_client: _FakeMetaClient | None = None,
    settings: Settings | None = None,
    user: AuthenticatedUser | None = None,
    fcm_service: FcmService | None = None,
) -> TestClient:
    app = create_app(settings or _settings())
    resolved_firestore = firestore if firestore is not None else FakeFirestore()
    resolved_meta = meta_client if meta_client is not None else _FakeMetaClient()
    resolved_settings = settings or _settings()
    app.dependency_overrides[require_user] = lambda: user or AuthenticatedUser(
        uid="owner-1",
        email="owner@example.com",
        name="Owner",
    )
    app.dependency_overrides[get_firestore] = lambda: resolved_firestore
    app.dependency_overrides[get_client] = lambda: resolved_meta
    app.dependency_overrides[get_settings] = lambda: resolved_settings
    app.dependency_overrides[get_fcm_service] = lambda: (
        fcm_service if fcm_service is not None else FcmService(resolved_firestore)
    )
    return TestClient(app)


def _authenticated_client(monkeypatch, firestore, token_result):
    settings = _settings(firebase_project_id="guard-ab0d3")
    app = create_app(settings)
    app.dependency_overrides[get_settings] = lambda: settings
    app.dependency_overrides[get_firestore] = lambda: firestore
    app.dependency_overrides[get_token_verifier] = lambda: TokenVerifier(settings)

    def verify_token(token, project_id=None):
        assert token == "unit-test-firebase-id-token"
        assert project_id == "guard-ab0d3"
        if isinstance(token_result, Exception):
            raise token_result
        return token_result

    monkeypatch.setattr(
        "app.firebase_gateway.verify_firebase_id_token",
        verify_token,
    )
    return TestClient(app)


def _seed_viewer(firestore: FakeFirestore, *, active: bool = True) -> None:
    firestore.seed(
        "users/owner-1/devices/device-1",
        {
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "nickname": "My Device",
            "sharingState": "active",
        },
    )
    firestore.seed(
        "users/owner-1/devices/device-1/approvedViewers/viewer-1",
        {
            "viewerUid": "viewer-1",
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "active": active,
            "viewerDisplayName": "Son",
            "relationship": "child",
        },
    )


def test_valid_bengali_help_request_reaches_agent_and_sends():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    meta = _FakeMetaClient()
    client = _client(firestore=firestore, meta_client=meta)

    transcribe = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert transcribe.status_code == 200
    assert transcribe.json()["transcript"] == "আমি পথ হারিয়ে ফেলেছি"
    assert meta.transcribe_calls[0]["language_bias"] == ["Bengali"]

    agent = client.post(
        "/agent/process",
        json={
            "transcript": "আমি পথ হারিয়ে ফেলেছি",
            "original_transcript": "আমি পথ হারিয়ে ফেলেছি",
            "language": "bn",
            "device_id": "device-1",
        },
    )
    assert agent.status_code == 200
    summary = agent.json()["summary"]
    assert summary["request_type"] == "lost"
    assert summary["detected_language"] == "bn"
    assert summary["consent_required"] is True
    assert summary["original_transcript"] == "আমি পথ হারিয়ে ফেলেছি"

    sent = client.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "bn",
            "original_message": "আমি পথ হারিয়ে ফেলেছি",
            "original_transcript": "আমি পথ হারিয়ে ফেলেছি",
            "generated_summary": summary["assistance_summary"],
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "key-bn-0001",
        },
    )
    assert sent.status_code == 200
    assert sent.json()["created"] is True
    assert sent.json()["request"]["recipient_uid"] == "viewer-1"


def test_valid_english_help_request_uses_english_language_bias():
    meta = _FakeMetaClient()
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "en"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 200
    assert meta.transcribe_calls[0]["language_bias"] == ["English"]


def test_mixed_language_request_is_accepted():
    meta = _FakeMetaClient()
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn-en"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 200
    assert meta.transcribe_calls[0]["language_bias"] == ["Bengali", "English"]


def test_consent_is_required_before_voice_processing():
    client = _client()
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "false", "language": "bn-en"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "consent_required"


def test_empty_recording_is_rejected():
    client = _client()
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn-en"},
        files={"audio": ("recording.wav", b"", "audio/wav")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "unsupported_audio"


def test_meta_unauthorized_is_surfaced_without_credentials():
    meta = _FakeMetaClient(error=UnauthorizedError())
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 502
    body = response.json()
    assert body["error"]["code"] == MetaApiErrorCode.UNAUTHORIZED.value
    assert "Bearer" not in response.text
    assert "sk-" not in response.text


def test_meta_rate_limit_is_surfaced():
    meta = _FakeMetaClient(error=RateLimitedError())
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 429
    assert response.json()["error"]["code"] == MetaApiErrorCode.RATE_LIMITED.value


def test_missing_api_key_is_reported():
    client = _client(settings=_settings(model_api_key=""))
    response = client.post("/connectivity/check")
    assert response.status_code == 200
    assert response.json()["error_code"] == "missing_api_key"


def test_forbidden_meta_error_maps_to_safe_message():
    meta = _FakeMetaClient(error=ForbiddenError())
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 502
    assert response.json()["error"]["code"] == MetaApiErrorCode.FORBIDDEN.value


def test_missing_location_is_reported_as_unavailable():
    firestore = FakeFirestore()
    firestore.seed(
        "users/owner-1/devices/device-1",
        {
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "sharingState": "stopped",
        },
    )
    client = _client(firestore=firestore)
    response = client.post(
        "/family/contacts?device_id=device-1",
    )
    assert response.status_code == 200
    body = response.json()
    assert body["approved_contacts"] == []
    assert body["count"] == 0


def test_stale_location_is_marked_stale_not_live():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    captured = datetime(2020, 1, 1, tzinfo=timezone.utc)
    firestore.seed(
        "users/owner-1/devices/device-1/location/current",
        {
            "latitude": 23.8,
            "longitude": 90.4,
            "accuracy": 12,
            "capturedAt": captured,
            "syncedAt": captured,
        },
    )
    client = _client(firestore=firestore)
    from app.family_tools import FamilyTools, ToolContext

    tools = FamilyTools(firestore)
    context = ToolContext(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
        device_id="device-1",
        now=datetime.now(timezone.utc),
    )
    result = tools.execute("get_last_authorized_location", {}, context)
    assert result["available"] is True
    assert result["freshness"] == "unavailable"


def test_revoked_family_access_is_excluded():
    firestore = FakeFirestore()
    _seed_viewer(firestore, active=False)
    client = _client(firestore=firestore)
    response = client.post("/family/contacts?device_id=device-1")
    assert response.status_code == 200
    assert response.json()["approved_contacts"] == []


def test_approved_contacts_return_saved_alias_and_real_firebase_uid():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    firestore.seed(
        "users/owner-1/devices/device-1/approvedViewers/viewer-1",
        {
            "viewerUid": "viewer-1",
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "active": True,
            "viewerDisplayName": "Family member",
            "alias": "father",
            "relationship": "parent",
        },
    )
    client = _client(firestore=firestore)
    response = client.post("/family/contacts?device_id=device-1")

    assert response.status_code == 200
    contact = response.json()["approved_contacts"][0]
    assert contact["recipient_uid"] == "viewer-1"
    assert contact["display_name"] == "father"
    assert contact["relationship"] == "parent"
    assert "email" not in contact


def test_no_approved_contacts_blocks_help_request():
    firestore = FakeFirestore()
    firestore.seed(
        "users/owner-1/devices/device-1",
        {
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "sharingState": "active",
        },
    )
    client = _client(firestore=firestore)
    response = client.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "en",
            "original_message": "I am lost",
            "original_transcript": "I am lost",
            "generated_summary": "User reported being lost.",
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "key-no-contacts-01",
        },
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "recipient_not_approved"


def test_user_cancels_before_sending_creates_nothing():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    client = _client(firestore=firestore)
    assert "helpRequests" not in firestore.store


def test_successful_confirmed_request_is_idempotent():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    client = _client(firestore=firestore)
    payload = {
        "recipient_uid": "viewer-1",
        "language": "en",
        "original_message": "I am lost",
        "original_transcript": "I am lost",
        "generated_summary": "User reported being lost.",
        "verified_data_snapshot": {"last_reported_battery": {"level": 55}},
        "sender_device_id": "device-1",
        "idempotency_key": "key-idem-000001",
    }
    first = client.post("/help-request", json=payload)
    second = client.post("/help-request", json=payload)
    assert first.status_code == 200
    assert first.json()["created"] is True
    assert second.json()["created"] is False
    assert second.json()["request"]["request_id"] == first.json()["request"]["request_id"]
    assert first.json()["request"]["notification_status"] == "unavailable"


def test_recipient_acknowledges_and_sender_sees_status():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    sender = _client(firestore=firestore)
    payload = {
        "recipient_uid": "viewer-1",
        "language": "en",
        "original_message": "I am lost",
        "original_transcript": "I am lost",
        "generated_summary": "User reported being lost.",
        "verified_data_snapshot": {},
        "sender_device_id": "device-1",
        "idempotency_key": "key-ack-0000001",
    }
    created = sender.post("/help-request", json=payload).json()["request"]
    request_id = created["request_id"]

    recipient = _client(
        firestore=firestore,
        user=AuthenticatedUser(
            uid="viewer-1",
            email="viewer@example.com",
            name="Son",
        ),
    )
    acknowledged = recipient.post(
        f"/help-request/acknowledge?request_id={request_id}",
    )
    assert acknowledged.status_code == 200
    assert acknowledged.json()["request"]["status"] == "acknowledged"

    sent = sender.get("/help-request/sent")
    assert sent.status_code == 200
    records = sent.json()["requests"]
    assert len(records) == 1
    assert records[0]["status"] == "acknowledged"
    assert records[0]["acknowledged_at"] is not None


def test_unauthorized_account_cannot_read_request():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    sender = _client(firestore=firestore)
    payload = {
        "recipient_uid": "viewer-1",
        "language": "en",
        "original_message": "I am lost",
        "original_transcript": "I am lost",
        "generated_summary": "User reported being lost.",
        "verified_data_snapshot": {},
        "sender_device_id": "device-1",
        "idempotency_key": "key-unauth-00001",
    }
    created = sender.post("/help-request", json=payload).json()["request"]

    recipient = _client(
        firestore=firestore,
        user=AuthenticatedUser(
            uid="viewer-1",
            email="viewer@example.com",
            name="Son",
        ),
    )
    inbox = recipient.get("/help-request/inbox")
    assert inbox.status_code == 200
    assert [item["request_id"] for item in inbox.json()["requests"]] == [
        created["request_id"]
    ]
    assert recipient.get(f"/help-request/{created['request_id']}").status_code == 200

    stranger = _client(
        firestore=firestore,
        user=AuthenticatedUser(
            uid="stranger-1",
            email="stranger@example.com",
            name="Stranger",
        ),
    )
    inbox = stranger.get("/help-request/inbox")
    assert inbox.status_code == 200
    assert inbox.json()["requests"] == []

    sent = stranger.get("/help-request/sent")
    assert sent.json()["requests"] == []

    acknowledge = stranger.post(
        f"/help-request/acknowledge?request_id={created['request_id']}",
    )
    assert acknowledge.status_code == 403
    assert acknowledge.json()["error"]["code"] == "permission_denied"
    assert stranger.get(f"/help-request/{created['request_id']}").status_code == 404


def test_fcm_registration_uses_authenticated_uid_and_owner_only_unregister():
    firestore = FakeFirestore()
    token = "test-fcm-device-token-0123456789"
    owner = _client(firestore=firestore)
    response = owner.post(
        "/fcm/register",
        json={"token": token, "platform": "android", "uid": "stranger-1"},
    )
    assert response.status_code == 200
    token_records = [
        data for path, data in firestore.store.items()
        if path.startswith("fcmTokens/")
    ]
    assert len(token_records) == 1
    assert token_records[0]["ownerUid"] == "owner-1"
    assert token_records[0]["token"] == token

    stranger = _client(
        firestore=firestore,
        user=AuthenticatedUser(
            uid="stranger-1", email="stranger@example.com", name="Stranger"
        ),
    )
    denied = stranger.post("/fcm/unregister", json={"token": token})
    assert denied.status_code == 200
    assert denied.json()["unregistered"] is False
    assert len([path for path in firestore.store if path.startswith("fcmTokens/")]) == 1

    removed = owner.post("/fcm/unregister", json={"token": token})
    assert removed.json()["unregistered"] is True
    assert not [path for path in firestore.store if path.startswith("fcmTokens/")]


def test_fcm_registration_authenticates_firebase_id_token(monkeypatch, caplog):
    firestore = FakeFirestore()
    client = _authenticated_client(
        monkeypatch,
        firestore,
        {"uid": "verified-owner", "aud": "guard-ab0d3"},
    )

    response = client.post(
        "/fcm/register",
        headers={"Authorization": "Bearer unit-test-firebase-id-token"},
        json={
            "token": "unit-test-fcm-token-123456789",
            "platform": "android",
            "uid": "attacker-controlled",
        },
    )

    assert response.status_code == 200
    token_records = [
        data for path, data in firestore.store.items()
        if path.startswith("fcmTokens/")
    ]
    assert len(token_records) == 1
    assert token_records[0]["ownerUid"] == "verified-owner"
    assert "unit-test-firebase-id-token" not in caplog.text
    assert "unit-test-fcm-token" not in caplog.text


def test_fcm_registration_rejects_invalid_firebase_id_token(monkeypatch, caplog):
    client = _authenticated_client(
        monkeypatch,
        FakeFirestore(),
        ValueError("invalid test token"),
    )

    response = client.post(
        "/fcm/register",
        headers={"Authorization": "Bearer unit-test-firebase-id-token"},
        json={"token": "unit-test-fcm-token-123456789", "platform": "android"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"
    assert (
        "endpoint=/fcm/register status=401 category=ValueError "
        "authorization_present=true"
    ) in caplog.text
    assert "unit-test-firebase-id-token" not in caplog.text
    assert "unit-test-fcm-token" not in caplog.text


def test_authenticated_sender_can_retrieve_sent_help_requests(monkeypatch):
    firestore = FakeFirestore()
    firestore.seed(
        "helpRequests/request-auth-history",
        {
            "requestId": "request-auth-history",
            "senderUid": "verified-owner",
            "senderDeviceId": "device-1",
            "recipientUid": "recipient-1",
            "requestedAt": datetime.now(timezone.utc),
            "language": "en",
            "originalMessage": "Please call me.",
            "originalTranscript": "Please call me.",
            "verifiedDataSnapshot": {},
            "generatedSummary": "A family member requested help.",
            "status": "sent",
            "notificationStatus": "pending",
            "acknowledgedAt": None,
        },
    )
    client = _authenticated_client(
        monkeypatch,
        firestore,
        {"uid": "verified-owner", "aud": "guard-ab0d3"},
    )

    response = client.get(
        "/help-request/sent",
        headers={"Authorization": "Bearer unit-test-firebase-id-token"},
    )

    assert response.status_code == 200
    assert [item["request_id"] for item in response.json()["requests"]] == [
        "request-auth-history"
    ]


def test_firestore_sent_history_failure_logs_safe_endpoint_and_category(
    monkeypatch,
    caplog,
):
    from google.api_core.exceptions import FailedPrecondition
    from app.incident_service import IncidentService

    def fail_history(self, sender_uid, limit=50):
        raise FailedPrecondition("private backend exception details")

    monkeypatch.setattr(IncidentService, "list_for_sender", fail_history)
    response = _client().get("/help-request/sent")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "firestore_access_failed"
    assert response.json()["error"]["message"] == (
        "Firestore could not complete the data request."
    )
    assert (
        "Firestore request endpoint=/help-request/sent status=503 "
        "category=FailedPrecondition"
    ) in caplog.text
    assert "private backend exception details" not in caplog.text


def test_help_request_notification_is_privacy_conscious_and_targets_request():
    from types import SimpleNamespace

    firestore = FakeFirestore()
    _seed_viewer(firestore)
    token = "test-fcm-device-token-9876543210"
    recipient = _client(
        firestore=firestore,
        user=AuthenticatedUser(
            uid="viewer-1",
            email="viewer@example.com",
            name="Father",
        ),
    )
    assert recipient.post(
        "/fcm/register", json={"token": token, "platform": "android"}
    ).status_code == 200

    sent_messages = []

    def send_multicast(message):
        sent_messages.append(message)
        return SimpleNamespace(
            success_count=1,
            failure_count=0,
            responses=[SimpleNamespace(exception=None)],
        )

    sender = _client(
        firestore=firestore,
        fcm_service=FcmService(firestore, send_multicast=send_multicast),
    )
    response = sender.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "en",
            "original_message": "I am lost at 23.8, 90.4",
            "original_transcript": "I am lost at 23.8, 90.4",
            "generated_summary": "User reported being lost.",
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "key-fcm-00000001",
        },
    )
    assert response.status_code == 200
    assert response.json()["saved"] is True
    assert response.json()["notification_status"] == "submitted"
    assert response.json()["request"]["notification_status"] == "submitted"
    assert len(sent_messages) == 1
    message = sent_messages[0]
    assert message.notification.title == "AmarGuard — Help Request from Owner"
    assert message.notification.body == "Open AmarGuard to view the help request."
    assert message.data["requestId"] == response.json()["request"]["request_id"]
    assert message.android.notification.channel_id == "care_signal_requests"
    assert "23.8" not in message.notification.body

    retry = sender.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "en",
            "original_message": "I am lost at 23.8, 90.4",
            "original_transcript": "I am lost at 23.8, 90.4",
            "generated_summary": "User reported being lost.",
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "key-fcm-00000001",
        },
    )
    assert retry.json()["created"] is False
    assert len(sent_messages) == 1


def test_invalid_fcm_token_is_removed():
    from hashlib import sha256
    from types import SimpleNamespace

    firestore = FakeFirestore()
    token = "expired-fcm-device-token-1234567890"
    token_path = f"fcmTokens/{sha256(token.encode('utf-8')).hexdigest()}"
    firestore.seed(token_path, {"ownerUid": "viewer-1", "token": token})
    service = FcmService(
        firestore,
        send_multicast=lambda message: SimpleNamespace(
            success_count=0,
            failure_count=1,
            responses=[
                SimpleNamespace(exception=SimpleNamespace(code="UNREGISTERED"))
            ],
        ),
    )

    status = service.send_help_request(
        request_id="request-1",
        recipient_uid="viewer-1",
        sender_display_name="Owner",
    )

    assert status == "failed"
    assert token_path not in firestore.store


def test_summary_builder_never_invents_location_or_battery():
    from app.agent_service import AgentService

    firestore = FakeFirestore()
    firestore.seed(
        "users/owner-1/devices/device-1",
        {
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "sharingState": "stopped",
        },
    )
    from app.family_tools import FamilyTools, ToolContext

    tools = FamilyTools(firestore)
    service = AgentService(_settings(), _FakeMetaClient(), tools)
    context = ToolContext(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
        device_id="device-1",
        now=datetime.now(timezone.utc),
    )
    summary, _ = service.process(
        transcript="I am lost",
        original_transcript="I am lost",
        language="en",
        context=context,
    )
    assert summary.last_authorized_location is None
    assert summary.last_reported_battery is None
    assert summary.location_freshness_status is LocationFreshnessStatus.sharing_disabled
    assert summary.detected_language is DetectedLanguage.english
    assert summary.request_type in {RequestType.lost, RequestType.unknown}


def test_agent_summary_only_resolves_ai_suggestion_against_spoken_contact():
    from app.agent_service import AgentService

    service = AgentService(_settings(), _FakeMetaClient(), object())
    contacts = {
        "approved_contacts": [
            {
                "recipient_uid": "father-uid",
                "display_name": "father",
                "alias": "",
                "relationship": "parent",
            },
            {
                "recipient_uid": "son-uid",
                "display_name": "son",
                "alias": "",
                "relationship": "child",
            },
        ]
    }
    summary = service._build_summary(
        model_output={"suggested_recipient": "father"},
        transcript="Please ask my son to call",
        original_transcript="Please ask my son to call",
        language="en",
        tool_log=[
            {"tool": "get_approved_family_contacts", "payload": contacts}
        ],
        ai_recipient_suggestion="father",
    )

    assert [item.recipient_uid for item in summary.approved_recipient_options] == [
        "father-uid",
        "son-uid",
    ]
    assert summary.suggested_recipient_uid is None
    assert summary.recipient_match_status == "manual_selection"


def test_invalid_transcribe_language_is_rejected():
    client = _client()
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "fr"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_language"


def test_oversized_audio_is_rejected():
    client = _client(settings=_settings(max_audio_upload_bytes=64))
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "payload_too_large"


def test_unsupported_audio_format_is_rejected():
    client = _client()
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", b"not-a-wav-file", "audio/wav")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "unsupported_audio"


def test_missing_api_key_error_is_reported_by_voice_endpoint():
    meta = _FakeMetaClient(error=MissingApiKeyError())
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "missing_api_key"


def test_audio_format_error_is_reported():
    meta = _FakeMetaClient(error=AudioFormatError("unsupported sample rate"))
    client = _client(meta_client=meta)
    response = client.post(
        "/voice/transcribe",
        data={"consent_to_process": "true", "language": "bn"},
        files={"audio": ("recording.wav", _wav_bytes(), "audio/wav")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "unsupported_audio"


def test_app_restart_persistence_reads_existing_request():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    first_client = _client(firestore=firestore)
    payload = {
        "recipient_uid": "viewer-1",
        "language": "en",
        "original_message": "I am lost",
        "original_transcript": "I am lost",
        "generated_summary": "User reported being lost.",
        "verified_data_snapshot": {},
        "sender_device_id": "device-1",
        "idempotency_key": "key-restart-0001",
    }
    created = first_client.post("/help-request", json=payload).json()["request"]

    restarted = _client(firestore=firestore)
    sent = restarted.get("/help-request/sent")
    records = sent.json()["requests"]
    assert len(records) == 1
    assert records[0]["request_id"] == created["request_id"]


def test_server_builds_verified_snapshot_and_ignores_client_values():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    now = datetime.now(timezone.utc)
    firestore.seed(
        "users/owner-1/devices/device-1/location/current",
        {
            "latitude": 23.8,
            "longitude": 90.4,
            "accuracy": 12,
            "capturedAt": now,
            "syncedAt": now,
        },
    )
    firestore.seed(
        "users/owner-1/devices/device-1/status/current",
        {"batteryLevel": 55, "isCharging": False, "batteryObservedAt": now},
    )
    firestore.seed(
        "users/owner-1",
        {"displayName": "Owner", "email": "owner@example.com", "phoneNumber": "+8801700000000"},
    )
    client = _client(firestore=firestore)

    response = client.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "en",
            "original_message": "I am lost",
            "original_transcript": "I am lost",
            "generated_summary": "User reported being lost.",
            "verified_data_snapshot": {
                "last_authorized_location": {"latitude": 0.0, "longitude": 0.0},
                "last_reported_battery": {"level": 99},
                "sender_phone_number": "+10000000000",
            },
            "sender_device_id": "device-1",
            "idempotency_key": "key-snapshot-001",
            "request_type": "lost",
            "detected_language": "en",
            "suggested_safe_actions": ["Call my son"],
        },
    )
    assert response.status_code == 200
    snapshot = response.json()["request"]["verified_data_snapshot"]
    assert snapshot["last_authorized_location"]["latitude"] == 23.8
    assert snapshot["last_authorized_location"]["longitude"] == 90.4
    assert snapshot["last_reported_battery"]["level"] == 55
    assert snapshot["sender_phone_number"] == "+8801700000000"
    assert snapshot["request_type"] == "lost"
    assert snapshot["detected_language"] == "en"
    assert snapshot["suggested_safe_actions"] == ["Call my son"]


def test_verified_snapshot_reports_unavailable_when_sharing_is_stopped():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    firestore.seed(
        "users/owner-1/devices/device-1",
        {
            "ownerUid": "owner-1",
            "deviceId": "device-1",
            "nickname": "My Device",
            "sharingState": "stopped",
        },
    )
    client = _client(firestore=firestore)

    response = client.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "en",
            "original_message": "I am lost",
            "original_transcript": "I am lost",
            "generated_summary": "User reported being lost.",
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "key-stopped-001",
        },
    )
    assert response.status_code == 200
    snapshot = response.json()["request"]["verified_data_snapshot"]
    assert snapshot["last_authorized_location"] is None
    assert snapshot["location_freshness_status"] == "sharing_disabled"


def test_silent_speak_help_request_does_not_attach_location_or_battery():
    firestore = FakeFirestore()
    _seed_viewer(firestore)
    now = datetime.now(timezone.utc)
    firestore.seed(
        "users/owner-1/devices/device-1/location/current",
        {
            "latitude": 23.8,
            "longitude": 90.4,
            "accuracy": 12,
            "capturedAt": now,
            "syncedAt": now,
        },
    )
    firestore.seed(
        "users/owner-1/devices/device-1/status/current",
        {"batteryLevel": 55, "isCharging": False, "batteryObservedAt": now},
    )
    client = _client(firestore=firestore)

    response = client.post(
        "/help-request",
        json={
            "recipient_uid": "viewer-1",
            "language": "bn",
            "original_message": "আমার সাহায্য দরকার।",
            "original_transcript": "আমার সাহায্য দরকার।",
            "generated_summary": "আমার সাহায্য দরকার।",
            "verified_data_snapshot": {},
            "sender_device_id": "device-1",
            "idempotency_key": "silent-speak-privacy-01",
            "include_location": False,
        },
    )

    assert response.status_code == 200
    snapshot = response.json()["request"]["verified_data_snapshot"]
    assert snapshot["sender_display_name"] == "Owner"
    assert "last_authorized_location" not in snapshot
    assert "location_accuracy" not in snapshot
    assert "last_reported_battery" not in snapshot
    assert "sender_phone_number" not in snapshot


def test_summary_model_rejects_missing_fields():
    summary = AssistanceSummary(
        request_type=RequestType.lost,
        detected_language=DetectedLanguage.bengali,
        original_transcript="আমি পথ হারিয়ে ফেলেছি",
        user_confirmed_transcript="আমি পথ হারিয়ে ফেলেছি",
        assistance_summary="ব্যবহারকারী পথ হারিয়ে ফেলেছেন।",
        location_freshness_status=LocationFreshnessStatus.fresh,
    )
    assert summary.consent_required is True
    assert summary.approved_recipient_options == []
