# Drag & Drop для расписания смен — Design Spec

## Goal
Позволить администратору мышью перетаскивать смену на другой день тому же мойщику или другому мойщику в ту же/другую дату.

## Scope
- Только администратор может перетаскивать.
- Перетаскивание доступно в таблице недельного расписания (`ShiftScheduleScreen`).
- После drop вызывается backend endpoint, который перемещает смену.
- Если в целевой ячейке уже есть смена — перезаписываем (как при ручном создании).

## Backend

### New endpoint
`PATCH /api/shifts/{shift_id}/move`

Request body:
```json
{
  "targetUserId": 2,
  "targetDate": "2026-06-18"
}
```

Response: `ShiftResponse`

### Behavior
1. Найти существующую смену по `shift_id`.
2. Проверить, что целевой пользователь существует.
3. Удалить старую смену.
4. Создать новую смену с `userId=targetUserId`, `date=targetDate`, теми же `startTime`, `endTime`, `status`, `createdBy`.
5. Вернуть новую смену.

### Authorization
Только `admin`.

## Frontend

### Model
Добавить в `ApiService`:
```dart
Future<Shift?> moveShift(int shiftId, int targetUserId, String targetDate)
```

### UI
- Оборачиваем существующий `ShiftCell` с данными в `Draggable<Shift>`.
- Оборачиваем каждую пустую/заполненную ячейку в `DragTarget<Shift>`.
- При `onAccept` вызываем `_moveShift(shift, targetUser, targetDate)` и перезагружаем неделю.
- Визуальный feedback:
  - `Draggable` — feedback виджет с краткой информацией о смене.
  - `DragTarget` — подсветка ячейки при наведении.

### Conflict handling
- Если целевая ячейка занята — спрашиваем подтверждение (`AlertDialog`) перед move.
- Если move не удался — показываем `SnackBar` с ошибкой.

## Testing

### Backend
- `test_shift_move.py`:
  - Admin moves shift to another date.
  - Admin moves shift to another washer.
  - Non-admin cannot move.
  - Target user not found returns 404.
  - Moving overwrites existing shift at target (userId, date).

### Frontend
- `test/screens/shift_schedule_screen_test.dart`:
  - `ShiftCell` is draggable.
  - Drag target accepts a shift.
  - Move callback is fired with correct userId/date.

## Files to touch
- `backend/routers/shifts.py`
- `backend/services/shifts_service.py`
- `backend/models.py`
- `backend/tests/test_shift_move.py`
- `lib/services/api_service.dart`
- `lib/screens/shared/shift_schedule_screen.dart`
- `test/screens/shift_schedule_screen_test.dart`
