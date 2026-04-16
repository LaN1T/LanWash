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
    service_map = {name.strip().lower(): cat for name, cat in all_services}
    service_map['пылесосная уборка'] = 'Уход за салоном'
    service_map['пылесосная уборка салона'] = 'Уход за салоном'

    # Получаем все акции
    all_promos = (await db.execute(select(Promo))).scalars().all()
    promo_names = {p.name for p in all_promos}

    query = select(Appointment.additionalServices, Appointment.promoName).where(
        and_(Appointment.status == 'completed', cast(Appointment.dateTime, String).like(f"{date}%"))
    )
    rows = (await db.execute(query)).all()
    service_counts = defaultdict(int)
    
    for add_services_json, promo_name in rows:
        is_promo = promo_name is not None and promo_name in promo_names
        
        try:
            services = json.loads(add_services_json)
            for s in services:
                s_name = s.strip()
                s_key = s_name.lower()
                cat = service_map.get(s_key, 'Прочее')
                
                # Если "Все" — учитываем один раз
                if category is None or category == 'Все':
                    service_counts[s_name] += 1
                else:
                    # Если фильтр активен — учитываем в родной категории
                    if cat == category:
                        service_counts[s_name] += 1
                    # И если это акционная запись и фильтр "Акции" — учитываем там
                    if is_promo and category == 'Акции':
                        service_counts[s_name] += 1
        except: pass

        # Факт самой акции учитываем только если фильтр "Все" или "Акции"
        if is_promo and (category is None or category == 'Все' or category == 'Акции'):
            service_counts[promo_name] += 1

    report_data = [{"serviceName": name, "count": count} for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)]
    return {"date": date, "data": report_data}

@router.get("/consumables-usage/")
async def get_consumables_usage(date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
    
    # 1. Получаем все услуги с их категориями
    all_services_res = await db.execute(select(Service.name, Service.category))
    service_map = {name.strip(): cat for name, cat in all_services_res.all()}
    
    # 2. Получаем все связи расходников с услугами
    all_links = await db.execute(select(Service.id, ServiceConsumable.consumableId, Service.category)
                                 .join(ServiceConsumable, ServiceConsumable.serviceId == Service.id))
    
    # Получаем все услуги, которые участвуют в акциях
    promo_services = (await db.execute(select(Promo.serviceId))).scalars().all()
    promo_services_set = set(promo_services)

    # Словарь: consumable_id -> set of categories it belongs to
    cons_to_cats = defaultdict(set)
    for s_id, c_id, cat in all_links.all():
        cons_to_cats[c_id].add(cat)
        if s_id in promo_services_set:
            cons_to_cats[c_id].add('Акции')

    # 3. Получаем логи использования
    query = select(Consumable.id, Consumable.name, Consumable.unit, ConsumableUsageLog.quantityUsed, ConsumableUsageLog.appointmentId) \
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id) \
            .where(cast(ConsumableUsageLog.timestamp, String).like(f"{date}%"))
    
    logs = (await db.execute(query)).all()
    
    appt_ids = list(set(r[4] for r in logs))
    apps = (await db.execute(select(Appointment.id, Appointment.notes).where(Appointment.id.in_(appt_ids)))).all()
    app_is_promo = {a.id: (a.notes and a.notes.startswith("Акция: ")) for a in apps}
    
    sums = defaultdict(float)
    units = {}
    
    # 4. Фильтруем и суммируем
    for c_id, name, unit, qty, app_id in logs:
        cats = cons_to_cats.get(c_id, set())
        is_promo = app_is_promo.get(app_id, False)
        
        matches_category = False
        if category is None or category == 'Все':
            matches_category = True
        elif category == 'Акции':
            matches_category = is_promo
        else:
            matches_category = category in cats
            
        if matches_category:
            sums[name] += float(qty)
            units[name] = unit
            
    data = [{"consumableName": n, "unit": units[n], "totalUsed": round(v, 2)} for n, v in sums.items()]
    return {"date": date, "data": sorted(data, key=lambda x: x['totalUsed'], reverse=True)}
