# Workload Forecasting — Design Spec

## Goal
Build an AI-powered workload forecasting feature that predicts car wash load by hour for the next N days, based on historical appointment data. Helps admins optimize staffing and scheduling.

## Architecture
Simple statistical model running in the backend. No external ML libraries. Predictions computed on-demand and cached in Redis for 1 hour.

**Data flow:**
1. Admin opens dashboard → frontend requests `/api/admin/forecast?days=7`
2. Backend queries `appointments` table for last 8 weeks of completed appointments
3. Aggregator groups appointments by `(day_of_week, hour)` and calculates average load
4. Forecaster builds a per-hour, per-day forecast for the requested window
5. Response includes forecast array + capacity utilization percentage
6. Frontend renders heatmap/bar chart on dashboard

## Components

### Backend

**File:** `backend/services/forecast_service.py`
- `async def get_forecast(db, days=7, weeks_history=8) -> ForecastResponse`
- Groups completed appointments by `(dow, hour)` for the last `weeks_history` weeks
- Calculates: `avg_appointments_per_hour`, `max_concurrent` (using box assignments), `utilization_pct`
- Returns forecast per day/hour

**File:** `backend/models.py`
- `ForecastSlot` — Pydantic model: `date`, `hour`, `predicted_load`, `capacity`, `utilization_pct`
- `ForecastResponse` — `items: list[ForecastSlot], generated_at`

**File:** `backend/routers/admin.py`
- `GET /api/admin/forecast` — admin only, query params `days` (1-14, default 7)
- Caches result in Redis with key `forecast:{days}` TTL 1 hour

### Frontend

**File:** `lib/services/api_service.dart`
- `Future<ForecastResponse?> getForecast({int days = 7})`

**File:** `lib/screens/admin/admin_dashboard_screen.dart`
- Add a new card "Прогноз загрузки"
- Horizontal bar chart: 7 days × 24 hours (aggregated by day or shown as 168 bars)
- Color coding: green < 50%, yellow 50-80%, red > 80%
- Toggle: next 7 days / next 14 days

## Data Model

```python
class ForecastSlot(BaseModel):
    date: str  # ISO date YYYY-MM-DD
    hour: int  # 0-23
    predicted_load: float  # average appointments in this slot
    capacity: int  # number of boxes
    utilization_pct: float  # predicted_load / capacity * 100

class ForecastResponse(BaseModel):
    items: list[ForecastSlot]
    generated_at: str  # ISO datetime
```

## Algorithm (Simple Statistical Model)

```python
# 1. Fetch completed appointments for last 8 weeks
from_date = (today - 8 weeks).isoformat()
appointments = select(Appointment).where(
    Appointment.status == "completed",
    Appointment.dateTime >= from_date,
    Appointment.dateTime < today,
)

# 2. Build training buckets
buckets = defaultdict(list)
for appt in appointments:
    dt = parse(appt.dateTime)
    dow = dt.weekday()  # 0=Monday
    hour = dt.hour
    buckets[(dow, hour)].append(appt)

# 3. Calculate averages
averages = {
    key: len(values) / weeks_history
    for key, values in buckets.items()
}

# 4. Build forecast for requested days
forecast = []
for day_offset in range(days):
    date = today + day_offset
    for hour in range(8, 21):  # operating hours 08:00-20:00
        key = (date.weekday(), hour)
        predicted = averages.get(key, 0)
        forecast.append(ForecastSlot(
            date=date.isoformat(),
            hour=hour,
            predicted_load=round(predicted, 1),
            capacity=NUM_BOXES,
            utilization_pct=round(predicted / NUM_BOXES * 100, 1),
        ))
```

## Error Handling

- Not enough data (< 1 week): return empty forecast with `generated_at` and warning message
- Database error: return 500 with generic error
- Redis unavailable: compute forecast without cache (degraded but functional)

## Security & Performance

- Endpoint protected by admin role check
- Rate limit: 60/minute
- Query limited to completed appointments in last 8 weeks
- Cache TTL: 1 hour to reduce DB load

## Testing

**Backend tests:** `backend/tests/test_forecast.py`
- `test_forecast_admin_access` — admin gets 200
- `test_forecast_non_admin_forbidden` — non-admin gets 403
- `test_forecast_calculation` — create known appointments, verify predicted_load
- `test_forecast_caching` — second request hits cache
- `test_forecast_insufficient_data` — no history returns empty but 200

**Frontend tests:** (optional) verify chart renders with mock data

## Future Improvements (out of scope for MVP)

- scikit-learn or Prophet integration for trend detection
- Weather API integration (rain/snow boosts demand)
- Holidays and events support
- Confidence intervals

## Self-Review Checklist

- [x] No placeholders
- [x] Internal consistency: models match algorithm output
- [x] Scope is focused: single endpoint + chart
- [x] No ambiguous requirements
