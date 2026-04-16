from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, cast, String
from database import get_db
from db_models import Appointment, Consumable, ConsumableUsageLog, Service, ServiceConsumable, Promo
from datetime import datetime
import json
import random
from collections import defaultdict

router = APIRouter(prefix="/api/reports", tags=["reports"])

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
async def monthly_report(date: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
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
async def get_popular_additional_services(date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
    
    all_services = (await db.execute(select(Service.name, Service.category))).all()
    service_map = {name.strip(): cat for name, cat in all_services}
    promos = (await db.execute(select(Promo.name))).scalars().all()
    for p in promos:
        service_map[p.strip()] = 'Акции'

    query = select(Appointment.additionalServices, Appointment.notes).where(
        and_(Appointment.status == 'completed', cast(Appointment.dateTime, String).like(f"{date}%"))
    )
    rows = (await db.execute(query)).all()
    service_counts = defaultdict(int)
    
    for add_services_json, notes in rows:
        try:
            services = json.loads(add_services_json)
            for s in services:
                s_stripped = s.strip()
                cat = service_map.get(s_stripped, 'Прочее')
                if category is None or category == 'Все' or cat == category:
                    service_counts[s_stripped] += 1
        except: pass

        if notes and notes.startswith("Акция: "):
            promo_name = notes.replace("Акция: ", "").split('\n')[0].strip()
            if category is None or category == 'Все' or category == 'Акции':
                service_counts[promo_name] += 1

    report_data = [{"serviceName": name, "count": count} for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)]
    return {"date": date, "data": report_data}

@router.get("/consumables-usage/")
async def get_consumables_usage(date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
    
    all_services_res = await db.execute(select(Service.name, Service.category))
    service_map = {name.strip(): cat for name, cat in all_services_res.all()}
    promos = (await db.execute(select(Promo.name))).scalars().all()
    for p in promos:
        service_map[p.strip()] = 'Акции'

    query = select(Consumable.name, Consumable.unit, ConsumableUsageLog.quantityUsed, ConsumableUsageLog.appointmentId) \
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id) \
            .where(cast(ConsumableUsageLog.timestamp, String).like(f"{date}%"))
    
    logs = (await db.execute(query)).all()
    
    appt_ids = list(set(r[3] for r in logs))
    if not appt_ids:
        return {"date": date, "data": []}

    apps = (await db.execute(select(Appointment.id, Appointment.notes, Appointment.washType, Appointment.additionalServices).where(Appointment.id.in_(appt_ids)))).all()
    app_map = {a.id: (a.notes, a.washType, a.additionalServices) for a in apps}
    
    sums = defaultdict(float)
    units = {}
    
    for name, unit, qty, app_id in logs:
        notes, wash_type, add_services = app_map.get(app_id, (None, None, "[]"))
        
        cats_in_app = set()
        wash_map = {'express': 'Экспресс-мойка', 'basic': 'Базовая мойка', 'complex': 'Комплексная мойка', 'premium': 'Премиум мойка'}
        if wash_type and wash_type in wash_map:
            wash_name = wash_map[wash_type]
            cats_in_app.add(service_map.get(wash_name, 'Мойка кузова'))
        
        try:
            if add_services:
                services = json.loads(add_services)
                for s in services:
                    cats_in_app.add(service_map.get(s.strip(), 'Прочее'))
        except: pass
        
        if notes and notes.startswith("Акция: "):
            cats_in_app.add('Акции')

        if category is None or category == 'Все' or category in cats_in_app:
            sums[name] += float(qty)
            units[name] = unit
            
    data = [{"consumableName": n, "unit": units[n], "totalUsed": round(v, 2)} for n, v in sums.items()]
    return {"date": date, "data": sorted(data, key=lambda x: x['totalUsed'], reverse=True)}
