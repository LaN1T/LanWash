import json
from collections import Counter
from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from repositories.appointment import AppointmentRepository
from repositories.consumable import ConsumableRepository
from repositories.consumable_usage_log import ConsumableUsageLogRepository
from repositories.service_consumable import ServiceConsumableRepository
from repositories.wash_type_consumable import WashTypeConsumableRepository
from schemas import ConsumableForecastItem, InventoryForecastResponse


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

    consumables_repo = ConsumableRepository(db)
    usage_repo = ConsumableUsageLogRepository(db)
    appointment_repo = AppointmentRepository(db)
    wash_type_consumable_repo = WashTypeConsumableRepository(db)
    service_consumable_repo = ServiceConsumableRepository(db)

    # Load all consumables once
    consumables = await consumables_repo.list_all_sorted()

    if not consumables:
        return InventoryForecastResponse(items=[], generated_at=ref_iso)

    # Average daily usage per consumable over the last 30 days
    usage_map = await usage_repo.sum_usage_grouped_since(cutoff_iso)

    # Upcoming scheduled appointments in the next 7 days
    appointments = await appointment_repo.list_scheduled_in_period(ref_iso, end_iso)

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
        for wtc in await wash_type_consumable_repo.list_for_wash_types(
            list(wash_type_counts.keys())
        ):
            planned_usage[wtc.consumableId] = (
                planned_usage.get(wtc.consumableId, 0.0)
                + wtc.quantity_per_service * wash_type_counts[wtc.washTypeId]
            )

    # Planned usage from additional service mappings
    if service_counts:
        for sc in await service_consumable_repo.list_for_services(
            list(service_counts.keys())
        ):
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
