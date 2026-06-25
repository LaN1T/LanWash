from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import User
from schemas import (
    CancellationsReportResponse,
    ConsumablesUsageResponse,
    DailyReportResponse,
    FinancialReportResponse,
    MonthlyCheckVsPriceResponse,
    PopularServicesResponse,
    PromoEffectivenessResponse,
    ShiftLoadResponse,
    WasherPayrollResponse,
)
from services.auth_service import get_current_user
from services.excel_export_service import ExcelExportService
from services.reports_service import ReportsService

router = APIRouter(
    prefix="/api/reports",
    tags=["reports"],
)


def _parse_day(date_str: str | None) -> str:
    """Validate and normalize a YYYY-MM-DD date string for the response payload."""
    if not date_str:
        return datetime.now().strftime("%Y-%m-%d")
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Invalid date format. Expected YYYY-MM-DD."
        )
    return date_str


def _parse_report_period(
    date_str: str | None,
) -> tuple[str, date, bool]:
    """Validate and normalize a report period string.

    Supports both YYYY-MM (month) and YYYY-MM-DD (day).
    Returns (payload_date, report_date, is_month).
    """
    if not date_str:
        payload = datetime.now().strftime("%Y-%m")
        return payload, datetime.strptime(payload, "%Y-%m").date(), True
    if len(date_str) == 7:
        try:
            datetime.strptime(date_str, "%Y-%m")
        except ValueError:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Invalid date format. Expected YYYY-MM."
            )
        return date_str, datetime.strptime(date_str, "%Y-%m").date(), True
    if len(date_str) == 10:
        try:
            datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Invalid date format. Expected YYYY-MM-DD.",
            )
        return date_str, date.fromisoformat(date_str), False
    raise HTTPException(
        status.HTTP_400_BAD_REQUEST,
        "Invalid date format. Expected YYYY-MM or YYYY-MM-DD.",
    )


@router.get("/monthly-check-vs-price/", response_model=MonthlyCheckVsPriceResponse)
@limiter.limit("30/minute")
async def monthly_report(
    request: Request,
    date_str: str = Query(None, alias="date"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    payload_date, report_date, is_month = _parse_report_period(date_str)
    svc = ReportsService(db)
    return await svc.monthly_report(report_date, payload_date, is_month)


@router.get("/popular-additional-services/", response_model=PopularServicesResponse)
@limiter.limit("30/minute")
async def get_popular_additional_services(
    request: Request,
    date_str: str = Query(None, alias="date"),
    category: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    payload_date, report_date, is_month = _parse_report_period(date_str)
    svc = ReportsService(db)
    return await svc.popular_additional_services(
        report_date, category, payload_date, is_month
    )


@router.get("/consumables-usage/", response_model=ConsumablesUsageResponse)
@limiter.limit("30/minute")
async def get_consumables_usage(
    request: Request,
    date_str: str = Query(None, alias="date"),
    category: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    payload_date, report_date, is_month = _parse_report_period(date_str)
    svc = ReportsService(db)
    return await svc.consumables_usage(
        report_date, category, payload_date, is_month
    )


@router.get("/daily/", response_model=DailyReportResponse)
@limiter.limit("60/minute")
async def daily_report(
    request: Request,
    date_str: str = Query(None, alias="date"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daily summary: revenue, appointments, top services,
    washers on shift, consumables alerts."""
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    payload_date = _parse_day(date_str)
    svc = ReportsService(db)
    return await svc.daily_report(date.fromisoformat(payload_date), payload_date)


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
    start_date_str = _parse_day(start_date)
    end_date_str = _parse_day(end_date)
    if start_date_str > end_date_str:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    return await svc.shift_load_report(
        date.fromisoformat(start_date_str),
        date.fromisoformat(end_date_str),
        start_date_str,
        end_date_str,
    )


@router.get("/financial/", response_model=FinancialReportResponse)
@limiter.limit("60/minute")
async def financial_report(
    request: Request,
    start_date: date,
    end_date: date,
    group_by: str = Query("day", pattern=r"^(day|week|month)$"),
    washer_username: str | None = None,
    wash_type_id: str | None = None,
    promo_id: str | None = None,
    format: str = Query("json", pattern=r"^(json|xlsx)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    if start_date > end_date:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    data = await svc.financial_report(
        start_date,
        end_date,
        group_by=group_by,
        washer_username=washer_username,
        wash_type_id=wash_type_id,
        promo_id=promo_id,
    )
    if format == "xlsx":
        headers = ["Период", "Записей", "Услуги", "Скидки", "Выручка"]
        rows = [
            [
                i["period"],
                i["appointments_count"],
                i["services_total"],
                i["discounts_total"],
                i["revenue"],
            ]
            for i in data["items"]
        ]
        xlsx, filename = ExcelExportService.generate(
            f"financial_{start_date}_{end_date}", headers, rows
        )
        return Response(
            content=xlsx,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    return data


@router.get("/washer-payroll/", response_model=WasherPayrollResponse)
@limiter.limit("60/minute")
async def washer_payroll_report(
    request: Request,
    start_date: date,
    end_date: date,
    washer_username: str | None = None,
    format: str = Query("json", pattern=r"^(json|xlsx)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    if start_date > end_date:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    data = await svc.washer_payroll_report(
        start_date, end_date, washer_username
    )
    if format == "xlsx":
        headers = ["Мойщик", "Записей", "Услуги", "Чаевые", "Итого"]
        rows = [
            [
                i["washer_name"],
                i["appointments_count"],
                i["services_total"],
                i["tips_total"],
                i["total"],
            ]
            for i in data["items"]
        ]
        xlsx, filename = ExcelExportService.generate(
            f"washer_payroll_{start_date}_{end_date}", headers, rows
        )
        return Response(
            content=xlsx,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    return data


@router.get("/cancellations/", response_model=CancellationsReportResponse)
@limiter.limit("60/minute")
async def cancellations_report(
    request: Request,
    start_date: date,
    end_date: date,
    reason: str | None = None,
    washer_username: str | None = None,
    wash_type_id: str | None = None,
    format: str = Query("json", pattern=r"^(json|xlsx)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    if start_date > end_date:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    data = await svc.cancellations_report(
        start_date,
        end_date,
        reason=reason,
        washer_username=washer_username,
        wash_type_id=wash_type_id,
    )
    if format == "xlsx":
        headers = [
            "ID",
            "Дата",
            "Клиент",
            "Авто",
            "Причина",
            "Кем отменено",
            "Потеря",
        ]
        rows = [
            [
                i["appointment_id"],
                i["date"],
                i["client_name"],
                i["car_model"],
                i["reason"],
                i["cancelled_by"],
                i["lost_revenue"],
            ]
            for i in data["items"]
        ]
        xlsx, filename = ExcelExportService.generate(
            f"cancellations_{start_date}_{end_date}", headers, rows
        )
        return Response(
            content=xlsx,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    return data


@router.get("/promo-effectiveness/", response_model=PromoEffectivenessResponse)
@limiter.limit("60/minute")
async def promo_effectiveness_report(
    request: Request,
    start_date: date,
    end_date: date,
    promo_id: str | None = None,
    format: str = Query("json", pattern=r"^(json|xlsx)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов."
        )
    if start_date > end_date:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "start_date must be before or equal to end_date",
        )
    svc = ReportsService(db)
    data = await svc.promo_effectiveness_report(
        start_date, end_date, promo_id
    )
    if format == "xlsx":
        headers = ["Акция", "Использований", "Выручка", "Скидка"]
        rows = [
            [
                i["promo_name"],
                i["uses_count"],
                i["revenue"],
                i["discount_total"],
            ]
            for i in data["items"]
        ]
        xlsx, filename = ExcelExportService.generate(
            f"promo_effectiveness_{start_date}_{end_date}", headers, rows
        )
        return Response(
            content=xlsx,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    return data
