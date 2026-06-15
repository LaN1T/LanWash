# Фаза 3 — Аналитика загрузки + копирование смен + визуал

**Date:** 2026-06-16  
**Scope:** `ShiftScheduleScreen`, backend reports, shift cell interactions.

---

## Goal

Сделать расписание более информативным: администратор видит нагрузку мойщиков прямо в разделе расписания, а копирование смен становится быстрее. Всё остаётся внутри одного экрана, без новых пунктов бокового меню.

---

## Scope

### Входит
1. Админская вкладка **«Аналитика»** в `ShiftScheduleScreen`.
2. Backend endpoint `/api/reports/shift-load` для агрегации загрузки по неделе.
3. Визуальные улучшения таблицы: выделение текущего дня, приглушение прошедших смен.
4. Быстрое копирование:
   - кнопка «Дублировать на следующий день» в диалоге смены;
   - копирование/вставка всего дня через контекстное меню ячейки;
   - существующее копирование недели остаётся.

### Не входит
- Финансовая статистика (выручка, средний чек) — отдельная фаза.
- Timeline/почасовое представление.
- Push-уведомления.

---

## Backend

### New endpoint

`GET /api/reports/shift-load?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`

- Доступ только `admin`.
- `start_date` и `end_date` обязательны, формат `YYYY-MM-DD`.

Response:

```json
{
  "startDate": "2026-06-08",
  "endDate": "2026-06-14",
  "targetWeeklyMinutesPerWasher": 2400,
  "dailyHours": [
    {"date": "2026-06-08", "confirmedMinutes": 480, "pendingMinutes": 120},
    {"date": "2026-06-09", "confirmedMinutes": 0, "pendingMinutes": 0}
  ],
  "washerStats": [
    {
      "userId": 1,
      "displayName": "Иван",
      "confirmedMinutes": 960,
      "pendingMinutes": 120,
      "rejectedMinutes": 0,
      "utilizationPercent": 40.0,
      "isOvertime": false,
      "isUnderload": true
    }
  ],
  "statusCounts": {
    "confirmed": 4,
    "pending": 1,
    "rejected": 0
  },
  "conflictCount": 0,
  "availabilityCoverage": {
    "availableDays": 5,
    "unavailableDays": 2,
    "unknownDays": 9
  }
}
```

* `targetWeeklyMinutesPerWasher` — 40 часов = 2400 минут (константа, совпадает с фронтендом).
* `utilizationPercent` — `confirmedMinutes / targetWeeklyMinutesPerWasher * 100`.
* `isOvertime` — `confirmedMinutes > targetWeeklyMinutesPerWasher`.
* `isUnderload` — `confirmedMinutes < targetWeeklyMinutesPerWasher * 0.5`.
* `conflictCount` — количество пар пересекающихся смен за период.
* `availabilityCoverage` — считается по всем мойщикам за период.

### Service

Добавить метод в `backend/services/reports_service.py`:

```python
async def shift_load_report(self, start_date: str, end_date: str) -> dict:
    ...
```

Логика:
1. Загрузить все смены за диапазон (`Shift.date >= start_date`, `Shift.date <= end_date`).
2. Загрузить все записи `WasherAvailability` за тот же диапазон.
3. Загрузить мойщиков (`role == "washer"`).
4. Посчитать агрегаты per day / per washer / статусы / конфликты / доступность.
5. Вернуть словарь согласно схеме.

### Pydantic response schema

Добавить в `backend/models.py`:

- `ShiftLoadDailyEntry`
- `ShiftLoadWasherStat`
- `ShiftLoadResponse`

### Router

Добавить в `backend/routers/reports.py`:

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
    if current_user.role != "admin":
        raise HTTPException(403, "Доступ только для администраторов")
    # validate dates
    svc = ReportsService(db)
    return await svc.shift_load_report(start_date, end_date)
```

---

## Frontend

### Schedule mode switch

В `ShiftScheduleScreen` режимы расширяются:

- Для мойщика: `Смены`, `Доступность`.
- Для админа: `Смены`, `Доступность`, `Аналитика`.

### Analytics tab

Новый виджет `lib/widgets/shift_schedule/shift_analytics_view.dart`.

Layout:

```
┌────────────────────────────────────────────┐
│  KPI cards row (hours / pending / conflicts)│
├────────────────────────────────────────────┤
│  Bar chart: hours per day of week            │
├────────────────────────────────────────────┤
│  Horizontal bars: hours per washer           │
├────────────────────────────────────────────┤
│  Availability coverage chips                 │
└────────────────────────────────────────────┘
```

- Bar chart — `fl_chart` `BarChart`.
- Horizontal bars — `fl_chart` `BarChart` с `alignment: BarChartAlignment.start` или кастомные `LinearProgressIndicator`.
- KPI cards — уже есть `ShiftAnalyticsHeader`, но здесь более детальные карточки с drill-down по мойщикам.

`ApiService` метод:

```dart
Future<ShiftLoadReport?> getShiftLoadReport(String startDate, String endDate);
```

Модель `lib/models/shift_load_report.dart` с `fromMap`/`toMap`.

### Visual improvements

1. **Текущий день**: лёгкий tinted background на всём столбце.
2. **Прошедшие смены**: `AppStyles.adaptiveTextSecondary` для текста + полупрозрачный фон.
3. **Цвета статусов** остаются как есть.

### Copy / duplicate

1. **Диалог смены (`_ShiftDialog`)**:
   - Добавить кнопку **«Дублировать на день X»** рядом с удалением.
   - При нажатии создаётся новая смена на следующий день с тем же временем.
   - Если следующий день занят — показать диалог подтверждения перезаписи.

2. **Контекстное меню ячейки (`ShiftCell`)**:
   - Для ячейки со сменой добавить **«Копировать день»**.
   - Для пустой ячейки добавить **«Вставить день»**, если скопирован день.
   - Копируются все смены мойщика за выбранный день.
   - Вставка вставляет смены в целевой день с сохранением времени.

State в `_ShiftScheduleScreenState`:

```dart
List<Shift>? _copiedDayShifts;
DateTime? _copiedDayDate;
```

---

## Testing

### Backend

`backend/tests/test_shift_load.py`:

- Admin получает отчёт за неделю.
- Washer получает 403.
- Неверный формат даты → 400.
- Конфликты считаются корректно.
- `availabilityCoverage` считается корректно.

### Frontend

- `test/widgets/shift_analytics_view_test.dart` — отрисовка карточек и графиков.
- `test/widgets/shift_copy_test.dart` — дублирование смены вызывает `ApiService.createShift`.

Запускаем только backend тесты и `dart analyze` (Flutter widget-тесты не запускаем на этом устройстве из-за перегрева).

---

## Rollout

- Phase 3 builds on Phase 2 availability data.
- No breaking API changes.
- New endpoint admin-only.
