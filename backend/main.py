import asyncio
import re
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, Depends, HTTPException, Header, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
import os

from database import init_db, get_db
from routers import auth, appointments, services, logs, notes, reports, consumables, wash_types, shifts, reviews, cars, referrals, tips, subscriptions, reminders, admin, health, support
from services.auth_service import check_roles, get_current_user
from services.websocket_manager import connect, disconnect, broadcast

from core.limiter import limiter
from core.config import get_settings
from core.logging import configure_logging
from core.metrics import update_business_metrics
from core.background import get_arq_pool, close_arq_pool
from tasks import check_inventory_forecast
from core.request_id import RequestIdMiddleware, get_request_id
from core.security_headers import SecurityHeadersMiddleware
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


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app_starting", environment=settings.environment)
    await init_db()
    logger.info("app_ready", environment=settings.environment)

    try:
        arq_pool = await get_arq_pool()
        app.state.arq_pool = arq_pool
        await arq_pool.enqueue_job("update_metrics", _defer_by=30)
        try:
            await arq_pool.enqueue_job("check_inventory_forecast", _defer_by=3600)
        except Exception as e:
            logger.warning("inventory_task_schedule_failed", error=str(e))
    except Exception as e:
        logger.warning("arq_pool_initialization_failed", error=str(e))
        app.state.arq_pool = None

    yield

    await close_arq_pool()
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
    if not filename or re.search(r'[/\\]', filename) or filename.startswith('.'):
        raise HTTPException(400, "Invalid filename")
    filepath = os.path.join(uploads_dir, "avatars", os.path.basename(filename))
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
        allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=_EXPOSED_HEADERS,
    )

app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RequestIdMiddleware)

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


# Debug routes only in development
if settings.debug:
    @app.get("/debug/routes", dependencies=[Depends(check_roles(["admin"]))])
    async def get_routes():
        return [{"path": route.path} for route in app.routes]


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
app.include_router(cars.router)
app.include_router(referrals.router)
app.include_router(tips.router)
app.include_router(subscriptions.router)
app.include_router(reminders.router)
app.include_router(admin.router)
app.include_router(health.router)
app.include_router(support.router)


# Telegram Bot Webhook endpoint
TELEGRAM_SECRET = os.environ.get("TELEGRAM_WEBHOOK_SECRET", "")

@app.post("/webhook")
@limiter.limit("20/minute")
async def telegram_webhook(request: Request, update: dict, x_telegram_bot_api_secret_token: str = Header(None)):
    if TELEGRAM_SECRET and x_telegram_bot_api_secret_token != TELEGRAM_SECRET:
        raise HTTPException(403, "Invalid secret token")
    from bot.webhook import process_update
    return await process_update(update)


# Telegram Mini App static files (must be after ALL API routes)
miniapp_dir = os.path.join(os.path.dirname(__file__), "..", "telegram-miniapp", "dist")
if os.path.exists(miniapp_dir):
    @app.get("/{path:path}")
    async def serve_miniapp(path: str):
        headers = {
            "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
            "Pragma": "no-cache",
            "Expires": "0",
        }
        file_path = os.path.join(miniapp_dir, path)
        if path and os.path.exists(file_path) and os.path.isfile(file_path):
            return FileResponse(file_path, headers=headers)
        return FileResponse(os.path.join(miniapp_dir, "index.html"), headers=headers)
else:
    logger.warning("miniapp_static_dir_not_found", path=miniapp_dir)


@app.on_event("startup")
async def startup_event():
    pass


# ─── Support Chat WebSocket ─────────────────────────────────────────────────
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy import select
from db_models import SupportChat
import json

_ws_attempts: dict[str, list[float]] = {}


@app.websocket("/ws/support/chats/{chat_id}")
async def support_chat_websocket(websocket: WebSocket, chat_id: int):
    ip = websocket.client.host if websocket.client else None
    if ip:
        now = time.time()
        attempts = [t for t in _ws_attempts.get(ip, []) if now - t < 60]
        if len(attempts) >= 20:
            await websocket.close(code=1008)
            return
        attempts.append(now)
        _ws_attempts[ip] = attempts

    await websocket.accept()

    token = None
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=5.0)
        data = json.loads(raw)
        if data.get("type") == "auth":
            token = data.get("token")
    except asyncio.TimeoutError:
        await websocket.close(code=1008)
        return
    except Exception:
        await websocket.close(code=1008)
        return

    if not token:
        await websocket.close(code=1008)
        return

    db_gen = None
    try:
        db_gen = get_db()
        db = await anext(db_gen)
    except Exception:
        await websocket.close(code=1011)
        return

    try:
        current_user = await get_current_user(token=token, db=db)
    except Exception:
        await websocket.close(code=1008)
        if db_gen:
            try:
                await db_gen.aclose()
            except Exception:
                pass
        return

    chat_res = await db.execute(select(SupportChat).where(SupportChat.id == chat_id))
    chat = chat_res.scalar_one_or_none()
    if not chat or (current_user.role != "admin" and chat.userId != current_user.id):
        await websocket.close(code=1008)
        try:
            await db_gen.aclose()
        except Exception:
            pass
        return

    connect(chat_id, websocket, current_user.id)

    heartbeat_task = asyncio.create_task(_websocket_heartbeat(websocket))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except Exception:
                continue
            if data.get("type") == "pong":
                continue
    except WebSocketDisconnect:
        pass
    finally:
        heartbeat_task.cancel()
        try:
            await heartbeat_task
        except asyncio.CancelledError:
            pass
        disconnect(chat_id, websocket)
        try:
            await db_gen.aclose()
        except Exception:
            pass


async def _websocket_heartbeat(websocket: WebSocket):
    while True:
        try:
            await asyncio.sleep(30)
            await websocket.send_text(json.dumps({"type": "ping"}))
        except Exception:
            break


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False, proxy_headers=True)
