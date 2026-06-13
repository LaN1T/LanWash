"""ARQ background tasks for push notifications."""

import structlog

from services.fcm_service import fcm_service

logger = structlog.get_logger()


async def send_fcm_notification(ctx, tokens: list[str], title: str, body: str, data: dict | None = None):
    """Send an FCM push notification to a list of tokens.

    This task is intended to run inside the ARQ worker so that notification
    delivery is durable and does not block the HTTP request/response cycle.
    """
    if not tokens:
        return {"sent": 0, "skipped": True}

    try:
        response = await fcm_service.send_notification_to_tokens(tokens, title, body, data)
        logger.info(
            "arq_fcm_task_sent",
            tokens_count=len(tokens),
            success=getattr(response, "success_count", 0) if response else 0,
            failure=getattr(response, "failure_count", 0) if response else 0,
        )
        return {
            "sent": getattr(response, "success_count", 0) if response else 0,
            "failure": getattr(response, "failure_count", 0) if response else 0,
        }
    except Exception as e:
        logger.error("arq_fcm_task_failed", error=str(e), tokens_count=len(tokens))
        raise
