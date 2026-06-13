"""ARQ background tasks for reminder notifications."""

import structlog

from database import AsyncSessionLocal
from services.reminder_service import check_and_send_reminders

logger = structlog.get_logger()


async def send_reminders_task(ctx):
    """Trigger smart reminders for all clients.

    Runs inside the ARQ worker so the HTTP endpoint returns immediately
    and the long-running job survives server restarts.
    """
    async with AsyncSessionLocal() as db:
        result = await check_and_send_reminders(db)
        logger.info(
            "arq_reminders_task_complete",
            sent=result.get("sent", 0),
            skipped=result.get("skipped", 0),
            errors=result.get("errors", 0),
        )
        return result
