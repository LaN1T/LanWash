import time
from typing import Awaitable, Callable

import structlog
from fastapi import Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.app_check import verify_app_check_token
from core.config import get_settings
from core.logging import configure_logging
from core.metrics import update_business_metrics
from core.request_id import RequestIdMiddleware, get_request_id
from core.security_headers import SecurityHeadersMiddleware

configure_logging()
logger = structlog.get_logger()
settings = get_settings()

_EXPOSED_HEADERS = [
    "X-Total-Pages",
    "X-Current-Page",
    "X-Current-Date",
    "X-Unique-Dates",
    "X-Content-Type-Options",
    "X-Frame-Options",
]

_EXCLUDED_APP_CHECK_PATHS = {
    "/health",
    "/metrics",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/webhook",
    "/uploads/",
    "/landing/",
    "/static/",
}


def _is_app_check_excluded(path: str) -> bool:
    if path in _EXCLUDED_APP_CHECK_PATHS:
        return True
    for prefix in _EXCLUDED_APP_CHECK_PATHS:
        if prefix.endswith("/"):
            if path.startswith(prefix):
                return True
        elif path == prefix or path.startswith(f"{prefix}/"):
            return True
    return False

_METRICS_RATE_LIMIT: dict[str, list[float]] = {}
_METRICS_MAX_PER_MINUTE = 60


def add_cors_middleware(app):
    allow_credentials = True

    if settings.is_production:
        allow_origins = settings.cors_origins
    else:
        # Restrictive default for local development/testing.
        allow_origins = []

    if allow_credentials and "*" in allow_origins:
        raise ValueError("Wildcard CORS origin is not allowed with credentials")

    if not settings.is_production:
        cors_kwargs = {"allow_origin_regex": r"^http://localhost:\d+$"}
    else:
        cors_kwargs = {"allow_origins": allow_origins}

    app.add_middleware(
        CORSMiddleware,
        allow_credentials=allow_credentials,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
        expose_headers=_EXPOSED_HEADERS,
        **cors_kwargs,
    )


def add_security_middleware(app):
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RequestIdMiddleware)


async def metrics_rate_limit_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
):
    if request.url.path == "/metrics":
        now = time.time()
        ip = request.client.host if request.client else "unknown"
        window = _METRICS_RATE_LIMIT.get(ip, [])
        window = [t for t in window if now - t < 60]
        if len(window) >= _METRICS_MAX_PER_MINUTE:
            return JSONResponse({"detail": "Rate limit exceeded"}, status_code=429)
        window.append(now)
        _METRICS_RATE_LIMIT[ip] = window
    return await call_next(request)


async def app_check_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
):
    if not _is_app_check_excluded(request.url.path):
        await verify_app_check_token(request)
    return await call_next(request)


async def business_metrics_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
):
    if request.url.path == "/metrics":
        try:
            await update_business_metrics()
        except Exception as e:
            logger.warning("business_metrics_update_failed", error=str(e))
    return await call_next(request)


async def log_requests(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
):
    start = time.time()
    try:
        response = await call_next(request)
    except Exception as exc:
        duration_ms = (time.time() - start) * 1000
        logger.warning(
            "request_error",
            method=request.method,
            path=request.url.path,
            duration_ms=round(duration_ms, 2),
            error=str(exc),
            request_id=get_request_id(),
        )
        raise
    duration_ms = (time.time() - start) * 1000
    logger.info(
        "request",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=round(duration_ms, 2),
        request_id=get_request_id(),
    )
    return response
