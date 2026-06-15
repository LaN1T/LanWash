import json
import random
from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from models import Shift
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
SHIFT_LOAD_TARGET_WEEKLY_MINUTES = 40 * 60


class CarPriceService:
    @staticmethod
    async def get_average_price(car_model: str) -> int:
        base_prices = {
            "toyota camry": 2500000,
            "bmw x5": 6000000,
            "mercedes-benz e-class": 4500000,
            "hyundai solaris": 1200000,
            "kia rio": 1100000,
            "lada vesta": 1000000,
            "volkswagen tiguan": 3000000,
            "skoda octavia": 2000000,
        }
        model_lower = car_model.lower()
        for key, price in base_prices.items():
            if key in model_lower:
                return price + random.randint(-100000, 100000)
        return random.randint(1500000, 3500000)


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
    def _month_bounds(date_str: str) -> tuple[str, str]:
        dt = datetime.strptime(date_str, "%Y-%m")
        start = dt.strftime("%Y-%m")
        year, month = (dt.year, dt.month + 1) if dt.month < 12 else (dt.year + 1, 1)
        end = f"{year}-{month:02d}"
        return start, end

    @staticmethod
    def _day_bounds(date_str: str) -> tuple[str, str]:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        start = dt.strftime("%Y-%m-%d")
        end = (dt + timedelta(days=1)).strftime("%Y-%m-%d")
        return start, end

    async def monthly_report(self, date: str) -> dict:
        start, end = self._month_bounds(date)
        rows = await self._appointment_repo.get_car_model_stats_in_period(start, end)
        report = []
        for car_model, avg_check, visit_count in rows:
            avg_car_price = await CarPriceService.get_average_price(car_model or "")
            report.append({
                "carModel": car_model,
                "avgCheck": round(float(avg_check), 2),
                "avgCarPrice": avg_car_price,
                "visitCount": visit_count,
                "ratio": round((avg_check / avg_car_price * 100) if avg_car_price > 0 else 0, 4),
            })
        return {"date": date, "data": report}

    async def popular_additional_services(self, date: str, category: str | None) -> dict:
        service_map = await self._service_repo.list_all_id_name_category_map()
        id_to_name = {s_id: name for s_id, (name, _) in service_map.items()}
        id_to_cat = {s_id: cat for s_id, (_, cat) in service_map.items()}

        wt_id_to_name = await self._wash_type_repo.list_all_id_name_map()
        promo_id_to_name = await self._promo_repo.list_all_id_name_map()

        start, end = self._month_bounds(date)

        service_counts: dict[str, int] = defaultdict(int)

        async for row in self._appointment_repo.stream_popular_services_fields_in_period(
            start, end
        ):
            add_services_json, promo_id, wash_type_id = row
            is_promo = promo_id is not None

            if wash_type_id in wt_id_to_name:
                wt_name = wt_id_to_name[wash_type_id]
                if category is None or category == "Все":
                    service_counts[wt_name] += 1
                elif category == "Акции" and is_promo:
                    service_counts[wt_name] += 1
                elif category == WASH_CATEGORY:
                    service_counts[wt_name] += 1

            try:
                services = json.loads(add_services_json or "[]")
            except Exception:
                services = []

            for s_id in services:
                if s_id not in id_to_name:
                    continue
                final_name = id_to_name[s_id]
                final_cat = id_to_cat[s_id]

                if category is None or category == "Все":
                    service_counts[final_name] += 1
                elif category == "Акции" and is_promo:
                    service_counts[final_name] += 1
                elif final_cat == category:
                    service_counts[final_name] += 1

            if is_promo and (category is None or category == "Все" or category == "Акции"):
                promo_name = promo_id_to_name.get(promo_id)
                if promo_name:
                    service_counts[promo_name] += 1

        report_data = [
            {"serviceName": name, "count": count}
            for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)
        ]
        return {"date": date, "data": report_data}

    async def consumables_usage(self, date: str, category: str | None) -> dict:
        service_map = await self._service_repo.list_all_id_name_category_map()
        id_to_cat = {s_id: cat for s_id, (_, cat) in service_map.items()}

        cons_to_cats: dict[str, set[str]] = defaultdict(set)

        sc_links = await self._service_consumable_repo.list_all_service_consumable_pairs()
        for s_id, c_id in sc_links:
            cat = id_to_cat.get(s_id, "Прочее")
            cons_to_cats[c_id].add(cat)

        wt_consumable_ids = await self._wash_type_consumable_repo.list_all_consumable_ids()
        for c_id in wt_consumable_ids:
            cons_to_cats[c_id].add(WASH_CATEGORY)

        start, end = self._month_bounds(date)

        sums: dict[str, float] = defaultdict(float)
        units: dict[str, str] = {}

        async for c_id, name, unit, qty, app_id, promo_id in self._consumable_usage_log_repo.stream_usage_with_appointment_in_period(
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
                sums[name] += float(qty)
                units[name] = unit

        data = [
            {"consumableName": n, "unit": units[n], "totalUsed": round(v, 2)}
            for n, v in sums.items()
        ]
        return {"date": date, "data": sorted(data, key=lambda x: x["totalUsed"], reverse=True)}

    async def daily_report(self, date: str) -> dict:
        start, end = self._day_bounds(date)

        appointments_count = await self._appointment_repo.count_in_period(start, end)

        completed_count, revenue, avg_check = await self._appointment_repo.get_completed_stats_in_period(
            start, end
        )
        revenue = revenue or 0
        avg_check = avg_check or 0

        box_rows = await self._appointment_repo.get_box_occupancy_in_period(start, end)
        box_occupancy = {f"box{r[0] + 1}": r[1] for r in box_rows}

        wash_types_map = await self._wash_type_repo.list_all_id_name_map()
        services_map = await self._service_repo.list_all_id_name_map()

        appt_rows = await self._appointment_repo.list_wash_type_and_additional_services_in_period(
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
            {"name": name, "count": count}
            for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)[:5]
        ]

        shifts = await self._shift_repo.list_for_range(date, date)
        washer_ids = [s.userId for s in shifts if s.userId is not None]
        washers_map = await self._user_repo.get_display_names_by_ids(washer_ids)

        washers_on_shift = [
            {"name": washers_map.get(s.userId, "Unknown"), "start": s.startTime, "end": s.endTime}
            for s in shifts
        ]

        low_stock_consumables = await self._consumable_repo.list_low_stock_alerts()
        consumables_alert = [
            {"name": c.name, "currentStock": round(float(c.currentStock), 1), "minStock": round(float(c.minStock), 1)}
            for c in low_stock_consumables
        ]

        return {
            "date": date,
            "revenue": int(revenue),
            "appointmentsCount": appointments_count,
            "completedCount": completed_count,
            "averageCheck": round(float(avg_check), 2) if avg_check else 0,
            "boxOccupancy": box_occupancy,
            "topServices": top_services,
            "washersOnShift": washers_on_shift,
            "consumablesAlert": consumables_alert,
        }

    async def shift_load_report(self, start_date: str, end_date: str) -> dict:
        target_minutes = SHIFT_LOAD_TARGET_WEEKLY_MINUTES

        shifts = await self._shift_repo.list_for_range(start_date, end_date)
        availability = await self._washer_availability_repo.list_for_range_all(
            start_date, end_date
        )
        washers = {
            u.id: u.displayName
            for u in await self._user_repo.list_washers()
        }

        start_dt = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_dt = datetime.strptime(end_date, "%Y-%m-%d").date()
        days_count = (end_dt - start_dt).days + 1

        daily_minutes: dict[str, dict[str, int]] = defaultdict(
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
        current = start_dt
        while current <= end_dt:
            d = current.strftime("%Y-%m-%d")
            entry = daily_minutes.get(d, {"confirmedMinutes": 0, "pendingMinutes": 0})
            daily_hours.append(
                {
                    "date": d,
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
            "startDate": start_date,
            "endDate": end_date,
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

    @staticmethod
    def _time_to_minutes(t: str) -> int:
        h, m = map(int, t.split(":"))
        return h * 60 + m

    @classmethod
    def _shift_minutes(cls, start_time: str, end_time: str) -> int:
        start = cls._time_to_minutes(start_time)
        end = cls._time_to_minutes(end_time)
        return end - start

    @classmethod
    def _count_conflicts(cls, shifts: list[Shift]) -> int:
        by_date: dict[str, list[Shift]] = defaultdict(list)
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
