from datetime import datetime, timezone

import pytest

from app.agent_service import (
    _parse_json_object,
    _parse_request_type,
    detect_language,
)
from app.errors import MetaApiError
from app.family_tools import FamilyTools, ToolContext
from app.models import DetectedLanguage, LocationFreshnessStatus, RequestType

from .fakes import FakeFirestore


def _context() -> ToolContext:
    return ToolContext(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
        device_id="device-1",
        now=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )


def _tools(tree: dict) -> FamilyTools:
    firestore = FakeFirestore()
    for path, payload in tree.items():
        firestore.seed(path, payload)
    return FamilyTools(firestore)


DEVICE = {
    "ownerUid": "owner-1",
    "deviceId": "device-1",
    "nickname": "My Device",
    "sharingState": "active",
}


def test_rejects_unknown_tool():
    with pytest.raises(MetaApiError):
        _tools({}).execute("drop_everything", {}, _context())


def test_rejects_device_not_owned_by_user():
    tools = _tools(
        {
            "users/owner-1/devices/device-1": {
                "ownerUid": "someone-else",
                "deviceId": "device-1",
            }
        }
    )
    with pytest.raises(MetaApiError) as error:
        tools.execute("get_own_device_sharing_status", {}, _context())
    assert error.value.status_code == 403


def test_location_hidden_when_sharing_stopped():
    tools = _tools(
        {
            "users/owner-1/devices/device-1": {
                **DEVICE,
                "sharingState": "stopped",
            },
            "users/owner-1/devices/device-1/location/current": {
                "latitude": 23.8,
                "longitude": 90.4,
                "accuracy": 12,
            },
        }
    )
    result = tools.execute("get_last_authorized_location", {}, _context())
    assert result["available"] is False
    assert result["reason"] == "location_sharing_disabled"
    assert "latitude" not in result


def test_location_available_when_sharing_active():
    tools = _tools(
        {
            "users/owner-1/devices/device-1": dict(DEVICE),
            "users/owner-1/devices/device-1/location/current": {
                "latitude": 23.8,
                "longitude": 90.4,
                "accuracy": 12,
                "capturedAt": datetime(2026, 1, 1, tzinfo=timezone.utc),
                "syncedAt": datetime(2026, 1, 1, tzinfo=timezone.utc),
            },
        }
    )
    result = tools.execute("get_last_authorized_location", {}, _context())
    assert result["available"] is True
    assert result["latitude"] == 23.8
    assert result["freshness"] == "fresh"


def test_stale_location_is_marked_stale_not_live():
    captured = datetime(2025, 12, 31, 23, 30, tzinfo=timezone.utc)
    tools = _tools(
        {
            "users/owner-1/devices/device-1": dict(DEVICE),
            "users/owner-1/devices/device-1/location/current": {
                "latitude": 23.8,
                "longitude": 90.4,
                "accuracy": 12,
                "capturedAt": captured,
                "syncedAt": captured,
            },
        }
    )
    result = tools.execute("get_last_authorized_location", {}, _context())
    assert result["available"] is True
    assert result["freshness"] == "stale"


def test_approved_contacts_only_include_active_grants():
    tools = _tools(
        {
            "users/owner-1/devices/device-1": dict(DEVICE),
            "users/owner-1/devices/device-1/approvedViewers/viewer-1": {
                "viewerUid": "viewer-1",
                "ownerUid": "owner-1",
                "deviceId": "device-1",
                "active": True,
                "viewerDisplayName": "Son",
            },
            "users/owner-1/devices/device-1/approvedViewers/viewer-2": {
                "viewerUid": "viewer-2",
                "ownerUid": "owner-1",
                "deviceId": "device-1",
                "active": False,
                "viewerDisplayName": "Revoked",
            },
        }
    )
    result = tools.execute("get_approved_family_contacts", {}, _context())
    assert result["count"] == 1
    assert result["approved_contacts"][0]["recipient_uid"] == "viewer-1"


def test_no_approved_contacts_returns_empty():
    tools = _tools({"users/owner-1/devices/device-1": dict(DEVICE)})
    result = tools.execute("get_approved_family_contacts", {}, _context())
    assert result["count"] == 0
    assert result["approved_contacts"] == []


def test_battery_unavailable_is_not_fabricated():
    tools = _tools({"users/owner-1/devices/device-1": dict(DEVICE)})
    result = tools.execute("get_last_reported_battery", {}, _context())
    assert result["available"] is False
    assert "level" not in result


def test_battery_reported_when_present():
    tools = _tools(
        {
            "users/owner-1/devices/device-1": dict(DEVICE),
            "users/owner-1/devices/device-1/status/current": {
                "batteryLevel": 42,
                "isCharging": False,
            },
        }
    )
    result = tools.execute("get_last_reported_battery", {}, _context())
    assert result["available"] is True
    assert result["level"] == 42


def test_detect_language_handles_code_switching():
    assert detect_language("আমি পথ হারিয়ে ফেলেছি") is DetectedLanguage.bengali
    assert detect_language("I am lost") is DetectedLanguage.english
    assert (
        detect_language("আমি path হারিয়ে ফেলেছি, please inform my family")
        is DetectedLanguage.mixed
    )


def test_detect_language_treats_romanized_bengali_as_mixed_for_bn_en():
    assert (
        detect_language("Ami lost hoye gesi, please inform koro", "bn-en")
        is DetectedLanguage.mixed
    )
    assert (
        detect_language("Ami lost hoye gesi, please inform koro", "en")
        is DetectedLanguage.english
    )


def test_parse_json_object_handles_fenced_output():
    parsed = _parse_json_object('```json\n{"request_type": "lost"}\n```')
    assert parsed["request_type"] == "lost"


def test_parse_json_object_handles_embedded_object():
    parsed = _parse_json_object('prefix {"assistance_summary": "ok"} suffix')
    assert parsed["assistance_summary"] == "ok"


def test_parse_json_object_handles_invalid_output():
    assert _parse_json_object("not json at all") == {}


def test_request_type_parsing_falls_back_to_unknown():
    assert _parse_request_type("not-a-type") is RequestType.unknown
    assert _parse_request_type("lost") is RequestType.lost


def test_location_freshness_status_values():
    assert LocationFreshnessStatus.fresh.value == "fresh"
    assert LocationFreshnessStatus.sharing_disabled.value == "sharing_disabled"
