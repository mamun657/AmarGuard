from datetime import datetime

import pytest

from app.incident_service import IncidentService, _build_request_id

from .fakes import FakeFirestore


def _service() -> IncidentService:
    return IncidentService(FakeFirestore())


def _create(service: IncidentService, **overrides):
    payload = {
        "sender_uid": "owner-1",
        "sender_device_id": "device-1",
        "recipient_uid": "viewer-1",
        "language": "bn",
        "original_message": "আমি পথ হারিয়ে ফেলেছি",
        "original_transcript": "আমি পথ হারিয়ে ফেলেছি",
        "generated_summary": "User reported being lost",
        "verified_data_snapshot": {"last_reported_battery": {"level": 55}},
        "idempotency_key": "key-123",
    }
    payload.update(overrides)
    return service.create_help_request(**payload)


def test_request_id_is_deterministic_per_sender_and_key():
    first = _build_request_id("owner-1", "key-123")
    second = _build_request_id("owner-1", "key-123")
    third = _build_request_id("owner-2", "key-123")
    assert first == second
    assert first != third


def test_create_help_request_is_idempotent():
    service = _service()
    record, created = _create(service)
    assert created is True
    assert record.status == "sent"
    assert record.sender_uid == "owner-1"
    assert record.recipient_uid == "viewer-1"

    duplicate, created_again = _create(service)
    assert created_again is False
    assert duplicate.request_id == record.request_id


def test_only_recipient_can_acknowledge():
    service = _service()
    record, _ = _create(service)
    with pytest.raises(PermissionError):
        service.acknowledge(
            request_id=record.request_id,
            recipient_uid="stranger-1",
        )

    updated = service.acknowledge(
        request_id=record.request_id,
        recipient_uid="viewer-1",
    )
    assert updated.status == "acknowledged"
    assert isinstance(updated.acknowledged_at, datetime)


def test_sender_cannot_acknowledge():
    service = _service()
    record, _ = _create(service)
    with pytest.raises(PermissionError):
        service.acknowledge(
            request_id=record.request_id,
            recipient_uid="owner-1",
        )


def test_missing_request_raises_lookup_error():
    service = _service()
    with pytest.raises(LookupError):
        service.acknowledge(request_id="req_missing", recipient_uid="viewer-1")


def test_recipient_listing_excludes_other_accounts():
    service = _service()
    _create(service, recipient_uid="viewer-1", idempotency_key="key-a")
    _create(service, recipient_uid="viewer-2", idempotency_key="key-b")
    inbox = service.list_for_recipient("viewer-1")
    assert len(inbox) == 1
    assert inbox[0].recipient_uid == "viewer-1"


def test_sender_listing_excludes_other_accounts():
    service = _service()
    _create(service, sender_uid="owner-1", idempotency_key="key-a")
    _create(service, sender_uid="owner-2", idempotency_key="key-b")
    sent = service.list_for_sender("owner-1")
    assert len(sent) == 1
    assert sent[0].sender_uid == "owner-1"
