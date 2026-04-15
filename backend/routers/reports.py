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
    service_map = {name: cat for name, cat in all_services}
    promos = (await db.execute(select(Promo.name))).scalars().all()
    for p in promos:
        service_map[p] = 'Акции'

    query = select(Appointment.additionalServices, Appointment.notes).where(
        and_(Appointment.status == 'completed', cast(Appointment.dateTime, String).like(f"{date}%"))
    )
    rows = (await db.execute(query)).all()
    print(f"DEBUG: Found {len(rows)} completed appointments for {date}")
    service_counts = defaultdict(int)
    
    for add_services_json, notes in rows:
        print(f"DEBUG: Processing row - add_services: {add_services_json}, notes: {notes}")
        try:
            services = json.loads(add_services_json)
            for s in services:
                cat = service_map.get(s, 'Прочее')
                # Исправлено: добавлена проверка на None
                if category is None or category == 'Все' or cat == category:
                    service_counts[s] += 1
        except: pass

        if notes and notes.startswith("Акция: "):
            promo_name = notes.replace("Акция: ", "").split('\n')[0].strip()
            # Исправлено: добавлена проверка на None
            if category is None or category == 'Все' or category == 'Акции':
                service_counts[promo_name] += 1
    
    print(f"DEBUG: Service counts: {dict(service_counts)}")
    report_data = [{"serviceName": name, "count": count} for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)]
    return {"date": date, "data": report_data}

@router.get("/consumables-usage/")
async def get_consumables_usage(date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
    
    all_services_res = await db.execute(select(Service.name, Service.category))
    service_map = {name: cat for name, cat in all_services_res.all()}
    promos = (await db.execute(select(Promo.name))).scalars().all()
    for p in promos:
        service_map[p] = 'Акции'

    query = select(Consumable.name, Consumable.unit, ConsumableUsageLog.quantityUsed, ConsumableUsageLog.appointmentId) \
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id) \
            .where(cast(ConsumableUsageLog.timestamp, String).like(f"{date}%"))
    
    logs = (await db.execute(query)).all()
    
    if category and category != 'Все':
        appt_ids = list(set(r[3] for r in logs))
        apps = (await db.execute(select(Appointment.id, Appointment.notes, Appointment.washType, Appointment.additionalServices).where(Appointment.id.in_(appt_ids)))).all()
        app_map = {a.id: (a.notes, a.washType, a.additionalServices) for a in apps}
        
        sums = defaultdict(float)
        units = {}
        for name, unit, qty, app_id in logs:
            notes, wash_type, add_services = app_map.get(app_id, (None, None, "[]"))
            in_app = []
            if wash_type: in_app.append({'name': {'express': 'Экспресс-мойка', 'basic': 'Базовая мойка', 'complex': 'Комплексная мойка', 'premium': 'Премиум мойка'}.get(wash_type, ''), 'is_promo': False})
            try:
                for s in json.loads(add_services): in_app.append({'name': s, 'is_promo': s in promos})
            except: pass
            if notes and notes.startswith("Акция: "): in_app.append({'name': notes.replace("Акция: ", "").split('\n')[0].strip(), 'is_promo': True})
            
            if any((cat == category) for s in in_app for cat in (['Акции'] if s['is_promo'] else [service_map.get(s['name'], 'Прочее')])):
                sums[name] += float(qty)
                units[name] = unit
        data = [{"consumableName": n, "unit": units[n], "totalUsed": round(v, 2)} for n, v in sums.items()]
    else:
        sums = defaultdict(float)
        units = {}
        for name, unit, qty, _ in logs:
            sums[name] += float(qty)
            units[name] = unit
        data = [{"consumableName": n, "unit": units[n], "totalUsed": round(v, 2)} for n, v in sums.items()]

    return {"date": date, "data": sorted(data, key=lambda x: x['totalUsed'], reverse=True)}

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
