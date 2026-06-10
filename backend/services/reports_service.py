import json
import random
from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import (
    Appointment,
    Consumable,
    ConsumableUsageLog,
    Promo,
    Service,
    ServiceConsumable,
    Shift,
    User,
    WashType,
    WashTypeConsumable,
)

WASH_CATEGORY = "Мойка кузова"


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
        result = await self._db.execute(
            select(
                Appointment.carModel,
                func.avg(Appointment.paidPrice).label("avgCheck"),
                func.count(Appointment.id).label("visitCount"),
            )
            .where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                )
            )
            .group_by(Appointment.carModel)
        )
        rows = result.all()
        report = []
        for row in rows:
            car_model, avg_check, visit_count = row
            avg_car_price = await CarPriceService.get_average_price(car_model)
            report.append({
                "carModel": car_model,
                "avgCheck": round(float(avg_check), 2),
                "avgCarPrice": avg_car_price,
                "visitCount": visit_count,
                "ratio": round((avg_check / avg_car_price * 100) if avg_car_price > 0 else 0, 4),
            })
        return {"date": date, "data": report}

    async def popular_additional_services(self, date: str, category: str | None) -> dict:
        all_services = (await self._db.execute(select(Service.id, Service.name, Service.category))).all()
        id_to_name = {s.id: s.name for s in all_services}
        id_to_cat = {s.id: s.category for s in all_services}

        all_wash_types = (await self._db.execute(select(WashType.id, WashType.name))).all()
        wt_id_to_name = {w.id: w.name for w in all_wash_types}

        all_promos = (await self._db.execute(select(Promo.id, Promo.name))).all()
        promo_id_to_name = {p.id: p.name for p in all_promos}

        start, end = self._month_bounds(date)
        query = select(
            Appointment.additionalServices,
            Appointment.promoId,
            Appointment.washTypeId,
        ).where(
            and_(
                Appointment.status == "completed",
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        rows = (await self._db.execute(query)).all()

        service_counts: dict[str, int] = defaultdict(int)

        for add_services_json, promo_id, wash_type_id in rows:
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
        all_services = (await self._db.execute(select(Service.id, Service.category))).all()
        id_to_cat = {s.id: s.category for s in all_services}

        cons_to_cats: dict[str, set[str]] = defaultdict(set)

        sc_links = (await self._db.execute(select(ServiceConsumable.serviceId, ServiceConsumable.consumableId))).all()
        for s_id, c_id in sc_links:
            cat = id_to_cat.get(s_id, "Прочее")
            cons_to_cats[c_id].add(cat)

        wt_links = (await self._db.execute(select(WashTypeConsumable.consumableId))).all()
        for (c_id,) in wt_links:
            cons_to_cats[c_id].add(WASH_CATEGORY)

        start, end = self._month_bounds(date)
        query = (
            select(
                Consumable.id,
                Consumable.name,
                Consumable.unit,
                ConsumableUsageLog.quantityUsed,
                ConsumableUsageLog.appointmentId,
                Appointment.dateTime,
            )
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id)
            .join(Appointment, ConsumableUsageLog.appointmentId == Appointment.id)
            .where(
                and_(
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                    Appointment.status == "completed",
                )
            )
        )
        logs = (await self._db.execute(query)).all()

        appt_ids = list({r[4] for r in logs})
        app_is_promo: dict[str, bool] = {}
        if appt_ids:
            apps = (await self._db.execute(
                select(Appointment.id, Appointment.promoId).where(Appointment.id.in_(appt_ids))
            )).all()
            app_is_promo = {a.id: (a.promoId is not None) for a in apps}

        sums: dict[str, float] = defaultdict(float)
        units: dict[str, str] = {}

        for c_id, name, unit, qty, app_id, _ in logs:
            cats = cons_to_cats.get(c_id, set())
            is_promo = app_is_promo.get(app_id, False)

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
        base_filter = and_(Appointment.dateTime >= start, Appointment.dateTime < end)

        total_result = await self._db.execute(
            select(func.count(Appointment.id)).where(base_filter)
        )
        appointments_count = total_result.scalar() or 0

        completed_result = await self._db.execute(
            select(func.count(Appointment.id), func.sum(Appointment.paidPrice), func.avg(Appointment.paidPrice))
            .where(and_(base_filter, Appointment.status == "completed"))
        )
        completed_row = completed_result.first()
        completed_count = completed_row[0] or 0
        revenue = completed_row[1] or 0
        avg_check = completed_row[2] or 0

        box_result = await self._db.execute(
            select(Appointment.box_index, func.count(Appointment.id))
            .where(and_(base_filter, Appointment.status == "completed"))
            .group_by(Appointment.box_index)
        )
        box_occupancy = {f"box{r[0] + 1}": r[1] for r in box_result.all()}

        wash_types_map = {w.id: w.name for w in (await self._db.execute(select(WashType.id, WashType.name))).all()}
        services_map = {s.id: s.name for s in (await self._db.execute(select(Service.id, Service.name))).all()}

        appts_result = await self._db.execute(
            select(Appointment.washTypeId, Appointment.additionalServices)
            .where(and_(base_filter, Appointment.status == "completed"))
        )
        service_counts: dict[str, int] = defaultdict(int)
        for wt_id, add_json in appts_result.all():
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

        shifts_result = await self._db.execute(
            select(Shift.userId, Shift.startTime, Shift.endTime)
            .where(Shift.date == date)
        )
        shifts = shifts_result.all()
        washer_ids = [s[0] for s in shifts]
        washers_map = {}
        if washer_ids:
            users_result = await self._db.execute(
                select(User.id, User.displayName).where(User.id.in_(washer_ids))
            )
            washers_map = {u[0]: u[1] for u in users_result.all()}

        washers_on_shift = [
            {"name": washers_map.get(s[0], "Unknown"), "start": s[1], "end": s[2]}
            for s in shifts
        ]

        consumables_result = await self._db.execute(
            select(Consumable.name, Consumable.currentStock, Consumable.minStock)
            .where(Consumable.currentStock < Consumable.minStock)
        )
        consumables_alert = [
            {"name": n, "currentStock": round(float(cs), 1), "minStock": round(float(ms), 1)}
            for n, cs, ms in consumables_result.all()
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
