from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from database import get_db
from db_models import User
from models import LogRequest, LogResponse
from services.auth_service import check_roles, get_current_user
from services.logs_service import LogsService

router = APIRouter(
    prefix="/api/logs",
    tags=["logs"],
)


@router.get("/", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, limit: int = Query(default=200, ge=1, le=1000), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ к логам только для администраторов.")
    svc = LogsService(db)
    return await svc.get_all(limit)


@router.get("/by-user/{username}", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_by_user(request: Request, username: str, limit: int = Query(default=1000, ge=1, le=5000), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к логам этого пользователя.")
    svc = LogsService(db)
    return await svc.get_by_user(username.lower(), limit)


@router.post("/", response_model=LogResponse)
@limiter.limit("30/minute")
async def create(request: Request, req: LogRequest, db: AsyncSession = Depends(get_db)):
    # Эндпоинт публичный, так как используется для записи логина/регистрации до авторизации
    svc = LogsService(db)
    return await svc.create_log(req.username.lower(), req.action, req.details)


@router.delete("/")
@limiter.limit("10/minute")
async def clear_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Только администраторы могут очищать логи.")
    svc = LogsService(db)
    await svc.clear_all()
    return {"ok": True}
