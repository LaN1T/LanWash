from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from database import get_db
from db_models import User
from services.auth_service import get_current_user
from services.reports_service import ReportsService

router = APIRouter(
    prefix="/api/reports",
    tags=["reports"],
)


@router.get("/monthly-check-vs-price/")
@limiter.limit("30/minute")
async def monthly_report(
    request: Request,
    date: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ только для администраторов.")
    if not date:
        date = datetime.now().strftime("%Y-%m")
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
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ только для администраторов.")
    if not date:
        date = datetime.now().strftime("%Y-%m")
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
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ только для администраторов.")
    if not date:
        date = datetime.now().strftime("%Y-%m")
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
    """Daily summary: revenue, appointments, top services, washers on shift, consumables alerts."""
    if current_user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ только для администраторов.")
    if not date:
        date = datetime.now().strftime("%Y-%m-%d")
    svc = ReportsService(db)
    return await svc.daily_report(date)
