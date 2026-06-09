from collections import Counter
from datetime import datetime, timedelta
import json

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import (
    Appointment,
    Consumable,
    ConsumableUsageLog,
    ServiceConsumable,
    WashTypeConsumable,
)
from models import ConsumableForecastItem, InventoryForecastResponse


async def generate_inventory_forecast(
    db: AsyncSession,
    reference_date: datetime | None = None,
) -> InventoryForecastResponse:
    """Build a predictive inventory forecast for all consumables.

    Forecasts are based on:
    - average daily usage over the last 30 days from ConsumableUsageLog
    - planned usage for the next 7 days derived from scheduled appointments
      and their linked WashTypeConsumable / ServiceConsumable mappings
    """
    if reference_date is None:
        reference_date = datetime.now()

    cutoff_iso = (reference_date - timedelta(days=30)).isoformat()
    end_iso = (reference_date + timedelta(days=7)).isoformat()
    ref_iso = reference_date.isoformat()

    # Load all consumables once
    consumables_result = await db.execute(
        select(Consumable).order_by(Consumable.name.asc())
    )
    consumables = consumables_result.scalars().all()

    if not consumables:
        return InventoryForecastResponse(items=[], generated_at=ref_iso)

    # Average daily usage per consumable over the last 30 days
    usage_result = await db.execute(
        select(
            ConsumableUsageLog.consumableId,
            func.coalesce(func.sum(ConsumableUsageLog.quantityUsed), 0.0),
        )
        .where(ConsumableUsageLog.timestamp >= cutoff_iso)
        .group_by(ConsumableUsageLog.consumableId)
    )
    usage_map = {cid: float(total) for cid, total in usage_result.all()}

    # Upcoming scheduled appointments in the next 7 days
    appointments_result = await db.execute(
        select(Appointment)
        .where(Appointment.status == "scheduled")
        .where(Appointment.dateTime >= ref_iso)
        .where(Appointment.dateTime < end_iso)
    )
    appointments = appointments_result.scalars().all()

    wash_type_counts: Counter[str] = Counter()
    service_counts: Counter[str] = Counter()
    for appt in appointments:
        wash_type_counts[appt.washTypeId] += 1
        try:
            extras = json.loads(appt.additionalServices or "[]")
        except Exception:
            extras = []
        if isinstance(extras, list):
            for service_id in extras:
                service_counts[str(service_id)] += 1

    # Planned usage from wash type mappings
    planned_usage: dict[str, float] = {}
    if wash_type_counts:
        wtc_result = await db.execute(
            select(WashTypeConsumable).where(
                WashTypeConsumable.washTypeId.in_(wash_type_counts.keys())
            )
        )
        for wtc in wtc_result.scalars().all():
            planned_usage[wtc.consumableId] = (
                planned_usage.get(wtc.consumableId, 0.0)
                + wtc.quantity_per_service * wash_type_counts[wtc.washTypeId]
            )

    # Planned usage from additional service mappings
    if service_counts:
        sc_result = await db.execute(
            select(ServiceConsumable).where(
                ServiceConsumable.serviceId.in_(service_counts.keys())
            )
        )
        for sc in sc_result.scalars().all():
            planned_usage[sc.consumableId] = (
                planned_usage.get(sc.consumableId, 0.0)
                + sc.quantity_per_service * service_counts[sc.serviceId]
            )

    items: list[ConsumableForecastItem] = []
    for c in consumables:
        avg_daily = usage_map.get(c.id, 0.0) / 30.0
        planned_7d = planned_usage.get(c.id, 0.0)
        total_daily = avg_daily + (planned_7d / 7.0)

        if total_daily > 0:
            days_until_low = (c.currentStock - c.minStock) / total_daily
            days_until_empty = c.currentStock / total_daily
        else:
            days_until_low = None
            days_until_empty = None

        recommended_order_amount = max(
            c.minStock * 3.0 - c.currentStock + planned_7d, 0.0
        )

        if days_until_low is not None and days_until_low <= 3:
            status = "critical"
        elif days_until_low is not None and days_until_low <= 7:
            status = "warning"
        else:
            status = "ok"

        items.append(
            ConsumableForecastItem(
                consumable_id=c.id,
                name=c.name,
                unit=c.unit,
                current_stock=c.currentStock,
                min_stock=c.minStock,
                avg_daily_usage=round(avg_daily, 2),
                planned_usage_7d=round(planned_7d, 2),
                days_until_low=round(days_until_low, 1)
                if days_until_low is not None
                else None,
                days_until_empty=round(days_until_empty, 1)
                if days_until_empty is not None
                else None,
                recommended_order_amount=round(recommended_order_amount, 2),
                status=status,
            )
        )

    return InventoryForecastResponse(items=items, generated_at=ref_iso)
