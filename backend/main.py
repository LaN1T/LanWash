import asyncio
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
import os

from database import init_db
from routers import auth, appointments, services, logs, notes, reports, consumables, wash_types, shifts, reviews
from services.auth_service import check_roles, get_current_user

from core.limiter import limiter
from core.config import get_settings
from core.logging import configure_logging
from core.metrics import update_business_metrics
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from prometheus_fastapi_instrumentator import Instrumentator

import structlog
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

# Configure structured logging
configure_logging()
logger = structlog.get_logger()
settings = get_settings()

# Initialize Sentry if DSN is configured
if settings.sentry_dsn:
    def _sentry_scrub_sensitive(event, hint):
        """Remove sensitive data from Sentry events."""
        from sentry_sdk.utils import AnnotatedValue
        if event.get("exception"):
            for value in event.get("exception", {}).get("values", []):
                if value.get("stacktrace"):
                    for frame in value["stacktrace"].get("frames", []):
                        if frame.get("vars"):
                            for key in list(frame["vars"].keys()):
                                key_lower = key.lower()
                                if any(s in key_lower for s in ("password", "token", "secret", "authorization", "api_key", "apikey")):
                                    frame["vars"][key] = AnnotatedValue("[Filtered]", {"rem": ["scrubbed"]})
        if event.get("request"):
            req = event["request"]
            for key in ("cookies", "data", "headers", "env"):
                if key not in req:
                    continue
                container = req[key]
                if not isinstance(container, dict):
                    continue
                for k in list(container.keys()):
                    if any(s in k.lower() for s in ("password", "token", "secret", "authorization", "api_key", "apikey", "cookie")):
                        container[k] = AnnotatedValue("[Filtered]", {"rem": ["scrubbed"]})
        return event

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,
        integrations=[
            StarletteIntegration(transaction_style="endpoint"),
            FastApiIntegration(transaction_style="endpoint"),
        ],
        traces_sample_rate=1.0 if settings.is_production else 0.0,
        before_send=_sentry_scrub_sensitive,
    )
    logger.info("sentry_initialized", environment=settings.environment)

_start_time = datetime.now(timezone.utc)


async def _metrics_background_task():
    """Update business metrics every 30 seconds."""
    while True:
        await asyncio.sleep(30)
        try:
            await update_business_metrics()
        except Exception as e:
            logger.warning("background_metrics_update_failed", error=str(e))


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app_starting", environment=settings.environment)
    await init_db()
    logger.info("app_ready", environment=settings.environment)

    metrics_task = asyncio.create_task(_metrics_background_task())
    yield

    metrics_task.cancel()
    try:
        await metrics_task
    except asyncio.CancelledError:
        pass
    logger.info("app_shutting_down")


app = FastAPI(
    title="LanWash API",
    description="REST API для системы управления автомойкой. Поддерживает роли: client, washer, admin.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
)

# Avatar files served with authentication
uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(uploads_dir, exist_ok=True)

@app.get("/uploads/avatars/{filename}")
async def get_avatar(filename: str, current_user=Depends(get_current_user)):
    """Serve avatar images with auth check."""
    safe_filename = os.path.basename(filename)
    filepath = os.path.join(uploads_dir, "avatars", safe_filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath)

# Apply rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Prometheus metrics (exposed at /metrics)
Instrumentator().instrument(app).expose(app, include_in_schema=False)

# CORS — development allows any localhost port; production uses strict whitelist
_EXPOSED_HEADERS = [
    "X-Total-Pages",
    "X-Current-Page",
    "X-Current-Date",
    "X-Unique-Dates",
    "X-Content-Type-Options",
    "X-Frame-Options",
]

if settings.is_production:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=_EXPOSED_HEADERS,
    )
else:
    # Development / testing: allow any localhost port (Flutter web random ports)
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"https?://localhost(:\d+)?",
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=_EXPOSED_HEADERS,
    )

# Security headers middleware
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response


# App Check middleware (optional, disabled by default)
# Set APP_CHECK_ENFORCED=true to enable in production
from core.app_check import verify_app_check_token

_EXCLUDED_APP_CHECK_PATHS = {"/health", "/metrics", "/docs", "/redoc", "/openapi.json"}

@app.middleware("http")
async def app_check_middleware(request, call_next):
    if request.url.path not in _EXCLUDED_APP_CHECK_PATHS:
        await verify_app_check_token(request)
    return await call_next(request)

# Business metrics middleware
@app.middleware("http")
async def business_metrics_middleware(request, call_next):
    if request.url.path == "/metrics":
        try:
            await update_business_metrics()
        except Exception as e:
            logger.warning("business_metrics_update_failed", error=str(e))
    return await call_next(request)


# Request logging middleware
@app.middleware("http")
async def log_requests(request, call_next):
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
        )
        raise
    duration_ms = (time.time() - start) * 1000
    logger.info(
        "request",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=round(duration_ms, 2),
    )
    return response


# Health check endpoint
@app.get("/health", tags=["health"])
async def health_check():
    uptime = (datetime.now(timezone.utc) - _start_time).total_seconds()
    return {
        "status": "healthy",
        "service": "LanWash API",
        "version": "1.0.0",
        "environment": settings.environment,
        "uptime_seconds": int(uptime),
    }


# Debug routes only in development
if settings.debug:
    @app.get("/debug/routes", dependencies=[Depends(check_roles(["admin"]))])
    async def get_routes():
        return [{"path": route.path} for route in app.routes]


# Root endpoint
@app.get("/")
async def root():
    return {"status": "ok", "service": "LanWash API"}


# Routers
app.include_router(auth.router)
app.include_router(appointments.router)
app.include_router(services.router)
app.include_router(logs.router)
app.include_router(notes.router)
app.include_router(reports.router, dependencies=[Depends(check_roles(["admin", "washer"]))])
app.include_router(consumables.router, dependencies=[Depends(check_roles(["admin", "washer"]))])
app.include_router(wash_types.router)
app.include_router(shifts.router)
app.include_router(reviews.router)


# Telegram Bot Webhook endpoint
@app.post("/webhook")
async def telegram_webhook(update: dict):
    from bot.webhook import process_update
    return await process_update(update)


@app.on_event("startup")
async def startup_event():
    pass


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False, proxy_headers=True)
