import ipaddress
import logging
from dataclasses import dataclass

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, get_settings
from .errors import MetaApiErrorCode

logger = logging.getLogger("caresignal.auth")

bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    uid: str
    email: str
    name: str


class TokenVerifier:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def verify(self, token: str) -> AuthenticatedUser:
        from .firebase_gateway import verify_firebase_id_token

        result = verify_firebase_id_token(
            token,
            project_id=self._settings.firebase_project_id or None,
        )
        if isinstance(result, AuthenticatedUser):
            return result
        if isinstance(result, dict):
            return AuthenticatedUser(
                uid=str(result.get("uid") or result.get("user_id") or result.get("sub") or ""),
                email=str(result.get("email") or ""),
                name=str(result.get("name") or result.get("display_name") or ""),
            )
        return result


def get_token_verifier(settings: Settings = Depends(get_settings)) -> TokenVerifier:
    return TokenVerifier(settings)


async def require_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    verifier: TokenVerifier = Depends(get_token_verifier),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    if credentials is None or not credentials.credentials:
        logger.info(
            "CareSignal authentication endpoint=%s status=401 "
            "category=missing_token authorization_present=%s",
            request.url.path,
            bool(request.headers.get("authorization")),
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "unauthenticated", "message": "Firebase ID token required."},
        )
    if settings.require_https and request.url.scheme != "https" and _is_exposed(request):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "https_required",
                "message": "HTTPS is required for authenticated endpoints.",
            },
        )
    try:
        return verifier.verify(credentials.credentials)
    except HTTPException:
        raise
    except Exception as error:
        logger.warning(
            "CareSignal authentication endpoint=%s status=401 category=%s "
            "authorization_present=true",
            request.url.path,
            type(error).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": MetaApiErrorCode.UNAUTHORIZED.value,
                "message": "Firebase ID token is invalid or expired.",
            },
        ) from error


def _is_exposed(request: Request) -> bool:
    host = (request.headers.get("host") or "").split(":")[0].strip()
    if not host or host in {"localhost", "127.0.0.1", "10.0.2.2", "::1"}:
        return False

    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return True

    return not (
        ip.is_loopback
        or ip.is_private
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
    )
