import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import sentry_sdk
import structlog
from fastapi import FastAPI
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

from core.background import close_arq_pool, get_arq_pool
from core.config import get_settings
from core.logging import configure_logging
from core.metrics import update_business_metrics
from db.engine import engine
from db.init import init_db

configure_logging()
logger = structlog.get_logger()
settings = get_settings()
_start_time = datetime.now(timezone.utc)


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


def _validate_production_settings():
    if not settings.is_production:
        return
    if not settings.redis_url:
        raise RuntimeError("REDIS_URL must be set in production")
    if settings.disable_rate_limit:
        raise RuntimeError("DISABLE_RATE_LIMIT must not be set in production")
    if not settings.prometheus_api_token:
        raise RuntimeError("PROMETHEUS_API_TOKEN must be set in production")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app_starting", environment=settings.environment)
    _validate_production_settings()
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

    logger.info("app_shutting_down")
    await close_arq_pool()
    try:
        from core.redis_client import get_redis
        r = await get_redis()
        if r:
            await r.aclose()
    except Exception as e:
        logger.warning("redis_close_failed", error=str(e))
    await engine.dispose()
    logger.info("app_shutdown_complete")
