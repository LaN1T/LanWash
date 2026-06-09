"""ARQ background tasks."""

import structlog

from arq import create_pool

from core.background import REDIS_SETTINGS
from core.metrics import update_business_metrics

logger = structlog.get_logger()


async def send_notification(ctx, user_id: int, message: str):
    """Send a notification to a user."""
    logger.info("send_notification_task", user_id=user_id, message=message)
    return True


async def update_metrics(ctx):
    """Update business metrics and reschedule self in 30 seconds."""
    await update_business_metrics()
    try:
        from core.background import get_arq_pool
        pool = await get_arq_pool()
        await pool.enqueue_job("update_metrics", _defer_by=30)
    except Exception as e:
        logger.warning("metrics_reschedule_failed", error=str(e))
    return True


class WorkerSettings:
    """ARQ worker configuration."""

    functions = [send_notification, update_metrics]
    redis_settings = REDIS_SETTINGS
