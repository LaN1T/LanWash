from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete
from database import get_db
from db_models import Shift, User
from models import ShiftRequest, ShiftResponse
from datetime import datetime
from services.auth_service import get_current_user
from core.limiter import limiter
from typing import List, Optional

router = APIRouter(prefix="/api/shifts", tags=["shifts"])


def _parse_date(date_str: str) -> bool:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def _parse_time(time_str: str) -> bool:
    try:
        datetime.strptime(time_str, "%H:%M")
        return True
    except ValueError:
        return False


@router.get("/", response_model=List[ShiftResponse])
@limiter.limit("60/minute")
async def list_shifts(
    request: Request,
    start_date: str,
    end_date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _parse_date(start_date) or not _parse_date(end_date):
        raise HTTPException(status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD")

    stmt = select(Shift).where(and_(Shift.date >= start_date, Shift.date <= end_date))
    if current_user.role != 'admin':
        stmt = stmt.where(Shift.userId == current_user.id)
    result = await db.execute(stmt)
    shifts = result.scalars().all()
    return shifts


@router.get("/my", response_model=List[ShiftResponse])
@limiter.limit("60/minute")
async def list_my_shifts(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(Shift).where(Shift.userId == current_user.id).order_by(Shift.date.asc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/", response_model=ShiftResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def create_shift(
    request: Request,
    req: ShiftRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _parse_date(req.date):
        raise HTTPException(status_code=400, detail="Неверный формат даты")
    if not _parse_time(req.startTime) or not _parse_time(req.endTime):
        raise HTTPException(status_code=400, detail="Неверный формат времени. Ожидается HH:MM")

    user_res = await db.execute(select(User).where(User.id == req.userId))
    target_user = user_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    is_admin = current_user.role == "admin"
    caller = current_user.username

    if not is_admin:
        if target_user.username != caller:
            raise HTTPException(status_code=403, detail="Можно редактировать только свои смены")

    now = datetime.now().isoformat()
    status_val = "confirmed" if is_admin else "pending"

    # Upsert: если смена на эту дату для этого пользователя уже есть — обновляем
    existing_res = await db.execute(
        select(Shift).where(and_(Shift.userId == req.userId, Shift.date == req.date))
    )
    existing = existing_res.scalar_one_or_none()

    if existing:
        if not is_admin and existing.status == "confirmed":
            # Мойщик не может редактировать подтверждённую смену напрямую
            raise HTTPException(
                status_code=403,
                detail="Подтверждённую смену может изменить только администратор",
            )
        existing.startTime = req.startTime
        existing.endTime = req.endTime
        existing.status = status_val
        existing.createdBy = caller
        existing.updatedAt = now
        await db.commit()
        await db.refresh(existing)
        return existing

    shift = Shift(
        userId=req.userId,
        date=req.date,
        startTime=req.startTime,
        endTime=req.endTime,
        status=status_val,
        createdBy=caller,
        createdAt=now,
        updatedAt=now,
    )
    db.add(shift)
    await db.commit()
    await db.refresh(shift)
    return shift


@router.put("/{shift_id}/approve", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def approve_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Только администратор может одобрять смены")

    res = await db.execute(select(Shift).where(Shift.id == shift_id))
    shift = res.scalar_one_or_none()
    if not shift:
        raise HTTPException(status_code=404, detail="Смена не найдена")

    shift.status = "confirmed"
    shift.updatedAt = datetime.now().isoformat()
    await db.commit()
    await db.refresh(shift)
    return shift


@router.put("/{shift_id}/reject", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def reject_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Только администратор может отклонять смены")

    res = await db.execute(select(Shift).where(Shift.id == shift_id))
    shift = res.scalar_one_or_none()
    if not shift:
        raise HTTPException(status_code=404, detail="Смена не найдена")

    shift.status = "rejected"
    shift.updatedAt = datetime.now().isoformat()
    await db.commit()
    await db.refresh(shift)
    return shift


@router.delete("/{shift_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("10/minute")
async def delete_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    is_admin = current_user.role == "admin"
    caller = current_user.username

    res = await db.execute(select(Shift).where(Shift.id == shift_id))
    shift = res.scalar_one_or_none()
    if not shift:
        raise HTTPException(status_code=404, detail="Смена не найдена")

    if not is_admin:
        user_res = await db.execute(select(User).where(User.id == shift.userId))
        target_user = user_res.scalar_one_or_none()
        if not target_user or target_user.username != caller:
            raise HTTPException(status_code=403, detail="Можно удалять только свои смены")
        if shift.status == "confirmed":
            raise HTTPException(status_code=403, detail="Нельзя удалить подтверждённую смену")

    await db.execute(delete(Shift).where(Shift.id == shift_id))
    await db.commit()
    return None
