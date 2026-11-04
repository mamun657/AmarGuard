import logging
import os
from typing import Any

from google.auth.exceptions import GoogleAuthError
from google.api_core.exceptions import GoogleAPICallError, PermissionDenied
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import Settings, get_settings
from .errors import MetaApiError
from .firebase_gateway import (
    FirestoreAccessError,
    FirestorePermissionDeniedError,
    firestore_credentials_configured,
)

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("caresignal")


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved = settings or get_settings()

    app = FastAPI(
        title="AmarGuard CareSignal AI Backend",
        version="1.0.1",
        docs_url="/docs",
        redoc_url=None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=resolved.origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    from .routes import router

    app.include_router(router)
    app.dependency_overrides[get_settings] = lambda: resolved

    @app.exception_handler(MetaApiError)
    async def _meta_error_handler(_request: Any, error: MetaApiError) -> JSONResponse:
        return JSONResponse(
            status_code=error.status_code,
            content={
                "error": {
                    "code": error.code.value,
                    "message": error.message,
                    "retryable": error.retryable,
                }
            },
        )

    @app.exception_handler(FirestorePermissionDeniedError)
    async def _firestore_permission_handler(
        _request: Any,
        error: FirestorePermissionDeniedError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=403,
            content={
                "error": {
                    "code": "firestore_permission_denied",
                    "message": str(error),
                }
            },
        )

    @app.exception_handler(FirestoreAccessError)
    async def _firestore_access_handler(
        _request: Any,
        error: FirestoreAccessError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "code": "firestore_access_failed",
                    "message": str(error),
                }
            },
        )

    @app.exception_handler(PermissionDenied)
    async def _google_firestore_permission_handler(
        _request: Any,
        _error: PermissionDenied,
    ) -> JSONResponse:
        logger.warning("Firestore operation denied by Google Cloud.")
        return JSONResponse(
            status_code=403,
            content={
                "error": {
                    "code": "firestore_permission_denied",
                    "message": "The backend identity is not permitted to access this Firestore data.",
                }
            },
        )

    @app.exception_handler(GoogleAPICallError)
    async def _google_firestore_access_handler(
        request: Any,
        error: GoogleAPICallError,
    ) -> JSONResponse:
        logger.error(
            "Firestore request endpoint=%s status=503 category=%s",
            request.url.path,
            type(error).__name__,
        )
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "code": "firestore_access_failed",
                    "message": "Firestore could not complete the data request.",
                }
            },
        )

    @app.exception_handler(GoogleAuthError)
    async def _google_auth_access_handler(
        request: Any,
        error: GoogleAuthError,
    ) -> JSONResponse:
        logger.error(
            "Firestore request endpoint=%s status=503 category=%s",
            request.url.path,
            type(error).__name__,
        )
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "code": "firestore_access_failed",
                    "message": "Google credentials could not complete the Firestore request.",
                }
            },
        )

    @app.get("/health")
    async def health() -> dict[str, Any]:
        return {
            "status": "ok",
            "version": app.version,
            "firebase_project_id": resolved.firebase_project_id,
            "model_api_configured": resolved.has_model_key,
            "firestore_credentials_configured": firestore_credentials_configured(),
            "chat_model": resolved.meta_chat_model,
            "transcribe_model": resolved.meta_transcribe_model,
        }

    @app.exception_handler(ValueError)
    async def _value_error_handler(_request: Any, error: ValueError) -> JSONResponse:
        return JSONResponse(
            status_code=400,
            content={"error": {"code": "invalid_request", "message": str(error)}},
        )

    @app.exception_handler(HTTPException)
    async def _http_error_handler(_request: Any, error: HTTPException) -> JSONResponse:
        detail = error.detail
        if isinstance(detail, dict):
            code = str(detail.get("code") or "request_failed")
            message = str(detail.get("message") or "The request could not be completed.")
            content = {"error": {"code": code, "message": message}}
        elif isinstance(detail, list):
            content = {
                "error": {
                    "code": "invalid_request",
                    "message": "The request payload is invalid.",
                }
            }
        else:
            content = {
                "error": {
                    "code": "request_failed",
                    "message": str(detail),
                }
            }
        return JSONResponse(status_code=error.status_code, content=content)

    return app


app = create_app()
