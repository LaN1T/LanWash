# Predictive Inventory — Design Spec

## Goal
Add predictive inventory forecasting to the existing consumables module. The feature estimates when each consumable will hit `minStock` or run out entirely, based on historical usage and upcoming scheduled appointments.

## Current State
- `Consumable` model already has `currentStock` and `minStock` fields
- `/api/consumables/alerts/low-stock` shows currently low items
- `ConsumableUsageLog` tracks every usage
- `ConsumableRefillLog` tracks refills
- `WashTypeConsumable` and `ServiceConsumable` define consumption rates per service

## Missing
- Projection of future stock levels
- Date when each item will hit `minStock`
- Recommended purchase quantity
- Notifications before stock runs out

## Architecture

**Data flow:**
1. Scheduler triggers `check_inventory_forecast` ARQ task once per day
2. Task calls `inventory_forecast_service.generate_forecast(db)`
3. Service computes:
   - `avg_daily_usage` from last 30 days of `ConsumableUsageLog`
   - `planned_usage` from upcoming scheduled appointments × consumption rates
   - `days_until_low = (currentStock - minStock) / avg_daily_usage`
   - `days_until_empty = currentStock / avg_daily_usage`
   - `recommended_order = max(minStock * 3 - currentStock + planned_usage, 0)`
4. If `days_until_low <= 3`, send FCM push + Telegram notification to admins
5. Frontend displays forecast table on new screen and dashboard widget

## Components

### Backend

**File:** `backend/services/inventory_forecast_service.py`
- `async def generate_forecast(db: AsyncSession) -> list[ConsumableForecast]`
- Computes per-consumable metrics

**File:** `backend/models.py`
- `ConsumableForecastItem(BaseModel)`
- `InventoryForecastResponse(BaseModel)`

**File:** `backend/routers/consumables.py`
- `GET /api/consumables/forecast` — returns forecast list
- Admin/washer access

**File:** `backend/tasks/__init__.py`
- Add `check_inventory_forecast(ctx)` ARQ task

### Frontend

**File:** `lib/models/consumable_forecast.dart`
- Dart models

**File:** `lib/services/api_service.dart`
- `getInventoryForecast()` wrapper

**File:** `lib/screens/admin/admin_dashboard_screen.dart`
- Add small widget: "Расходники: требуют внимания" with count of critical items

**File:** `lib/screens/admin/inventory_forecast_screen.dart`
- Full forecast table with sorting and color-coded rows

## Data Model

```python
class ConsumableForecastItem(BaseModel):
    consumable_id: str
    name: str
    unit: str
    current_stock: float
    min_stock: float
    avg_daily_usage: float
    planned_usage_7d: float
    days_until_low: float | None
    days_until_empty: float | None
    recommended_order_amount: float
    status: Literal["critical", "warning", "ok"]

class InventoryForecastResponse(BaseModel):
    items: list[ConsumableForecastItem]
    generated_at: str
```

## Algorithm

```python
# 1. Compute avg daily usage per consumable for last 30 days
usage_30d = await db.execute(
    select(ConsumableUsageLog.consumableId, func.sum(ConsumableUsageLog.quantityUsed))
    .where(ConsumableUsageLog.timestamp >= thirty_days_ago)
    .group_by(ConsumableUsageLog.consumableId)
)

# 2. Compute planned usage from upcoming scheduled appointments
planned = defaultdict(float)
for appt in upcoming_appointments:
    services = [appt.washTypeId] + json.loads(appt.additionalServices)
    for svc in services:
        for sc in service_consumables[svc]:
            planned[sc.consumableId] += sc.quantity_per_service

# 3. For each consumable
forecast = []
for c in consumables:
    avg = usage_30d.get(c.id, 0) / 30
    planned_7d = planned.get(c.id, 0)
    total_daily = avg + (planned_7d / 7)
    
    if total_daily <= 0:
        days_low = days_empty = None
    else:
        days_low = (c.currentStock - c.minStock) / total_daily
        days_empty = c.currentStock / total_daily
    
    recommended = max(c.minStock * 3 - c.currentStock + planned_7d, 0)
    
    if days_low is not None and days_low <= 3:
        status = "critical"
    elif days_low is not None and days_low <= 7:
        status = "warning"
    else:
        status = "ok"
    
    forecast.append(ConsumableForecastItem(...))
```

## Notifications

Trigger when `status == "critical"`:
- FCM push to admin tokens: title="Критический запас", body="{name} закончится через {days} дн."
- Telegram notification to admin chat
- ARQ task runs daily at 08:00

## Testing

**Backend tests:** `backend/tests/test_inventory_forecast.py`
- `test_inventory_forecast_basic` — seed usage logs, verify days_until_low
- `test_inventory_forecast_planned_usage` — create future appointment, verify planned usage included
- `test_inventory_forecast_endpoint_access` — admin/washer 200, client 403
- `test_inventory_forecast_notification` — verify critical status triggers notification

## UI/UX

**Dashboard widget:**
- Small card with icon and text: "3 расходника требуют закупки"
- Red badge if critical > 0
- Taps navigate to full forecast screen

**Forecast screen:**
- Table columns: Name | Stock | Daily Usage | Days until low | Recommended Order
- Color-coded status dots
- Sort by days_until_low ascending
- Pull-to-refresh

## Future Improvements

- Integration with supplier APIs
- Automatic purchase order generation
- Seasonal adjustment (winter = more anti-corrosion usage)
- Per-box tracking instead of global stock

## Self-Review

- [x] No placeholders
- [x] Builds on existing consumables module
- [x] Clear separation: service, router, task, frontend
- [x] Testable algorithm with deterministic inputs
