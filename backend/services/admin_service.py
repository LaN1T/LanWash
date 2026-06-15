import json
import json as _json
from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.redis_client import get_redis
from models import Appointment, Review, User
from models import ForecastResponse
from services.forecast_service import generate_forecast


class AdminService:
    """Business logic for admin operations."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

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
        to_dt_inclusive = to_dt + timedelta(days=1)

        base_filter = and_(
            Appointment.dateTime >= from_dt.isoformat(),
            Appointment.dateTime < to_dt_inclusive.isoformat(),
        )

        # Total counts by status
        status_result = await self._db.execute(
            select(Appointment.status, func.count(Appointment.id))
            .where(base_filter)
            .group_by(Appointment.status)
        )
        status_counts = {row[0]: row[1] for row in status_result.all()}
        total_appointments = sum(status_counts.values())
        completed = status_counts.get("completed", 0)
        cancelled = status_counts.get("cancelled", 0)

        # Revenue & avg check
        revenue_result = await self._db.execute(
            select(func.sum(Appointment.paidPrice), func.avg(Appointment.paidPrice))
            .where(and_(base_filter, Appointment.status == "completed"))
        )
        revenue_row = revenue_result.first()
        total_revenue = int(revenue_row[0] or 0)
        avg_check = round(float(revenue_row[1] or 0), 2)

        # Clients analysis
        appts_result = await self._db.execute(
            select(Appointment.ownerUsername, Appointment.dateTime)
            .where(and_(base_filter, Appointment.status == "completed"))
            .order_by(Appointment.dateTime.asc())
        )
        appts = appts_result.all()

        first_visit_result = await self._db.execute(
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
                returning_clients += 1

        # Average rating
        rating_result = await self._db.execute(
            select(func.avg(Review.rating))
            .where(
                and_(
                    Review.createdAt >= from_dt.isoformat(),
                    Review.createdAt < to_dt_inclusive.isoformat(),
                    Review.isPublished == 1,
                )
            )
        )
        avg_rating = round(float(rating_result.scalar() or 0), 2)

        # Daily breakdown
        daily_revenue: dict[str, int] = defaultdict(int)
        daily_apps: dict[str, int] = defaultdict(int)
        daily_completed: dict[str, int] = defaultdict(int)

        day_result = await self._db.execute(
            select(
                Appointment.date,
                Appointment.status,
                Appointment.paidPrice,
            ).where(base_filter)
        )
        for day, status, paid in day_result.all():
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

        # Top washers
        washer_apps_result = await self._db.execute(
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
            share = int(paid or 0) // len(usernames)
            for u in usernames:
                washer_revenue[u] += share
                washer_count[u] += 1

        top_washers = [
            {"name": name, "revenue": rev, "appointments": washer_count[name]}
            for name, rev in sorted(washer_revenue.items(), key=lambda x: x[1], reverse=True)[:5]
        ]

        washer_usernames = [w["name"] for w in top_washers]
        if washer_usernames:
            user_result = await self._db.execute(
                select(User.username, User.displayName).where(User.username.in_(washer_usernames))
            )
            name_map = {row[0]: row[1] for row in user_result.all()}
            for w in top_washers:
                w["name"] = name_map.get(w["name"], w["name"])

        # Top clients
        client_result = await self._db.execute(
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
            user_result = await self._db.execute(
                select(User.username, User.displayName).where(User.username.in_(client_usernames))
            )
            name_map = {row[0]: row[1] for row in user_result.all()}
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

    async def bulk_assign_washer(self, appointment_ids: list[str], washer_username: str) -> dict:
        result = await self._db.execute(
            select(Appointment).where(Appointment.id.in_(appointment_ids))
        )
        appointments = result.scalars().all()

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
        errors: list[str] = []
        if missing:
            errors.append(f"Не найдены записи: {', '.join(missing)}")

        processed = 0
        for appt in appointments:
            if appt.status == "cancelled":
                errors.append(f"{appt.id}: нельзя назначить мойщика на отменённую запись")
                continue
            appt.assignedWasher = json.dumps([washer_username])
            appt.isModifiedByAdmin = 1
            processed += 1

        await self._db.commit()
        return {"processed": processed, "failed": len(errors), "errors": errors}

    async def bulk_cancel(self, appointment_ids: list[str], reason: str | None) -> dict:
        result = await self._db.execute(
            select(Appointment).where(Appointment.id.in_(appointment_ids))
        )
        appointments = result.scalars().all()

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
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
            if reason:
                appt.notes = f"{appt.notes}\n[Отмена: {reason}]".strip()
            appt.isModifiedByAdmin = 1
            appt.updatedAt = now
            processed += 1

        await self._db.commit()
        return {"processed": processed, "failed": len(errors), "errors": errors}

    async def bulk_update_status(self, appointment_ids: list[str], status: str) -> dict:
        result = await self._db.execute(
            select(Appointment).where(Appointment.id.in_(appointment_ids))
        )
        appointments = result.scalars().all()

        found_ids = {a.id for a in appointments}
        missing = [i for i in appointment_ids if i not in found_ids]
        errors: list[str] = []
        if missing:
            errors.append(f"Не найдены записи: {', '.join(missing)}")

        processed = 0
        now = datetime.now().isoformat()
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
        from_date: str | None,
        to_date: str | None,
        limit: int,
        offset: int,
    ) -> dict:
        stmt = select(User)
        filters = []

        if q:
            escaped_q = q.replace('%', r'\%').replace('_', r'\_')
            safe_q = f"%{escaped_q}%"
            filters.append(
                or_(
                    User.displayName.ilike(safe_q, escape='\\'),
                    User.username.ilike(safe_q, escape='\\'),
                    User.phone.ilike(safe_q, escape='\\'),
                    User.carModel.ilike(safe_q, escape='\\'),
                    User.carNumber.ilike(safe_q, escape='\\'),
                )
            )

        if role:
            filters.append(User.role == role)

        if from_date:
            filters.append(User.createdAt >= from_date)
        if to_date:
            filters.append(User.createdAt < to_date + "T23:59:59")

        if filters:
            stmt = stmt.where(and_(*filters))

        count_stmt = select(func.count(User.id))
        if filters:
            count_stmt = count_stmt.where(and_(*filters))
        total_result = await self._db.execute(count_stmt)
        total = total_result.scalar() or 0

        stmt = stmt.order_by(User.createdAt.desc()).limit(limit).offset(offset)
        result = await self._db.execute(stmt)
        items = result.scalars().all()

        from models import UserListItem

        return {
            "items": [UserListItem.model_validate(u) for u in items],
            "total": total,
        }
