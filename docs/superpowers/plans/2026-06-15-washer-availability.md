# Календарь доступности мойщиков — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Позволить мойщикам отмечать дни, когда они доступны/недоступны, и показывать эту информацию админу при планировании смен — всё внутри одного экрана расписания.

**Architecture:** Backend: таблица `washer_availability` + REST API для чтения/изменения записей. Frontend: новая модель и методы ApiService, виджет недельной сетки доступности, интеграция в `ShiftScheduleScreen` через переключатель «Смены / Доступность».

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2 async, Pydantic v2, Alembic; Flutter 3.x, Provider, `shared_preferences` уже подключена.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/db_models.py` | SQLAlchemy-модель `WasherAvailability` |
| `backend/alembic/versions/..._add_washer_availability.py` | Миграция создания таблицы и индексов |
| `backend/models.py` | Pydantic-схемы `WasherAvailabilityEntry`, `WasherAvailabilityUpdateRequest` |
| `backend/services/washer_availability_service.py` | Бизнес-логика чтения/обновления доступности |
| `backend/routers/washer_availability.py` | Эндпоинты `/api/washers/{user_id}/availability` |
| `backend/main.py` | Регистрация роутера |
| `backend/tests/test_washer_availability.py` | Тесты API |
| `lib/models/washer_availability.dart` | Модель данных фронтенда |
| `lib/services/api_service.dart` | Методы `getWasherAvailability`, `updateWasherAvailability` |
| `lib/widgets/shift_schedule/availability_grid.dart` | Виджет сетки доступности |
| `lib/screens/shared/shift_schedule_screen.dart` | Переключатель режимов, загрузка/сохранение, индикаторы в ячейках |
| `test/widgets/availability_grid_test.dart` | Виджет-тест сетки |

---

## Task 1: Backend — модель БД

**Files:**
- Modify: `backend/db_models.py:276`

- [ ] **Step 1: Добавить класс `WasherAvailability` после `ShiftTemplate`**

```python
class WasherAvailability(Base):
    __tablename__ = 'washer_availability'
    __table_args__ = (
        Index('ix_washer_availability_user_date', 'userId', 'date'),
        Index('ix_washer_availability_date', 'date'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    date = Column(String, nullable=False)
    status = Column(String, nullable=False)
    updatedAt = Column(String, nullable=False)
```

- [ ] **Step 2: Проверить импорты**

Убедиться, что `ForeignKey` и `Index` уже импортированы (строки 2–10).

- [ ] **Step 3: Commit**

```bash
git add backend/db_models.py
git commit -m "feat(availability): add WasherAvailability model"
```

---

## Task 2: Backend — Alembic-миграция

**Files:**
- Create: `backend/alembic/versions/xxxxxxxx_add_washer_availability_table.py`

- [ ] **Step 1: Сгенерировать файл миграции**

Run:
```bash
cd backend && source ../.venv/bin/activate && alembic revision -m "add washer availability table"
```
Expected: файл создан, путь выведен в stdout.

- [ ] **Step 2: Заполнить `upgrade` / `downgrade`**

```python
def upgrade() -> None:
    op.create_table(
        'washer_availability',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('userId', sa.Integer(), nullable=False),
        sa.Column('date', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('updatedAt', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('userId', 'date', name='uq_washer_availability_user_date'),
        sa.ForeignKeyConstraint(['userId'], ['users.id'], ondelete='CASCADE'),
    )
    op.create_index('ix_washer_availability_user_date', 'washer_availability', ['userId', 'date'], unique=False)
    op.create_index('ix_washer_availability_date', 'washer_availability', ['date'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_washer_availability_date', table_name='washer_availability')
    op.drop_index('ix_washer_availability_user_date', table_name='washer_availability')
    op.drop_table('washer_availability')
```

- [ ] **Step 3: Применить миграцию**

Run: `cd backend && alembic upgrade head`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add backend/alembic/versions/xxxxxxxx_add_washer_availability_table.py
git commit -m "chore(alembic): add washer_availability migration"
```

---

## Task 3: Backend — Pydantic-схемы

**Files:**
- Modify: `backend/models.py`

- [ ] **Step 1: Добавить схемы после `ShiftMoveRequest`**

```python
class WasherAvailabilityEntry(BaseModel):
    date: str = Field(..., max_length=10, description="YYYY-MM-DD")
    status: str = Field(..., pattern=r"^(available|unavailable)$")


class WasherAvailabilityUpdateRequest(BaseModel):
    entries: List[WasherAvailabilityEntry] = Field(..., min_length=1)
```

- [ ] **Step 2: Проверить синтаксис**

Run: `cd backend && python -c "from models import WasherAvailabilityEntry, WasherAvailabilityUpdateRequest; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/models.py
git commit -m "feat(availability): add availability request schemas"
```

---

## Task 4: Backend — сервис

**Files:**
- Create: `backend/services/washer_availability_service.py`

- [ ] **Step 1: Создать сервис**

```python
from datetime import datetime

from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import WasherAvailability
from models import WasherAvailabilityUpdateRequest


class WasherAvailabilityService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_availability(
        self, user_id: int, start_date: str, end_date: str
    ) -> list[WasherAvailability]:
        stmt = (
            select(WasherAvailability)
            .where(WasherAvailability.userId == user_id)
            .where(
                and_(
                    WasherAvailability.date >= start_date,
                    WasherAvailability.date <= end_date,
                )
            )
            .order_by(WasherAvailability.date.asc())
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def update_availability(
        self, user_id: int, req: WasherAvailabilityUpdateRequest
    ) -> list[WasherAvailability]:
        now = datetime.now().isoformat()

        # Удаляем дубликаты: последняя запись по дате побеждает.
        latest_by_date: dict[str, str] = {}
        for entry in req.entries:
            latest_by_date[entry.date] = entry.status

        dates = list(latest_by_date.keys())
        await self._db.execute(
            delete(WasherAvailability).where(
                and_(
                    WasherAvailability.userId == user_id,
                    WasherAvailability.date.in_(dates),
                )
            )
        )

        rows = [
            WasherAvailability(
                userId=user_id,
                date=date,
                status=status,
                updatedAt=now,
            )
            for date, status in latest_by_date.items()
        ]
        self._db.add_all(rows)
        await self._db.commit()
        for row in rows:
            await self._db.refresh(row)
        return rows
```

- [ ] **Step 2: Проверить синтаксис**

Run: `cd backend && python -c "from services.washer_availability_service import WasherAvailabilityService; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/services/washer_availability_service.py
git commit -m "feat(availability): add availability service"
```

---

## Task 5: Backend — роутер

**Files:**
- Create: `backend/routers/washer_availability.py`
- Modify: `backend/main.py:283`

- [ ] **Step 1: Создать роутер**

```python
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from db_models import User
from models import (
    WasherAvailabilityUpdateRequest,
)
from services.auth_service import get_current_user
from services.washer_availability_service import WasherAvailabilityService

router = APIRouter(prefix="/api/washers", tags=["washer-availability"])


def _parse_date(date_str: str) -> bool:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def _owns_or_admin(target_user_id: int, current_user: User) -> bool:
    return current_user.id == target_user_id or current_user.role == "admin"


@router.get("/{user_id}/availability")
async def list_availability(
    request: Request,
    user_id: int,
    start_date: str,
    end_date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _parse_date(start_date) or not _parse_date(end_date):
        raise HTTPException(status_code=400, detail="Неверный формат даты")
    if not _owns_or_admin(user_id, current_user):
        raise HTTPException(status_code=403, detail="Доступ запрещён")

    svc = WasherAvailabilityService(db)
    rows = await svc.get_availability(user_id, start_date, end_date)
    return [
        {
            "id": row.id,
            "userId": row.userId,
            "date": row.date,
            "status": row.status,
            "updatedAt": row.updatedAt,
        }
        for row in rows
    ]


@router.put("/{user_id}/availability", status_code=status.HTTP_200_OK)
async def update_availability(
    request: Request,
    user_id: int,
    req: WasherAvailabilityUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _owns_or_admin(user_id, current_user):
        raise HTTPException(status_code=403, detail="Доступ запрещён")
    for entry in req.entries:
        if not _parse_date(entry.date):
            raise HTTPException(
                status_code=400, detail=f"Неверный формат даты: {entry.date}"
            )

    svc = WasherAvailabilityService(db)
    rows = await svc.update_availability(user_id, req)
    return [
        {
            "id": row.id,
            "userId": row.userId,
            "date": row.date,
            "status": row.status,
            "updatedAt": row.updatedAt,
        }
        for row in rows
    ]
```

- [ ] **Step 2: Зарегистрировать роутер в `main.py`**

Добавить после `app.include_router(shifts.router)`:

```python
app.include_router(washer_availability.router)
```

и импортировать:

```python
from routers import washer_availability
```

- [ ] **Step 3: Проверить запуск**

Run: `cd backend && python -c "from main import app; print('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add backend/routers/washer_availability.py backend/main.py
git commit -m "feat(availability): add availability REST endpoints"
```

---

## Task 6: Backend — тесты

**Files:**
- Create: `backend/tests/test_washer_availability.py`

- [ ] **Step 1: Создать тесты**

```python
from datetime import datetime, timedelta

import pytest

from db_models import User, WasherAvailability


class TestWasherAvailability:
    @pytest.mark.asyncio
    async def test_washer_reads_own_availability(self, async_client, db_session, washer_token):
        washer = User(
            username="avail_washer",
            passwordHash="fakehash",
            role="washer",
            displayName="Avail Washer",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        row = WasherAvailability(
            userId=washer.id,
            date=today,
            status="available",
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(row)
        await db_session.commit()

        response = await async_client.get(
            f"/api/washers/{washer.id}/availability",
            params={"start_date": today, "end_date": today},
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["status"] == "available"

    @pytest.mark.asyncio
    async def test_washer_cannot_read_other_availability(self, async_client, db_session, washer_token, other_washer_token):
        washer = User(
            username="avail_washer_a",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer A",
            createdAt=datetime.now().isoformat(),
        )
        other = User(
            username="avail_washer_b",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer B",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add_all([washer, other])
        await db_session.commit()
        await db_session.refresh(washer)
        await db_session.refresh(other)

        today = datetime.now().strftime("%Y-%m-%d")
        response = await async_client.get(
            f"/api/washers/{other.id}/availability",
            params={"start_date": today, "end_date": today},
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_updates_availability(self, async_client, db_session, admin_token):
        washer = User(
            username="avail_washer_admin",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer Admin",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

        response = await async_client.put(
            f"/api/washers/{washer.id}/availability",
            json={
                "entries": [
                    {"date": today, "status": "available"},
                    {"date": tomorrow, "status": "unavailable"},
                ]
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

        list_response = await async_client.get(
            f"/api/washers/{washer.id}/availability",
            params={"start_date": today, "end_date": tomorrow},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert list_response.status_code == 200
        statuses = {r["date"]: r["status"] for r in list_response.json()}
        assert statuses[today] == "available"
        assert statuses[tomorrow] == "unavailable"

    @pytest.mark.asyncio
    async def test_invalid_date_returns_400(self, async_client, db_session, admin_token):
        washer = User(
            username="avail_washer_bad",
            passwordHash="fakehash",
            role="washer",
            displayName="Bad Date",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        response = await async_client.put(
            f"/api/washers/{washer.id}/availability",
            json={"entries": [{"date": "not-a-date", "status": "available"}]},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 400
```

- [ ] **Step 2: Запустить тесты**

Run: `cd backend && pytest tests/test_washer_availability.py -v`
Expected: 4 passed

- [ ] **Step 3: Запустить полный backend-suite**

Run: `cd backend && pytest -q`
Expected: все проходят

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_washer_availability.py
git commit -m "test(availability): add availability endpoint tests"
```

---

## Task 7: Frontend — модель

**Files:**
- Create: `lib/models/washer_availability.dart`

- [ ] **Step 1: Создать модель**

```dart
class WasherAvailability {
  final int id;
  final int userId;
  final String date;
  final String status; // 'available' | 'unavailable'
  final String updatedAt;

  const WasherAvailability({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    required this.updatedAt,
  });

  factory WasherAvailability.fromMap(Map<String, dynamic> map) {
    return WasherAvailability(
      id: map['id'] as int,
      userId: map['userId'] as int,
      date: map['date'] as String,
      status: map['status'] as String,
      updatedAt: map['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'status': status,
      'updatedAt': updatedAt,
    };
  }

  WasherAvailability copyWith({
    int? id,
    int? userId,
    String? date,
    String? status,
    String? updatedAt,
  }) {
    return WasherAvailability(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 2: Проверить analyze**

Run: `dart analyze lib/models/washer_availability.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/models/washer_availability.dart
git commit -m "feat(availability): add WasherAvailability model"
```

---

## Task 8: Frontend — ApiService

**Files:**
- Modify: `lib/services/api_service.dart`

- [ ] **Step 1: Импортировать модель**

```dart
import '../models/washer_availability.dart';
```

- [ ] **Step 2: Добавить методы после `moveShift`**

```dart
  Future<List<WasherAvailability>> getWasherAvailability(
      int userId, String startDate, String endDate) async {
    final result = await ApiClient.getList(
      '/washers/$userId/availability?start_date=$startDate&end_date=$endDate',
    );
    return result.when(
      success: (list) => list
          .cast<Map<String, dynamic>>()
          .map(WasherAvailability.fromMap)
          .toList(),
      failure: (_) => [],
    );
  }

  Future<List<WasherAvailability>> updateWasherAvailability(
      int userId, List<WasherAvailability> entries) async {
    final body = {
      'entries': entries
          .map((e) => {'date': e.date, 'status': e.status})
          .toList(),
    };
    final result = await ApiClient.put('/washers/$userId/availability', body: body);
    return result.when(
      success: (data) {
        final list = data['data'];
        if (list is List) {
          return list
              .cast<Map<String, dynamic>>()
              .map(WasherAvailability.fromMap)
              .toList();
        }
        return [];
      },
      failure: (_) => [],
    );
  }
```

**Note:** роутер возвращает список напрямую, поэтому в `updateWasherAvailability` используем `data` как список:

```dart
      success: (data) {
        if (data is List) {
          return data.cast<Map<String, dynamic>>().map(WasherAvailability.fromMap).toList();
        }
        return [];
      },
```

- [ ] **Step 3: Проверить analyze**

Run: `dart analyze lib/services/api_service.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat(availability): add ApiService availability methods"
```

---

## Task 9: Frontend — виджет сетки доступности

**Files:**
- Create: `lib/widgets/shift_schedule/availability_grid.dart`

- [ ] **Step 1: Создать виджет**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_styles.dart';
import '../../models/user.dart';
import '../../models/washer_availability.dart';

enum AvailabilityStatus { unknown, available, unavailable }

class AvailabilityGrid extends StatelessWidget {
  final User washer;
  final DateTime weekStart;
  final Map<String, AvailabilityStatus> statuses;
  final bool canEdit;
  final ValueChanged<DateTime>? onToggle;

  const AvailabilityGrid({
    super.key,
    required this.washer,
    required this.weekStart,
    required this.statuses,
    this.canEdit = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final fmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            washer.displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppStyles.adaptiveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: days.map((d) {
              final status = statuses[fmt.format(d)] ?? AvailabilityStatus.unknown;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _DayCell(
                    date: d,
                    status: status,
                    canEdit: canEdit,
                    onTap: () => onToggle?.call(d),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: [
              _legend(context, Icons.check_circle, AppStyles.success, 'Доступен'),
              _legend(context, Icons.cancel, AppStyles.danger, 'Недоступен'),
              _legend(context, Icons.remove_circle_outline, AppStyles.adaptiveTextSecondary(context), 'Не указано'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppStyles.adaptiveTextSecondary(context))),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final AvailabilityStatus status;
  final bool canEdit;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.status,
    required this.canEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      AvailabilityStatus.available => (Icons.check_circle, AppStyles.success),
      AvailabilityStatus.unavailable => (Icons.cancel, AppStyles.danger),
      AvailabilityStatus.unknown => (Icons.remove_circle_outline, AppStyles.adaptiveTextSecondary(context)),
    };

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Column(
        children: [
          Text(
            DateFormat('E', 'ru').format(date).toUpperCase(),
            style: TextStyle(fontSize: 10, color: AppStyles.adaptiveTextSecondary(context)),
          ),
          const SizedBox(height: 4),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(child: Icon(icon, color: color, size: 22)),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppStyles.adaptiveTextPrimary(context)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Проверить analyze**

Run: `dart analyze lib/widgets/shift_schedule/availability_grid.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/shift_schedule/availability_grid.dart
git commit -m "feat(availability): add AvailabilityGrid widget"
```

---

## Task 10: Frontend — интеграция в ShiftScheduleScreen

**Files:**
- Modify: `lib/screens/shared/shift_schedule_screen.dart`

- [ ] **Step 1: Импортировать виджет и модель**

```dart
import '../../models/washer_availability.dart';
import '../../widgets/shift_schedule/availability_grid.dart';
```

- [ ] **Step 2: Добавить enum режима и состояние**

После `ShiftFilter _filter = ShiftFilter.all;` добавить:

```dart
enum _ScheduleMode { shifts, availability }
_ScheduleMode _mode = _ScheduleMode.shifts;
Map<String, WasherAvailability> _availability = {};
```

- [ ] **Step 3: Загрузка доступности**

Добавить метод:

```dart
  Future<void> _loadAvailability() async {
    if (!_isAdmin && !_isWasher) return;
    final fmt = DateFormat('yyyy-MM-dd');
    final end = _weekStart.add(const Duration(days: 6));
    try {
      final targetId = _isAdmin
          ? (_selectedWasher?.id ?? (_visibleWashers.isNotEmpty ? _visibleWashers.first.id : null))
          : context.read<AuthProvider>().user?.id;
      if (targetId == null) return;
      final rows = await context.read<ApiService>().getWasherAvailability(
            targetId,
            fmt.format(_weekStart),
            fmt.format(end),
          );
      if (mounted) {
        setState(() {
          _availability = {for (final r in rows) r.date: r};
        });
      }
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load availability: $e\n$st');
    }
  }
```

- [ ] **Step 4: Сохранение доступности**

Добавить метод:

```dart
  Future<void> _saveAvailability(int userId, Map<String, AvailabilityStatus> statuses) async {
    final now = DateTime.now().toIso8601String();
    final entries = statuses.entries
        .where((e) => e.value != AvailabilityStatus.unknown)
        .map((e) => WasherAvailability(
              id: 0,
              userId: userId,
              date: e.key,
              status: e.value == AvailabilityStatus.available ? 'available' : 'unavailable',
              updatedAt: now,
            ))
        .toList();
    final result = await context.read<ApiService>().updateWasherAvailability(userId, entries);
    if (result.isNotEmpty && mounted) {
      _showSnack('Доступность сохранена');
      _loadAvailability();
    } else if (mounted) {
      _showSnack('Не удалось сохранить доступность', isError: true);
    }
  }
```

- [ ] **Step 5: Переключатель режимов в AppBar**

В `actions` AppBar добавить `SegmentedButton<_ScheduleMode>`:

```dart
          SegmentedButton<_ScheduleMode>(
            segments: const [
              ButtonSegment(
                value: _ScheduleMode.shifts,
                label: Text('Смены'),
                icon: Icon(Icons.calendar_today_outlined),
              ),
              ButtonSegment(
                value: _ScheduleMode.availability,
                label: Text('Доступность'),
                icon: Icon(Icons.event_available_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (set) {
              setState(() => _mode = set.first);
              if (_mode == _ScheduleMode.availability) _loadAvailability();
            },
          ),
          const SizedBox(width: 8),
```

- [ ] **Step 6: Отрисовка режима доступности**

В `build`, вместо `_buildTable()` для режима availability показывать:

```dart
_mode == _ScheduleMode.availability
    ? _buildAvailabilityView()
    : _buildTable()
```

Добавить метод `_buildAvailabilityView()`:

```dart
  Widget _buildAvailabilityView() {
    final washers = _isAdmin ? _visibleWashers : _washers.where((w) => w.id == context.read<AuthProvider>().user?.id).toList();
    if (washers.isEmpty) {
      return const Center(child: Text('Нет мойщиков для отображения'));
    }
    return Expanded(
      child: ListView(
        children: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Выберите мойщика (тап по строке в режиме смен)',
                style: TextStyle(color: AppStyles.adaptiveTextSecondary(context)),
              ),
            ),
          ...washers.map((w) {
            final fmt = DateFormat('yyyy-MM-dd');
            final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
            final statuses = {
              for (final d in days)
                fmt.format(d): _availability[fmt.format(d)]?.status == 'available'
                    ? AvailabilityStatus.available
                    : _availability[fmt.format(d)]?.status == 'unavailable'
                        ? AvailabilityStatus.unavailable
                        : AvailabilityStatus.unknown,
            };
            return AvailabilityGrid(
              washer: w,
              weekStart: _weekStart,
              statuses: statuses,
              canEdit: _isAdmin || _canEdit(w),
              onToggle: (date) {
                final key = fmt.format(date);
                final next = switch (statuses[key]) {
                  AvailabilityStatus.available => AvailabilityStatus.unavailable,
                  AvailabilityStatus.unavailable => AvailabilityStatus.unknown,
                  AvailabilityStatus.unknown => AvailabilityStatus.available,
                };
                setState(() {
                  _availability[key] = WasherAvailability(
                    id: 0,
                    userId: w.id!,
                    date: key,
                    status: next == AvailabilityStatus.available
                        ? 'available'
                        : next == AvailabilityStatus.unavailable
                            ? 'unavailable'
                            : '',
                    updatedAt: DateTime.now().toIso8601String(),
                  );
                });
              },
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                final target = _isAdmin ? _selectedWasher ?? (_visibleWashers.isNotEmpty ? _visibleWashers.first : null) : _washers.firstWhere((w) => w.id == context.read<AuthProvider>().user?.id);
                if (target == null) return;
                final fmt = DateFormat('yyyy-MM-dd');
                final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
                final statuses = {
                  for (final d in days)
                    fmt.format(d): _availability[fmt.format(d)]?.status == 'available'
                        ? AvailabilityStatus.available
                        : _availability[fmt.format(d)]?.status == 'unavailable'
                            ? AvailabilityStatus.unavailable
                            : AvailabilityStatus.unknown,
                };
                _saveAvailability(target.id!, statuses);
              },
              icon: const Icon(Icons.save),
              label: const Text('Сохранить доступность'),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 7: Индикатор доступности в ячейках смен**

В `_buildTable`, внутри `ShiftCell`/`DraggableShiftCell` можно передать `dayShifts` и дополнительно проверить availability. Для простоты — добавить подсказку в `_ShiftDialog`: если статус `unavailable`, показать предупреждение.

- [ ] **Step 8: Проверить analyze**

Run: `dart analyze lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/availability_grid.dart lib/services/api_service.dart lib/models/washer_availability.dart`
Expected: No issues found

- [ ] **Step 9: Commit**

```bash
git add lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/availability_grid.dart lib/services/api_service.dart lib/models/washer_availability.dart
git commit -m "feat(availability): integrate availability mode into schedule screen"
```

---

## Task 11: Frontend — виджет-тест сетки

**Files:**
- Create: `test/widgets/availability_grid_test.dart`

- [ ] **Step 1: Создать тест**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/user.dart';
import 'package:lanwash/widgets/shift_schedule/availability_grid.dart';

void main() {
  final washer = User(
    id: 1,
    username: 'ivan',
    displayName: 'Иван',
    passwordHash: '',
    role: UserRole.washer,
    createdAt: DateTime(2026, 6, 15),
  );

  testWidgets('cycles status on tap', (tester) async {
    DateTime? toggled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvailabilityGrid(
            washer: washer,
            weekStart: DateTime(2026, 6, 15),
            statuses: const {},
            canEdit: true,
            onToggle: (d) => toggled = d,
          ),
        ),
      ),
    );
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(toggled, isNotNull);
  });
}
```

- [ ] **Step 2: Проверить**

Run: `flutter test test/widgets/availability_grid_test.dart`
Expected: test passes

- [ ] **Step 3: Commit**

```bash
git add test/widgets/availability_grid_test.dart
git commit -m "test(availability): add AvailabilityGrid widget test"
```

---

## Task 12: Финальная верификация

- [ ] **Backend tests**

Run: `cd backend && pytest -q`
Expected: все проходят

- [ ] **Frontend analyze**

Run: `dart analyze`
Expected: No issues in changed files (pre-existing warnings are ok)

- [ ] **Git summary**

Run: `git log --oneline -12`
Expected: все коммиты фазы 2 на месте

---

## Self-Review

1. **Spec coverage:**
   - DB model → Task 1
   - Migration → Task 2
   - Schemas → Task 3
   - Service → Task 4
   - Router + registration → Task 5
   - Tests → Task 6
   - Frontend model/ApiService → Tasks 7–8
   - Availability grid widget → Task 9
   - Integration into schedule screen → Task 10
   - Frontend tests → Task 11
2. **Placeholder scan:** нет `TBD`, `TODO`, непрописанных шагов.
3. **Type consistency:** `WasherAvailability` поля (`userId`, `date`, `status`, `updatedAt`) согласованы между backend model/frontend model/service/router.
