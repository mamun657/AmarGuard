from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.auth import AuthenticatedUser
from app.config import Settings
from app.firebase_gateway import FirebaseCredentialsMissingError
from app.main import create_app
from app import firebase_gateway
from app.routes import require_user


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


def test_health_reports_missing_model_key():
    app = create_app(_settings())
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["model_api_configured"] is False
    assert response.json()["version"] == "1.0.1"


def test_local_private_network_http_is_allowed_for_dev():
    app = create_app(_settings(require_https=True))
    with TestClient(app) as client:
        response = client.get(
            "http://192.168.1.25/help-request/inbox",
            headers={"Authorization": "Bearer fake-token"},
        )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_private_endpoint_requires_token():
    app = create_app(_settings())
    with TestClient(app) as client:
        response = client.get("/help-request/inbox")
    assert response.status_code == 401


def test_transcribe_requires_consent():
    app = create_app(_settings())
    with TestClient(app) as client:
        response = client.post(
            "/voice/transcribe",
            data={"consent_to_process": "false", "language": "bn-en"},
            files={"audio": ("recording.wav", b"RIFFfake", "audio/wav")},
        )
    assert response.status_code == 401


def test_connectivity_check_reports_missing_key():
    app = create_app(_settings())
    with TestClient(app) as client:
        response = client.post("/connectivity/check")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "failed"
    assert payload["error_code"] == "missing_api_key"


def test_health_reports_firestore_configuration(monkeypatch):
    app = create_app(_settings())
    monkeypatch.setattr(
        "app.main.firestore_credentials_configured",
        lambda: False,
    )
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["firestore_credentials_configured"] is False


def test_health_reports_backend_firebase_project_id():
    app = create_app(_settings(firebase_project_id="guard-ab0d3"))
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.json()["firebase_project_id"] == "guard-ab0d3"


def test_family_contacts_distinguishes_missing_firebase_credentials(monkeypatch):
    app = create_app(_settings())
    app.dependency_overrides[require_user] = lambda: AuthenticatedUser(
        uid="owner-1",
        email="",
        name="",
    )

    def missing_firestore():
        raise FirebaseCredentialsMissingError("ADC missing.")

    monkeypatch.setattr(firebase_gateway, "firestore_client", missing_firestore)
    with TestClient(app) as client:
        response = client.post("/family/contacts?device_id=device-1")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "firebase_credentials_missing"


def test_agent_process_explains_missing_firestore_credentials(monkeypatch):
    app = create_app(_settings())
    app.dependency_overrides[require_user] = lambda: AuthenticatedUser(
        uid="owner-1",
        email="",
        name="",
    )

    def missing_firestore():
        raise FirebaseCredentialsMissingError(
            "Set FIREBASE_CREDENTIALS_PATH in backend/.env."
        )

    monkeypatch.setattr(firebase_gateway, "firestore_client", missing_firestore)
    with TestClient(app) as client:
        response = client.post(
            "/agent/process",
            json={"transcript": "I need help", "device_id": "device-1"},
        )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "firebase_credentials_missing"
    assert "FIREBASE_CREDENTIALS_PATH" in response.json()["error"]["message"]
