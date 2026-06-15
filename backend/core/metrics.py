"""Business metrics exposed to Prometheus."""

import time
from datetime import datetime, timedelta

from database import AsyncSessionLocal
from db_models import Appointment, Shift, User
from prometheus_client import Counter, Gauge
from sqlalchemy import and_, func, select

# Cache business metrics to avoid hitting the DB on every Prometheus scrape.
_METRICS_CACHE_TTL_SECONDS = 30.0
_metrics_last_updated = 0.0

# ─── Appointments ────────────────────────────────────────────────────────────
appointments_total = Counter(
    "lanwash_appointments_total",
    "Total number of appointments created",
    ["status"],
)

# ─── Revenue ─────────────────────────────────────────────────────────────────
daily_revenue = Gauge(
    "lanwash_daily_revenue",
    "Revenue from completed appointments today",
)

weekly_revenue = Gauge(
    "lanwash_weekly_revenue",
    "Revenue from completed appointments this week",
)

monthly_revenue = Gauge(
    "lanwash_monthly_revenue",
    "Revenue from completed appointments this month",
)

# ─── Average check ───────────────────────────────────────────────────────────
avg_check = Gauge(
    "lanwash_avg_check",
    "Average paid price for completed appointments today",
)

# ─── Box utilization ─────────────────────────────────────────────────────────
box_appointments = Gauge(
    "lanwash_box_appointments",
    "Number of appointments per box today",
    ["box"],
)

# ─── Shift coverage ──────────────────────────────────────────────────────────
shift_hours = Gauge(
    "lanwash_shift_hours",
    "Total scheduled shift hours per washer today",
    ["washer"],
)


def _today_range():
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    tomorrow = (now + timedelta(days=1)).strftime("%Y-%m-%d")
    return f"{today}T00:00:00", f"{tomorrow}T00:00:00"


async def update_business_metrics():
    """Recalculate business gauges from the database."""
    global _metrics_last_updated
    now_ts = time.monotonic()
    if now_ts - _metrics_last_updated < _METRICS_CACHE_TTL_SECONDS:
        return
    async with AsyncSessionLocal() as session:
        now = datetime.now()
        today_start, today_end = _today_range()
        week_start = (now - timedelta(days=now.weekday())).strftime("%Y-%m-%d")
        month_start = now.replace(day=1).strftime("%Y-%m-%d")

        # Daily revenue
        daily = await session.scalar(
            select(func.coalesce(func.sum(Appointment.paidPrice), 0)).where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= today_start,
                    Appointment.dateTime < today_end,
                )
            )
        )
        daily_revenue.set(daily or 0)

        # Weekly revenue
        weekly = await session.scalar(
            select(func.coalesce(func.sum(Appointment.paidPrice), 0)).where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= f"{week_start}T00:00:00",
                )
            )
        )
        weekly_revenue.set(weekly or 0)

        # Monthly revenue
        monthly = await session.scalar(
            select(func.coalesce(func.sum(Appointment.paidPrice), 0)).where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= f"{month_start}T00:00:00",
                )
            )
        )
        monthly_revenue.set(monthly or 0)

        # Average check (today)
        avg = await session.scalar(
            select(func.coalesce(func.avg(Appointment.paidPrice), 0)).where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= today_start,
                    Appointment.dateTime < today_end,
                )
            )
        )
        avg_check.set(avg or 0)

        # Box appointments today
        for box in [0, 1]:
            count = await session.scalar(
                select(func.count(Appointment.id)).where(
                    and_(
                        Appointment.dateTime >= today_start,
                        Appointment.dateTime < today_end,
                        Appointment.box_index == box,
                    )
                )
            )
            box_appointments.labels(box=str(box + 1)).set(count or 0)

        # Shift hours today
        today_str = now.strftime("%Y-%m-%d")
        res = await session.execute(
            select(Shift, User.displayName)
            .join(User, Shift.userId == User.id)
            .where(Shift.date == today_str, Shift.status == "confirmed")
        )
        for shift, name in res.all():
            start_h, start_m = map(int, shift.startTime.split(":"))
            end_h, end_m = map(int, shift.endTime.split(":"))
            minutes = (end_h * 60 + end_m) - (start_h * 60 + start_m)
            if minutes < 0:
                minutes += 24 * 60
            shift_hours.labels(washer=name).set(minutes / 60.0)

    _metrics_last_updated = time.monotonic()
