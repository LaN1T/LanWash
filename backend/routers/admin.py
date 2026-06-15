from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from database import get_db
from models import User
from models import (
    BulkAssignWasherRequest,
    BulkCancelRequest,
    BulkResult,
    BulkUpdateStatusRequest,
    DashboardResponse,
    ForecastResponse,
    UserListResponse,
)
from services.admin_service import AdminService
from services.audit_service import log_admin_action
from services.auth_service import check_roles

router = APIRouter(prefix="/api/admin", tags=["admin"])


def _parse_iso_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат даты. Ожидается YYYY-MM-DD")


@router.get("/dashboard", response_model=DashboardResponse)
@limiter.limit("30/minute")
async def admin_dashboard(
    request: Request,
    from_date: str,
    to_date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Period dashboard KPIs for admins."""
    from_dt = _parse_iso_date(from_date)
    to_dt = _parse_iso_date(to_date)
    if from_dt > to_dt:
        raise HTTPException(status_code=400, detail="from_date не может быть позже to_date")

    svc = AdminService(db)
    return await svc.get_dashboard(from_date, to_date)


@router.get("/forecast", response_model=ForecastResponse)
@limiter.limit("60/minute")
async def get_forecast(
    request: Request,
    days: int = 7,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    if days < 1 or days > 14:
        raise HTTPException(status_code=400, detail="days must be between 1 and 14")

    svc = AdminService(db)
    return await svc.get_forecast(days)


@router.post("/bulk/assign-washer", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_assign_washer(
    request: Request,
    req: BulkAssignWasherRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Assign a washer to multiple appointments at once."""
    svc = AdminService(db)
    result = await svc.bulk_assign_washer(req.appointmentIds, req.washerUsername)
    await log_admin_action(
        db,
        current_user,
        action="bulk_assign_washer",
        entity_type="appointment",
        entity_id=",".join(req.appointmentIds),
        new_values={"appointmentIds": req.appointmentIds, "washerUsername": req.washerUsername, "result": result},
        request=request,
    )
    await db.commit()
    return result


@router.post("/bulk/cancel", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_cancel(
    request: Request,
    req: BulkCancelRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Cancel multiple appointments at once."""
    svc = AdminService(db)
    result = await svc.bulk_cancel(req.appointmentIds, req.reason)
    await log_admin_action(
        db,
        current_user,
        action="bulk_cancel_appointments",
        entity_type="appointment",
        entity_id=",".join(req.appointmentIds),
        new_values={"appointmentIds": req.appointmentIds, "reason": req.reason, "result": result},
        request=request,
    )
    await db.commit()
    return result


@router.post("/bulk/update-status", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_update_status(
    request: Request,
    req: BulkUpdateStatusRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Update status for multiple appointments at once."""
    svc = AdminService(db)
    result = await svc.bulk_update_status(req.appointmentIds, req.status)
    await log_admin_action(
        db,
        current_user,
        action="bulk_update_status",
        entity_type="appointment",
        entity_id=",".join(req.appointmentIds),
        new_values={"appointmentIds": req.appointmentIds, "status": req.status, "result": result},
        request=request,
    )
    await db.commit()
    return result


@router.get("/users", response_model=UserListResponse)
@limiter.limit("30/minute")
async def search_users(
    request: Request,
    q: str | None = None,
    role: str | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = 20,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Search and filter users (admin only)."""
    svc = AdminService(db)
    return await svc.search_users(q, role, from_date, to_date, limit, offset)
