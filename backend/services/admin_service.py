import json
import json as _json
from collections import defaultdict
from datetime import date, datetime, timedelta, time

from sqlalchemy.ext.asyncio import AsyncSession

from core.redis_client import get_redis
from repositories import AppointmentRepository, ReviewRepository, UserRepository
from schemas import ForecastResponse
from services.forecast_service import generate_forecast


class AdminService:
    """Business logic for admin operations."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._appointments = AppointmentRepository(db)
        self._reviews = ReviewRepository(db)
        self._users = UserRepository(db)

    _DASHBOARD_CACHE_TTL_SECONDS = 60

    async def get_dashboard(self, from_date: str, to_date: str) -> dict:
        cache_key = f"dashboard:{from_date}:{to_date}"
        try:
            redis = get_redis()
            if redis:
                cached = await redis.get(cache_key)
                if cached:
                    return json.loads(cached)
        except Exception:
            pass

        from_dt = datetime.strptime(from_date, "%Y-%m-%d")
        to_dt = datetime.strptime(to_date, "%Y-%m-%d")

        start = datetime.combine(from_dt, time.min)
        end = datetime.combine(to_dt + timedelta(days=1), time.min)

        # Total counts by status
        status_rows = await self._appointments.get_status_counts_in_period(
            start, end
        )
        status_counts = dict(status_rows)
        total_appointments = sum(status_counts.values())
        completed = status_counts.get("completed", 0)
        cancelled = status_counts.get("cancelled", 0)

        # Revenue & avg check
        revenue_sum, revenue_avg = await self._appointments.get_revenue_stats_in_period(
            start, end
        )
        total_revenue = int(revenue_sum or 0)
        avg_check = round(float(revenue_avg or 0), 2)

        # Clients analysis
        appts = await self._appointments.list_completed_owners_datetimes_in_period(
            start, end
        )
        first_visit_map = await self._appointments.get_first_visit_dates()

        client_visits_in_period: dict[str, int] = defaultdict(int)
        for owner, _ in appts:
            client_visits_in_period[owner] += 1

        new_clients = 0
        returning_clients = 0
        for owner, visits in client_visits_in_period.items():
            first_visit = first_visit_map.get(owner)
            if first_visit and start <= first_visit < end:
                new_clients += 1
            elif visits >= 2:
                returning_clients += 1
            elif visits == 1:
                returning_clients += 1

        # Average rating
        avg_rating_value = await self._reviews.get_average_rating_published_in_period(
            start, end
        )
        avg_rating = round(float(avg_rating_value or 0), 2)

        # Daily breakdown
        daily_revenue: dict[str, int] = defaultdict(int)
        daily_apps: dict[str, int] = defaultdict(int)
        daily_completed: dict[str, int] = defaultdict(int)

        day_rows = await self._appointments.list_period_details(start, end)
        for day, status, paid in day_rows:
            day_str = day.isoformat()
            daily_apps[day_str] += 1
            if status == "completed":
                daily_completed[day_str] += 1
                daily_revenue[day_str] += int(paid or 0)

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

        # Top washers
        washer_rows = await self._appointments.list_completed_washer_paid_in_period(
            start, end
        )
        washer_revenue: dict[str, int] = defaultdict(int)
        washer_count: dict[str, int] = defaultdict(int)
        for username, paid in washer_rows:
            if not username:
                continue
            washer_revenue[username] += int(paid or 0)
            washer_count[username] += 1

        top_washers = [
            {"name": name, "revenue": rev, "appointments": washer_count[name]}
            for name, rev in sorted(
                washer_revenue.items(), key=lambda x: x[1], reverse=True
            )[:5]
        ]

        washer_usernames = [w["name"] for w in top_washers]
        if washer_usernames:
            name_map = await self._users.get_display_names_by_usernames(
                washer_usernames
            )
            for w in top_washers:
                w["name"] = name_map.get(w["name"], w["name"])

        # Top clients
        client_rows = await self._appointments.list_completed_owner_stats_in_period(
            start, end, limit=5
        )
        top_clients = [
            {
                "name": row[0] or "Unknown",
                "visits": row[1],
                "totalSpent": int(row[2] or 0),
            }
            for row in client_rows
        ]

        client_usernames = [c["name"] for c in top_clients]
        if client_usernames:
            name_map = await self._users.get_display_names_by_usernames(
                client_usernames
            )
            for c in top_clients:
                c["name"] = name_map.get(c["name"], c["name"])

        result = {
            "fromDate": from_date,
            "toDate": to_date,
            "totalRevenue": total_revenue,
            "totalAppointments": total_appointments,
            "completedAppointments": completed,
            "cancelledAppointments": cancelled,
            "averageCheck": avg_check,
            "newClients": new_clients,
            "returningClients": returning_clients,
            "averageRating": avg_rating,
            "dailyBreakdown": all_days,
            "topWashers": top_washers,
            "topClients": top_clients,
        }

        try:
            redis = get_redis()
            if redis:
                await redis.setex(
                    cache_key, self._DASHBOARD_CACHE_TTL_SECONDS, json.dumps(result)
                )
        except Exception:
            pass

        return result

    async def get_forecast(self, days: int) -> ForecastResponse:
        cache_key = f"forecast:{days}"
        try:
            redis = get_redis()
            if redis:
                cached = await redis.get(cache_key)
                if cached:
                    data = _json.loads(cached)
                    return ForecastResponse(**data)
        except Exception:
            pass

        forecast = await generate_forecast(self._db, days=days)

        try:
            redis = get_redis()
            if redis:
                await redis.setex(cache_key, 3600, _json.dumps(forecast.model_dump()))
        except Exception:
            pass

        return forecast

    async def bulk_assign_washer(
        self, appointment_ids: list[str], washer_username: str
    ) -> dict:
        appointments = await self._appointments.get_by_ids(appointment_ids)

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
        errors: list[str] = []
        if missing:
            errors.append(f"Не найдены записи: {', '.join(missing)}")

        processed = 0
        for appt in appointments:
            if appt.status == "cancelled":
                errors.append(
                    f"{appt.id}: нельзя назначить мойщика на отменённую запись"
                )
                continue
            appt.assignedWasher = json.dumps([washer_username])
            appt.isModifiedByAdmin = 1
            processed += 1

        await self._db.commit()
        return {"processed": processed, "failed": len(errors), "errors": errors}

    async def bulk_cancel(self, appointment_ids: list[str], reason: str | None) -> dict:
        appointments = await self._appointments.get_by_ids(appointment_ids)

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
        errors: list[str] = []
        if missing:
            errors.append(f"Не найдены записи: {', '.join(missing)}")

        processed = 0
        now = datetime.now()
        for appt in appointments:
            if appt.status == "cancelled":
                errors.append(f"{appt.id}: уже отменена")
                continue
            if appt.status == "completed":
                errors.append(f"{appt.id}: нельзя отменить завершённую запись")
                continue
            appt.status = "cancelled"
            if reason:
                appt.notes = f"{appt.notes}\n[Отмена: {reason}]".strip()
            appt.isModifiedByAdmin = 1
            appt.updatedAt = now
            processed += 1

        await self._db.commit()
        return {"processed": processed, "failed": len(errors), "errors": errors}

    async def bulk_update_status(self, appointment_ids: list[str], status: str) -> dict:
        appointments = await self._appointments.get_by_ids(appointment_ids)

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
        errors: list[str] = []
        if missing:
            errors.append(f"Не найдены записи: {', '.join(missing)}")

        processed = 0
        now = datetime.now()
        for appt in appointments:
            if appt.status == status:
                errors.append(f"{appt.id}: уже имеет статус {status}")
                continue
            if status == "cancelled" and appt.status == "completed":
                errors.append(f"{appt.id}: нельзя отменить завершённую запись")
                continue
            appt.status = status
            appt.isModifiedByAdmin = 1
            appt.updatedAt = now
            processed += 1

        await self._db.commit()
        return {"processed": processed, "failed": len(errors), "errors": errors}

    async def search_users(
        self,
        q: str | None,
        role: str | None,
        from_date: date | None,
        to_date: date | None,
        limit: int,
        offset: int,
    ) -> dict:
        items, total = await self._users.search(
            q=q,
            role=role,
            from_date=from_date,
            to_date=to_date,
            limit=limit,
            offset=offset,
        )

        from schemas import UserListItem

        return {
            "items": [UserListItem.model_validate(u) for u in items],
            "total": total,
        }
