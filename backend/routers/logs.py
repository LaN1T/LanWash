from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, update, delete, func
from database import get_db
from models import LogRequest, LogResponse
from db_models import LogEntry, User
from datetime import datetime
from services.auth_service import get_current_user, check_roles

router = APIRouter(prefix="/api/logs", tags=["logs"])

@router.get("/", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_all(request: Request, limit: int = 200, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ к логам только для администраторов.")
    result = await db.execute(select(LogEntry).order_by(LogEntry.timestamp.desc()).limit(limit))
    return result.scalars().all()

@router.get("/by-user/{username}", response_model=list[LogResponse])
@limiter.limit("60/minute")
async def get_by_user(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к логам этого пользователя.")
    result = await db.execute(select(LogEntry).where(LogEntry.username == username.lower()).order_by(LogEntry.timestamp.desc()))
    return result.scalars().all()

@router.post("/", response_model=LogResponse)
@limiter.limit("30/minute")
async def create(request: Request, req: LogRequest, db: AsyncSession = Depends(get_db)):
    # Эндпоинт публичный, так как используется для записи логина/регистрации до авторизации
    new_log = LogEntry(
        username=req.username.lower(),
        action=req.action,
        details=req.details,
        timestamp=datetime.now().isoformat()
    )
    db.add(new_log)
    await db.commit()
    await db.refresh(new_log)
    return new_log

@router.delete("/")
@limiter.limit("10/minute")
async def clear_all(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Только администраторы могут очищать логи.")
    await db.execute(delete(LogEntry))
    await db.commit()
    return {"ok": True}
