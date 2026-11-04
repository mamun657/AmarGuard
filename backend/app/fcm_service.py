import hashlib
import logging
from typing import Any, Callable

from firebase_admin import messaging
from firebase_admin.exceptions import FirebaseError
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import GoogleAuthError

from .firebase_gateway import get_firebase_app

logger = logging.getLogger("caresignal.fcm")

_TOKEN_COLLECTION = "fcmTokens"
_MAX_MULTICAST_TOKENS = 500
_INVALID_TOKEN_CODES = {"UNREGISTERED", "SENDER_ID_MISMATCH"}


class FcmService:
    def __init__(
        self,
        firestore: Any,
        send_multicast: Callable[[Any], Any] | None = None,
    ) -> None:
        self._db = firestore
        self._send_multicast_override = send_multicast

    def register_token(self, *, uid: str, token: str, platform: str) -> None:
        token_id = _token_id(token)
        self._db.collection(_TOKEN_COLLECTION).document(token_id).set(
            {
                "ownerUid": uid,
                "token": token,
                "platform": platform,
                "updatedAt": _server_timestamp(),
            },
            merge=True,
        )
        logger.info("FCM token registration uid=%s outcome=registered", uid)

    def unregister_token(self, *, uid: str, token: str) -> bool:
        token_id = _token_id(token)
        ref = self._db.collection(_TOKEN_COLLECTION).document(token_id)
        snapshot = ref.get()
        if not snapshot.exists or (snapshot.to_dict() or {}).get("ownerUid") != uid:
            return False
        ref.delete()
        logger.info("FCM token registration uid=%s outcome=unregistered", uid)
        return True

    def send_help_request(
        self,
        *,
        request_id: str,
        recipient_uid: str,
        sender_display_name: str,
    ) -> str:
        try:
            token_docs = (
                self._db.collection(_TOKEN_COLLECTION)
                .where("ownerUid", "==", recipient_uid)
                .get()
            )
        except (FirebaseError, GoogleAPICallError, GoogleAuthError) as error:
            logger.warning(
                "CareSignal notification request_id=%s recipient_uid=%s outcome=failed error=%s",
                request_id,
                recipient_uid,
                type(error).__name__,
            )
            return "failed"
        token_records = [
            (doc, str((doc.to_dict() or {}).get("token") or ""))
            for doc in token_docs
        ]
        token_records = [(doc, token) for doc, token in token_records if token]
        if not token_records:
            logger.info(
                "CareSignal notification request_id=%s recipient_uid=%s outcome=no_tokens",
                request_id,
                recipient_uid,
            )
            return "unavailable"

        title_name = sender_display_name.strip() or "family member"
        success_count = 0
        failure_count = 0
        for offset in range(0, len(token_records), _MAX_MULTICAST_TOKENS):
            batch = token_records[offset : offset + _MAX_MULTICAST_TOKENS]
            message = messaging.MulticastMessage(
                tokens=[token for _, token in batch],
                notification=messaging.Notification(
                    title=f"AmarGuard — Help Request from {title_name}"[:150],
                    body="Open AmarGuard to view the help request.",
                ),
                data={
                    "type": "help_request",
                    "requestId": request_id,
                },
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="care_signal_requests",
                    ),
                ),
            )

            try:
                response = self._send_multicast(message)
            except FirebaseError as error:
                failure_count += len(batch)
                logger.warning(
                    "CareSignal notification request_id=%s recipient_uid=%s outcome=failed error=%s",
                    request_id,
                    recipient_uid,
                    type(error).__name__,
                )
                continue

            success_count += response.success_count
            failure_count += response.failure_count
            for (token_doc, _), token_response in zip(batch, response.responses):
                error = token_response.exception
                if error is not None and _error_code(error) in _INVALID_TOKEN_CODES:
                    self._db.collection(_TOKEN_COLLECTION).document(token_doc.id).delete()

        status = "submitted" if success_count else "failed"
        logger.info(
            "CareSignal notification request_id=%s recipient_uid=%s outcome=%s accepted=%s failed=%s",
            request_id,
            recipient_uid,
            status,
            success_count,
            failure_count,
        )
        return status

    def _send_multicast(self, message: Any) -> Any:
        if self._send_multicast_override is not None:
            return self._send_multicast_override(message)
        return messaging.send_each_for_multicast(message, app=get_firebase_app())


def _token_id(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _server_timestamp() -> Any:
    from google.cloud.firestore import SERVER_TIMESTAMP

    return SERVER_TIMESTAMP


def _error_code(error: Exception) -> str:
    code = getattr(error, "code", "")
    return str(code() if callable(code) else code).upper()
