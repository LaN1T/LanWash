# WebSocket для записей + редизайн меню мойщика

## Цель

- Записи обновляются в реальном времени во всех клиентах (iOS, Android, macOS, web) без ручного pull-to-refresh.
- Мойщик получает доступ к записи на мойку, истории, чаевым, расписанию, доступности, поддержке и настройкам через боковое меню.
- Убрать кнопку «Выйти» из бокового меню мойщика — logout только через **Профиль → Настройки**.

## Вне скоупа (сейчас не делаем)

- WebSocket для чаевых, заметок, расписания, уведомлений — только записи.
- Удаление FCM: он остаётся fallback для фона и веб-пушей.
- Горизонтальное масштабирование WebSocket через Redis — пока один инстанс.

## Архитектура

### Backend

#### Новый endpoint

```
WebSocket /ws/appointments
```

#### Протокол

1. Клиент открывает сокет.
2. Первым сообщением отправляет JWT:
   ```json
   {"type": "auth", "token": "<jwt>"}
   ```
3. Сервер валидирует токен, сохраняет связку `user_id + role -> WebSocket`.
4. Сервер шлёт `ping` каждые 30 сек, клиент отвечает `pong`.

#### Сообщение от сервера

```json
{
  "type": "appointment_updated",
  "event": "created|updated|assigned|cancelled|deleted|qr_scanned|late",
  "appointment": { /* полная модель Appointment */ }
}
```

#### Кому отправлять

- `created`: владельцу, назначенному мойщику (если авто-назначение), всем админам.
- `updated/assigned/cancelled/deleted/qr_scanned/late`: владельцу, назначенным мойщикам, всем админам.

#### Где вставлять broadcast

`backend/app/routers/appointments.py` сразу после успешных операций:

- `POST /api/appointments/`
- `PUT /api/appointments/{id}`
- `POST /api/appointments/{id}/assign-washer`
- `POST /api/appointments/scan-qr`
- `POST /api/appointments/{id}/late`
- `POST /api/appointments/{id}/cancel-reason`
- `DELETE /api/appointments/{id}`

#### Менеджер подключений

Новый файл `backend/services/appointment_ws_manager.py`:

```python
class AppointmentWebSocketManager:
    async def connect(self, user_id: str, role: str, websocket: WebSocket)
    async def disconnect(self, user_id: str, websocket: WebSocket)
    async def notify(self, appointment: Appointment, event: str)
```

Хранит `Dict[str, List[WebSocket]]` по `user_id`. Рассылка идёт по списку сокетов конкретного пользователя. Админам рассылается через отдельный список ролей (`role == "admin"`) или по общей маппе.

#### Масштабируемость

- До нескольких тысяч одновременных сокетов на одном инстансе — ок.
- При переходе на несколько инстансов добавить Redis pub/sub между воркерами.

### Frontend

#### Новый сервис

`lib/services/appointment_websocket_service.dart`

- Подключается после логина, слушает `AuthProvider`.
- Берёт base URL из `ApiClient`, заменяет `http(s)://` на `ws(s)://`.
- Экспоненциальный reconnect: 1, 2, 4, 8, 16, 30 сек.
- При получении `401/403` на auth закрывает сокет и переводит пользователя на логин.
- При logout закрывает сокет.

#### Обработка событий

- Полученное сообщение содержит полную модель `Appointment`.
- `AppointmentWebSocketService` обновляет локальный стейт `AppointmentProvider`:
  - если запись есть — заменить;
  - если записи нет — добавить в начало соответствующего списка или триггернуть `reloadAppointments(...)`.
- Дополнительно можно эмитить событие в `NotificationService.onAppointmentUpdated`, чтобы `ClientShell`/`WasherShell`/`AdminShell` делали полный reload как fallback.

#### Web

- WebSocket работает в web из коробки.
- Для локальной разработки `ws://localhost:8000`.
- В проде `wss://<host>`.

### UI изменения для мойщика

#### Нижняя навигация

Оставить 2 таба:

- **Записи**
- **Заметки**

Убрать таб **Чаевые**.

#### Боковое меню (`lib/screens/washer/washer_shell.dart`)

```
[Шапка: имя + роль]

ЗАПИСИ
  ├─ Мои записи          → главная вкладка
  ├─ История             → WasherHistoryScreen
  └─ Записаться на мойку → BookingWizardScreen

РАБОТА
  ├─ Расписание          → ShiftScheduleScreen
  ├─ Доступность         → WasherAvailabilityScreen
  ├─ Статистика          → StatisticsScreen
  └─ Чаевые              → WasherTipsScreen

ПОДДЕРЖКА
  └─ Написать в поддержку → SupportChatsScreen

АККАУНТ
  ├─ Профиль             → ProfileScreen
  └─ Настройки           → SettingsScreen
```

#### Logout

- Убрать «Выйти» из бокового меню мойщика.
- Добавить в `ProfileScreen` AppBar иконку **«Настройки»**, открывающую `SettingsScreen`.
- Logout остаётся в `SettingsScreen`.

#### Запись на мойку мойщиком

- Переиспользовать `BookingWizardScreen`.
- Владельцем записи будет `auth.username` (мойщик сам себя записывает).
- После успешного создания возвращаться на главную вкладку **«Записи»** и обновлять список.

#### История мойщика

- Вынести `_buildHistorySection` из `ProfileScreen` в отдельный `WasherHistoryScreen`.
- Экран показывает завершённые/отменённые записи текущего мойщика.

#### Чаевые

- Вынести `_WasherTipsTab` в `WasherTipsScreen`.
- Открывать из бокового меню.

## Обработка ошибок

- **WebSocket не подключается:** показывать индикатор offline, работать через pull-to-refresh и FCM.
- **Auth failed:** закрыть сокет, разлогинить пользователя.
- **Reconnect:** максимальный интервал 30 сек, не пытаться бесконечно быстро.
- **Broadcast failed:** ловить исключения, не ломать HTTP-ответ.

## Тестирование

- Backend unit test: подключение к `/ws/appointments`, auth, broadcast после создания записи.
- Frontend widget test: drawer мойщика содержит новые пункты, таб «Чаевые» отсутствует.
- Интеграционный тест: создать запись в web → увидеть обновление в приложении без ручного refresh.

## Файлы для изменений

### Backend

- `backend/app/main.py` — регистрация WebSocket endpoint.
- `backend/services/appointment_ws_manager.py` — новый менеджер.
- `backend/app/routers/appointments.py` — broadcast после мутаций.
- `backend/tests/...` — новые тесты.

### Frontend

- `lib/services/appointment_websocket_service.dart` — новый сервис.
- `lib/providers/appointment_provider.dart` — обновление по событию.
- `lib/services/notification_service.dart` — дополнительная эмиссия событий.
- `lib/screens/washer/washer_shell.dart` — новое меню и нижний бар.
- `lib/screens/washer/washer_tips_screen.dart` — новый экран чаевых.
- `lib/screens/washer/washer_history_screen.dart` — новый экран истории.
- `lib/screens/shared/profile_screen.dart` — иконка настроек.
- `lib/screens/shared/settings_screen.dart` — logout (уже есть для клиента).

## Последующие шаги

После утверждения спецификации — написать implementation plan через `writing-plans`.
