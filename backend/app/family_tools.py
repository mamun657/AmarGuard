import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from google.auth.exceptions import GoogleAuthError
from google.api_core.exceptions import GoogleAPICallError

from .errors import MetaApiError, MetaApiErrorCode
from .firebase_gateway import FirestoreAccessError, FirestorePermissionDeniedError

logger = logging.getLogger("caresignal.family_tools")

DEVICE_SHARING_ACTIVE = "active"
DEVICE_SHARING_PAUSED = "paused"
DEVICE_SHARING_STOPPED = "stopped"
DEVICE_SHARING_NOT_CONFIGURED = "notConfigured"
DEVICE_SHARING_PERMISSION_DISABLED = "permissionDisabled"

SHAREABLE_STATES = {DEVICE_SHARING_ACTIVE, DEVICE_SHARING_PAUSED}

FRESH_WINDOW_SECONDS = 5 * 60
STALE_WINDOW_SECONDS = 30 * 60


@dataclass
class ToolContext:
    uid: str
    email: str
    display_name: str
    device_id: str
    now: datetime


class FamilyTools:
    def __init__(self, firestore: Any) -> None:
        self._db = firestore

    def execute(self, name: str, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        handler = self._handlers().get(name)
        if handler is None:
            raise MetaApiError(
                MetaApiErrorCode.INVALID_REQUEST,
                f"Tool '{name}' is not allowed.",
                status_code=400,
            )
        try:
            return handler(arguments, context)
        except Exception as error:
            from google.api_core.exceptions import PermissionDenied

            if isinstance(error, PermissionDenied):
                raise FirestorePermissionDeniedError(
                    "The authenticated account is not permitted to read family authorization data."
                ) from error
            if isinstance(error, GoogleAPICallError):
                raise FirestoreAccessError(
                    "Firestore could not complete the family data request."
                ) from error
            if isinstance(error, GoogleAuthError):
                raise FirestoreAccessError(
                    "Google credentials could not authorize the Firestore data request."
                ) from error
            raise

    def _handlers(self) -> dict[str, Any]:
        return {
            "get_current_user_identity": self.get_current_user_identity,
            "get_approved_family_contacts": self.get_approved_family_contacts,
            "get_own_device_sharing_status": self.get_own_device_sharing_status,
            "get_last_authorized_location": self.get_last_authorized_location,
            "get_location_last_sync_time": self.get_location_last_sync_time,
            "get_last_reported_battery": self.get_last_reported_battery,
            "get_connection_status": self.get_connection_status,
        }

    def _device_ref(self, uid: str, device_id: str) -> Any:
        if self._db is None:
            return None
        return self._db.collection("users").document(uid).collection("devices").document(device_id)

    def _owned_device(self, uid: str, device_id: str) -> dict[str, Any]:
        if self._db is None:
            return {
                "ownerUid": uid,
                "deviceId": device_id,
                "nickname": "My Device",
                "sharingState": DEVICE_SHARING_ACTIVE,
            }
        snapshot = self._device_ref(uid, device_id).get()
        data = snapshot.to_dict() or {}
        if data.get("ownerUid") != uid or data.get("deviceId") != device_id:
            raise MetaApiError(
                MetaApiErrorCode.INVALID_REQUEST,
                "Device does not belong to the authenticated user.",
                status_code=403,
            )
        return data

    def get_current_user_identity(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        display_name = context.display_name or "AmarGuard user"
        email = context.email
        phone_number = ""
        if self._db is not None:
            snapshot = self._db.collection("users").document(context.uid).get()
            data = snapshot.to_dict() or {}
            display_name = data.get("displayName") or display_name
            email = data.get("email") or email
            phone_number = str(data.get("phoneNumber") or "")
        return {
            "uid": context.uid,
            "display_name": display_name,
            "email": email,
            "phone_number": phone_number,
            "device_id": context.device_id,
        }

    def build_verified_snapshot(self, context: ToolContext) -> dict[str, Any]:
        device = self.get_own_device_sharing_status({}, context)
        connection = self.get_connection_status({}, context)
        location = self.get_last_authorized_location({}, context)
        battery = self.get_last_reported_battery({}, context)
        identity = self.get_current_user_identity({}, context)

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
            location_accuracy = as_float(location.get("accuracy"))
            location_timestamp = location.get("captured_at") or location.get("synced_at")

        battery_payload: dict[str, Any] | None = None
        if battery.get("available") is True:
            battery_payload = {
                "level": battery.get("level"),
                "is_charging": battery.get("is_charging"),
                "observed_at": battery.get("observed_at"),
            }

        return {
            "last_authorized_location": location_payload,
            "location_accuracy": location_accuracy,
            "location_timestamp": location_timestamp,
            "location_freshness_status": resolve_freshness(location, device, connection),
            "last_reported_battery": battery_payload,
            "sender_phone_number": str(identity.get("phone_number") or ""),
            "sender_display_name": str(identity.get("display_name") or ""),
        }

    def get_approved_family_contacts(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        self._owned_device(context.uid, context.device_id)
        if self._db is None:
            return {"approved_contacts": [], "count": 0}
        grants = self._device_ref(context.uid, context.device_id).collection("approvedViewers").get()
        contacts: list[dict[str, Any]] = []
        for grant in grants:
            data = grant.to_dict() or {}
            if data.get("active") is not True:
                continue
            if data.get("viewerUid") != grant.id:
                continue
            if data.get("ownerUid") != context.uid:
                continue
            if data.get("deviceId") != context.device_id:
                continue
            alias = str(data.get("alias") or "").strip()
            display_name = str(data.get("viewerDisplayName") or "").strip()
            if not display_name or display_name.casefold() == "family member":
                profile = self._db.collection("users").document(grant.id).get()
                profile_data = profile.to_dict() or {}
                display_name = str(profile_data.get("displayName") or "").strip()
            contacts.append(
                {
                    "recipient_uid": grant.id,
                    "display_name": alias or display_name or "Family member",
                    "alias": alias,
                    "relationship": data.get("relationship") or "other",
                    "granted_at": _iso(data.get("grantedAt")),
                }
            )
        return {"approved_contacts": contacts, "count": len(contacts)}

    def get_own_device_sharing_status(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        device = self._owned_device(context.uid, context.device_id)
        state = str(device.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED)
        return {
            "device_id": context.device_id,
            "device_nickname": device.get("nickname") or "My Device",
            "sharing_state": state,
            "location_sharing_enabled": state in SHAREABLE_STATES,
        }

    def get_last_authorized_location(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        device = self._owned_device(context.uid, context.device_id)
        state = str(device.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED)
        if state not in SHAREABLE_STATES:
            return {
                "available": False,
                "reason": "location_sharing_disabled",
                "sharing_state": state,
            }
        if self._db is None:
            return {
                "available": False,
                "reason": "location_unavailable",
                "sharing_state": state,
            }
        snapshot = self._device_ref(context.uid, context.device_id).collection("location").document("current").get()
        data = snapshot.to_dict() or {}
        latitude = data.get("latitude")
        longitude = data.get("longitude")
        if not isinstance(latitude, (int, float)) or not isinstance(longitude, (int, float)):
            return {
                "available": False,
                "reason": "location_unavailable",
                "sharing_state": state,
            }
        captured_at = data.get("capturedAt")
        synced_at = data.get("syncedAt")
        return {
            "available": True,
            "latitude": float(latitude),
            "longitude": float(longitude),
            "accuracy": float(data.get("accuracy") or 0),
            "captured_at": _iso(captured_at),
            "synced_at": _iso(synced_at),
            "freshness": _freshness(captured_at, synced_at, context.now),
            "address_label": data.get("addressLabel"),
            "sharing_state": state,
        }

    def get_location_last_sync_time(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        device = self._owned_device(context.uid, context.device_id)
        if self._db is None:
            return {
                "last_successful_upload": None,
                "last_heartbeat": None,
                "sharing_state": device.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED,
            }
        snapshot = self._device_ref(context.uid, context.device_id).collection("status").document("current").get()
        data = snapshot.to_dict() or {}
        return {
            "last_successful_upload": _iso(data.get("lastSuccessfulUpload")),
            "last_heartbeat": _iso(data.get("lastHeartbeat")),
            "sharing_state": data.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED,
        }

    def get_last_reported_battery(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        self._owned_device(context.uid, context.device_id)
        if self._db is None:
            return {"available": False, "reason": "battery_unavailable"}
        snapshot = self._device_ref(context.uid, context.device_id).collection("status").document("current").get()
        data = snapshot.to_dict() or {}
        level = data.get("batteryLevel")
        if not isinstance(level, int) or level < 0 or level > 100:
            return {"available": False, "reason": "battery_unavailable"}
        return {
            "available": True,
            "level": level,
            "is_charging": bool(data.get("isCharging")),
            "observed_at": _iso(data.get("batteryObservedAt")),
        }

    def get_connection_status(self, arguments: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        device = self._owned_device(context.uid, context.device_id)
        if self._db is None:
            return {
                "sharing_state": device.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED,
                "last_successful_upload": None,
                "recently_connected": True,
            }
        snapshot = self._device_ref(context.uid, context.device_id).collection("status").document("current").get()
        data = snapshot.to_dict() or {}
        last_upload = data.get("lastSuccessfulUpload")
        connected = False
        if last_upload is not None:
            connected = _age_seconds(last_upload, context.now) <= FRESH_WINDOW_SECONDS
        return {
            "sharing_state": device.get("sharingState") or DEVICE_SHARING_NOT_CONFIGURED,
            "last_successful_upload": _iso(last_upload),
            "recently_connected": connected,
        }


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _as_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if hasattr(value, "timestamp"):
        try:
            return value.timestamp().astimezone(timezone.utc)
        except Exception:
            return None
    return None


def _age_seconds(value: Any, now: datetime) -> float | None:
    parsed = _as_datetime(value)
    if parsed is None:
        return None
    return max(0.0, (now - parsed).total_seconds())


def _freshness(captured_at: Any, synced_at: Any, now: datetime) -> str:
    reference = _as_datetime(captured_at) or _as_datetime(synced_at)
    if reference is None:
        return "unavailable"
    age = max(0.0, (now - reference).total_seconds())
    if age <= FRESH_WINDOW_SECONDS:
        return "fresh"
    if age <= STALE_WINDOW_SECONDS:
        return "stale"
    return "unavailable"


def as_float(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None


def resolve_freshness(
    location: dict[str, Any],
    device: dict[str, Any],
    connection: dict[str, Any],
) -> str:
    if location.get("available") is True:
        raw = str(location.get("freshness") or "")
        if raw in {"fresh", "stale"}:
            return raw
        return "unavailable"
    state = str(
        device.get("sharing_state")
        or connection.get("sharing_state")
        or ""
    )
    if state == DEVICE_SHARING_PAUSED:
        return "paused"
    if state == DEVICE_SHARING_PERMISSION_DISABLED:
        return "permission_disabled"
    if state == DEVICE_SHARING_NOT_CONFIGURED:
        return "not_configured"
    if state in {DEVICE_SHARING_STOPPED, ""}:
        return "sharing_disabled"
    return "unavailable"
