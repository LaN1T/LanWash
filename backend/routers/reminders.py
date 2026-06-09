from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from db_models import User
from services.auth_service import get_current_user, check_roles
from services.reminder_service import check_and_send_reminders
from core.limiter import limiter
from fastapi import Request
import structlog

logger = structlog.get_logger()

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.post("/trigger-reminders", response_model=dict, summary="Запустить умные напоминания клиентам")
@limiter.limit("5/minute")
async def trigger_reminders(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"]))
):
    result = await check_and_send_reminders(db)
    logger.info(
        "reminders_triggered",
        admin=current_user.username,
        sent=result["sent"],
        skipped=result["skipped"],
        errors=result["errors"]
    )
    return result
