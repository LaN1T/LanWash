from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from sqlalchemy import select, func, and_, cast, String
from database import get_db
from db_models import (
    Appointment, Consumable, ConsumableUsageLog, Service, ServiceConsumable,
    Promo, WashType, WashTypeConsumable,
)
from datetime import datetime
import json
import random
from collections import defaultdict

router = APIRouter(
    prefix="/api/reports",
    tags=["reports"],
    
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


@router.get("/monthly-check-vs-price/")
@limiter.limit("30/minute")
async def monthly_report(request: Request, date: str = None, db: AsyncSession = Depends(get_db)):
    if not date:
        date = datetime.now().strftime("%Y-%m")
    result = await db.execute(
        select(
            Appointment.carModel,
            func.avg(Appointment.paidPrice).label("avgCheck"),
            func.count(Appointment.id).label("visitCount")
        )
        .where(and_(Appointment.status == 'completed', cast(Appointment.dateTime, String).like(f"{date}%")))
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
            "ratio": round((avg_check / avg_car_price * 100) if avg_car_price > 0 else 0, 4)
        })
    return {"date": date, "data": report}


@router.get("/popular-additional-services/")
@limiter.limit("30/minute")
async def get_popular_additional_services(request: Request, date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date:
        date = datetime.now().strftime("%Y-%m")

    # Справочники услуг
    all_services = (await db.execute(select(Service.id, Service.name, Service.category))).all()
    id_to_name = {s.id: s.name for s in all_services}
    id_to_cat = {s.id: s.category for s in all_services}

    # Типы мойки считаем в категории «Мойка кузова»
    all_wash_types = (await db.execute(select(WashType.id, WashType.name))).all()
    wt_id_to_name = {w.id: w.name for w in all_wash_types}

    # Промо (если фильтр "Акции")
    all_promos = (await db.execute(select(Promo.id, Promo.name))).all()
    promo_id_to_name = {p.id: p.name for p in all_promos}

    query = select(
        Appointment.additionalServices,
        Appointment.promoId,
        Appointment.washTypeId,
    ).where(
        and_(Appointment.status == 'completed', cast(Appointment.dateTime, String).like(f"{date}%"))
    )
    rows = (await db.execute(query)).all()

    service_counts: dict[str, int] = defaultdict(int)

    for add_services_json, promo_id, wash_type_id in rows:
        is_promo = promo_id is not None

        # Тип мойки учитывается как услуга категории «Мойка кузова»
        if wash_type_id in wt_id_to_name:
            wt_name = wt_id_to_name[wash_type_id]
            if category is None or category == 'Все':
                service_counts[wt_name] += 1
            elif category == 'Акции' and is_promo:
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

            if category is None or category == 'Все':
                service_counts[final_name] += 1
            elif category == 'Акции' and is_promo:
                service_counts[final_name] += 1
            elif final_cat == category:
                service_counts[final_name] += 1

        # Сам факт акции
        if is_promo and (category is None or category == 'Все' or category == 'Акции'):
            promo_name = promo_id_to_name.get(promo_id)
            if promo_name:
                service_counts[promo_name] += 1

    report_data = [
        {"serviceName": name, "count": count}
        for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)
    ]
    return {"date": date, "data": report_data}


@router.get("/consumables-usage/")
@limiter.limit("30/minute")
async def get_consumables_usage(request: Request, date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date:
        date = datetime.now().strftime("%Y-%m")

    # Категории для услуг
    all_services = (await db.execute(select(Service.id, Service.category))).all()
    id_to_cat = {s.id: s.category for s in all_services}

    # Связка consumable -> множество категорий (по использующим его услугам)
    cons_to_cats: dict[str, set[str]] = defaultdict(set)

    sc_links = (await db.execute(select(ServiceConsumable.serviceId, ServiceConsumable.consumableId))).all()
    for s_id, c_id in sc_links:
        cat = id_to_cat.get(s_id, 'Прочее')
        cons_to_cats[c_id].add(cat)

    wt_links = (await db.execute(select(WashTypeConsumable.consumableId))).all()
    for (c_id,) in wt_links:
        cons_to_cats[c_id].add(WASH_CATEGORY)

    # Логи использования за месяц
    query = (
        select(
            Consumable.id,
            Consumable.name,
            Consumable.unit,
            ConsumableUsageLog.quantityUsed,
            ConsumableUsageLog.appointmentId,
            Appointment.dateTime, # Include Appointment.dateTime for filtering
        )
        .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id)
        .join(Appointment, ConsumableUsageLog.appointmentId == Appointment.id) # Join with Appointment
        .where(and_(
            cast(Appointment.dateTime, String).like(f"{date}%"), # Filter by Appointment.dateTime
            Appointment.status == 'completed' # Ensure only completed appointments are considered
        ))
    )
    logs = (await db.execute(query)).all()

    appt_ids = list({r[4] for r in logs})
    app_is_promo: dict[str, bool] = {}
    if appt_ids:
        apps = (await db.execute(
            select(Appointment.id, Appointment.promoId).where(Appointment.id.in_(appt_ids))
        )).all()
        app_is_promo = {a.id: (a.promoId is not None) for a in apps}

    sums: dict[str, float] = defaultdict(float)
    units: dict[str, str] = {}

    for c_id, name, unit, qty, app_id, _ in logs:
        cats = cons_to_cats.get(c_id, set())
        is_promo = app_is_promo.get(app_id, False)

        if category is None or category == 'Все':
            matches = True
        elif category == 'Акции':
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
    return {"date": date, "data": sorted(data, key=lambda x: x['totalUsed'], reverse=True)}
