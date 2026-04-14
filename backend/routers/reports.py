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
    
    # 1. Читаем всё из базы для маппинга
    all_services = (await db.execute(select(Service.id, Service.name, Service.category))).all()
    id_to_name = {s.id: s.name for s in all_services}
    id_to_cat = {s.id: s.category for s in all_services}
    name_to_id = {s.name.strip().lower(): s.id for s in all_services}

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
            for s_item in services:
                # Определяем имя и категорию, учитывая что в базе может быть и ID и Имя
                final_name = s_item
                final_cat = 'Прочее'
                
                if s_item in id_to_name:
                    final_name = id_to_name[s_item]
                    final_cat = id_to_cat[s_item]
                elif s_item.strip().lower() in name_to_id:
                    sid = name_to_id[s_item.strip().lower()]
                    final_name = id_to_name[sid]
                    final_cat = id_to_cat[sid]
                
                # Фильтр: или Все, или родная категория, или Акции
                if category is None or category == 'Все':
                    service_counts[final_name] += 1
                elif category == 'Акции' and is_promo:
                    service_counts[final_name] += 1
                elif final_cat == category:
                    service_counts[final_name] += 1
        except: pass

        # Факт самой акции учитываем только если фильтр "Все" или "Акции"
        if is_promo and (category is None or category == 'Все' or category == 'Акции'):
            service_counts[promo_name] += 1

    report_data = [{"serviceName": name, "count": count} for name, count in sorted(service_counts.items(), key=lambda i: i[1], reverse=True)]
    return {"date": date, "data": report_data}

@router.get("/consumables-usage/")
async def get_consumables_usage(date: str = None, category: str = None, db: AsyncSession = Depends(get_db)):
    if not date: date = datetime.now().strftime("%Y-%m")
    
    # 1. Получаем услуги и их категории напрямую из БД
    all_services = (await db.execute(select(Service.id, Service.name, Service.category))).all()
    id_to_cat = {s.id: s.category for s in all_services}
    name_to_id = {s.name.strip().lower(): s.id for s in all_services}
    
    # 2. Получаем все связи расходников с услугами
    all_links = (await db.execute(select(ServiceConsumable.serviceId, ServiceConsumable.consumableId))).all()
    
    # Получаем услуги, участвующие в акциях
    promo_service_ids = (await db.execute(select(Promo.serviceId))).scalars().all()
    
    # Словарь: consumable_id -> set of categories
    cons_to_cats = defaultdict(set)
    for s_id, c_id in all_links:
        cat = id_to_cat.get(s_id, 'Прочее')
        cons_to_cats[c_id].add(cat)
        if s_id in promo_service_ids:
            cons_to_cats[c_id].add('Акции')

    # 3. Получаем логи использования
    query = select(Consumable.id, Consumable.name, Consumable.unit, ConsumableUsageLog.quantityUsed, ConsumableUsageLog.appointmentId) \
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id) \
            .where(cast(ConsumableUsageLog.timestamp, String).like(f"{date}%"))
    logs = (await db.execute(query)).all()
    
    appt_ids = list(set(r[4] for r in logs))
    apps = (await db.execute(select(Appointment.id, Appointment.promoName).where(Appointment.id.in_(appt_ids)))).all()
    app_is_promo = {a.id: (a.promoName is not None) for a in apps}
    
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
