from datetime import datetime
from typing import List

from core.limiter import limiter
from database import get_db
from db_models import User
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from models import ShiftMoveRequest, ShiftRequest, ShiftResponse
from services.auth_service import get_current_user
from services.shifts_service import (
    ShiftAccessDeniedError,
    ShiftNotFoundError,
    ShiftsService,
)
from sqlalchemy.ext.asyncio import AsyncSession

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


def _time_to_minutes(time_str: str) -> int:
    h, m = map(int, time_str.split(":"))
    return h * 60 + m


_MAX_SHIFT_RANGE_DAYS = 180


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
        raise HTTPException(
            status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD"
        )

    start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    end_dt = datetime.strptime(end_date, "%Y-%m-%d")
    if (end_dt - start_dt).days > _MAX_SHIFT_RANGE_DAYS:
        raise HTTPException(
            status_code=400,
            detail=f"Диапазон не может превышать {_MAX_SHIFT_RANGE_DAYS} дней",
        )

    svc = ShiftsService(db)
    return await svc.list_shifts(
        start_date, end_date, current_user.id, current_user.role == "admin"
    )


@router.get("/today", response_model=List[ShiftResponse])
@limiter.limit("60/minute")
async def list_today_shifts(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List confirmed shifts for today."""
    today = datetime.now().strftime("%Y-%m-%d")
    svc = ShiftsService(db)
    return await svc.list_today_shifts(
        today, current_user.id, current_user.role == "admin"
    )


@router.get("/current", response_model=List[dict])
@limiter.limit("60/minute")
async def list_current_shifts(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List washers currently on shift (confirmed, today, within time range)."""
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    current_minutes = _time_to_minutes(now.strftime("%H:%M"))

    svc = ShiftsService(db)
    return await svc.list_current_shifts(
        today, current_minutes, current_user.id, current_user.role == "admin"
    )


@router.get("/my", response_model=List[ShiftResponse])
@limiter.limit("60/minute")
async def list_my_shifts(
    request: Request,
    limit: int = Query(365, ge=1, le=2000),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ShiftsService(db)
    return await svc.list_my_shifts(current_user.id, limit)


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
        raise HTTPException(
            status_code=400, detail="Неверный формат времени. Ожидается HH:MM"
        )
    if _time_to_minutes(req.startTime) >= _time_to_minutes(req.endTime):
        raise HTTPException(
            status_code=400,
            detail="Время начала должно быть раньше времени окончания",
        )

    svc = ShiftsService(db)
    try:
        return await svc.create_shift(
            req, current_user.username, current_user.role == "admin"
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.put("/{shift_id}/approve", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def approve_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status_code=403, detail="Только администратор может одобрять смены"
        )

    svc = ShiftsService(db)
    try:
        return await svc.approve_shift(shift_id)
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")


@router.put("/{shift_id}/reject", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def reject_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status_code=403, detail="Только администратор может отклонять смены"
        )

    svc = ShiftsService(db)
    try:
        return await svc.reject_shift(shift_id)
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")


@router.put("/{shift_id}/reopen", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def reopen_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Только администратор может возвращать смены на рассмотрение",
        )

    svc = ShiftsService(db)
    try:
        return await svc.reopen_shift(shift_id)
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")


@router.delete("/{shift_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("10/minute")
async def delete_shift(
    request: Request,
    shift_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ShiftsService(db)
    try:
        await svc.delete_shift(
            shift_id, current_user.username, current_user.role == "admin"
        )
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")
    except ShiftAccessDeniedError as e:
        raise HTTPException(status_code=403, detail=str(e))
    return None


@router.patch("/{shift_id}/move", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def move_shift(
    request: Request,
    shift_id: int,
    req: ShiftMoveRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _parse_date(req.targetDate):
        raise HTTPException(status_code=400, detail="Неверный формат даты")

    svc = ShiftsService(db)
    try:
        return await svc.move_shift(
            shift_id, req, current_user.username, current_user.role == "admin"
        )
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
