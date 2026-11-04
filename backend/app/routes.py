import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import GoogleAuthError
from pydantic import ValidationError

from .agent_service import AgentService
from .audio_utils import ensure_wav
from .auth import AuthenticatedUser, require_user
from .config import Settings, get_settings
from .errors import MetaApiError
from .fcm_service import FcmService
from .firebase_gateway import (
    FirebaseCredentialsMissingError,
    FirestoreInitializationError,
    FirestoreUnavailableError,
)
from .family_tools import FamilyTools, ToolContext
from .incident_service import IncidentService
from .meta_client import MetaClient
from .models import (
    AgentProcessRequest,
    AssistanceSummary,
    ConnectivityCheck,
    HelpRequestCreate,
    HelpRequestRecord,
    FcmTokenRequest,
    TranscribeRequest,
)
from .voice_service import VoiceService

logger = logging.getLogger("caresignal.routes")

router = APIRouter()

CONNECTIVITY_PROMPT = "Reply with one short Bengali sentence explaining family safety."


def get_client(settings: Settings = Depends(get_settings)) -> MetaClient:
    return MetaClient(settings)


def get_firestore() -> Any:
    from .firebase_gateway import firestore_client

    try:
        return firestore_client()
    except FirebaseCredentialsMissingError as error:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "firebase_credentials_missing",
                "message": str(error),
            },
        ) from error
    except FirestoreInitializationError as error:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "firestore_initialization_failed",
                "message": str(error),
            },
        ) from error
    except FirestoreUnavailableError as error:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "firestore_unavailable",
                "message": str(error),
            },
        ) from error


def get_fcm_service(
    firestore: Any = Depends(get_firestore),
) -> FcmService:
    return FcmService(firestore)


def _tools(firestore: Any) -> FamilyTools:
    return FamilyTools(firestore)


def _tool_context(user: AuthenticatedUser, device_id: str) -> ToolContext:
    return ToolContext(
        uid=user.uid,
        email=user.email,
        display_name=user.name,
        device_id=device_id,
        now=datetime.now(timezone.utc),
    )


@router.post("/auth/verify", response_model=dict)
async def verify_auth(user: AuthenticatedUser = Depends(require_user)) -> dict[str, Any]:
    return {"uid": user.uid, "email": user.email, "name": user.name, "verified": True}


@router.post("/voice/transcribe", response_model=dict)
async def transcribe_voice(
    consent_to_process: bool = Form(...),
    language: str = Form("bn-en"),
    audio: UploadFile = File(...),
    user: AuthenticatedUser = Depends(require_user),
    settings: Settings = Depends(get_settings),
    client: MetaClient = Depends(get_client),
) -> dict[str, Any]:
    if not consent_to_process:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "consent_required",
                "message": "Explicit consent is required before processing voice data.",
            },
        )
    if language not in {"bn", "en", "bn-en"}:
        raise HTTPException(
            status_code=400,
            detail={"code": "invalid_language", "message": "Unsupported language."},
        )

    raw = await audio.read()
    normalized = ensure_wav(
        raw,
        max_bytes=settings.max_audio_upload_bytes,
        max_seconds=settings.max_audio_duration_seconds,
    )
    if normalized.duration_ms < 300:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "empty_recording",
                "message": "The recording is too short to transcribe.",
            },
        )

    voice_service = VoiceService(settings, client)
    result = voice_service.transcribe(normalized.wav_bytes, language=language)
    if not result.transcript:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "empty_transcript",
                "message": "No speech was detected in the recording.",
            },
        )
    return {
        "transcript": result.transcript,
        "session_id": result.session_id,
        "audio_duration_ms": result.audio_duration_ms,
        "sample_rate": normalized.sample_rate,
        "converted": normalized.converted,
        "uid": user.uid,
    }


@router.post("/agent/process", response_model=dict)
async def process_agent(
    payload: AgentProcessRequest,
    user: AuthenticatedUser = Depends(require_user),
    settings: Settings = Depends(get_settings),
    client: MetaClient = Depends(get_client),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    service = AgentService(settings, client, _tools(firestore))
    context = _tool_context(user, payload.device_id)
    try:
        summary, diagnostics = service.process(
            transcript=payload.transcript,
            original_transcript=payload.original_transcript or payload.transcript,
            language=payload.language,
            context=context,
        )
    except MetaApiError:
        raise
    return {
        "summary": summary.model_dump(mode="json"),
        "diagnostics": diagnostics,
    }


@router.post("/family/contacts", response_model=dict)
async def family_contacts(
    device_id: str,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    tools = _tools(firestore)
    context = _tool_context(user, device_id)
    return tools.execute("get_approved_family_contacts", {}, context)


@router.post("/help-request", response_model=dict)
async def create_help_request(
    payload: HelpRequestCreate,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
    fcm: FcmService = Depends(get_fcm_service),
) -> dict[str, Any]:
    tools = _tools(firestore)
    context = _tool_context(user, payload.sender_device_id)
    grants = tools.execute("get_approved_family_contacts", {}, context)
    approved = {
        str(item.get("recipient_uid"))
        for item in (grants.get("approved_contacts") or [])
        if item.get("recipient_uid")
    }
    if payload.recipient_uid not in approved:
        logger.info(
            "CareSignal recipient validation sender_uid=%s recipient_uid=%s result=denied",
            user.uid,
            payload.recipient_uid,
        )
        raise HTTPException(
            status_code=403,
            detail={
                "code": "recipient_not_approved",
                "message": "The selected family member is not approved for help requests.",
            },
        )
    logger.info(
        "CareSignal recipient validation sender_uid=%s recipient_uid=%s result=approved",
        user.uid,
        payload.recipient_uid,
    )

    snapshot = (
        tools.build_verified_snapshot(context)
        if payload.include_location
        else {"sender_display_name": str(user.name or "")}
    )
    snapshot["request_type"] = payload.request_type.value
    snapshot["detected_language"] = payload.detected_language.value
    snapshot["suggested_safe_actions"] = list(payload.suggested_safe_actions)

    service = IncidentService(firestore)
    try:
        record, created = service.create_help_request(
            sender_uid=user.uid,
            sender_device_id=payload.sender_device_id,
            recipient_uid=payload.recipient_uid,
            language=payload.language,
            original_message=payload.original_message,
            original_transcript=payload.original_transcript or payload.original_message,
            generated_summary=payload.generated_summary,
            verified_data_snapshot=snapshot,
            idempotency_key=payload.idempotency_key,
        )
    except PermissionError as error:
        raise HTTPException(
            status_code=403,
            detail={"code": "permission_denied", "message": str(error)},
        ) from error
    notification_status = record.notification_status
    if created or record.notification_status in {"pending", "failed", "unavailable"}:
        notification_status = fcm.send_help_request(
            request_id=record.request_id,
            recipient_uid=record.recipient_uid,
            sender_display_name=str(
                snapshot.get("sender_display_name") or user.name or ""
            ),
        )
        try:
            record = service.update_notification_status(
                request_id=record.request_id,
                status=notification_status,
            )
        except (GoogleAPICallError, GoogleAuthError) as error:
            logger.error(
                "CareSignal notification status persistence request_id=%s outcome=failed error=%s",
                record.request_id,
                type(error).__name__,
            )
            notification_status = "pending"
    logger.info(
        "CareSignal request persistence request_id=%s sender_uid=%s recipient_uid=%s created=%s notification=%s",
        record.request_id,
        record.sender_uid,
        record.recipient_uid,
        created,
        notification_status,
    )
    return {
        "request": record.model_dump(mode="json"),
        "created": created,
        "saved": True,
        "notification_status": notification_status,
    }


@router.post("/fcm/register", response_model=dict)
async def register_fcm_token(
    payload: FcmTokenRequest,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    FcmService(firestore).register_token(
        uid=user.uid,
        token=payload.token,
        platform=payload.platform,
    )
    return {"registered": True}


@router.post("/fcm/unregister", response_model=dict)
async def unregister_fcm_token(
    payload: FcmTokenRequest,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    removed = FcmService(firestore).unregister_token(
        uid=user.uid,
        token=payload.token,
    )
    return {"unregistered": removed}


@router.get("/help-request/inbox", response_model=dict)
async def help_request_inbox(
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    service = IncidentService(firestore)
    records = service.list_for_recipient(user.uid)
    logger.info("CareSignal inbox query uid=%s result=count:%s", user.uid, len(records))
    return {"requests": [record.model_dump(mode="json") for record in records]}


@router.get("/help-request/sent", response_model=dict)
async def help_request_sent(
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    service = IncidentService(firestore)
    records = service.list_for_sender(user.uid)
    return {"requests": [record.model_dump(mode="json") for record in records]}


@router.get("/help-request/{request_id}", response_model=dict)
async def get_help_request(
    request_id: str,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    record = IncidentService(firestore).read(request_id)
    if record is None or user.uid not in {record.sender_uid, record.recipient_uid}:
        raise HTTPException(
            status_code=404,
            detail={"code": "not_found", "message": "Help request not found."},
        )
    return {"request": record.model_dump(mode="json")}


@router.post("/help-request/acknowledge", response_model=dict)
async def acknowledge_help_request(
    request_id: str,
    user: AuthenticatedUser = Depends(require_user),
    firestore: Any = Depends(get_firestore),
) -> dict[str, Any]:
    service = IncidentService(firestore)
    try:
        record = service.acknowledge(request_id=request_id, recipient_uid=user.uid)
    except LookupError as error:
        raise HTTPException(
            status_code=404,
            detail={"code": "not_found", "message": "Help request not found."},
        ) from error
    except PermissionError as error:
        raise HTTPException(
            status_code=403,
            detail={"code": "permission_denied", "message": str(error)},
        ) from error
    return {"request": record.model_dump(mode="json")}


@router.post("/connectivity/check", response_model=ConnectivityCheck)
async def connectivity_check(
    settings: Settings = Depends(get_settings),
    client: MetaClient = Depends(get_client),
) -> ConnectivityCheck:
    if not settings.has_model_key:
        return ConnectivityCheck(
            status="failed",
            error_code="missing_api_key",
            error_message="MODEL_API_KEY is not configured on the backend.",
        )
    try:
        result = client.chat(
            [{"role": "user", "content": CONNECTIVITY_PROMPT}],
            temperature=0.2,
            max_tokens=200,
        )
    except MetaApiError as error:
        return ConnectivityCheck(
            status="failed",
            error_code=error.code.value,
            error_message=error.message,
        )
    return ConnectivityCheck(
        status="success",
        model=result.model,
        response_text=result.content,
        usage=result.usage.as_dict(),
    )
