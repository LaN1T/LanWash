# Workload Forecasting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement AI workload forecasting endpoint and dashboard widget that predicts car wash load by hour for the next N days using historical appointment data.

**Architecture:** A simple statistical backend service aggregates completed appointments from the last 8 weeks by `(weekday, hour)`, computes averages, and projects them onto the requested future days. Results are cached in Redis for 1 hour. The frontend renders a bar chart on the admin dashboard.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, Pydantic, Redis, Flutter, fl_chart, Provider

---

## File Structure

| File | Purpose |
|------|---------|
| `backend/services/forecast_service.py` | Core forecast algorithm and data aggregation |
| `backend/models.py` | `ForecastSlot`, `ForecastResponse` Pydantic models |
| `backend/routers/admin.py` | `GET /api/admin/forecast` endpoint with caching |
| `backend/tests/test_forecast.py` | Backend tests for forecast endpoint |
| `lib/models/forecast.dart` | Flutter model for forecast slots |
| `lib/services/api_service.dart` | `getForecast()` API wrapper |
| `lib/screens/admin/admin_dashboard_screen.dart` | Forecast chart widget on dashboard |

---

## Task 1: Pydantic Models

**Files:**
- Modify: `backend/models.py` (append at end)
- Test: `backend/tests/test_forecast.py` (models import sanity)

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_forecast.py
import pytest
from models import ForecastSlot, ForecastResponse

@pytest.mark.asyncio
async def test_forecast_models_exist():
    slot = ForecastSlot(date="2026-06-10", hour=10, predicted_load=2.5, capacity=2, utilization_pct=125.0)
    resp = ForecastResponse(items=[slot], generated_at="2026-06-09T12:00:00")
    assert resp.items[0].hour == 10
    assert resp.items[0].utilization_pct == 125.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && source ../.venv/bin/activate && pytest tests/test_forecast.py::test_forecast_models_exist -v`
Expected: ImportError `ForecastSlot`

- [ ] **Step 3: Add models to backend/models.py**

Append at the end of `backend/models.py`:

```python
# ─── Forecast ────────────────────────────────────────────────────────────────
class ForecastSlot(BaseModel):
    date: str = Field(..., description="ISO date YYYY-MM-DD")
    hour: int = Field(..., ge=0, le=23, description="Hour of day")
    predicted_load: float = Field(..., ge=0, description="Average appointments in this slot")
    capacity: int = Field(..., ge=1, description="Number of wash boxes")
    utilization_pct: float = Field(..., description="Predicted load / capacity * 100")


class ForecastResponse(BaseModel):
    items: list[ForecastSlot]
    generated_at: str = Field(..., description="ISO datetime when forecast was generated")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_forecast.py::test_forecast_models_exist -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/models.py backend/tests/test_forecast.py
git commit -m "feat(forecast): add ForecastSlot and ForecastResponse models"
```

---

## Task 2: Forecast Service

**Files:**
- Create: `backend/services/forecast_service.py`
- Test: `backend/tests/test_forecast.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_forecast.py
import pytest
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from db_models import Appointment, User
from services.forecast_service import generate_forecast

@pytest.mark.asyncio
async def test_generate_forecast_basic(db_session: AsyncSession):
    # Seed completed appointments: every Monday at 10:00 for last 4 weeks
    today = datetime(2026, 6, 9, 12, 0, 0)  # Tuesday
    for weeks_ago in range(1, 5):
        monday = today - timedelta(weeks=weeks_ago, days=today.weekday() - 0)
        dt = monday.replace(hour=10, minute=0, second=0).isoformat()
        appt = Appointment(
            id=f"fc_appt_{weeks_ago}",
            clientName="Client",
            carModel="Car",
            carNumber="A123",
            dateTime=dt,
            washTypeId="w1",
            additionalServices="[]",
            status="completed",
            ownerUsername="client",
            assignedWasher='["washer1"]',
        )
        db_session.add(appt)
    await db_session.commit()

    # Forecast for next Monday (2026-06-15)
    forecast = await generate_forecast(db_session, reference_date=today, days=7)
    monday_slots = [s for s in forecast.items if s.date == "2026-06-15" and s.hour == 10]
    assert len(monday_slots) == 1
    assert monday_slots[0].predicted_load == 1.0  # 4 appointments / 4 weeks
    assert monday_slots[0].capacity == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_forecast.py::test_generate_forecast_basic -v`
Expected: ModuleNotFoundError or function not defined

- [ ] **Step 3: Implement forecast_service.py**

```python
# backend/services/forecast_service.py
from datetime import datetime, timedelta
from collections import defaultdict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from db_models import Appointment
from models import ForecastSlot, ForecastResponse
from services.workload_service import NUM_BOXES

_OPERATING_HOURS_START = 8
_OPERATING_HOURS_END = 20  # inclusive start, exclusive end
_WEEKS_HISTORY = 8


async def generate_forecast(
    db: AsyncSession,
    reference_date: datetime | None = None,
    days: int = 7,
) -> ForecastResponse:
    """Generate a workload forecast for the next `days` days.

    Uses a simple statistical model: average completed appointments per
    (weekday, hour) bucket over the last `_WEEKS_HISTORY` weeks.
    """
    if reference_date is None:
        reference_date = datetime.now()
    reference_date = reference_date.replace(hour=0, minute=0, second=0, microsecond=0)

    history_start = reference_date - timedelta(weeks=_WEEKS_HISTORY)

    stmt = select(Appointment).where(
        and_(
            Appointment.status == "completed",
            Appointment.dateTime >= history_start.isoformat(),
            Appointment.dateTime < reference_date.isoformat(),
            Appointment.dateTime != None,
            Appointment.dateTime != "",
        )
    )
    result = await db.execute(stmt)
    appointments = result.scalars().all()

    # Aggregate by (weekday, hour)
    buckets: dict[tuple[int, int], list[Appointment]] = defaultdict(list)
    for appt in appointments:
        try:
            dt = datetime.fromisoformat(appt.dateTime)
        except Exception:
            continue
        buckets[(dt.weekday(), dt.hour)].append(appt)

    # Compute averages
    averages: dict[tuple[int, int], float] = {}
    for key, items in buckets.items():
        averages[key] = len(items) / _WEEKS_HISTORY

    # Build forecast
    items: list[ForecastSlot] = []
    for day_offset in range(days):
        date = reference_date + timedelta(days=day_offset)
        for hour in range(_OPERATING_HOURS_START, _OPERATING_HOURS_END + 1):
            key = (date.weekday(), hour)
            predicted = averages.get(key, 0.0)
            items.append(
                ForecastSlot(
                    date=date.strftime("%Y-%m-%d"),
                    hour=hour,
                    predicted_load=round(predicted, 1),
                    capacity=NUM_BOXES,
                    utilization_pct=round((predicted / NUM_BOXES) * 100, 1) if NUM_BOXES else 0.0,
                )
            )

    return ForecastResponse(
        items=items,
        generated_at=datetime.now().isoformat(),
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_forecast.py::test_generate_forecast_basic -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/services/forecast_service.py backend/tests/test_forecast.py
git commit -m "feat(forecast): implement statistical forecast service"
```

---

## Task 3: Admin Forecast Endpoint

**Files:**
- Modify: `backend/routers/admin.py`
- Modify: `backend/core/redis_client.py` (ensure async Redis client works)
- Test: `backend/tests/test_forecast.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_forecast.py
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_forecast_endpoint_admin_access(async_client: AsyncClient, admin_token: str):
    r = await async_client.get(
        "/api/admin/forecast?days=7",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "generated_at" in data
    # 7 days * 13 hours (8-20 inclusive) = 91 slots
    assert len(data["items"]) == 91


@pytest.mark.asyncio
async def test_forecast_endpoint_non_admin_forbidden(async_client: AsyncClient, client_token: str):
    r = await async_client.get(
        "/api/admin/forecast?days=7",
        headers={"Authorization": f"Bearer {client_token}"},
    )
    assert r.status_code == 403
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_forecast.py::test_forecast_endpoint_admin_access tests/test_forecast.py::test_forecast_endpoint_non_admin_forbidden -v`
Expected: 404 or route not found

- [ ] **Step 3: Add endpoint to admin.py**

In `backend/routers/admin.py`, add import at the top:

```python
from models import (
    DashboardResponse, BulkAssignWasherRequest, BulkCancelRequest,
    BulkUpdateStatusRequest, BulkResult, UserListResponse, UserListItem,
    ForecastResponse,
)
```

Append a new endpoint near the end of `backend/routers/admin.py`:

```python
from services.forecast_service import generate_forecast
from core.redis_client import get_redis
import json as _json


@router.get("/forecast", response_model=ForecastResponse)
@limiter.limit("60/minute")
async def get_forecast(
    request: Request,
    days: int = 7,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Workload forecast for the next N days (admin only)."""
    if days < 1 or days > 14:
        raise HTTPException(status_code=400, detail="days must be between 1 and 14")

    cache_key = f"forecast:{days}"
    try:
        redis = get_redis()
        cached = await redis.get(cache_key)
        if cached:
            data = _json.loads(cached)
            return ForecastResponse(**data)
    except Exception:
        pass  # degrade gracefully if Redis is unavailable

    forecast = await generate_forecast(db, days=days)

    try:
        redis = get_redis()
        await redis.setex(cache_key, 3600, _json.dumps(forecast.model_dump()))
    except Exception:
        pass

    return forecast
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_forecast.py::test_forecast_endpoint_admin_access tests/test_forecast.py::test_forecast_endpoint_non_admin_forbidden -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/routers/admin.py backend/tests/test_forecast.py
git commit -m "feat(forecast): add GET /api/admin/forecast endpoint with Redis cache"
```

---

## Task 4: Frontend Forecast Model

**Files:**
- Create: `lib/models/forecast.dart`
- Test: dart analyzer only

- [ ] **Step 1: Create the model file**

```dart
// lib/models/forecast.dart
class ForecastSlot {
  final String date;
  final int hour;
  final double predictedLoad;
  final int capacity;
  final double utilizationPct;

  ForecastSlot({
    required this.date,
    required this.hour,
    required this.predictedLoad,
    required this.capacity,
    required this.utilizationPct,
  });

  factory ForecastSlot.fromMap(Map<String, dynamic> m) => ForecastSlot(
        date: m['date'] as String,
        hour: m['hour'] as int,
        predictedLoad: (m['predicted_load'] as num).toDouble(),
        capacity: m['capacity'] as int,
        utilizationPct: (m['utilization_pct'] as num).toDouble(),
      );
}

class ForecastResponse {
  final List<ForecastSlot> items;
  final String generatedAt;

  ForecastResponse({required this.items, required this.generatedAt});

  factory ForecastResponse.fromMap(Map<String, dynamic> m) => ForecastResponse(
        items: (m['items'] as List<dynamic>)
            .map((e) => ForecastSlot.fromMap(e as Map<String, dynamic>))
            .toList(),
        generatedAt: m['generated_at'] as String,
      );
}
```

- [ ] **Step 2: Verify analyzer passes**

Run: `DART_SDK=/Users/lan1t/development/flutter/bin/cache/dart-sdk /Users/lan1t/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib/models/forecast.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/models/forecast.dart
git commit -m "feat(forecast): add Flutter forecast models"
```

---

## Task 5: API Service Wrapper

**Files:**
- Modify: `lib/services/api_service.dart`
- Test: dart analyzer only

- [ ] **Step 1: Add import and method**

At the top of `lib/services/api_service.dart`, add:

```dart
import '../models/forecast.dart';
```

Inside the `ApiService` class, add:

```dart
  Future<ForecastResponse?> getForecast({int days = 7}) async {
    final result = await ApiClient.get('/admin/forecast?days=$days');
    return result.when(
      success: (data) => ForecastResponse.fromMap(data),
      failure: (_) => null,
    );
  }
```

- [ ] **Step 2: Verify analyzer passes**

Run: `DART_SDK=/Users/lan1t/development/flutter/bin/cache/dart-sdk /Users/lan1t/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib/services/api_service.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat(forecast): add ApiService.getForecast wrapper"
```

---

## Task 6: Dashboard Forecast Widget

**Files:**
- Modify: `lib/screens/admin/admin_dashboard_screen.dart`
- Test: manual UI verification + dart analyzer

- [ ] **Step 1: Add state and load method**

Add imports at the top:

```dart
import '../../models/forecast.dart';
```

Add state fields inside `_AdminDashboardScreenState`:

```dart
  ForecastResponse? _forecast;
  bool _forecastLoading = true;
  String? _forecastError;
  int _forecastDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
    _loadForecast();
  }
```

Add load method:

```dart
  Future<void> _loadForecast() async {
    setState(() {
      _forecastLoading = true;
      _forecastError = null;
    });
    final result = await ApiService().getForecast(days: _forecastDays);
    if (mounted) {
      setState(() {
        _forecastLoading = false;
        if (result == null) {
          _forecastError = 'Ошибка загрузки прогноза';
        } else {
          _forecast = result;
        }
      });
    }
  }
```

- [ ] **Step 2: Add forecast widget to build**

Inside the main `build` body (after the existing dashboard KPIs/charts), add:

```dart
          const SizedBox(height: 24),
          _buildForecastSection(context),
```

Add helper method inside `_AdminDashboardScreenState`:

```dart
  Widget _buildForecastSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppStyles.adaptiveSurface(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Прогноз загрузки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 дней')),
                    ButtonSegment(value: 14, label: Text('14 дней')),
                  ],
                  selected: {_forecastDays},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty && set.first != _forecastDays) {
                      setState(() => _forecastDays = set.first);
                      _loadForecast();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_forecastLoading)
              const Center(child: CircularProgressIndicator())
            else if (_forecastError != null)
              Center(child: Text(_forecastError!, style: TextStyle(color: AppStyles.danger)))
            else if (_forecast != null)
              SizedBox(height: 220, child: _ForecastChart(slots: _forecast!.items))
            else
              const Center(child: Text('Нет данных')),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Add chart widget**

At the bottom of the same file (after `_AdminDashboardScreenState`), add:

```dart
class _ForecastChart extends StatelessWidget {
  final List<ForecastSlot> slots;
  const _ForecastChart({required this.slots});

  Color _barColor(double utilization) {
    if (utilization < 50) return Colors.green;
    if (utilization < 80) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final maxY = slots.isEmpty
        ? 1.0
        : slots.map((s) => s.predictedLoad).reduce((a, b) => a > b ? a : b) * 1.2;
    final safeMaxY = maxY < 0.1 ? 1.0 : maxY;

    return BarChart(
      BarChartData(
        maxY: safeMaxY,
        barGroups: slots.asMap().entries.map((entry) {
          final s = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: s.predictedLoad,
                color: _barColor(s.utilizationPct),
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= slots.length) return const SizedBox.shrink();
                final s = slots[idx];
                if (s.hour != 12) return const SizedBox.shrink();
                return Text('${s.date.substring(5)}', style: const TextStyle(fontSize: 10));
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify analyzer passes**

Run: `DART_SDK=/Users/lan1t/development/flutter/bin/cache/dart-sdk /Users/lan1t/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib/screens/admin/admin_dashboard_screen.dart`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/screens/admin/admin_dashboard_screen.dart
git commit -m "feat(forecast): add forecast chart widget to admin dashboard"
```

---

## Task 7: Final Verification

- [ ] **Step 1: Run backend tests**

Run: `cd backend && source ../.venv/bin/activate && pytest tests/test_forecast.py -v`
Expected: 4 PASS

- [ ] **Step 2: Run full backend suite**

Run: `cd backend && source ../.venv/bin/activate && pytest tests/ -q --tb=short`
Expected: 199+ passed, 1 skipped

- [ ] **Step 3: Run Dart analyzer**

Run: `DART_SDK=/Users/lan1t/development/flutter/bin/cache/dart-sdk /Users/lan1t/development/flutter/bin/cache/dart-sdk/bin/dart analyze lib/models/forecast.dart lib/services/api_service.dart lib/screens/admin/admin_dashboard_screen.dart`
Expected: No issues

- [ ] **Step 4: Commit any remaining changes**

```bash
git add -A
git commit -m "feat(forecast): complete workload forecasting feature"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ Backend forecast algorithm — Tasks 2-3
- ✅ Redis caching — Task 3
- ✅ Pydantic models — Task 1
- ✅ Admin-only endpoint with rate limit — Task 3
- ✅ Frontend model — Task 4
- ✅ API service wrapper — Task 5
- ✅ Dashboard chart widget — Task 6
- ✅ Tests — Tasks 1-3

**2. Placeholder scan:** No TBD/TODO placeholders found.

**3. Type consistency:** `ForecastSlot`/`ForecastResponse` match across backend and frontend. `generate_forecast` accepts `days: int` and returns `ForecastResponse`.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-09-workload-forecast-impl.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
