from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from database import get_db
from models import User
from models import (
    AppointmentResponse,
    TipCreateRequest,
    TipResponse,
    TipStatsResponse,
    TipWithAppointmentResponse,
)
from services.auth_service import get_current_user
from services.sbp_service import generate_sbp_url
from services.tips_service import (
    AppointmentNotFoundError,
    DuplicateTipError,
    TipAccessDeniedError,
    TipNotFoundError,
    TipsService,
)

router = APIRouter(prefix="/api/tips", tags=["tips"])


@router.post("/", response_model=TipResponse)
@limiter.limit("10/minute")
async def create_tip(
    request: Request,
    data: TipCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = TipsService(db)
    try:
        tip = await svc.create_tip(data, current_user.username)
    except AppointmentNotFoundError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except DuplicateTipError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Чаевые на эту запись уже оставлены")

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
        resp_data["sbpUrl"] = generate_sbp_url(data.amount, tip.washerUsername)
    return resp_data


@router.get("/my", response_model=List[TipWithAppointmentResponse])
@limiter.limit("60/minute")
async def list_my_tips(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = TipsService(db)
    rows = await svc.list_my_tips(current_user.username)

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
    svc = TipsService(db)
    stats = await svc.get_tip_stats(current_user.username)
    return TipStatsResponse(**stats)


@router.post("/{tip_id}/mark-paid", response_model=TipResponse)
@limiter.limit("30/minute")
async def mark_tip_paid(
    request: Request,
    tip_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = TipsService(db)
    try:
        tip = await svc.mark_tip_paid(tip_id, current_user.username, current_user.role == "admin")
    except TipNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except TipAccessDeniedError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return tip
