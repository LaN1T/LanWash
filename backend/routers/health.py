from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import get_settings
from core.redis_client import get_redis
from database import get_db

settings = get_settings()
_start_time = datetime.now(timezone.utc)

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check():
    uptime = (datetime.now(timezone.utc) - _start_time).total_seconds()
    return {
        "status": "healthy",
        "service": "LanWash API",
        "version": "1.0.0",
        "environment": settings.environment,
        "uptime_seconds": int(uptime),
    }


@router.get("/health/deep")
async def health_check_deep(db: AsyncSession = Depends(get_db)):
    uptime = (datetime.now(timezone.utc) - _start_time).total_seconds()
    checks = {}
    overall = "healthy"

    # Database check
    try:
        await db.execute(select(1))
        checks["database"] = {"status": "ok"}
    except Exception as exc:
        checks["database"] = {"status": "error", "error": str(exc)}
        overall = "degraded"

    # Redis check
    try:
        redis_client = get_redis()
        if redis_client is not None:
            await redis_client.ping()
            checks["redis"] = {"status": "ok"}
        else:
            checks["redis"] = {"status": "error", "error": "Redis not available"}
            overall = "degraded"
    except Exception as exc:
        checks["redis"] = {"status": "error", "error": str(exc)}
        overall = "degraded"

    return {
        "status": overall,
        "uptime_seconds": int(uptime),
        "checks": checks,
    }
