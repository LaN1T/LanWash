# Фаза 2 — Календарь доступности мойщиков

**Date:** 2026-06-15  
**Scope:** backend availability API + washer availability screen + admin visibility in shift editor.

---

## Goal

Мойщик может отметить, в какие даты он готов работать. Администратор видит статус «доступен / недоступен / не указано» при создании смены и в таблице расписания.

---

## Data Model

New table: `washer_availability`

| Column | Type | Notes |
|---|---|---|
| id | Integer PK autoincrement | |
| userId | Integer FK → users.id | |
| date | String | YYYY-MM-DD |
| status | String | `available` / `unavailable` |
| updatedAt | String | ISO datetime |

Unique constraint: `(userId, date)`.

Missing record = `unknown` (neutral). Explicit record = available or unavailable.

---

## Backend

### New Pydantic schemas (`backend/models.py`)

```python
class WasherAvailabilityEntry(BaseModel):
    date: str
    status: str  # "available" | "unavailable"

class WasherAvailabilityUpdateRequest(BaseModel):
    entries: List[WasherAvailabilityEntry]
```

### New endpoints (`backend/routers/washers.py` or extend `shifts.py`)

Create `backend/routers/washer_availability.py` and register under `/api/washers`.

- `GET /api/washers/{user_id}/availability?start_date=&end_date=`
  - Returns list of explicit availability records for the washer.
  - Auth: own records or admin.

- `PUT /api/washers/{user_id}/availability`
  - Body: `{ "entries": [ { "date": "...", "status": "available" }, ... ] }`
  - Upserts records. Invalid dates → 400. Unknown user → 404.
  - Auth: own records or admin.

### Service (`backend/services/washer_availability_service.py`)

- `get_availability(user_id, start, end)` → list of `WasherAvailability` rows.
- `update_availability(user_id, entries)` → upserts rows, sets `updatedAt`, removes duplicates (last wins).

### Migrations

Add Alembic migration creating `washer_availability` table with indexes:
- `ix_washer_availability_user_date` (userId, date)
- `ix_washer_availability_date` (date)

---

## Frontend

### ApiService (`lib/services/api_service.dart`)

```dart
Future<List<WasherAvailability>> getWasherAvailability(
    int userId, String startDate, String endDate);

Future<bool> updateWasherAvailability(
    int userId, List<WasherAvailability> entries);
```

New model `lib/models/washer_availability.dart`:

```dart
class WasherAvailability {
  final int id;
  final int userId;
  final String date;
  final String status; // 'available' | 'unavailable'
  final String updatedAt;
}
```

### Integrated availability view inside `ShiftScheduleScreen`

No new drawer item. Availability is a mode inside the existing schedule screen.

Add a segmented control in the app bar / above the table:
- «Смены» — current weekly shift table.
- «Доступность» — availability grid.

**Washer mode:**
- The grid shows only the current washer's row (7 days).
- Each day cell shows current status.
- Tap cycles: unknown → available → unavailable → unknown.
- Color: green / red / grey.
- Buttons:
  - «Отметить всю неделю доступным»
  - «Сбросить» (удаляет записи за неделю)
  - «Сохранить» (batch PUT)
- Week switcher works the same as in shifts mode.

**Admin mode:**
- In «Смены» view, table cells show a small availability indicator:
  - red dot / stripe for `unavailable`
  - subtle green dot for `available`
  - nothing for unknown.
- Tapping a washer's name opens an inline availability editor for that washer (bottom sheet or expanded row) inside the schedule screen. The editor uses the same 7-day grid and save logic.
- **Shift editor (`_ShiftDialog`):** when opening a cell for a washer/date, show availability status text/icon. If `unavailable`, show warning: «Мойщик отметил этот день как недоступный. Создать смену всё равно?» Allow proceed (business decision).

---

## Testing

### Backend

- `backend/tests/test_washer_availability.py`:
  - Washer reads own availability.
  - Washer cannot read another washer's availability (403).
  - Admin reads any availability.
  - Update creates/updates records.
  - Duplicate dates in request — last wins.
  - Invalid date → 400.

### Frontend

- Widget test for `WasherAvailabilityScreen`:
  - Tapping cell cycles statuses.
  - Save button calls `ApiService.updateWasherAvailability`.

---

## Rollout

This is Phase 2 of the shift-management roadmap. Builds on Phase 1 (drag & drop). No breaking changes to existing shift endpoints.
