from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from db_models import User
from services.auth_service import get_current_user, check_roles
from services.reminders_service import RemindersService
from core.limiter import limiter
from fastapi import Request

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.post("/trigger-reminders", response_model=dict, summary="Запустить умные напоминания клиентам")
@limiter.limit("5/minute")
async def trigger_reminders(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"]))
):
    svc = RemindersService(db)
    return await svc.trigger_reminders(current_user.username)
