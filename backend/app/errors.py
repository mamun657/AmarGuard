import logging
from enum import Enum


class MetaApiErrorCode(str, Enum):
    MISSING_API_KEY = "missing_api_key"
    UNAUTHORIZED = "unauthorized"
    FORBIDDEN = "forbidden"
    RATE_LIMITED = "rate_limited"
    INVALID_REQUEST = "invalid_request"
    TIMEOUT = "timeout"
    SERVER_ERROR = "server_error"
    NETWORK_ERROR = "network_error"
    UNSUPPORTED_AUDIO = "unsupported_audio"
    PAYLOAD_TOO_LARGE = "payload_too_large"
    UNKNOWN = "unknown"


class MetaApiError(Exception):
    def __init__(
        self,
        code: MetaApiErrorCode,
        message: str,
        *,
        status_code: int = 502,
        retryable: bool = False,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable


class MissingApiKeyError(MetaApiError):
    def __init__(self) -> None:
        super().__init__(
            MetaApiErrorCode.MISSING_API_KEY,
            "MODEL_API_KEY is not configured on the backend.",
            status_code=503,
        )


class UnauthorizedError(MetaApiError):
    def __init__(self) -> None:
        super().__init__(
            MetaApiErrorCode.UNAUTHORIZED,
            "Meta Model API rejected the configured credential.",
            status_code=502,
        )


class ForbiddenError(MetaApiError):
    def __init__(self) -> None:
        super().__init__(
            MetaApiErrorCode.FORBIDDEN,
            "Meta Model API access is restricted for this credential.",
            status_code=502,
        )


class TimeoutError(MetaApiError):
    def __init__(self) -> None:
        super().__init__(
            MetaApiErrorCode.TIMEOUT,
            "Meta Model API request timed out.",
            status_code=504,
            retryable=True,
        )


class ServerError(MetaApiError):
    def __init__(self) -> None:
        super().__init__(
            MetaApiErrorCode.SERVER_ERROR,
            "Meta Model API returned a server error.",
            status_code=502,
            retryable=True,
        )


class RateLimitedError(MetaApiError):
    def __init__(self, retry_after: int | None = None) -> None:
        super().__init__(
            MetaApiErrorCode.RATE_LIMITED,
            "Meta Model API rate limit reached. Retry later.",
            status_code=429,
            retryable=True,
        )
        self.retry_after = retry_after


class InvalidRequestError(MetaApiError):
    def __init__(self, message: str = "Meta Model API rejected the request.") -> None:
        super().__init__(
            MetaApiErrorCode.INVALID_REQUEST,
            message,
            status_code=400,
        )


class AudioFormatError(MetaApiError):
    def __init__(self, message: str) -> None:
        super().__init__(
            MetaApiErrorCode.UNSUPPORTED_AUDIO,
            message,
            status_code=400,
        )


class PayloadTooLargeError(MetaApiError):
    def __init__(self, message: str) -> None:
        super().__init__(
            MetaApiErrorCode.PAYLOAD_TOO_LARGE,
            message,
            status_code=413,
        )


def safe_log(logger: logging.Logger, message: str, **fields: object) -> None:
    safe = {key: value for key, value in fields.items() if "key" not in key.lower()}
    logger.info(message, extra=safe)
