import asyncio
import json
import os
import re
import time
from datetime import datetime, timezone

import structlog
from fastapi import (
    Depends,
    FastAPI,
    Header,
    HTTPException,
    Request,
    Security,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_fastapi_instrumentator.middleware import PrometheusInstrumentatorMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import select

from app.deps import check_roles, get_current_user, get_db
from app.lifespan import lifespan
from app.middleware import (
    add_cors_middleware,
    add_security_middleware,
    app_check_middleware,
    business_metrics_middleware,
    log_requests,
    metrics_rate_limit_middleware,
)
from app.routers import (
    admin,
    appointments,
    auth,
    cars,
    consumables,
    health,
    logs,
    notes,
    referrals,
    reminders,
    reports,
    reviews,
    services,
    shift_templates,
    shifts,
    subscriptions,
    support,
    tips,
    wash_types,
    washer_availability,
)
from core.config import get_settings
from core.limiter import limiter
from core.logging import configure_logging
from models import SupportChat
from services.appointment_ws_manager import appointment_ws_manager
from services.websocket_manager import connect, disconnect

configure_logging()
logger = structlog.get_logger()
settings = get_settings()
_start_time = datetime.now(timezone.utc)

app = FastAPI(
    title="LanWash API",
    description=(
        "REST API для системы управления автомойкой. "
        "Поддерживает роли: client, washer, admin."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
)

# Avatar files served with authentication
uploads_dir = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(uploads_dir, exist_ok=True)


@app.get("/uploads/avatars/{filename}")
@limiter.limit("60/minute")
async def get_avatar(
    request: Request, filename: str, current_user=Depends(get_current_user)
):
    """Serve avatar images with auth check."""
    if not filename or re.search(r"[/\\]", filename) or filename.startswith("."):
        raise HTTPException(400, "Invalid filename")
    filepath = os.path.join(uploads_dir, "avatars", os.path.basename(filename))
    if not await asyncio.to_thread(os.path.exists, filepath):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath)


# Apply rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Prometheus metrics (exposed at /metrics) — protected by static token
_metrics_scheme = HTTPBearer(auto_error=False)


def _verify_metrics_token(
    credentials: HTTPAuthorizationCredentials = Security(_metrics_scheme),
):
    if not settings.prometheus_api_token:
        raise HTTPException(status_code=403, detail="Metrics auth not configured")
    if not credentials or credentials.credentials != settings.prometheus_api_token:
        raise HTTPException(status_code=403, detail="Forbidden")
    return credentials.credentials


# Patch: newer Starlette uses _IncludedRouter, which the instrumentator's
# route-name resolver does not handle. Fall back to the raw path when it fails.
_orig_get_handler = PrometheusInstrumentatorMiddleware._get_handler


def _safe_get_handler(self, request: Request) -> tuple[str, bool]:
    try:
        return _orig_get_handler(self, request)
    except AttributeError:
        return request.url.path, False


PrometheusInstrumentatorMiddleware._get_handler = _safe_get_handler


Instrumentator().instrument(app).expose(
    app,
    include_in_schema=False,
    dependencies=[Depends(_verify_metrics_token)],
)

# Middleware (order matters)
app.middleware("http")(metrics_rate_limit_middleware)
add_cors_middleware(app)
add_security_middleware(app)
app.middleware("http")(app_check_middleware)
app.middleware("http")(business_metrics_middleware)
app.middleware("http")(log_requests)


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
app.include_router(
    reports.router, dependencies=[Depends(check_roles(["admin", "washer"]))]
)
app.include_router(
    consumables.router, dependencies=[Depends(check_roles(["admin", "washer"]))]
)
app.include_router(wash_types.router)
app.include_router(shifts.router)
app.include_router(
    shift_templates.router, dependencies=[Depends(check_roles(["admin", "washer"]))]
)
app.include_router(washer_availability.router)
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
async def telegram_webhook(
    request: Request, update: dict, x_telegram_bot_api_secret_token: str = Header(None)
):
    if not TELEGRAM_SECRET:
        raise HTTPException(500, "Webhook secret not configured")
    if x_telegram_bot_api_secret_token != TELEGRAM_SECRET:
        raise HTTPException(403, "Invalid secret token")
    from bot.webhook import process_update

    return await process_update(update)


# Telegram Mini App static files (must be after ALL API routes)
miniapp_dir = os.path.join(
    os.path.dirname(__file__), "..", "..", "telegram-miniapp", "dist"
)
if os.path.exists(miniapp_dir):

    @app.get("/{path:path}")
    async def serve_miniapp(path: str):
        headers = {
            "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
            "Pragma": "no-cache",
            "Expires": "0",
        }
        file_path = os.path.normpath(os.path.join(miniapp_dir, path))
        norm_miniapp = os.path.normpath(miniapp_dir)
        if not file_path.startswith(norm_miniapp):
            raise HTTPException(403, "Invalid path")
        if (
            path
            and await asyncio.to_thread(os.path.exists, file_path)
            and await asyncio.to_thread(os.path.isfile, file_path)
        ):
            return FileResponse(file_path, headers=headers)
        return FileResponse(os.path.join(miniapp_dir, "index.html"), headers=headers)
else:
    logger.warning("miniapp_static_dir_not_found", path=miniapp_dir)


# ─── Support Chat WebSocket ─────────────────────────────────────────────────
_ws_attempts: dict[str, list[float]] = {}


def _cleanup_ws_attempts() -> None:
    now = time.time()
    stale = [
        ip
        for ip, attempts in _ws_attempts.items()
        if not any(now - t < 60 for t in attempts)
    ]
    for ip in stale:
        _ws_attempts.pop(ip, None)


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
        if attempts:
            _ws_attempts[ip] = attempts
        else:
            _ws_attempts.pop(ip, None)

    # Opportunistically clean stale entries every ~100 connections
    if len(_ws_attempts) > 10000:
        _cleanup_ws_attempts()

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
            if len(raw) > 65536:
                await websocket.close(code=1009)
                break
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


# ─── Appointments WebSocket ─────────────────────────────────────────────────

@app.websocket("/ws/appointments")
async def appointments_websocket(websocket: WebSocket):
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

    await appointment_ws_manager.connect(
        current_user.id, current_user.role, websocket
    )
    heartbeat_task = asyncio.create_task(_websocket_heartbeat(websocket))

    try:
        while True:
            raw = await websocket.receive_text()
            if len(raw) > 4096:
                await websocket.close(code=1009)
                break
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
        await appointment_ws_manager.disconnect(current_user.id, websocket)
        if db_gen:
            try:
                await db_gen.aclose()
            except Exception:
                pass


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        # Intentionally bind all interfaces inside the container.
        host="0.0.0.0",  # nosec: B104
        port=8000,
        reload=False,
        proxy_headers=True,
    )
