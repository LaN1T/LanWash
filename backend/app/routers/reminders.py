from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import User
from services.auth_service import check_roles
from services.reminders_service import RemindersService

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.post(
    "/trigger-reminders",
    response_model=dict,
    summary="Запустить умные напоминания клиентам",
)
@limiter.limit("5/minute")
async def trigger_reminders(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    arq_pool = getattr(request.app.state, "arq_pool", None)
    if arq_pool:
        job = await arq_pool.enqueue_job("send_reminders_task")
        return {"status": "queued", "job_id": job.job_id}

    # Fallback: run inline when ARQ is unavailable (tests / dev without Redis)
    svc = RemindersService(db)
    return await svc.trigger_reminders(current_user.username)
