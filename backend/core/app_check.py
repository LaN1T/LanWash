"""Firebase App Check token verification.

App Check protects backend resources from abuse by verifying that incoming
requests come from your authentic app.

Enforcement is controlled by APP_CHECK_ENFORCED env variable.
In development, App Check uses debug providers and verification can be skipped.
"""

from fastapi import Request, HTTPException, status
import firebase_admin
from firebase_admin import app_check as firebase_app_check
import structlog

from core.config import get_settings

logger = structlog.get_logger()
settings = get_settings()

# Cached verifier
_verify_token = None


def _get_verifier():
    global _verify_token
    if _verify_token is not None:
        return _verify_token

    if not firebase_admin._apps:
        logger.warning("app_check_firebase_not_initialized")
        return None

    _verify_token = firebase_app_check.verify_token
    return _verify_token


async def verify_app_check_token(request: Request) -> None:
    """Verify X-Firebase-AppCheck header. Raises 401 if invalid/missing."""
    # Skip if not enforced (development / testing)
    if not settings.app_check_enforced:
        return

    token = request.headers.get("X-Firebase-AppCheck")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing App Check token",
        )

    verifier = _get_verifier()
    if verifier is None:
        logger.warning("app_check_verifier_unavailable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="App Check unavailable",
        )

    try:
        verifier(token)
        logger.debug("app_check_verified")
    except Exception as e:
        logger.warning("app_check_verification_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid App Check token",
        )
