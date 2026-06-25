import json
from collections import defaultdict
from datetime import date, datetime, time, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import get_settings
from models import (
    Appointment,
    AppointmentWasher,
    Shift,
    Tip,
    User,
)
from repositories import (
    AppointmentRepository,
    ConsumableRepository,
    ConsumableUsageLogRepository,
    PromoRepository,
    ServiceConsumableRepository,
    ServiceRepository,
    ShiftRepository,
    UserRepository,
    WasherAvailabilityRepository,
    WashTypeConsumableRepository,
    WashTypeRepository,
)

WASH_CATEGORY = "Мойка кузова"


class ReportsService:
    """Business logic for reports."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._appointment_repo = AppointmentRepository(db)
        self._consumable_repo = ConsumableRepository(db)
        self._consumable_usage_log_repo = ConsumableUsageLogRepository(db)
        self._promo_repo = PromoRepository(db)
        self._service_repo = ServiceRepository(db)
        self._service_consumable_repo = ServiceConsumableRepository(db)
        self._shift_repo = ShiftRepository(db)
        self._user_repo = UserRepository(db)
        self._washer_availability_repo = WasherAvailabilityRepository(db)
        self._wash_type_repo = WashTypeRepository(db)
        self._wash_type_consumable_repo = WashTypeConsumableRepository(db)

    @staticmethod
    def _apply_common_filters(
        stmt,
        *,
        washer_username: str | None = None,
        wash_type_id: str | None = None,
        promo_id: str | None = None,
        statuses: list[str] | None = None,
    ):
        if washer_username:
            stmt = stmt.where(
                or_(
                    Appointment.ownerUsername == washer_username,
                    Appointment.assigned_washers.any(
                        AppointmentWasher.washerUsername == washer_username
                    ),
                )
            )
        if wash_type_id:
            stmt = stmt.where(Appointment.washTypeId == wash_type_id)
        if promo_id:
            stmt = stmt.where(Appointment.promoId == promo_id)
        if statuses:
            stmt = stmt.where(Appointment.status.in_(statuses))
        return stmt

    @staticmethod
    def _month_bounds(d: date) -> tuple[datetime, datetime]:
        start = datetime.combine(d.replace(day=1), time.min)
        year, month = (d.year, d.month + 1) if d.month < 12 else (d.year + 1, 1)
        end = datetime.combine(date(year, month, 1), time.min)
        return start, end

    @staticmethod
    def _day_bounds(d: date) -> tuple[datetime, datetime]:
        start = datetime.combine(d, time.min)
        end = datetime.combine(d + timedelta(days=1), time.min)
        return start, end

    async def monthly_report(
        self, d: date, payload_date: str, is_month: bool = True
    ) -> dict:
        start, end = (
            self._month_bounds(d) if is_month else self._day_bounds(d)
        )
        rows = await self._appointment_repo.get_car_model_stats_in_period(start, end)
        report = []
        for car_model, avg_check, visit_count in rows:
            report.append(
                {
                    "car_model": car_model or "Не указана",
                    "avg_check": round(float(avg_check), 2),
                    "visit_count": visit_count,
                }
            )
        return {"month": payload_date, "items": report}

    async def popular_additional_services(
        self, d: date, category: str | None, payload_date: str, is_month: bool = True
    ) -> dict:
        service_map = await self._service_repo.list_all_id_name_category_map()
        id_to_name = {s_id: name for s_id, (name, _) in service_map.items()}
        id_to_cat = {s_id: cat for s_id, (_, cat) in service_map.items()}

        wt_id_to_name = await self._wash_type_repo.list_all_id_name_map()
        promo_id_to_name = await self._promo_repo.list_all_id_name_map()

        start, end = (
            self._month_bounds(d) if is_month else self._day_bounds(d)
        )

        service_counts: dict[str, int] = defaultdict(int)
        service_categories: dict[str, str] = {}

        async for (
            row
        ) in self._appointment_repo.stream_popular_services_fields_in_period(
            start, end
        ):
            add_services_json, promo_id, wash_type_id = row
            is_promo = promo_id is not None

            if wash_type_id in wt_id_to_name:
                wt_name = wt_id_to_name[wash_type_id]
                wt_cat = "Акции" if is_promo else WASH_CATEGORY
                if category is None or category == "Все":
                    service_counts[wt_name] += 1
                    service_categories[wt_name] = wt_cat
                elif category == "Акции" and is_promo:
                    service_counts[wt_name] += 1
                    service_categories[wt_name] = wt_cat
                elif category == WASH_CATEGORY:
                    service_counts[wt_name] += 1
                    service_categories[wt_name] = wt_cat

            try:
                services = json.loads(add_services_json or "[]")
            except Exception:
                services = []

            for s_id in services:
                if s_id not in id_to_name:
                    continue
                final_name = id_to_name[s_id]
                final_cat = id_to_cat[s_id] or "Прочее"

                if category is None or category == "Все":
                    service_counts[final_name] += 1
                    service_categories[final_name] = final_cat
                elif category == "Акции" and is_promo:
                    service_counts[final_name] += 1
                    service_categories[final_name] = "Акции"
                elif final_cat == category:
                    service_counts[final_name] += 1
                    service_categories[final_name] = final_cat

            if is_promo and (
                category is None or category == "Все" or category == "Акции"
            ):
                promo_name = promo_id_to_name.get(promo_id)
                if promo_name:
                    service_counts[promo_name] += 1
                    service_categories[promo_name] = "Акции"

        report_data = [
            {
                "name": name,
                "count": count,
                "category": service_categories.get(name),
            }
            for name, count in sorted(
                service_counts.items(), key=lambda i: i[1], reverse=True
            )
        ]
        return {"month": payload_date, "category": category, "items": report_data}

    async def consumables_usage(
        self, d: date, category: str | None, payload_date: str, is_month: bool = True
    ) -> dict:
        service_map = await self._service_repo.list_all_id_name_category_map()
        id_to_cat = {s_id: cat for s_id, (_, cat) in service_map.items()}

        cons_to_cats: dict[str, set[str]] = defaultdict(set)

        sc_links = (
            await self._service_consumable_repo.list_all_service_consumable_pairs()
        )
        for s_id, c_id in sc_links:
            cat = id_to_cat.get(s_id, "Прочее")
            cons_to_cats[c_id].add(cat)

        wt_consumable_ids = (
            await self._wash_type_consumable_repo.list_all_consumable_ids()
        )
        for c_id in wt_consumable_ids:
            cons_to_cats[c_id].add(WASH_CATEGORY)

        start, end = (
            self._month_bounds(d) if is_month else self._day_bounds(d)
        )

        all_consumables = await self._consumable_repo.list_all_sorted()
        sums: dict[str, float] = {c.name: 0.0 for c in all_consumables}
        units: dict[str, str] = {c.name: c.unit or "" for c in all_consumables}

        async for (
            c_id,
            name,
            unit,
            qty,
            app_id,
            promo_id,
        ) in self._consumable_usage_log_repo.stream_usage_with_appointment_in_period(
            start, end
        ):
            cats = cons_to_cats.get(c_id, set())
            is_promo = promo_id is not None

            if category is None or category == "Все":
                matches = True
            elif category == "Акции":
                matches = is_promo
            else:
                matches = category in cats

            if matches:
                sums[name] = sums.get(name, 0.0) + float(qty)
                units[name] = unit

        data = [
            {"consumable_name": n, "unit": units[n], "total_used": round(v, 2)}
            for n, v in sums.items()
        ]
        return {
            "month": payload_date,
            "category": category,
            "items": sorted(data, key=lambda x: x["total_used"], reverse=True),
        }

    async def daily_report(self, d: date, payload_date: str) -> dict:
        start, end = self._day_bounds(d)

        appointments_count = await self._appointment_repo.count_in_period(start, end)

        (
            completed_count,
            revenue,
            avg_check,
        ) = await self._appointment_repo.get_completed_stats_in_period(start, end)
        revenue = revenue or 0
        avg_check = avg_check or 0

        box_rows = await self._appointment_repo.get_box_occupancy_in_period(start, end)
        box_occupancy = {f"box{(r[0] or 0) + 1}": r[1] for r in box_rows}

        wash_types_map = await self._wash_type_repo.list_all_id_name_map()
        services_map = await self._service_repo.list_all_id_name_map()

        appt_repo = self._appointment_repo
        appt_rows = await appt_repo.list_wash_type_and_additional_services_in_period(
            start, end
        )
        service_counts: dict[str, int] = defaultdict(int)
        for wt_id, add_json in appt_rows:
            wt_name = wash_types_map.get(wt_id, wt_id)
            service_counts[wt_name] += 1
            try:
                add_ids = json.loads(add_json or "[]")
            except Exception:
                add_ids = []
            for s_id in add_ids:
                s_name = services_map.get(s_id, s_id)
                service_counts[s_name] += 1

        top_services = [
            {"name": name, "count": count, "revenue": 0.0}
            for name, count in sorted(
                service_counts.items(), key=lambda i: i[1], reverse=True
            )[:5]
        ]

        shifts = await self._shift_repo.list_for_range(d, d)

        low_stock_consumables = await self._consumable_repo.list_low_stock_alerts()
        consumables_alert = [c.name for c in low_stock_consumables]

        return {
            "report_date": d,
            "revenue": float(revenue),
            "appointments_count": appointments_count,
            "completed_count": completed_count,
            "average_check": round(float(avg_check), 2) if avg_check else 0,
            "box_occupancy": {k: float(v) for k, v in box_occupancy.items()},
            "top_services": top_services,
            "washers_on_shift": len(shifts),
            "consumables_alert": consumables_alert,
        }

    async def shift_load_report(
        self,
        start_date: date,
        end_date: date,
        start_date_payload: str,
        end_date_payload: str,
    ) -> dict:
        settings = get_settings()
        target_minutes = settings.washer_weekly_target_minutes

        shifts = await self._shift_repo.list_for_range(start_date, end_date)
        availability = await self._washer_availability_repo.list_for_range_all(
            start_date, end_date
        )
        washers = {u.id: u.displayName for u in await self._user_repo.list_washers()}

        days_count = (end_date - start_date).days + 1

        daily_minutes: dict[date, dict[str, int]] = defaultdict(
            lambda: {"confirmedMinutes": 0, "pendingMinutes": 0}
        )
        washer_minutes: dict[int, dict[str, int]] = defaultdict(
            lambda: {"confirmed": 0, "pending": 0, "rejected": 0}
        )
        status_counts = {"confirmed": 0, "pending": 0, "rejected": 0}

        for shift in shifts:
            minutes = self._shift_minutes(shift.startTime, shift.endTime)
            if shift.status == "confirmed":
                daily_minutes[shift.date]["confirmedMinutes"] += minutes
                washer_minutes[shift.userId]["confirmed"] += minutes
                status_counts["confirmed"] += 1
            elif shift.status == "pending":
                daily_minutes[shift.date]["pendingMinutes"] += minutes
                washer_minutes[shift.userId]["pending"] += minutes
                status_counts["pending"] += 1
            elif shift.status == "rejected":
                washer_minutes[shift.userId]["rejected"] += minutes
                status_counts["rejected"] += 1

        daily_hours = []
        current = start_date
        while current <= end_date:
            entry = daily_minutes.get(
                current, {"confirmedMinutes": 0, "pendingMinutes": 0}
            )
            daily_hours.append(
                {
                    "date": current.isoformat(),
                    "confirmedMinutes": entry["confirmedMinutes"],
                    "pendingMinutes": entry["pendingMinutes"],
                }
            )
            current += timedelta(days=1)

        washer_stats = []
        for user_id, display_name in sorted(washers.items(), key=lambda x: x[1]):
            confirmed = washer_minutes[user_id]["confirmed"]
            pending = washer_minutes[user_id]["pending"]
            rejected = washer_minutes[user_id]["rejected"]
            utilization = (confirmed / target_minutes * 100) if target_minutes else 0.0
            washer_stats.append(
                {
                    "userId": user_id,
                    "displayName": display_name,
                    "confirmedMinutes": confirmed,
                    "pendingMinutes": pending,
                    "rejectedMinutes": rejected,
                    "utilizationPercent": round(utilization, 1),
                    "isOvertime": confirmed > target_minutes,
                    "isUnderload": confirmed < target_minutes * 0.5,
                }
            )

        availability_counts = {"available": 0, "unavailable": 0}
        for a in availability:
            if a.status in availability_counts:
                availability_counts[a.status] += 1

        total_possible_days = len(washers) * days_count
        unknown_days = max(
            0,
            total_possible_days
            - availability_counts["available"]
            - availability_counts["unavailable"],
        )

        return {
            "startDate": start_date_payload,
            "endDate": end_date_payload,
            "targetWeeklyMinutesPerWasher": target_minutes,
            "dailyHours": daily_hours,
            "washerStats": washer_stats,
            "statusCounts": status_counts,
            "conflictCount": self._count_conflicts(shifts),
            "availabilityCoverage": {
                "availableDays": availability_counts["available"],
                "unavailableDays": availability_counts["unavailable"],
                "unknownDays": unknown_days,
            },
        }

    async def financial_report(
        self,
        start_date: date,
        end_date: date,
        group_by: str = "day",
        washer_username: str | None = None,
        wash_type_id: str | None = None,
        promo_id: str | None = None,
    ) -> dict:
        stmt = select(
            Appointment.date,
            func.count(Appointment.id).label("appointments_count"),
            func.coalesce(func.sum(Appointment.paidPrice), 0).label("revenue"),
            func.coalesce(
                func.sum(Appointment.originalPrice - Appointment.paidPrice), 0
            ).label("discounts_total"),
            func.coalesce(func.sum(Appointment.originalPrice), 0).label(
                "services_total"
            ),
        ).where(
            Appointment.date >= start_date,
            Appointment.date <= end_date,
            Appointment.status == "completed",
        )
        stmt = self._apply_common_filters(
            stmt,
            washer_username=washer_username,
            wash_type_id=wash_type_id,
            promo_id=promo_id,
        )
        stmt = stmt.group_by(Appointment.date).order_by(Appointment.date)
        result = await self._db.execute(stmt)
        rows = result.all()

        def _key(d: date) -> str:
            if group_by == "week":
                return d.strftime("%Y-W%W")
            if group_by == "month":
                return d.strftime("%Y-%m")
            return d.strftime("%Y-%m-%d")

        grouped: dict[str, dict] = {}
        for row in rows:
            key = _key(row.date)
            entry = grouped.setdefault(
                key,
                {
                    "period": key,
                    "appointments_count": 0,
                    "services_total": 0.0,
                    "discounts_total": 0.0,
                    "revenue": 0.0,
                },
            )
            entry["appointments_count"] += row.appointments_count
            entry["services_total"] += float(row.services_total)
            entry["discounts_total"] += float(row.discounts_total)
            entry["revenue"] += float(row.revenue)

        items = list(grouped.values())
        summary = {
            "appointments_count": sum(i["appointments_count"] for i in items),
            "services_total": round(sum(i["services_total"] for i in items), 2),
            "discounts_total": round(sum(i["discounts_total"] for i in items), 2),
            "revenue": round(sum(i["revenue"] for i in items), 2),
        }
        return {"summary": summary, "items": items}

    async def washer_payroll_report(
        self,
        start_date: date,
        end_date: date,
        washer_username: str | None = None,
    ) -> dict:
        stmt = (
            select(
                User.username,
                User.displayName.label("washer_name"),
                func.count(Appointment.id).label("appointments_count"),
                func.coalesce(func.sum(Appointment.paidPrice), 0).label(
                    "services_total"
                ),
            )
            .join(AppointmentWasher, AppointmentWasher.appointmentId == Appointment.id)
            .join(User, User.username == AppointmentWasher.washerUsername)
            .where(
                Appointment.date >= start_date,
                Appointment.date <= end_date,
                Appointment.status == "completed",
            )
        )
        if washer_username:
            stmt = stmt.where(User.username == washer_username)
        stmt = stmt.group_by(User.username, User.displayName).order_by(
            User.displayName
        )
        result = await self._db.execute(stmt)
        rows = result.all()

        dt_start = datetime.combine(start_date, time.min)
        dt_end = datetime.combine(end_date, time(23, 59, 59, 999999))
        tips_result = await self._db.execute(
            select(
                Tip.washerUsername,
                func.coalesce(func.sum(Tip.amount), 0).label("tips_total"),
            )
            .where(Tip.createdAt >= dt_start, Tip.createdAt <= dt_end)
            .group_by(Tip.washerUsername)
        )
        tips_by_washer = {
            row[0]: float(row[1]) for row in tips_result.all() if row[0]
        }

        items = []
        for row in rows:
            services_total = float(row.services_total)
            tips_total = tips_by_washer.get(row.username, 0.0)
            items.append(
                {
                    "washer_username": row.username,
                    "washer_name": row.washer_name or row.username,
                    "appointments_count": row.appointments_count,
                    "services_total": services_total,
                    "tips_total": tips_total,
                    "total": services_total + tips_total,
                }
            )
        return {"items": items}

    async def cancellations_report(
        self,
        start_date: date,
        end_date: date,
        reason: str | None = None,
        washer_username: str | None = None,
        wash_type_id: str | None = None,
    ) -> dict:
        stmt = select(
            Appointment.id,
            Appointment.date,
            Appointment.clientName,
            Appointment.carModel,
            Appointment.cancel_reason,
            Appointment.paidPrice,
        ).where(
            Appointment.date >= start_date,
            Appointment.date <= end_date,
            Appointment.status.in_(["cancelled", "refunded"]),
        )
        stmt = self._apply_common_filters(
            stmt,
            washer_username=washer_username,
            wash_type_id=wash_type_id,
        )
        if reason:
            stmt = stmt.where(Appointment.cancel_reason == reason)
        result = await self._db.execute(
            stmt.order_by(Appointment.date, Appointment.dateTime)
        )
        rows = result.all()

        items = []
        for row in rows:
            items.append(
                {
                    "appointment_id": row[0],
                    "date": row[1],
                    "client_name": row[2],
                    "car_model": row[3],
                    "reason": row[4],
                    "cancelled_by": "unknown",
                    "lost_revenue": float(row[5] or 0),
                }
            )
        summary = {
            "total_cancellations": len(items),
            "lost_revenue": round(sum(i["lost_revenue"] for i in items), 2),
        }
        return {"summary": summary, "items": items}

    async def promo_effectiveness_report(
        self,
        start_date: date,
        end_date: date,
        promo_id: str | None = None,
    ) -> dict:
        stmt = select(
            Appointment.promoId,
            func.count(Appointment.id).label("uses_count"),
            func.coalesce(func.sum(Appointment.paidPrice), 0).label("revenue"),
            func.coalesce(
                func.sum(Appointment.originalPrice - Appointment.paidPrice), 0
            ).label("discount_total"),
        ).where(
            Appointment.date >= start_date,
            Appointment.date <= end_date,
            Appointment.status == "completed",
            Appointment.promoId.isnot(None),
        )
        if promo_id:
            stmt = stmt.where(Appointment.promoId == promo_id)
        stmt = stmt.group_by(Appointment.promoId)
        result = await self._db.execute(stmt)
        rows = result.all()

        promo_names = await self._promo_repo.list_all_id_name_map()

        items = []
        for row in rows:
            items.append(
                {
                    "promo_id": row.promoId,
                    "promo_name": promo_names.get(row.promoId) or "Без названия",
                    "uses_count": row.uses_count,
                    "revenue": float(row.revenue),
                    "discount_total": float(row.discount_total),
                }
            )
        return {"items": items}

    @staticmethod
    def _time_to_minutes(t: time | str) -> int:
        if isinstance(t, time):
            return t.hour * 60 + t.minute
        h, m = map(int, t.split(":"))
        return h * 60 + m

    @classmethod
    def _shift_minutes(cls, start_time: time | str, end_time: time | str) -> int:
        start = cls._time_to_minutes(start_time)
        end = cls._time_to_minutes(end_time)
        return end - start

    @classmethod
    def _count_conflicts(cls, shifts: list[Shift]) -> int:
        by_date: dict[date, list[Shift]] = defaultdict(list)
        for shift in shifts:
            if shift.status not in ("confirmed", "pending"):
                continue
            by_date[shift.date].append(shift)

        total = 0
        for day_shifts in by_date.values():
            for i in range(len(day_shifts)):
                for j in range(i + 1, len(day_shifts)):
                    a = day_shifts[i]
                    b = day_shifts[j]
                    a_s = cls._time_to_minutes(a.startTime)
                    a_e = a_s + cls._shift_minutes(a.startTime, a.endTime)
                    b_s = cls._time_to_minutes(b.startTime)
                    b_e = b_s + cls._shift_minutes(b.startTime, b.endTime)
                    if a_s < b_e and a_e > b_s:
                        total += 1
        return total
