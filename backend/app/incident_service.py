import logging
from datetime import datetime, timezone
from typing import Any

from google.api_core.exceptions import AlreadyExists
from google.cloud.firestore_v1 import Query

from .models import HelpRequestRecord

logger = logging.getLogger("caresignal.incident")

STATUS_SENT = "sent"
STATUS_ACKNOWLEDGED = "acknowledged"
STATUS_CANCELLED = "cancelled"

HELP_REQUESTS_COLLECTION = "helpRequests"

_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


_STORE: dict[str, dict[str, Any]] = {}


class IncidentService:
    def __init__(self, firestore: Any) -> None:
        self._db = firestore

    def _collection(self) -> Any:
        return self._db.collection(HELP_REQUESTS_COLLECTION)

    def create_help_request(
        self,
        *,
        sender_uid: str,
        sender_device_id: str,
        recipient_uid: str,
        language: str,
        original_message: str,
        original_transcript: str,
        generated_summary: str,
        verified_data_snapshot: dict[str, Any],
        idempotency_key: str,
    ) -> tuple[HelpRequestRecord, bool]:
        request_id = _build_request_id(sender_uid, idempotency_key)
        if self._db is None:
            if request_id in _STORE:
                existing = _STORE[request_id]
                if existing.get("senderUid") != sender_uid:
                    raise PermissionError("Request id collision with another sender.")
                _validate_duplicate(existing, sender_uid, sender_device_id, recipient_uid)
                return _to_record(request_id, existing), False
            payload = {
                "requestId": request_id,
                "senderUid": sender_uid,
                "senderDeviceId": sender_device_id,
                "recipientUid": recipient_uid,
                "requestedAt": datetime.now(timezone.utc),
                "language": language,
                "originalMessage": original_message,
                "originalTranscript": original_transcript,
                "verifiedDataSnapshot": verified_data_snapshot,
                "generatedSummary": generated_summary,
                "status": STATUS_SENT,
                "notificationStatus": "pending",
                "acknowledgedAt": None,
            }
            _STORE[request_id] = payload
            return _to_record(request_id, payload), True

        ref = self._collection().document(request_id)
        payload = {
            "requestId": request_id,
            "senderUid": sender_uid,
            "senderDeviceId": sender_device_id,
            "recipientUid": recipient_uid,
            "requestedAt": _server_timestamp(),
            "language": language,
            "originalMessage": original_message,
            "originalTranscript": original_transcript,
            "verifiedDataSnapshot": verified_data_snapshot,
            "generatedSummary": generated_summary,
            "status": STATUS_SENT,
            "notificationStatus": "pending",
            "acknowledgedAt": None,
        }
        try:
            ref.create(payload)
            return _to_record(request_id, payload), True
        except AlreadyExists:
            existing = ref.get().to_dict() or {}
            _validate_duplicate(existing, sender_uid, sender_device_id, recipient_uid)
            return _to_record(request_id, existing), False

    def update_notification_status(
        self,
        *,
        request_id: str,
        status: str,
    ) -> HelpRequestRecord:
        if status not in {"submitted", "failed", "unavailable"}:
            raise ValueError("Invalid notification status.")
        if self._db is None:
            data = _STORE.get(request_id)
            if data is None:
                raise LookupError("Help request not found.")
            data["notificationStatus"] = status
            data["notificationAttemptedAt"] = datetime.now(timezone.utc)
            return _to_record(request_id, data)
        ref = self._collection().document(request_id)
        ref.update(
            {
                "notificationStatus": status,
                "notificationAttemptedAt": _server_timestamp(),
            }
        )
        snapshot = ref.get()
        return _to_record(request_id, snapshot.to_dict() or {})

    def acknowledge(self, *, request_id: str, recipient_uid: str) -> HelpRequestRecord:
        if self._db is None:
            if request_id not in _STORE:
                raise LookupError("Help request not found.")
            data = _STORE[request_id]
            if data.get("recipientUid") != recipient_uid:
                raise PermissionError("Only the intended recipient can acknowledge this request.")
            data["status"] = STATUS_ACKNOWLEDGED
            data["acknowledgedAt"] = datetime.now(timezone.utc)
            return _to_record(request_id, data)

        ref = self._collection().document(request_id)
        snapshot = ref.get()
        if not snapshot.exists:
            raise LookupError("Help request not found.")
        data = snapshot.to_dict() or {}
        if data.get("recipientUid") != recipient_uid:
            raise PermissionError(
                "Only the intended recipient can acknowledge this request."
            )
        if data.get("status") == STATUS_ACKNOWLEDGED:
            return _to_record(request_id, data)
        ref.update(
            {
                "status": STATUS_ACKNOWLEDGED,
                "acknowledgedAt": _server_timestamp(),
            }
        )
        refreshed = ref.get()
        return _to_record(request_id, refreshed.to_dict() or data)

    def list_for_recipient(
        self,
        recipient_uid: str,
        limit: int = 50,
    ) -> list[HelpRequestRecord]:
        if self._db is None:
            matches = [
                _to_record(rid, data)
                for rid, data in _STORE.items()
                if data.get("recipientUid") == recipient_uid
            ]
            matches.sort(key=lambda item: item.requested_at or _EPOCH, reverse=True)
            return matches[:limit]

        snapshot = (
            self._collection()
            .where("recipientUid", "==", recipient_uid)
            .order_by("requestedAt", direction=Query.DESCENDING)
            .limit(limit)
            .get()
        )
        records = [_to_record(doc.id, doc.to_dict() or {}) for doc in snapshot]
        records.sort(key=lambda item: item.requested_at or _EPOCH, reverse=True)
        return records

    def list_for_sender(
        self,
        sender_uid: str,
        limit: int = 50,
    ) -> list[HelpRequestRecord]:
        if self._db is None:
            matches = [
                _to_record(rid, data)
                for rid, data in _STORE.items()
                if data.get("senderUid") == sender_uid
            ]
            matches.sort(key=lambda item: item.requested_at or _EPOCH, reverse=True)
            return matches[:limit]

        snapshot = (
            self._collection()
            .where("senderUid", "==", sender_uid)
            .order_by("requestedAt", direction=Query.DESCENDING)
            .limit(limit)
            .get()
        )
        records = [_to_record(doc.id, doc.to_dict() or {}) for doc in snapshot]
        records.sort(key=lambda item: item.requested_at or _EPOCH, reverse=True)
        return records

    def read(self, request_id: str) -> HelpRequestRecord | None:
        if self._db is None:
            data = _STORE.get(request_id)
            return _to_record(request_id, data) if data else None

        snapshot = self._collection().document(request_id).get()
        if not snapshot.exists:
            return None
        return _to_record(request_id, snapshot.to_dict() or {})


def _server_timestamp() -> Any:
    from google.cloud.firestore import SERVER_TIMESTAMP

    return SERVER_TIMESTAMP


def _build_request_id(sender_uid: str, idempotency_key: str) -> str:
    import hashlib

    digest = hashlib.sha256(
        f"{sender_uid}:{idempotency_key}".encode("utf-8")
    ).hexdigest()[:32]
    return f"req_{digest}"


def _as_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str) and value:
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def _to_record(request_id: str, data: dict[str, Any]) -> HelpRequestRecord:
    return HelpRequestRecord(
        request_id=request_id,
        sender_uid=str(data.get("senderUid") or ""),
        sender_device_id=str(data.get("senderDeviceId") or ""),
        recipient_uid=str(data.get("recipientUid") or ""),
        requested_at=_as_datetime(data.get("requestedAt")),
        language=str(data.get("language") or "en"),
        original_message=str(data.get("originalMessage") or ""),
        original_transcript=str(data.get("originalTranscript") or ""),
        verified_data_snapshot=data.get("verifiedDataSnapshot") or {},
        generated_summary=str(data.get("generatedSummary") or ""),
        status=str(data.get("status") or STATUS_SENT),
        notification_status=str(data.get("notificationStatus") or "pending"),
        acknowledged_at=_as_datetime(data.get("acknowledgedAt")),
    )


def _validate_duplicate(
    existing: dict[str, Any],
    sender_uid: str,
    sender_device_id: str,
    recipient_uid: str,
) -> None:
    if (
        existing.get("senderUid") != sender_uid
        or existing.get("senderDeviceId") != sender_device_id
        or existing.get("recipientUid") != recipient_uid
    ):
        raise PermissionError(
            "The idempotency key was already used for a different request."
        )
