import os
from types import SimpleNamespace

from google.auth.exceptions import DefaultCredentialsError

from app import config, firebase_gateway


def test_firestore_credentials_configured_does_not_probe_adc(monkeypatch, tmp_path):
    monkeypatch.setattr(
        config,
        "get_settings",
        lambda: SimpleNamespace(
            firebase_credentials_path="",
            google_application_credentials="",
        ),
    )
    monkeypatch.setattr(firebase_gateway, "_app", None)
    monkeypatch.delenv("FIREBASE_CREDENTIALS_PATH", raising=False)
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
    monkeypatch.delenv("CLOUDSDK_CONFIG", raising=False)
    monkeypatch.delenv("K_SERVICE", raising=False)
    monkeypatch.delenv("GAE_ENV", raising=False)
    monkeypatch.delenv("GCE_METADATA_HOST", raising=False)
    monkeypatch.setenv("APPDATA", str(tmp_path))

    def fail_if_adc_is_probed():
        raise AssertionError("Credential status checks must not access the network.")

    monkeypatch.setattr(
        firebase_gateway,
        "_application_default_credentials",
        fail_if_adc_is_probed,
    )

    assert firebase_gateway.firestore_credentials_configured() is False


def test_firestore_credentials_configured_resolves_relative_service_account_path(
    monkeypatch,
    tmp_path,
):
    from app import config

    credential_file = tmp_path / "service-account.json"
    credential_file.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(firebase_gateway, "_BACKEND_DIR", tmp_path)
    monkeypatch.setattr(
        config,
        "get_settings",
        lambda: SimpleNamespace(
            firebase_credentials_path="service-account.json",
            google_application_credentials="",
        ),
    )
    monkeypatch.delenv("FIREBASE_CREDENTIALS_PATH", raising=False)
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)

    assert firebase_gateway.firestore_credentials_configured() is True


def test_missing_adc_fails_without_network_probe(monkeypatch, tmp_path):
    from app import config

    monkeypatch.setattr(
        config,
        "get_settings",
        lambda: SimpleNamespace(google_application_credentials=""),
    )
    monkeypatch.setattr(firebase_gateway, "_BACKEND_DIR", tmp_path)
    monkeypatch.setenv("APPDATA", str(tmp_path))
    monkeypatch.delenv("CLOUDSDK_CONFIG", raising=False)
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
    monkeypatch.delenv("K_SERVICE", raising=False)
    monkeypatch.delenv("GAE_ENV", raising=False)
    monkeypatch.delenv("GCE_METADATA_HOST", raising=False)

    def fail_if_adc_is_probed():
        raise AssertionError("Missing credentials must be detected before ADC lookup.")

    monkeypatch.setattr(
        firebase_gateway.credentials,
        "ApplicationDefault",
        fail_if_adc_is_probed,
    )

    try:
        firebase_gateway._application_default_credentials()
    except firebase_gateway.FirebaseCredentialsMissingError as error:
        assert "FIREBASE_CREDENTIALS_PATH" in str(error)
        assert "GOOGLE_APPLICATION_CREDENTIALS" in str(error)
    else:
        raise AssertionError("Missing Firebase credentials must be reported.")


def test_firestore_client_uses_firebase_admin_factory(monkeypatch):
    fake_app = object()
    fake_client = object()
    calls = []

    monkeypatch.setattr(firebase_gateway, "_app", fake_app)
    monkeypatch.setattr(firebase_gateway, "_firestore", None)
    monkeypatch.setattr(firebase_gateway, "get_firebase_app", lambda: fake_app)

    def create_client(*, app):
        calls.append(app)
        return fake_client

    monkeypatch.setattr(firebase_gateway.admin_firestore, "client", create_client)

    assert firebase_gateway.firestore_client() is fake_client
    assert firebase_gateway.firestore_client() is fake_client
    assert calls == [fake_app]


def test_get_firebase_app_reuses_default_app(monkeypatch):
    class FakeApp:
        project_id = "guard-ab0d3"

    fake_app = FakeApp()
    monkeypatch.setattr(firebase_gateway, "_app", None)
    monkeypatch.setattr(firebase_gateway.firebase_admin, "get_app", lambda: fake_app)

    def fail_initialize(*_args, **_kwargs):
        raise AssertionError("Default Firebase app must not be initialized twice.")

    monkeypatch.setattr(firebase_gateway.firebase_admin, "initialize_app", fail_initialize)

    assert firebase_gateway.get_firebase_app() is fake_app


def test_application_default_credentials_wrap_google_adc(monkeypatch, tmp_path):
    fake_credential = object()
    calls = []
    adc_file = tmp_path / "application_default_credentials.json"
    adc_file.write_text("{}", encoding="utf-8")
    monkeypatch.setenv("CLOUDSDK_CONFIG", str(tmp_path))
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)

    class ApplicationDefault:
        def get_credential(self):
            calls.append(True)
            return fake_credential

    monkeypatch.setattr(
        firebase_gateway.credentials,
        "ApplicationDefault",
        ApplicationDefault,
    )

    assert isinstance(
        firebase_gateway._application_default_credentials(),
        ApplicationDefault,
    )
    assert calls == [True]


def test_settings_adc_path_overrides_empty_environment_variable(
    monkeypatch,
    tmp_path,
):
    credential_file = tmp_path / "application_default_credentials.json"
    credential_file.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(
        config,
        "get_settings",
        lambda: SimpleNamespace(
            google_application_credentials=str(credential_file),
        ),
    )
    monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", "")

    class ApplicationDefault:
        def get_credential(self):
            assert os.environ["GOOGLE_APPLICATION_CREDENTIALS"] == str(credential_file)

    monkeypatch.setattr(
        firebase_gateway.credentials,
        "ApplicationDefault",
        ApplicationDefault,
    )

    assert isinstance(
        firebase_gateway._application_default_credentials(),
        ApplicationDefault,
    )


def test_application_default_credentials_reports_adc_auth_failure(
    monkeypatch,
    tmp_path,
):
    adc_file = tmp_path / "application_default_credentials.json"
    adc_file.write_text("{}", encoding="utf-8")
    monkeypatch.setenv("CLOUDSDK_CONFIG", str(tmp_path))
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)

    class ApplicationDefault:
        def get_credential(self):
            raise DefaultCredentialsError("credential details must not be returned")

    monkeypatch.setattr(
        firebase_gateway.credentials,
        "ApplicationDefault",
        ApplicationDefault,
    )

    try:
        firebase_gateway._application_default_credentials()
    except firebase_gateway.FirebaseCredentialsMissingError as error:
        assert "GOOGLE_APPLICATION_CREDENTIALS" in str(error)
    else:
        raise AssertionError("Missing ADC must be reported.")
