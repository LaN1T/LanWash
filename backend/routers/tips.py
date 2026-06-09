import json
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update

from database import get_db
from db_models import Tip, Appointment, User
from models import (
    TipCreateRequest,
    TipResponse,
    TipStatsResponse,
    TipWithAppointmentResponse,
    AppointmentResponse,
)
from services.auth_service import get_current_user, check_roles
from services.sbp_service import generate_sbp_url
from core.limiter import limiter

router = APIRouter(prefix="/api/tips", tags=["tips"])


def _first_washer(assigned_washer_raw: str) -> Optional[str]:
    try:
        washers = json.loads(assigned_washer_raw) if assigned_washer_raw else []
        if isinstance(washers, list) and washers:
            return washers[0]
    except json.JSONDecodeError:
        if assigned_washer_raw and assigned_washer_raw != "[]":
            return assigned_washer_raw
    return None


@router.post("/", response_model=TipResponse)
@limiter.limit("10/minute")
async def create_tip(
    request: Request,
    data: TipCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Appointment).where(Appointment.id == data.appointmentId))
    appointment = result.scalar_one_or_none()
    if not appointment:
        raise HTTPException(status_code=400, detail="Запись не найдена")
    if appointment.status != "completed":
        raise HTTPException(status_code=400, detail="Можно оставить чаевые только за завершённую мойку")
    if appointment.ownerUsername != current_user.username:
        raise HTTPException(status_code=403, detail="Нельзя оставить чаевые за чужую запись")

    washer_username = _first_washer(appointment.assignedWasher)
    if not washer_username:
        raise HTTPException(status_code=400, detail="На эту запись не назначен мойщик")

    existing = await db.execute(
        select(Tip).where(Tip.appointmentId == data.appointmentId, Tip.washerUsername == washer_username)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Чаевые на эту запись уже оставлены")

    tip = Tip(
        appointmentId=data.appointmentId,
        washerUsername=washer_username,
        amount=data.amount,
        method=data.method,
        status="pending",
        createdAt=datetime.now(timezone.utc).isoformat(),
    )
    db.add(tip)
    await db.commit()
    await db.refresh(tip)

    resp_data = {
        "id": tip.id,
        "appointmentId": tip.appointmentId,
        "washerUsername": tip.washerUsername,
        "amount": tip.amount,
        "method": tip.method,
        "status": tip.status,
        "createdAt": tip.createdAt,
    }
    if data.method == "sbp":
        resp_data["sbpUrl"] = generate_sbp_url(data.amount, washer_username)
    return resp_data


@router.get("/my", response_model=List[TipWithAppointmentResponse])
@limiter.limit("60/minute")
async def list_my_tips(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(Tip, Appointment)
        .join(Appointment, Tip.appointmentId == Appointment.id, isouter=True)
        .where(Tip.washerUsername == current_user.username)
        .order_by(Tip.createdAt.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    out = []
    for tip, appointment in rows:
        item = {
            "id": tip.id,
            "appointmentId": tip.appointmentId,
            "washerUsername": tip.washerUsername,
            "amount": tip.amount,
            "method": tip.method,
            "status": tip.status,
            "createdAt": tip.createdAt,
        }
        if appointment:
            item["appointment"] = AppointmentResponse.model_validate(appointment)
        else:
            item["appointment"] = None
        out.append(item)
    return out


@router.get("/stats", response_model=TipStatsResponse)
@limiter.limit("60/minute")
async def get_tip_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    total_res = await db.execute(
        select(func.count(Tip.id)).where(Tip.washerUsername == current_user.username)
    )
    total_tips = total_res.scalar() or 0

    total_amount_res = await db.execute(
        select(func.sum(Tip.amount)).where(
            Tip.washerUsername == current_user.username,
            Tip.status == "paid",
        )
    )
    total_amount = total_amount_res.scalar() or 0

    pending_amount_res = await db.execute(
        select(func.sum(Tip.amount)).where(
            Tip.washerUsername == current_user.username,
            Tip.status == "pending",
        )
    )
    pending_amount = pending_amount_res.scalar() or 0

    return {
        "totalTips": total_tips,
        "totalAmount": total_amount,
        "pendingAmount": pending_amount,
    }


@router.post("/{tip_id}/mark-paid", response_model=TipResponse)
@limiter.limit("30/minute")
async def mark_tip_paid(
    request: Request,
    tip_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Tip).where(Tip.id == tip_id))
    tip = result.scalar_one_or_none()
    if not tip:
        raise HTTPException(status_code=404, detail="Чаевые не найдены")

    if current_user.username != tip.washerUsername and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Нет прав на изменение статуса")

    update_result = await db.execute(
        update(Tip)
        .where(Tip.id == tip_id, Tip.status == "pending")
        .values(status="paid")
    )
    await db.commit()
    if update_result.rowcount == 0:
        raise HTTPException(status_code=409, detail="Чаевые уже отмечены как полученные")

    await db.refresh(tip)
    tip.status = "paid"
    return tip
