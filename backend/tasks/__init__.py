"""ARQ background tasks."""

import structlog

from core.background import REDIS_SETTINGS
from core.metrics import update_business_metrics
from tasks.notifications import send_fcm_notification
from tasks.reminders import send_reminders_task

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


async def check_inventory_forecast(ctx, db=None):
    """Check inventory forecast and log alerts for critical items."""
    from db.session import AsyncSessionLocal
    from services.inventory_forecast_service import generate_inventory_forecast

    session = db
    opened_session = False
    if session is None:
        session = AsyncSessionLocal()
        opened_session = True

    try:
        forecast = await generate_inventory_forecast(session)
        alerts = []
        for item in forecast.items:
            if item.status == "critical":
                logger.warning(
                    "inventory_critical_alert",
                    consumable_id=item.consumable_id,
                    name=item.name,
                    days_until_low=item.days_until_low,
                )
                alerts.append(
                    {
                        "consumable_id": item.consumable_id,
                        "name": item.name,
                        "days_until_low": item.days_until_low,
                        "status": item.status,
                    }
                )
        return {"checked": len(forecast.items), "alerts": alerts}
    finally:
        if opened_session:
            await session.close()


class WorkerSettings:
    """ARQ worker configuration."""

    functions = [
        send_notification,
        update_metrics,
        check_inventory_forecast,
        send_fcm_notification,
        send_reminders_task,
    ]
    redis_settings = REDIS_SETTINGS
