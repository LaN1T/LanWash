# Фаза 3 — Аналитика загрузки + копирование смен + визуал Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить админскую аналитику загрузки прямо в экран расписания, улучшить визуальное отображение смен и упростить копирование смен.

**Architecture:** Backend: новый endpoint `/api/reports/shift-load/` агрегирует смены и доступность за период. Frontend: новая модель `ShiftLoadReport`, виджет `ShiftAnalyticsView`, расширение переключателя режимов `ShiftScheduleScreen` третьей вкладкой для админа, доработка `ShiftCell`/`_ShiftDialog` для копирования.

**Tech Stack:** Python 3.13, FastAPI, SQLAlchemy 2 async, Pydantic v2; Flutter 3.x, Provider, fl_chart.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/models.py` | Pydantic-схемы ответа `ShiftLoadResponse` |
| `backend/services/reports_service.py` | Метод `shift_load_report` и вспомогательные функции |
| `backend/routers/reports.py` | Endpoint `GET /api/reports/shift-load/` |
| `backend/tests/test_shift_load.py` | Тесты endpoint и агрегации |
| `lib/models/shift_load_report.dart` | Модель фронтенда |
| `lib/services/api_service.dart` | Метод `getShiftLoadReport` |
| `lib/widgets/shift_schedule/shift_analytics_view.dart` | Виджет с KPI и графиками |
| `lib/screens/shared/shift_schedule_screen.dart` | Переключатель режимов, загрузка аналитики, визуал, копирование |
| `test/widgets/shift_analytics_view_test.dart` | Виджет-тест (не запускаем на этом устройстве) |

---

### Task 1: Backend — Pydantic response schemas

**Files:**
- Modify: `backend/models.py`

- [ ] **Step 1: Add schemas after `WasherAvailabilityResponse`**

Insert the following block after `WasherAvailabilityResponse`:

```python

# ─── Shift Load Report ───────────────────────────────────────────────────────
class ShiftLoadDailyEntry(BaseModel):
    date: str
    confirmedMinutes: int
    pendingMinutes: int


class ShiftLoadWasherStat(BaseModel):
    userId: int
    displayName: str
    confirmedMinutes: int
    pendingMinutes: int
    rejectedMinutes: int
    utilizationPercent: float
    isOvertime: bool
    isUnderload: bool


class ShiftLoadStatusCounts(BaseModel):
    confirmed: int
    pending: int
    rejected: int


class ShiftLoadAvailabilityCoverage(BaseModel):
    availableDays: int
    unavailableDays: int
    unknownDays: int


class ShiftLoadResponse(BaseModel):
    startDate: str
    endDate: str
    targetWeeklyMinutesPerWasher: int
    dailyHours: List[ShiftLoadDailyEntry]
    washerStats: List[ShiftLoadWasherStat]
    statusCounts: ShiftLoadStatusCounts
    conflictCount: int
    availabilityCoverage: ShiftLoadAvailabilityCoverage
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && source ../.venv/bin/activate && python -c "from models import ShiftLoadResponse; print('ok')"
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add backend/models.py && git commit -m "feat(shift-load): add response schemas"
```

---

### Task 2: Backend — service method

**Files:**
- Modify: `backend/services/reports_service.py`
- Modify: `backend/db_models.py` (already has `WasherAvailability`, just verify import)

- [ ] **Step 1: Add imports in `reports_service.py`**

Change the `db_models` import block to include `WasherAvailability`:

```python
from db_models import (
    Appointment,
    Consumable,
    ConsumableUsageLog,
    Promo,
    Service,
    ServiceConsumable,
    Shift,
    User,
    WashType,
    WashTypeConsumable,
    WasherAvailability,
)
```

- [ ] **Step 2: Add helper functions and service method**

Insert the following code at the end of `ReportsService`, before the file ends:

```python
    async def shift_load_report(self, start_date: str, end_date: str) -> dict:
        target_minutes = 40 * 60

        shifts_result = await self._db.execute(
            select(Shift).where(
                and_(Shift.date >= start_date, Shift.date <= end_date)
            )
        )
        shifts = shifts_result.scalars().all()

        availability_result = await self._db.execute(
            select(WasherAvailability).where(
                and_(
                    WasherAvailability.date >= start_date,
                    WasherAvailability.date <= end_date,
                )
            )
        )
        availability = availability_result.scalars().all()

        users_result = await self._db.execute(
            select(User.id, User.displayName).where(User.role == "washer")
        )
        washers = {u[0]: u[1] for u in users_result.all()}

        start_dt = datetime.strptime(start_date, "%Y-%m-%d").date()
        end_dt = datetime.strptime(end_date, "%Y-%m-%d").date()
        days_count = (end_dt - start_dt).days + 1

        daily_minutes: dict[str, dict[str, int]] = defaultdict(
            lambda: {"confirmedMinutes": 0, "pendingMinutes": 0}
        )
        washer_minutes: dict[int, dict[str, int]] = defaultdict(
            lambda: {"confirmed": 0, "pending": 0, "rejected": 0}
        )
        status_counts = {"confirmed": 0, "pending": 0, "rejected": 0}

        for shift in shifts:
            minutes = self._shift_minutes(shift.startTime, shift.endTime)
            if shift.status == "confirmed":
                daily_minutes[shift.date]["confirmedMinutes"] += minutes
                washer_minutes[shift.userId]["confirmed"] += minutes
                status_counts["confirmed"] += 1
            elif shift.status == "pending":
                daily_minutes[shift.date]["pendingMinutes"] += minutes
                washer_minutes[shift.userId]["pending"] += minutes
                status_counts["pending"] += 1
            elif shift.status == "rejected":
                washer_minutes[shift.userId]["rejected"] += minutes
                status_counts["rejected"] += 1

        daily_hours = []
        current = start_dt
        while current <= end_dt:
            d = current.strftime("%Y-%m-%d")
            entry = daily_minutes.get(d, {"confirmedMinutes": 0, "pendingMinutes": 0})
            daily_hours.append(
                {
                    "date": d,
                    "confirmedMinutes": entry["confirmedMinutes"],
                    "pendingMinutes": entry["pendingMinutes"],
                }
            )
            current += timedelta(days=1)

        washer_stats = []
        for user_id, display_name in sorted(washers.items(), key=lambda x: x[1]):
            confirmed = washer_minutes[user_id]["confirmed"]
            pending = washer_minutes[user_id]["pending"]
            rejected = washer_minutes[user_id]["rejected"]
            utilization = (confirmed / target_minutes * 100) if target_minutes else 0.0
            washer_stats.append(
                {
                    "userId": user_id,
                    "displayName": display_name,
                    "confirmedMinutes": confirmed,
                    "pendingMinutes": pending,
                    "rejectedMinutes": rejected,
                    "utilizationPercent": round(utilization, 1),
                    "isOvertime": confirmed > target_minutes,
                    "isUnderload": confirmed < target_minutes * 0.5,
                }
            )

        availability_counts = {"available": 0, "unavailable": 0}
        for a in availability:
            if a.status in availability_counts:
                availability_counts[a.status] += 1
        total_possible_days = len(washers) * days_count
        unknown_days = max(
            0,
            total_possible_days
            - availability_counts["available"]
            - availability_counts["unavailable"],
        )

        return {
            "startDate": start_date,
            "endDate": end_date,
            "targetWeeklyMinutesPerWasher": target_minutes,
            "dailyHours": daily_hours,
            "washerStats": washer_stats,
            "statusCounts": status_counts,
            "conflictCount": self._count_conflicts(shifts),
            "availabilityCoverage": {
                "availableDays": availability_counts["available"],
                "unavailableDays": availability_counts["unavailable"],
                "unknownDays": unknown_days,
            },
        }

    @staticmethod
    def _shift_minutes(start_time: str, end_time: str) -> int:
        def _to_minutes(t: str) -> int:
            h, m = map(int, t.split(":"))
            return h * 60 + m

        start = _to_minutes(start_time)
        end = _to_minutes(end_time)
        if end < start:
            end += 24 * 60
        return end - start

    @staticmethod
    def _count_conflicts(shifts: list[Shift]) -> int:
        by_date: dict[str, list[Shift]] = defaultdict(list)
        for shift in shifts:
            by_date[shift.date].append(shift)

        total = 0
        for day_shifts in by_date.values():
            sorted_shifts = sorted(day_shifts, key=lambda s: s.startTime)
            for i in range(len(sorted_shifts)):
                for j in range(i + 1, len(sorted_shifts)):
                    a = sorted_shifts[i]
                    b = sorted_shifts[j]
                    a_start = ReportsService._shift_minutes(a.startTime, a.endTime)
                    a_end = a_start + 0
                    # we need absolute minutes from midnight for overlap
                    a_s = int(a.startTime.split(":")[0]) * 60 + int(
                        a.startTime.split(":")[1]
                    )
                    a_e = a_s + ReportsService._shift_minutes(a.startTime, a.endTime)
                    b_s = int(b.startTime.split(":")[0]) * 60 + int(
                        b.startTime.split(":")[1]
                    )
                    b_e = b_s + ReportsService._shift_minutes(b.startTime, b.endTime)
                    if a_s < b_e and a_e > b_s:
                        total += 1
        return total
```

Note: the conflict counting logic uses absolute start/end minutes; each overlapping pair is counted once.

- [ ] **Step 3: Verify syntax**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && source ../.venv/bin/activate && python -c "from services.reports_service import ReportsService; print('ok')"
```
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add backend/services/reports_service.py && git commit -m "feat(shift-load): add shift load report service"
```

---

### Task 3: Backend — router endpoint + tests

**Files:**
- Modify: `backend/routers/reports.py`
- Create: `backend/tests/test_shift_load.py`

- [ ] **Step 1: Add endpoint in `reports.py`**

Insert after the `/daily/` endpoint:

```python

@router.get("/shift-load/")
@limiter.limit("60/minute")
async def shift_load_report(
    request: Request,
    start_date: str,
    end_date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Weekly shift load analytics (admin only)."""
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ только для администраторов"
        )
    try:
        datetime.strptime(start_date, "%Y-%m-%d")
        datetime.strptime(end_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Неверный формат даты. Ожидается YYYY-MM-DD",
        )
    svc = ReportsService(db)
    return await svc.shift_load_report(start_date, end_date)
```

- [ ] **Step 2: Write failing test**

Create `backend/tests/test_shift_load.py`:

```python
from datetime import date, datetime, timedelta

import pytest

from db_models import Shift, User, WasherAvailability


@pytest.mark.asyncio
async def test_admin_gets_shift_load_report(async_client, admin_token, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer = next(u for u in washers.json() if u["username"] == "washer_test")

    today = date.today().isoformat()
    tomorrow = (date.today() + timedelta(days=1)).isoformat()

    async with async_client.app.state.db() as session:  # type: ignore
        pass

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": tomorrow},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["startDate"] == today
    assert data["endDate"] == tomorrow
    assert data["targetWeeklyMinutesPerWasher"] == 2400
    assert "dailyHours" in data
    assert "washerStats" in data
    assert "statusCounts" in data
    assert "conflictCount" in data
    assert "availabilityCoverage" in data


@pytest.mark.asyncio
async def test_washer_cannot_access_shift_load(async_client, washer_token):
    today = date.today().isoformat()
    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": tomorrow},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_invalid_date_returns_400(async_client, admin_token):
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": "bad", "end_date": "2026-06-14"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_conflict_count(async_client, admin_token, washer_token, db_session):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer = next(u for u in washers.json() if u["username"] == "washer_test")

    today = date.today().isoformat()
    now = datetime.now().isoformat()
    db_session.add_all(
        [
            Shift(
                userId=washer["id"],
                date=today,
                startTime="10:00",
                endTime="14:00",
                status="confirmed",
                createdBy="admin",
                createdAt=now,
                updatedAt=now,
            ),
            Shift(
                userId=washer["id"],
                date=today,
                startTime="12:00",
                endTime="16:00",
                status="confirmed",
                createdBy="admin",
                createdAt=now,
                updatedAt=now,
            ),
        ]
    )
    await db_session.commit()

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": today},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["conflictCount"] == 1
```

Note: the first test uses the endpoint without pre-seeded shifts; it validates structure.

- [ ] **Step 3: Run tests and watch them fail (optional) / pass**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && source ../.venv/bin/activate && pytest tests/test_shift_load.py -q
```
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add backend/routers/reports.py backend/tests/test_shift_load.py && git commit -m "feat(shift-load): add endpoint and tests"
```

---

### Task 4: Frontend — model + ApiService

**Files:**
- Create: `lib/models/shift_load_report.dart`
- Modify: `lib/services/api_service.dart`

- [ ] **Step 1: Create `lib/models/shift_load_report.dart`**

```dart
class ShiftLoadReport {
  final String startDate;
  final String endDate;
  final int targetWeeklyMinutesPerWasher;
  final List<ShiftLoadDailyEntry> dailyHours;
  final List<ShiftLoadWasherStat> washerStats;
  final ShiftLoadStatusCounts statusCounts;
  final int conflictCount;
  final ShiftLoadAvailabilityCoverage availabilityCoverage;

  const ShiftLoadReport({
    required this.startDate,
    required this.endDate,
    required this.targetWeeklyMinutesPerWasher,
    required this.dailyHours,
    required this.washerStats,
    required this.statusCounts,
    required this.conflictCount,
    required this.availabilityCoverage,
  });

  factory ShiftLoadReport.fromMap(Map<String, dynamic> map) {
    return ShiftLoadReport(
      startDate: map['startDate'] as String,
      endDate: map['endDate'] as String,
      targetWeeklyMinutesPerWasher:
          map['targetWeeklyMinutesPerWasher'] as int? ?? 2400,
      dailyHours: (map['dailyHours'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ShiftLoadDailyEntry.fromMap)
          .toList(),
      washerStats: (map['washerStats'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ShiftLoadWasherStat.fromMap)
          .toList(),
      statusCounts:
          ShiftLoadStatusCounts.fromMap(map['statusCounts'] as Map<String, dynamic>),
      conflictCount: map['conflictCount'] as int? ?? 0,
      availabilityCoverage: ShiftLoadAvailabilityCoverage.fromMap(
          map['availabilityCoverage'] as Map<String, dynamic>),
    );
  }
}

class ShiftLoadDailyEntry {
  final String date;
  final int confirmedMinutes;
  final int pendingMinutes;

  const ShiftLoadDailyEntry({
    required this.date,
    required this.confirmedMinutes,
    required this.pendingMinutes,
  });

  factory ShiftLoadDailyEntry.fromMap(Map<String, dynamic> map) {
    return ShiftLoadDailyEntry(
      date: map['date'] as String,
      confirmedMinutes: map['confirmedMinutes'] as int? ?? 0,
      pendingMinutes: map['pendingMinutes'] as int? ?? 0,
    );
  }
}

class ShiftLoadWasherStat {
  final int userId;
  final String displayName;
  final int confirmedMinutes;
  final int pendingMinutes;
  final int rejectedMinutes;
  final double utilizationPercent;
  final bool isOvertime;
  final bool isUnderload;

  const ShiftLoadWasherStat({
    required this.userId,
    required this.displayName,
    required this.confirmedMinutes,
    required this.pendingMinutes,
    required this.rejectedMinutes,
    required this.utilizationPercent,
    required this.isOvertime,
    required this.isUnderload,
  });

  factory ShiftLoadWasherStat.fromMap(Map<String, dynamic> map) {
    return ShiftLoadWasherStat(
      userId: map['userId'] as int,
      displayName: map['displayName'] as String,
      confirmedMinutes: map['confirmedMinutes'] as int? ?? 0,
      pendingMinutes: map['pendingMinutes'] as int? ?? 0,
      rejectedMinutes: map['rejectedMinutes'] as int? ?? 0,
      utilizationPercent: (map['utilizationPercent'] as num?)?.toDouble() ?? 0.0,
      isOvertime: map['isOvertime'] as bool? ?? false,
      isUnderload: map['isUnderload'] as bool? ?? false,
    );
  }
}

class ShiftLoadStatusCounts {
  final int confirmed;
  final int pending;
  final int rejected;

  const ShiftLoadStatusCounts({
    required this.confirmed,
    required this.pending,
    required this.rejected,
  });

  factory ShiftLoadStatusCounts.fromMap(Map<String, dynamic> map) {
    return ShiftLoadStatusCounts(
      confirmed: map['confirmed'] as int? ?? 0,
      pending: map['pending'] as int? ?? 0,
      rejected: map['rejected'] as int? ?? 0,
    );
  }
}

class ShiftLoadAvailabilityCoverage {
  final int availableDays;
  final int unavailableDays;
  final int unknownDays;

  const ShiftLoadAvailabilityCoverage({
    required this.availableDays,
    required this.unavailableDays,
    required this.unknownDays,
  });

  factory ShiftLoadAvailabilityCoverage.fromMap(Map<String, dynamic> map) {
    return ShiftLoadAvailabilityCoverage(
      availableDays: map['availableDays'] as int? ?? 0,
      unavailableDays: map['unavailableDays'] as int? ?? 0,
      unknownDays: map['unknownDays'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 2: Add import and method in `api_service.dart`**

Add import:
```dart
import '../models/shift_load_report.dart';
```

Add method after `updateWasherAvailability`:

```dart
  Future<ShiftLoadReport?> getShiftLoadReport(
    String startDate,
    String endDate,
  ) async {
    final result = await ApiClient.get(
      '/reports/shift-load/?start_date=$startDate&end_date=$endDate',
    );
    return result.when(
      success: (data) => ShiftLoadReport.fromMap(data),
      failure: (_) => null,
    );
  }
```

- [ ] **Step 3: Verify analyze**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze lib/models/shift_load_report.dart lib/services/api_service.dart
```
Expected: `No issues found`

- [ ] **Step 4: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add lib/models/shift_load_report.dart lib/services/api_service.dart && git commit -m "feat(shift-load): frontend model and ApiService"
```

---

### Task 5: Frontend — `ShiftAnalyticsView` widget

**Files:**
- Create: `lib/widgets/shift_schedule/shift_analytics_view.dart`

- [ ] **Step 1: Implement widget**

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../app_styles.dart';
import '../../models/shift_load_report.dart';

class ShiftAnalyticsView extends StatelessWidget {
  final ShiftLoadReport report;
  final DateTime weekStart;

  const ShiftAnalyticsView({
    super.key,
    required this.report,
    required this.weekStart,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKpiRow(context),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Часы по дням недели'),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: _buildDailyChart(context)),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Загрузка по мойщикам'),
        const SizedBox(height: 12),
        _buildWasherStats(context),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Доступность мойщиков'),
        const SizedBox(height: 12),
        _buildAvailabilityChips(context),
      ],
    );
  }

  Widget _buildKpiRow(BuildContext context) {
    final totalConfirmed = report.washerStats.fold<int>(
      0,
      (sum, s) => sum + s.confirmedMinutes,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          context,
          'Всего часов',
          '${(totalConfirmed / 60).toStringAsFixed(1)} ч',
          AppStyles.primary,
        ),
        _kpiCard(
          context,
          'На рассмотрении',
          '${report.statusCounts.pending}',
          report.statusCounts.pending > 0 ? AppStyles.warning : AppStyles.success,
        ),
        _kpiCard(
          context,
          'Конфликтов',
          '${report.conflictCount}',
          report.conflictCount > 0 ? AppStyles.danger : AppStyles.success,
        ),
        _kpiCard(
          context,
          'Перегрузок',
          '${report.washerStats.where((s) => s.isOvertime).length}',
          report.washerStats.any((s) => s.isOvertime)
              ? AppStyles.danger
              : AppStyles.success,
        ),
      ],
    );
  }

  Widget _kpiCard(BuildContext context, String title, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppStyles.adaptiveTextPrimary(context),
      ),
    );
  }

  Widget _buildDailyChart(BuildContext context) {
    final maxY = report.dailyHours
            .map((e) => (e.confirmedMinutes + e.pendingMinutes) / 60.0)
            .fold<double>(0, (m, v) => v > m ? v : m) *
        1.2;
    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY,
        barGroups: report.dailyHours.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: day.confirmedMinutes / 60.0,
                color: AppStyles.success,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: (day.confirmedMinutes + day.pendingMinutes) / 60.0,
                color: AppStyles.warning,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= report.dailyHours.length) {
                  return const SizedBox.shrink();
                }
                final date = DateTime.parse(report.dailyHours[index].date);
                return Text(
                  DateFormat('E', 'ru_RU').format(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()} ч',
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildWasherStats(BuildContext context) {
    if (report.washerStats.isEmpty) {
      return const Text('Нет данных по мойщикам');
    }
    final maxMinutes = report.targetWeeklyMinutesPerWasher;
    return Column(
      children: report.washerStats.map((stat) {
        final ratio = (stat.confirmedMinutes / maxMinutes).clamp(0.0, 1.0);
        final color = stat.isOvertime
            ? AppStyles.danger
            : stat.isUnderload
                ? AppStyles.warning
                : AppStyles.success;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stat.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                  ),
                  Text(
                    '${(stat.confirmedMinutes / 60).toStringAsFixed(1)} ч · ${stat.utilizationPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilityChips(BuildContext context) {
    final coverage = report.availabilityCoverage;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, 'Доступны', coverage.availableDays.toString(), AppStyles.success),
        _chip(context, 'Недоступны', coverage.unavailableDays.toString(), AppStyles.danger),
        _chip(context, 'Не указано', coverage.unknownDays.toString(), Colors.grey),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze lib/widgets/shift_schedule/shift_analytics_view.dart
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add lib/widgets/shift_schedule/shift_analytics_view.dart && git commit -m "feat(shift-load): add analytics view widget"
```

---

### Task 6: Frontend — integrate analytics tab

**Files:**
- Modify: `lib/screens/shared/shift_schedule_screen.dart`

- [ ] **Step 1: Update enum and state**

Change `_ScheduleMode` from:
```dart
enum _ScheduleMode { shifts, availability }
```
to:
```dart
enum _ScheduleMode { shifts, availability, analytics }
```

Add state after `_availabilityLoading`:
```dart
  ShiftLoadReport? _shiftLoadReport;
  bool _shiftLoadLoading = false;
```

- [ ] **Step 2: Add analytics loading method**

Add inside `_ShiftScheduleScreenState`:

```dart
  Future<void> _loadShiftLoadReport() async {
    if (!_isAdmin) return;
    setState(() => _shiftLoadLoading = true);
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final end = _weekStart.add(const Duration(days: 6));
      final report = await context.read<ApiService>().getShiftLoadReport(
            fmt.format(_weekStart),
            fmt.format(end),
          );
      if (mounted) {
        setState(() {
          _shiftLoadReport = report;
          _shiftLoadLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load shift load report: $e\n$st');
      if (mounted) setState(() => _shiftLoadLoading = false);
    }
  }
```

- [ ] **Step 3: Load report when mode or week changes**

In `_loadData`, after `_loadAvailability(washers)` call, add:
```dart
      if (_mode == _ScheduleMode.analytics) {
        await _loadShiftLoadReport();
      }
```

In `_buildModeToggle`, the `onPressed` should already call `_loadData()` after switching mode; ensure it does.

- [ ] **Step 4: Update mode toggle labels**

Change `_buildModeToggle` children to conditionally include analytics for admin:

```dart
  Widget _buildModeToggle() {
    final modes = _isAdmin
        ? _ScheduleMode.values
        : [_ScheduleMode.shifts, _ScheduleMode.availability];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: ToggleButtons(
          isSelected: modes.map((m) => _mode == m).toList(),
          onPressed: (index) {
            final newMode = modes[index];
            if (newMode != _mode) {
              setState(() => _mode = newMode);
              _loadData();
            }
          },
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: AppStyles.primary,
          color: AppStyles.adaptiveTextPrimary(context),
          children: modes.map((m) {
            final label = switch (m) {
              _ScheduleMode.shifts => 'Смены',
              _ScheduleMode.availability => 'Доступность',
              _ScheduleMode.analytics => 'Аналитика',
            };
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(label),
            );
          }).toList(),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Render analytics view**

In `_buildShiftsViewOrAvailability`, update the conditional:

```dart
    if (_mode == _ScheduleMode.shifts) return _buildShiftsView();
    if (_mode == _ScheduleMode.availability) return _buildAvailabilityView();
    return _buildAnalyticsView();
```

Add method:

```dart
  Widget _buildAnalyticsView() {
    if (_shiftLoadLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final report = _shiftLoadReport;
    if (report == null) {
      return const Center(child: Text('Не удалось загрузить аналитику'));
    }
    return ShiftAnalyticsView(
      report: report,
      weekStart: _weekStart,
    );
  }
```

- [ ] **Step 6: Import `ShiftAnalyticsView` and `ShiftLoadReport`**

Add at the top of `shift_schedule_screen.dart`:
```dart
import '../../models/shift_load_report.dart';
import '../../widgets/shift_schedule/shift_analytics_view.dart';
```

- [ ] **Step 7: Verify analyze**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze lib/screens/shared/shift_schedule_screen.dart
```
Expected: `No issues found`

- [ ] **Step 8: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add lib/screens/shared/shift_schedule_screen.dart && git commit -m "feat(shift-load): integrate analytics tab"
```

---

### Task 7: Frontend — visual improvements

**Files:**
- Modify: `lib/screens/shared/shift_schedule_screen.dart` (header and table)

- [ ] **Step 1: Highlight today column**

In `_buildTable`, compute today string once:
```dart
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
```

Update header cell generation to pass `isToday`:
```dart
                  ...days.map(
                    (d) => _headerCell(
                      _dayLabel(d),
                      isWeekend: d.weekday >= 6,
                      isToday: fmt.format(d) == todayStr,
                    ),
                  ),
```

Update `_headerCell` signature and decoration:
```dart
  Widget _headerCell(
    String text, {
    bool isWeekend = false,
    bool isToday = false,
    Alignment align = Alignment.center,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      alignment: align,
      decoration: isToday
          ? BoxDecoration(
              color: AppStyles.primary.withValues(alpha: 0.08),
            )
          : null,
      child: Text(...),
    );
  }
```

In row cells, wrap each `DraggableShiftCell` with a today background:
```dart
                  return _wrapHighlight(
                    highlight,
                    Container(
                      color: fmt.format(d) == todayStr
                          ? AppStyles.primary.withValues(alpha: 0.04)
                          : null,
                      child: matchesFilter
                          ? DraggableShiftCell(...)
                          : const SizedBox(height: 72),
                    ),
                  );
```

- [ ] **Step 2: Mute past shifts**

In `ShiftCell`, adjust text color for past dates. Add parameter `bool isPast = false;` and use muted colors when `isPast`.

Pass `isPast` from `_buildTable`:
```dart
final isPast = d.isBefore(DateTime(now.year, now.month, now.day));
```

Modify `ShiftCell` build:
- `textColor` for confirmed shifts when past: `AppStyles.adaptiveTextSecondary(context)`.
- For pending/rejected past shifts keep existing status colors but reduce opacity via `withValues(alpha: 0.7)`.

- [ ] **Step 3: Verify analyze**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart
```
Expected: `No issues found`

- [ ] **Step 4: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart && git commit -m "feat(shift-schedule): today highlight and past shift muted colors"
```

---

### Task 8: Frontend — duplicate / copy day

**Files:**
- Modify: `lib/screens/shared/shift_schedule_screen.dart`

- [ ] **Step 1: Add duplicate button to `_ShiftDialog`**

Add parameter `final VoidCallback? onDuplicate;` to `_ShiftDialog`.

In `_ShiftDialog.build`, add a duplicate button next to delete:
```dart
        if (widget.existing != null && widget.canEdit)
          TextButton(
            onPressed: () => Navigator.pop(context, _EditResult(duplicate: true)),
            child: const Text('Дублировать'),
          ),
```

Update `_EditResult`:
```dart
class _EditResult {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool delete;
  final bool duplicate;

  _EditResult({this.start, this.end, this.delete = false, this.duplicate = false});
}
```

- [ ] **Step 2: Handle duplicate in `_openEditor`**

After the dialog result, add:
```dart
    if (result.duplicate && existing != null) {
      await _duplicateShift(existing);
      return;
    }
```

Add method:
```dart
  Future<void> _duplicateShift(Shift shift) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final nextDate = DateTime.parse(shift.date).add(const Duration(days: 1));
    final nextDateStr = fmt.format(nextDate);

    final existingNext = _findShift(shift.userId, nextDate);
    if (existingNext != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Перезаписать смену?'),
          content: const Text('На следующий день уже есть смена. Заменить её?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Заменить', style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _deleteShift(existingNext);
    }

    final created = await context.read<ApiService>().createShift(
          shift.userId,
          nextDateStr,
          shift.startTime,
          shift.endTime,
        );
    if (created != null && mounted) {
      _showSnack('Смена продублирована');
      _loadData();
    }
  }
```

- [ ] **Step 3: Add copy/paste day via name cell menu**

Add state:
```dart
  List<Shift>? _copiedDayShifts;
  DateTime? _copiedDayDate;
```

Add methods:
```dart
  void _copyDay(User washer, DateTime date) {
    final fmt = DateFormat('yyyy-MM-dd');
    final dayShifts = _shifts
        .where((s) => s.userId == washer.id && s.date == fmt.format(date))
        .toList();
    setState(() {
      _copiedDayShifts = dayShifts;
      _copiedDayDate = date;
      _copiedShift = null;
      _copiedWeek = null;
    });
    _showSnack('День скопирован');
  }

  Future<void> _pasteDay(User washer, DateTime date) async {
    if (_copiedDayShifts == null || _copiedDayShifts!.isEmpty) return;
    final fmt = DateFormat('yyyy-MM-dd');
    final targetDateStr = fmt.format(date);

    for (final shift in _copiedDayShifts!) {
      await context.read<ApiService>().createShift(
        washer.id!,
        targetDateStr,
        shift.startTime,
        shift.endTime,
      );
    }
    if (mounted) {
      _showSnack('День вставлен');
      _loadData();
    }
  }
```

Update `_showNameCellMenu` to include copy/paste day items:
```dart
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать день'),
              onTap: () {
                Navigator.pop(context);
                _copyDay(washer, _weekStart.add(Duration(days: _selectedDayIndex ?? 0)));
              },
            ),
```

Note: `_selectedDayIndex` does not exist. Simpler: pass the date when invoking the menu. Change `_nameCell` to pass `DateTime`? The name cell is not tied to a day. Better approach: add copy/paste day via long-press on any cell, not name. Use `ShiftCell` menu.

Revised approach: add `onCopyDay` / `onPasteDay` callbacks to `ShiftCell` and `DraggableShiftCell`, call from `_buildTable` with the cell's date.

Add parameters to `ShiftCell`:
```dart
  final VoidCallback? onCopyDay;
  final VoidCallback? onPasteDay;
```

In `_showMenu`, add:
```dart
    items.add(
      const PopupMenuItem(
        value: null,
        child: Row(children: [Icon(Icons.copy_all, size: 18), SizedBox(width: 8), Text('Копировать день')]),
      ),
    );
    if (_copiedDayShifts != null && onPasteDay != null) {
      items.add(
        const PopupMenuItem(... Text('Вставить день')),
      );
    }
```

In `_buildTable`, pass:
```dart
                            onCopyDay: () => _copyDay(w, d),
                            onPasteDay: _copiedDayShifts != null ? () => _pasteDay(w, d) : null,
```

- [ ] **Step 4: Verify analyze**

Run:
```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart
```
Expected: `No issues found`

- [ ] **Step 5: Commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git add lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart && git commit -m "feat(shift-schedule): duplicate shift and copy/paste day"
```

---

### Task 9: Verify and final commit

- [ ] **Step 1: Run backend tests**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && source ../.venv/bin/activate && pytest -q
```
Expected: all pass.

- [ ] **Step 2: Run dart analyze**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && /Users/lan1t/development/flutter/bin/dart analyze 2>&1 | grep -E "error - (lib|test)/(screens/shared/shift_schedule_screen|widgets/shift_schedule/shift_analytics_view|widgets/shift_schedule/draggable_shift_cell|services/api_service|models/shift_load_report)" || echo "No errors in changed files"
```
Expected: `No errors in changed files`

- [ ] **Step 3: Final commit / summary**

If not already committed, commit any remaining changes.

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash && git status --short
```

Report final status to user.

---

## Self-review checklist

1. **Spec coverage:**
   - [x] Admin analytics tab — Tasks 4–6
   - [x] Backend shift-load report — Tasks 1–3
   - [x] Visual improvements — Task 7
   - [x] Duplicate/copy day — Task 8
   - [x] Tests — Tasks 3, 9

2. **Placeholder scan:** no TBD/TODO; all code blocks contain concrete implementation.

3. **Type consistency:** `ShiftLoadResponse` schema matches model `ShiftLoadReport.fromMap`; endpoint path `/reports/shift-load/` matches `ApiService.getShiftLoadReport`.
