from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from database import get_db
from db_models import User
from models import WasherAvailabilityResponse, WasherAvailabilityUpdateRequest
from services.auth_service import check_roles, get_current_user
from services.washer_availability_service import WasherAvailabilityService

router = APIRouter(
    prefix="/api/washers",
    tags=["washers"],
    dependencies=[Depends(check_roles(["admin", "washer"]))],
)


def _parse_date(date_str: str) -> bool:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def _service(db: AsyncSession = Depends(get_db)) -> WasherAvailabilityService:
    return WasherAvailabilityService(db)


def _ensure_access(current_user: User, target_user_id: int) -> None:
    if current_user.id != target_user_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Доступ запрещён")


@router.get("/{user_id}/availability", response_model=List[WasherAvailabilityResponse])
@limiter.limit("60/minute")
async def get_availability(
    request: Request,
    user_id: int,
    start_date: str,
    end_date: str,
    service: WasherAvailabilityService = Depends(_service),
    current_user: User = Depends(get_current_user),
):
    _ensure_access(current_user, user_id)
    if not _parse_date(start_date) or not _parse_date(end_date):
        raise HTTPException(
            status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD"
        )
    return await service.get_availability(user_id, start_date, end_date)


@router.put("/{user_id}/availability")
@limiter.limit("20/minute")
async def update_availability(
    request: Request,
    user_id: int,
    payload: WasherAvailabilityUpdateRequest,
    service: WasherAvailabilityService = Depends(_service),
    current_user: User = Depends(get_current_user),
):
    _ensure_access(current_user, user_id)
    for entry in payload.entries:
        if not _parse_date(entry.date):
            raise HTTPException(
                status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD"
            )
    rows = await service.update_availability(user_id, payload.entries)
    return {"entries": [WasherAvailabilityResponse.model_validate(r).model_dump() for r in rows]}


@router.delete("/{user_id}/availability")
@limiter.limit("20/minute")
async def delete_availability(
    request: Request,
    user_id: int,
    start_date: str,
    end_date: str,
    service: WasherAvailabilityService = Depends(_service),
    current_user: User = Depends(get_current_user),
):
    _ensure_access(current_user, user_id)
    if not _parse_date(start_date) or not _parse_date(end_date):
        raise HTTPException(
            status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD"
        )
    deleted = await service.delete_availability(user_id, start_date, end_date)
    return {"deleted": deleted}
