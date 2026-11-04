import json
import logging
import os
from pathlib import Path
from threading import RLock
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore as admin_firestore
from google.auth.exceptions import DefaultCredentialsError
from google.api_core.exceptions import GoogleAPICallError, PermissionDenied

logger = logging.getLogger("caresignal.firebase")

_app: firebase_admin.App | None = None
_firestore: Any = None
_firebase_lock = RLock()
_BACKEND_DIR = Path(__file__).resolve().parents[1]


class FirestoreUnavailableError(RuntimeError):
    pass


class FirebaseCredentialsMissingError(FirestoreUnavailableError):
    pass


class FirestoreInitializationError(FirestoreUnavailableError):
    pass


class FirestorePermissionDeniedError(RuntimeError):
    pass


class FirestoreAccessError(RuntimeError):
    pass


def get_firebase_app() -> firebase_admin.App:
    global _app
    with _firebase_lock:
        from .config import get_settings

        settings = get_settings()
        credential_path = _configured_path(
            os.getenv("FIREBASE_CREDENTIALS_PATH")
            or settings.firebase_credentials_path
        )
        project_id = (
            os.getenv("FIREBASE_PROJECT_ID") or settings.firebase_project_id
        ).strip()

        if _app is not None:
            _validate_app_project(_app, project_id)
            return _app
        try:
            _app = firebase_admin.get_app()
            _validate_app_project(_app, project_id)
            return _app
        except ValueError:
            pass

        try:
            if credential_path:
                if not credential_path.is_file():
                    raise FirebaseCredentialsMissingError(
                        "The Firebase Admin credentials file configured by "
                        "FIREBASE_CREDENTIALS_PATH does not exist. Set it in "
                        "backend/.env to a valid Firebase service-account JSON file "
                        "for this project, then restart the backend."
                    )
                credential = credentials.Certificate(str(credential_path))
            else:
                credential = _application_default_credentials()

            options = {"projectId": project_id} if project_id else None
            try:
                _app = firebase_admin.initialize_app(credential, options)
            except ValueError:
                _app = firebase_admin.get_app()
            _validate_app_project(_app, project_id)
            return _app
        except (FirebaseCredentialsMissingError, DefaultCredentialsError):
            raise
        except Exception as error:
            logger.error(
                "Firebase Admin initialization failed: %s",
                type(error).__name__,
            )
            raise FirestoreInitializationError(
                "Firebase Admin could not initialize with the configured credentials."
            ) from error


def _validate_app_project(app: firebase_admin.App, expected_project_id: str) -> None:
    actual_project_id = app.project_id
    if expected_project_id and actual_project_id and actual_project_id != expected_project_id:
        raise FirestoreInitializationError(
            "The initialized Firebase app does not match FIREBASE_PROJECT_ID."
        )


def _application_default_credentials() -> Any:
    from .config import get_settings

    configured_adc_path = (
        os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        or get_settings().google_application_credentials
    ).strip()
    if configured_adc_path:
        adc_path = _configured_path(configured_adc_path)
        if not adc_path.is_file():
            raise FirebaseCredentialsMissingError(
                "The file configured by GOOGLE_APPLICATION_CREDENTIALS does not "
                "exist. Check backend/.env and restart the backend."
            )
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(adc_path)
    elif not _default_adc_file().is_file() and not _has_cloud_adc_source():
        raise _missing_firebase_credentials_error()

    credential = credentials.ApplicationDefault()
    try:
        credential.get_credential()
    except DefaultCredentialsError as error:
        raise _missing_firebase_credentials_error() from error
    return credential


def _configured_path(value: str) -> Path | None:
    value = value.strip()
    if not value:
        return None
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = _BACKEND_DIR / path
    return path.resolve()


def _default_adc_file() -> Path:
    cloud_sdk_dir = os.getenv("CLOUDSDK_CONFIG")
    if cloud_sdk_dir:
        return Path(cloud_sdk_dir).expanduser() / "application_default_credentials.json"
    if os.name == "nt":
        app_data = os.getenv("APPDATA")
        if app_data:
            return Path(app_data) / "gcloud" / "application_default_credentials.json"
    return Path.home() / ".config" / "gcloud" / "application_default_credentials.json"


def _has_cloud_adc_source() -> bool:
    return bool(
        os.getenv("K_SERVICE")
        or os.getenv("GAE_ENV")
        or os.getenv("GCE_METADATA_HOST")
    )


def _missing_firebase_credentials_error() -> FirebaseCredentialsMissingError:
    return FirebaseCredentialsMissingError(
        "Firestore access is not configured. Set FIREBASE_CREDENTIALS_PATH in "
        "backend/.env to the absolute path of a Firebase service-account JSON file "
        "for this project, then restart the backend. Keep that file outside the "
        "repository. Alternatively, configure Google Application Default Credentials "
        "or set GOOGLE_APPLICATION_CREDENTIALS to that file."
    )


def reset_firebase_app() -> None:
    global _app, _firestore
    with _firebase_lock:
        if _app is not None:
            try:
                firebase_admin.delete_app(_app)
            except ValueError:
                pass
        _app = None
        _firestore = None


def verify_firebase_id_token(token: str, project_id: str | None = None) -> Any:
    try:
        from firebase_admin import auth as firebase_auth

        app = get_firebase_app()
        return firebase_auth.verify_id_token(token, app=app, check_revoked=False)
    except Exception as error:
        logger.warning(
            "Firebase Admin ID token verification failed category=%s; "
            "trying Firebase token verification fallback",
            type(error).__name__,
        )
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
        from .config import get_settings

        pid = project_id or get_settings().firebase_project_id or "guard-ab0d3"
        return google_id_token.verify_firebase_token(
            token,
            google_requests.Request(),
            audience=pid,
        )


def firestore_client() -> Any:
    global _firestore
    if _firestore is not None:
        return _firestore
    try:
        with _firebase_lock:
            if _firestore is None:
                _firestore = admin_firestore.client(app=get_firebase_app())
            return _firestore
    except FirebaseCredentialsMissingError:
        raise
    except FirestoreInitializationError:
        raise
    except PermissionDenied as error:
        raise FirestorePermissionDeniedError(
            "The backend credentials cannot initialize a Firestore client."
        ) from error
    except GoogleAPICallError as error:
        logger.error(
            "Firestore client initialization failed: %s",
            type(error).__name__,
        )
        raise FirestoreInitializationError(
            "The Firestore client could not be initialized."
        ) from error
    except Exception as error:
        logger.error(
            "Firestore client initialization failed: %s",
            type(error).__name__,
        )
        raise FirestoreInitializationError(
            "The Firestore client could not be initialized."
        ) from error


def firestore_credentials_configured() -> bool:
    from .config import get_settings

    settings = get_settings()
    path = _configured_path(
        os.getenv("FIREBASE_CREDENTIALS_PATH") or settings.firebase_credentials_path
    )
    adc_path = _configured_path(
        os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        or settings.google_application_credentials
    )
    if path:
        return path.is_file()
    if adc_path:
        return adc_path.is_file()
    if _app is not None:
        return _app.credential is not None

    if _default_adc_file().is_file():
        return True

    return _has_cloud_adc_source()


def translate_firestore_access_error(error: Exception) -> Exception:
    if isinstance(error, PermissionDenied):
        return FirestorePermissionDeniedError(
            "The authenticated request is not permitted to access this Firestore data."
        )
    if isinstance(error, GoogleAPICallError):
        return FirestoreAccessError(
            "Firestore rejected or could not complete the data request."
        )
    return error


def parse_server_timestamp(value: Any) -> Any:
    if isinstance(value, dict) and isinstance(value.get("timestampValue"), str):
        try:
            from datetime import datetime, timezone

            raw = value["timestampValue"].replace("Z", "+00:00")
            return datetime.fromisoformat(raw).astimezone(timezone.utc)
        except ValueError:
            return None
    return None


def to_serializable(value: Any) -> Any:
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if isinstance(value, (list, tuple)):
        return [to_serializable(item) for item in value]
    if isinstance(value, dict):
        return {str(key): to_serializable(item) for key, item in value.items()}
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return json.dumps(value, default=str)
