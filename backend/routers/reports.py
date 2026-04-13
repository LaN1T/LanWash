from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from backend.database import get_db
from backend.db_models import Appointment, Consumable, ConsumableUsageLog
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
async def monthly_report(month: str = None, db: AsyncSession = Depends(get_db)):
    if not month:
        month = datetime.now().strftime("%Y-%m")
        
    result = await db.execute(
        select(
            Appointment.carModel, 
            func.avg(Appointment.paidPrice).label("avgCheck"), 
            func.count(Appointment.id).label("visitCount")
        )
        .where(and_(Appointment.status == 'completed', Appointment.dateTime.like(f"{month}%")))
        .group_by(Appointment.carModel)
    )
    rows = result.all()
    
    report = []
    for row in rows:
        car_model, avg_check, visit_count = row
        avg_car_price = await CarPriceService.get_average_price(car_model)
        ratio = (avg_check / avg_car_price * 100) if avg_car_price > 0 else 0
        
        report.append({
            "carModel": car_model,
            "avgCheck": round(float(avg_check), 2),
            "avgCarPrice": avg_car_price,
            "visitCount": visit_count,
            "ratio": round(float(ratio), 4) 
        })
            
    return {"month": month, "data": report}

@router.get("/popular-additional-services/")
async def get_popular_additional_services(month: str = None, db: AsyncSession = Depends(get_db)):
    if not month:
        month = datetime.now().strftime("%Y-%m")

    result = await db.execute(
        select(Appointment.additionalServices)
        .where(and_(Appointment.status == 'completed', Appointment.dateTime.like(f"{month}%")))
    )
    rows = result.scalars().all()

    service_counts = defaultdict(int)
    for row in rows:
        try:
            services = json.loads(row)
            if isinstance(services, list):
                for service_name in services:
                    service_counts[service_name] += 1
        except:
            continue

    popular_services = sorted(service_counts.items(), key=lambda item: item[1], reverse=True)
    report_data = [{"serviceName": name, "count": count} for name, count in popular_services]
    return {"month": month, "data": report_data}

@router.get("/consumables-usage/")
async def get_consumables_usage(month: str = None, db: AsyncSession = Depends(get_db)):
    if not month:
        month = datetime.now().strftime("%Y-%m")

    result = await db.execute(
        select(
            Consumable.name.label("consumableName"), 
            Consumable.unit, 
            func.sum(ConsumableUsageLog.quantityUsed).label("totalUsed")
        )
        .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id)
        .where(ConsumableUsageLog.timestamp.like(f"{month}%"))
        .group_by(Consumable.id)
    )
    rows = result.all()

    report_data = []
    for row in rows:
        c_name, c_unit, total_used = row
        total_used = float(total_used)
        
        if c_unit == "мл" and total_used >= 1000:
            report_data.append({
                "consumableName": c_name,
                "unit": "л",
                "totalUsed": round(total_used / 1000, 2)
            })
        else:
            report_data.append({
                "consumableName": c_name,
                "unit": c_unit,
                "totalUsed": round(total_used, 2)
            })

    return {"month": month, "data": report_data}
