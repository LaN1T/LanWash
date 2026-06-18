from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import User
from schemas import ShiftLoadResponse
from services.auth_service import get_current_user
from services.reports_service import ReportsService

router = APIRouter(
    prefix="/api/reports",
    tags=["reports"],
)


def _parse_month(date: str | None) -> str:
    """Validate and normalize a YYYY-MM date string."""
    if not date:
        return datetime.now().strftime("%Y-%m")
    try:
        datetime.strptime(date, "%Y-%m")
    except ValueError:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Invalid date format. Expected YYYY-MM."
        )
    return date


def _parse_day(date: str | None) -> str:
    """Validate and normalize a YYYY-MM-DD date string."""
    if not date:
        return datetime.now().strftime("%Y-%m-%d")
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Invalid date format. Expected YYYY-MM-DD."
        )
    return date


@router.get("/monthly-check-vs-price/")
@limiter.limit("30/minute")
async def monthly_report(
    request: Request,
    date: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    date = _parse_month(date)
    svc = ReportsService(db)
    return await svc.monthly_report(date)


@router.get("/popular-additional-services/")
@limiter.limit("30/minute")
async def get_popular_additional_services(
    request: Request,
    date: str = None,
    category: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    date = _parse_month(date)
    svc = ReportsService(db)
    return await svc.popular_additional_services(date, category)


@router.get("/consumables-usage/")
@limiter.limit("30/minute")
async def get_consumables_usage(
    request: Request,
    date: str = None,
    category: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    date = _parse_month(date)
    svc = ReportsService(db)
    return await svc.consumables_usage(date, category)


@router.get("/daily/")
@limiter.limit("60/minute")
async def daily_report(
    request: Request,
    date: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daily summary: revenue, appointments, top services,
    washers on shift, consumables alerts."""
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    date = _parse_day(date)
    svc = ReportsService(db)
    return await svc.daily_report(date)


@router.get("/shift-load/", response_model=ShiftLoadResponse)
@limiter.limit("60/minute")
async def shift_load_report(
    request: Request,
    start_date: str,
    end_date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Weekly shift load analytics (admin only)."""
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов"
        )
    start_date = _parse_day(start_date)
    end_date = _parse_day(end_date)
    if start_date > end_date:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    return await svc.shift_load_report(start_date, end_date)
