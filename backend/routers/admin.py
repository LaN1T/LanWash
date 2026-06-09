from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, cast, String
from database import get_db
from db_models import Appointment, User, Review
from models import DashboardResponse, BulkAssignWasherRequest, BulkCancelRequest, BulkUpdateStatusRequest, BulkResult
from services.auth_service import check_roles
from core.limiter import limiter
from datetime import datetime, timedelta
from collections import defaultdict
import json

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

    # Include full last day
    to_dt_inclusive = to_dt + timedelta(days=1)

    # ─── Appointments base query ──────────────────────────────────────────────
    base_filter = and_(
        Appointment.dateTime >= from_dt.isoformat(),
        Appointment.dateTime < to_dt_inclusive.isoformat(),
    )

    # Total counts by status
    status_result = await db.execute(
        select(Appointment.status, func.count(Appointment.id))
        .where(base_filter)
        .group_by(Appointment.status)
    )
    status_counts = {row[0]: row[1] for row in status_result.all()}
    total_appointments = sum(status_counts.values())
    completed = status_counts.get("completed", 0)
    cancelled = status_counts.get("cancelled", 0)

    # Revenue & avg check
    revenue_result = await db.execute(
        select(func.sum(Appointment.paidPrice), func.avg(Appointment.paidPrice))
        .where(and_(base_filter, Appointment.status == "completed"))
    )
    revenue_row = revenue_result.first()
    total_revenue = int(revenue_row[0] or 0)
    avg_check = round(float(revenue_row[1] or 0), 2)

    # ─── Clients analysis ─────────────────────────────────────────────────────
    # All completed appointments in period with owners
    appts_result = await db.execute(
        select(Appointment.ownerUsername, Appointment.dateTime)
        .where(and_(base_filter, Appointment.status == "completed"))
        .order_by(Appointment.dateTime.asc())
    )
    appts = appts_result.all()

    # First ever completed appointment per client (all time)
    first_visit_result = await db.execute(
        select(Appointment.ownerUsername, func.min(Appointment.dateTime))
        .where(Appointment.status == "completed")
        .group_by(Appointment.ownerUsername)
    )
    first_visit_map = {row[0]: row[1] for row in first_visit_result.all()}

    client_visits_in_period: dict[str, int] = defaultdict(int)
    for owner, _ in appts:
        client_visits_in_period[owner] += 1

    new_clients = 0
    returning_clients = 0
    for owner, visits in client_visits_in_period.items():
        first_visit = first_visit_map.get(owner)
        if first_visit and from_dt.isoformat() <= first_visit < to_dt_inclusive.isoformat():
            new_clients += 1
        elif visits >= 2:
            returning_clients += 1
        elif visits == 1:
            # Single visit but not first ever in period -> returning
            returning_clients += 1

    # ─── Average rating ───────────────────────────────────────────────────────
    rating_result = await db.execute(
        select(func.avg(Review.rating))
        .where(
            and_(
                Review.createdAt >= from_dt.isoformat(),
                Review.createdAt < to_dt_inclusive.isoformat(),
                Review.isPublished == True,
            )
        )
    )
    avg_rating = round(float(rating_result.scalar() or 0), 2)

    # ─── Daily breakdown ──────────────────────────────────────────────────────
    daily_revenue: dict[str, int] = defaultdict(int)
    daily_apps: dict[str, int] = defaultdict(int)
    daily_completed: dict[str, int] = defaultdict(int)

    # Revenue/completed by day
    day_result = await db.execute(
        select(
            cast(Appointment.dateTime, String),
            Appointment.status,
            Appointment.paidPrice,
        ).where(base_filter)
    )
    for dt_str, status, paid in day_result.all():
        day = dt_str[:10]
        daily_apps[day] += 1
        if status == "completed":
            daily_completed[day] += 1
            daily_revenue[day] += int(paid or 0)

    all_days = []
    d = from_dt
    while d <= to_dt:
        day_str = d.strftime("%Y-%m-%d")
        all_days.append(
            {
                "date": day_str,
                "revenue": daily_revenue.get(day_str, 0),
                "appointments": daily_apps.get(day_str, 0),
                "completed": daily_completed.get(day_str, 0),
            }
        )
        d += timedelta(days=1)

    # ─── Top washers ──────────────────────────────────────────────────────────
    # assignedWasher is JSON array; process in Python
    washer_apps_result = await db.execute(
        select(Appointment.assignedWasher, Appointment.paidPrice)
        .where(and_(base_filter, Appointment.status == "completed"))
    )
    washer_revenue: dict[str, int] = defaultdict(int)
    washer_count: dict[str, int] = defaultdict(int)
    for assigned_json, paid in washer_apps_result.all():
        try:
            usernames = json.loads(assigned_json or "[]")
        except Exception:
            usernames = []
        if not usernames:
            continue
        # Split revenue equally among assigned washers
        share = int(paid or 0) // len(usernames)
        for u in usernames:
            washer_revenue[u] += share
            washer_count[u] += 1

    top_washers = [
        {"name": name, "revenue": rev, "appointments": washer_count[name]}
        for name, rev in sorted(washer_revenue.items(), key=lambda x: x[1], reverse=True)[:5]
    ]

    # Resolve display names for washers
    washer_usernames = [w["name"] for w in top_washers]
    if washer_usernames:
        user_result = await db.execute(
            select(User.username, User.displayName).where(User.username.in_(washer_usernames))
        )
        name_map = {row[0]: row[1] for row in user_result.all()}
        for w in top_washers:
            w["name"] = name_map.get(w["name"], w["name"])

    # ─── Top clients ──────────────────────────────────────────────────────────
    client_result = await db.execute(
        select(Appointment.ownerUsername, func.count(Appointment.id), func.sum(Appointment.paidPrice))
        .where(and_(base_filter, Appointment.status == "completed", Appointment.ownerUsername.isnot(None)))
        .group_by(Appointment.ownerUsername)
        .order_by(func.count(Appointment.id).desc())
        .limit(5)
    )
    top_clients = [
        {"name": row[0] or "Unknown", "visits": row[1], "totalSpent": int(row[2] or 0)}
        for row in client_result.all()
    ]

    client_usernames = [c["name"] for c in top_clients]
    if client_usernames:
        user_result = await db.execute(
            select(User.username, User.displayName).where(User.username.in_(client_usernames))
        )
        name_map = {row[0]: row[1] for row in user_result.all()}
        for c in top_clients:
            c["name"] = name_map.get(c["name"], c["name"])

    return DashboardResponse(
        fromDate=from_date,
        toDate=to_date,
        totalRevenue=total_revenue,
        totalAppointments=total_appointments,
        completedAppointments=completed,
        cancelledAppointments=cancelled,
        averageCheck=avg_check,
        newClients=new_clients,
        returningClients=returning_clients,
        averageRating=avg_rating,
        dailyBreakdown=all_days,
        topWashers=top_washers,
        topClients=top_clients,
    )


# ─── Bulk Operations ────────────────────────────────────────────────────────
@router.post("/bulk/assign-washer", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_assign_washer(
    request: Request,
    req: BulkAssignWasherRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Assign a washer to multiple appointments at once."""
    result = await db.execute(
        select(Appointment).where(Appointment.id.in_(req.appointmentIds))
    )
    appointments = result.scalars().all()

    found_ids = {a.id for a in appointments}
    missing = [i for i in req.appointmentIds if i not in found_ids]
    errors: list[str] = []
    if missing:
        errors.append(f"Не найдены записи: {', '.join(missing)}")

    processed = 0
    for appt in appointments:
        if appt.status == "cancelled":
            errors.append(f"{appt.id}: нельзя назначить мойщика на отменённую запись")
            continue
        appt.assignedWasher = json.dumps([req.washerUsername])
        appt.isModifiedByAdmin = 1
        processed += 1

    await db.commit()
    return BulkResult(processed=processed, failed=len(errors), errors=errors)


@router.post("/bulk/cancel", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_cancel(
    request: Request,
    req: BulkCancelRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Cancel multiple appointments at once."""
    result = await db.execute(
        select(Appointment).where(Appointment.id.in_(req.appointmentIds))
    )
    appointments = result.scalars().all()

    found_ids = {a.id for a in appointments}
    missing = [i for i in req.appointmentIds if i not in found_ids]
    errors: list[str] = []
    if missing:
        errors.append(f"Не найдены записи: {', '.join(missing)}")

    processed = 0
    now = datetime.now().isoformat()
    for appt in appointments:
        if appt.status == "cancelled":
            errors.append(f"{appt.id}: уже отменена")
            continue
        if appt.status == "completed":
            errors.append(f"{appt.id}: нельзя отменить завершённую запись")
            continue
        appt.status = "cancelled"
        if req.reason:
            appt.notes = f"{appt.notes}\n[Отмена: {req.reason}]".strip()
        appt.isModifiedByAdmin = 1
        appt.updatedAt = now
        processed += 1

    await db.commit()
    return BulkResult(processed=processed, failed=len(errors), errors=errors)


@router.post("/bulk/update-status", response_model=BulkResult)
@limiter.limit("10/minute")
async def bulk_update_status(
    request: Request,
    req: BulkUpdateStatusRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Update status for multiple appointments at once."""
    result = await db.execute(
        select(Appointment).where(Appointment.id.in_(req.appointmentIds))
    )
    appointments = result.scalars().all()

    found_ids = {a.id for a in appointments}
    missing = [i for i in req.appointmentIds if i not in found_ids]
    errors: list[str] = []
    if missing:
        errors.append(f"Не найдены записи: {', '.join(missing)}")

    processed = 0
    now = datetime.now().isoformat()
    for appt in appointments:
        if appt.status == req.status:
            errors.append(f"{appt.id}: уже имеет статус {req.status}")
            continue
        if req.status == "cancelled" and appt.status == "completed":
            errors.append(f"{appt.id}: нельзя отменить завершённую запись")
            continue
        appt.status = req.status
        appt.isModifiedByAdmin = 1
        appt.updatedAt = now
        processed += 1

    await db.commit()
    return BulkResult(processed=processed, failed=len(errors), errors=errors)
