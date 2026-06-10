from sqlalchemy.ext.asyncio import AsyncSession
from services.reminder_service import check_and_send_reminders
import structlog

logger = structlog.get_logger()


class RemindersService:
    """Business logic for triggering reminders."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def trigger_reminders(self, admin_username: str) -> dict:
        result = await check_and_send_reminders(self._db)
        logger.info(
            "reminders_triggered",
            admin=admin_username,
            sent=result["sent"],
            skipped=result["skipped"],
            errors=result["errors"]
        )
        return result
