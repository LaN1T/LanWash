# Drag & Drop для расписания смен — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать drag & drop перенос смен в таблице недельного расписания: backend-эндпоинт `PATCH /api/shifts/{shift_id}/move` и frontend-виджеты `Draggable`/`DragTarget` с подтверждением перезаписи.

**Architecture:** Администратор перетаскивает ячейку смены на другую ячейку. Frontend отправляет PATCH с `targetUserId` + `targetDate`. Backend удаляет исходную смену и создаёт новую с тем же временем/статусом/`createdBy`, предварительно удалив смену в целевой ячейке. Frontend после успеха перезагружает неделю.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2 async, Pydantic v2; Flutter 3.x, `provider`, встроенные `Draggable`/`DragTarget`.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/models.py` | Pydantic-схема `ShiftMoveRequest` |
| `backend/services/shifts_service.py` | Метод `ShiftsService.move_shift` (удалить старую, создать новую) |
| `backend/routers/shifts.py` | Эндпоинт `PATCH /api/shifts/{shift_id}/move` |
| `backend/tests/test_shift_move.py` | Тесты переноса смен |
| `lib/services/api_service.dart` | Метод `ApiService.moveShift` |
| `lib/widgets/shift_schedule/draggable_shift_cell.dart` | Обертка `ShiftCell` в `Draggable`/`DragTarget` |
| `lib/screens/shared/shift_schedule_screen.dart` | Подключение `DraggableShiftCell`, обработка drop, диалог подтверждения |
| `test/screens/shift_schedule_screen_test.dart` | Виджет-тесты drag & drop |

---

## Task 1: Backend — схема запроса

**Files:**
- Modify: `backend/models.py:396`

- [ ] **Step 1: Добавить `ShiftMoveRequest`**

Вставьте сразу после `ShiftResponse` (перед блоком `Shift Templates`):

```python
class ShiftMoveRequest(BaseModel):
    targetUserId: int = Field(..., ge=1)
    targetDate: str = Field(..., max_length=10, description="YYYY-MM-DD")
```

- [ ] **Step 2: Проверить синтаксис**

Run: `cd backend && python -c "from models import ShiftMoveRequest; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/models.py
git commit -m "feat(shifts): add ShiftMoveRequest schema"
```

---

## Task 2: Backend — сервис `move_shift`

**Files:**
- Modify: `backend/services/shifts_service.py:7`, `backend/services/shifts_service.py:180`

- [ ] **Step 1: Импортировать `ShiftMoveRequest`**

Замените строку:

```python
from models import ShiftRequest
```

на:

```python
from models import ShiftMoveRequest, ShiftRequest
```

- [ ] **Step 2: Добавить метод `move_shift` перед `_time_to_minutes`**

Вставьте после `delete_shift` (строка 179) и перед `@staticmethod`:

```python
    async def move_shift(
        self, shift_id: int, req: ShiftMoveRequest, caller_username: str, is_admin: bool
    ) -> Shift:
        if not is_admin:
            raise PermissionError("Только администратор может перемещать смены")

        shift_res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = shift_res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()

        user_res = await self._db.execute(select(User).where(User.id == req.targetUserId))
        target_user = user_res.scalar_one_or_none()
        if not target_user:
            raise ValueError("Пользователь не найден")

        now = datetime.now().isoformat()

        # Удаляем смену в целевой ячейке, если она есть (перезапись).
        await self._db.execute(
            delete(Shift).where(
                and_(Shift.userId == req.targetUserId, Shift.date == req.targetDate)
            )
        )

        # Удаляем исходную смену.
        await self._db.execute(delete(Shift).where(Shift.id == shift_id))

        new_shift = Shift(
            userId=req.targetUserId,
            date=req.targetDate,
            startTime=shift.startTime,
            endTime=shift.endTime,
            status=shift.status,
            createdBy=shift.createdBy,
            createdAt=shift.createdAt,
            updatedAt=now,
        )
        self._db.add(new_shift)
        await self._db.commit()
        await self._db.refresh(new_shift)
        return new_shift
```

- [ ] **Step 3: Запустить существующие тесты смен**

Run: `cd backend && pytest tests/test_shifts.py -q`
Expected: все проходят

- [ ] **Step 4: Commit**

```bash
git add backend/services/shifts_service.py
git commit -m "feat(shifts): add move_shift service method"
```

---

## Task 3: Backend — роутер `PATCH /api/shifts/{shift_id}/move`

**Files:**
- Modify: `backend/routers/shifts.py:10`, `backend/routers/shifts.py:215`

- [ ] **Step 1: Импортировать `ShiftMoveRequest`**

Замените:

```python
from models import ShiftRequest, ShiftResponse
```

на:

```python
from models import ShiftMoveRequest, ShiftRequest, ShiftResponse
```

- [ ] **Step 2: Добавить эндпоинт в конец файла**

Вставьте после `delete_shift`:

```python
@router.patch("/{shift_id}/move", response_model=ShiftResponse)
@limiter.limit("10/minute")
async def move_shift(
    request: Request,
    shift_id: int,
    req: ShiftMoveRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _parse_date(req.targetDate):
        raise HTTPException(status_code=400, detail="Неверный формат даты")

    svc = ShiftsService(db)
    try:
        return await svc.move_shift(
            shift_id, req, current_user.username, current_user.role == "admin"
        )
    except ShiftNotFoundError:
        raise HTTPException(status_code=404, detail="Смена не найдена")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
```

- [ ] **Step 3: Проверить, что приложение стартует**

Run: `cd backend && python -c "from main import app; print('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add backend/routers/shifts.py
git commit -m "feat(shifts): add PATCH /api/shifts/{id}/move endpoint"
```

---

## Task 4: Backend — тесты переноса

**Files:**
- Create: `backend/tests/test_shift_move.py`

- [ ] **Step 1: Создать файл тестов**

```python
from datetime import datetime, timedelta

import pytest

from db_models import Shift, User


class TestShiftMove:
    @pytest.mark.asyncio
    async def test_admin_moves_shift_to_another_date(self, async_client, db_session, admin_token):
        washer = User(
            username="move_washer1",
            passwordHash="fakehash",
            role="washer",
            displayName="Move Washer 1",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="09:00",
            endTime="18:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["userId"] == washer.id
        assert data["date"] == tomorrow
        assert data["startTime"] == "09:00"
        assert data["endTime"] == "18:00"
        assert data["status"] == "confirmed"

    @pytest.mark.asyncio
    async def test_admin_moves_shift_to_another_washer(self, async_client, db_session, admin_token):
        washer_a = User(
            username="move_washer_a",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer A",
            createdAt=datetime.now().isoformat(),
        )
        washer_b = User(
            username="move_washer_b",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer B",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add_all([washer_a, washer_b])
        await db_session.commit()
        await db_session.refresh(washer_a)
        await db_session.refresh(washer_b)

        today = datetime.now().strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer_a.id,
            date=today,
            startTime="10:00",
            endTime="19:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer_b.id, "targetDate": today},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["userId"] == washer_b.id
        assert data["date"] == today

    @pytest.mark.asyncio
    async def test_non_admin_cannot_move_shift(self, async_client, db_session, admin_token, washer_token):
        washer = User(
            username="move_washer_c",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer C",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="09:00",
            endTime="18:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow},
            headers={"Authorization": f"Bearer {washer_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_move_target_user_not_found(self, async_client, db_session, admin_token):
        washer = User(
            username="move_washer_d",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer D",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        shift = Shift(
            userId=washer.id,
            date=today,
            startTime="09:00",
            endTime="18:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add(shift)
        await db_session.commit()
        await db_session.refresh(shift)

        response = await async_client.patch(
            f"/api/shifts/{shift.id}/move",
            json={"targetUserId": 99999, "targetDate": tomorrow},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_move_overwrites_existing_shift_at_target(self, async_client, db_session, admin_token):
        washer = User(
            username="move_washer_e",
            passwordHash="fakehash",
            role="washer",
            displayName="Washer E",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(washer)
        await db_session.commit()
        await db_session.refresh(washer)

        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

        source = Shift(
            userId=washer.id,
            date=today,
            startTime="08:00",
            endTime="17:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        target_existing = Shift(
            userId=washer.id,
            date=tomorrow,
            startTime="12:00",
            endTime="20:00",
            status="confirmed",
            createdBy="admin",
            createdAt=datetime.now().isoformat(),
            updatedAt=datetime.now().isoformat(),
        )
        db_session.add_all([source, target_existing])
        await db_session.commit()
        await db_session.refresh(source)
        await db_session.refresh(target_existing)
        old_target_id = target_existing.id

        response = await async_client.patch(
            f"/api/shifts/{source.id}/move",
            json={"targetUserId": washer.id, "targetDate": tomorrow},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == tomorrow
        assert data["startTime"] == "08:00"
        assert data["endTime"] == "17:00"
        assert data["id"] != source.id
        assert data["id"] != old_target_id
```

- [ ] **Step 2: Запустить новые тесты**

Run: `cd backend && pytest tests/test_shift_move.py -v`
Expected: 5 passed

- [ ] **Step 3: Запустить полный backend-suite**

Run: `cd backend && pytest -q`
Expected: все проходят

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_shift_move.py
git commit -m "test(shifts): add shift move endpoint tests"
```

---

## Task 5: Frontend — `ApiService.moveShift`

**Files:**
- Modify: `lib/services/api_service.dart:1052`

- [ ] **Step 1: Добавить метод после `reopenShift`**

Вставьте после метода `reopenShift` и перед комментарием `// ─── Shift Templates ───────────────────────────────────────────────────────`:

```dart
  Future<Shift?> moveShift(
      int shiftId, int targetUserId, String targetDate) async {
    final body = {
      'targetUserId': targetUserId,
      'targetDate': targetDate,
    };
    final result = await ApiClient.patch('/shifts/$shiftId/move', body: body);
    return result.when(
      success: (data) => Shift.fromMap(data),
      failure: (_) => null,
    );
  }
```

- [ ] **Step 2: Проверить analyze**

Run: `flutter analyze lib/services/api_service.dart`
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat(shifts): add ApiService.moveShift"
```

---

## Task 6: Frontend — виджет `DraggableShiftCell`

**Files:**
- Create: `lib/widgets/shift_schedule/draggable_shift_cell.dart`

- [ ] **Step 1: Создать файл**

```dart
import 'package:flutter/material.dart';

import '../../../app_styles.dart';
import '../../../models/shift.dart';
import '../../../models/user.dart';
import 'shift_cell.dart';

/// Wraps [ShiftCell] with drag & drop affordances.
///
/// When [shift] is not null and [isDraggable] is true, the cell can be dragged.
/// When [isDropTarget] is true, the cell accepts dropped shifts and reports
/// them via [onMove].
class DraggableShiftCell extends StatelessWidget {
  final User washer;
  final DateTime date;
  final Shift? shift;
  final bool canEdit;
  final bool isDraggable;
  final bool isDropTarget;
  final List<Shift> dayShifts;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;
  final ValueChanged<Shift>? onMove;

  const DraggableShiftCell({
    super.key,
    required this.washer,
    required this.date,
    this.shift,
    required this.canEdit,
    this.isDraggable = false,
    this.isDropTarget = false,
    this.dayShifts = const [],
    this.onTap,
    this.onCopy,
    this.onPaste,
    this.onClear,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell = ShiftCell(
      washer: washer,
      date: date,
      shift: shift,
      canEdit: canEdit,
      dayShifts: dayShifts,
      onTap: onTap,
      onCopy: onCopy,
      onPaste: onPaste,
      onClear: onClear,
    );

    if (isDraggable && shift != null) {
      cell = Draggable<Shift>(
        data: shift,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppStyles.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              '${shift!.startTime}–${shift!.endTime}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: cell,
        ),
        child: cell,
      );
    }

    if (isDropTarget) {
      cell = DragTarget<Shift>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => onMove?.call(details.data),
        builder: (context, candidateData, rejectedData) {
          final active = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: AppStyles.primary, width: 2)
                  : null,
            ),
            child: cell,
          );
        },
      );
    }

    return cell;
  }
}
```

- [ ] **Step 2: Проверить analyze**

Run: `flutter analyze lib/widgets/shift_schedule/draggable_shift_cell.dart`
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/shift_schedule/draggable_shift_cell.dart
git commit -m "feat(shifts): add DraggableShiftCell widget"
```

---

## Task 7: Frontend — подключение в экран расписания

**Files:**
- Modify: `lib/screens/shared/shift_schedule_screen.dart:14`, `lib/screens/shared/shift_schedule_screen.dart:526`, `lib/screens/shared/shift_schedule_screen.dart:1166`

- [ ] **Step 1: Импортировать виджет**

Добавьте импорт:

```dart
import '../../widgets/shift_schedule/draggable_shift_cell.dart';
```

после импорта `shift_templates_sheet.dart` (строка 14).

- [ ] **Step 2: Добавить обработчик drop**

Вставьте после `_reopenShiftFromPanel` (примерно строка 532) метод:

```dart
  Future<void> _handleShiftMove(
      Shift moved, User targetWasher, DateTime targetDate) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final targetDateStr = fmt.format(targetDate);

    // No-op drop on the same cell.
    if (moved.userId == targetWasher.id && moved.date == targetDateStr) {
      return;
    }

    final existing = _findShift(targetWasher.id!, targetDate);
    if (existing != null && existing.id != moved.id) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Перезаписать смену?'),
          content: const Text(
              'В целевой ячейке уже есть смена. Продолжить и заменить её?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перезаписать',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await context
        .read<ApiService>()
        .moveShift(moved.id, targetWasher.id!, targetDateStr);
    if (result != null && mounted) {
      _showSnack('Смена перемещена');
      _loadData();
    } else if (mounted) {
      _showSnack('Не удалось переместить смену', isError: true);
    }
  }
```

- [ ] **Step 3: Заменить `ShiftCell` на `DraggableShiftCell` в `_buildTable`**

Найдите блок в `_buildTable`:

```dart
                    ? ShiftCell(
                        washer: w,
                        date: d,
                        shift: shift,
                        canEdit: _canEdit(w),
                        dayShifts: dayShifts,
                        onTap: () => _openEditor(w, d, shift),
                        onCopy: shift != null
                            ? () => _copyShift(shift)
                            : null,
                        onPaste: shift == null && _copiedShift != null
                            ? () => _pasteShift(w, d)
                            : null,
                        onClear: shift != null
                            ? () => _deleteShift(shift)
                            : null,
                      )
```

Замените на:

```dart
                    ? DraggableShiftCell(
                        washer: w,
                        date: d,
                        shift: shift,
                        canEdit: _canEdit(w),
                        isDraggable: _isAdmin && shift != null,
                        isDropTarget: _isAdmin,
                        dayShifts: dayShifts,
                        onTap: () => _openEditor(w, d, shift),
                        onCopy: shift != null
                            ? () => _copyShift(shift)
                            : null,
                        onPaste: shift == null && _copiedShift != null
                            ? () => _pasteShift(w, d)
                            : null,
                        onClear: shift != null
                            ? () => _deleteShift(shift)
                            : null,
                        onMove: (moved) => _handleShiftMove(moved, w, d),
                      )
```

- [ ] **Step 4: Проверить analyze и тесты**

Run:
```bash
flutter analyze lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart lib/services/api_service.dart
flutter test test/screens/shift_schedule_screen_test.dart
```

Expected: `No issues found`, тесты проходят

- [ ] **Step 5: Commit**

```bash
git add lib/screens/shared/shift_schedule_screen.dart lib/widgets/shift_schedule/draggable_shift_cell.dart
git commit -m "feat(shifts): wire drag & drop into schedule screen"
```

---

## Task 8: Frontend — виджет-тесты drag & drop

**Files:**
- Modify: `test/screens/shift_schedule_screen_test.dart`

- [ ] **Step 1: Импортировать новый виджет**

Добавьте:

```dart
import 'package:lanwash/widgets/shift_schedule/draggable_shift_cell.dart';
```

- [ ] **Step 2: Добавить группу тестов**

Вставьте перед закрывающей скобкой `main`:

```dart
  group('DraggableShiftCell', () {
    final washer = User(
      id: 1,
      username: 'ivan',
      displayName: 'Иван',
      passwordHash: '',
      role: UserRole.washer,
      createdAt: DateTime(2026, 6, 15),
    );
    final shift = Shift(
      id: 1,
      userId: 1,
      date: '2026-06-15',
      startTime: '10:00',
      endTime: '18:00',
      status: 'confirmed',
      createdBy: 'admin',
      createdAt: DateTime(2026, 6, 15).toIso8601String(),
      updatedAt: DateTime(2026, 6, 15).toIso8601String(),
    );

    testWidgets('filled cell renders Draggable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: shift,
              canEdit: true,
              isDraggable: true,
              isDropTarget: true,
            ),
          ),
        ),
      );
      expect(find.byType(Draggable<Shift>), findsOneWidget);
    });

    testWidgets('empty cell renders DragTarget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 16),
              shift: null,
              canEdit: true,
              isDropTarget: true,
            ),
          ),
        ),
      );
      expect(find.byType(DragTarget<Shift>), findsOneWidget);
    });

    testWidgets('drop target calls onMove with dropped shift', (tester) async {
      Shift? moved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DraggableShiftCell(
                  washer: washer,
                  date: DateTime(2026, 6, 15),
                  shift: shift,
                  canEdit: true,
                  isDraggable: true,
                  isDropTarget: true,
                ),
                DraggableShiftCell(
                  washer: washer,
                  date: DateTime(2026, 6, 16),
                  shift: null,
                  canEdit: true,
                  isDropTarget: true,
                  onMove: (s) => moved = s,
                ),
              ],
            ),
          ),
        ),
      );

      final source = find.text('10:00–18:00').first;
      final targetCenter = tester.getCenter(find.byIcon(Icons.add).first);
      final sourceCenter = tester.getCenter(source);
      final offset = targetCenter - sourceCenter;

      await tester.drag(source, offset);
      await tester.pumpAndSettle();

      expect(moved, isNotNull);
      expect(moved!.id, shift.id);
    });
  });
```

- [ ] **Step 3: Запустить виджет-тесты**

Run: `flutter test test/screens/shift_schedule_screen_test.dart`
Expected: все тесты проходят

- [ ] **Step 4: Запустить полный Flutter test suite**

Run: `flutter test`
Expected: все проходят

- [ ] **Step 5: Commit**

```bash
git add test/screens/shift_schedule_screen_test.dart
git commit -m "test(shifts): add drag & drop widget tests"
```

---

## Task 9: Финальная верификация

- [ ] **Step 1: Backend suite**

Run: `cd backend && pytest -q`
Expected: `231 passed, 1 skipped` (или аналогично, без новых падений)

- [ ] **Step 2: Frontend suite**

Run:
```bash
flutter test
flutter analyze
```
Expected: `All tests passed`, `No issues found`

- [ ] **Step 3: Git summary**

Run: `git log --oneline -10`
Expected: в истории коммиты этой фазы

- [ ] **Step 4: Report**

Сообщить пользователю:
"Drag & drop для смен реализован. Backend: `PATCH /api/shifts/{id}/move`, 5 тестов. Frontend: `DraggableShiftCell`, подтверждение перезаписи, виджет-тесты. Push не выполнялся."

---

## Self-Review Checklist

1. **Spec coverage:**
   - Admin drag & drop → Task 7.
   - `PATCH /api/shifts/{shift_id}/move` → Task 3.
   - `targetUserId` + `targetDate` request → Tasks 1–2.
   - Overwrite target cell → Task 2 + Task 7 (frontend confirmation).
   - Backend tests → Task 4.
   - Frontend tests → Task 8.
2. **Placeholder scan:** нет `TBD`, `TODO`, непрописанных шагов.
3. **Type consistency:** `ShiftMoveRequest.targetUserId`/`targetDate`, `ApiService.moveShift` параметры, `_handleShiftMove` сигнатуры согласованы.
