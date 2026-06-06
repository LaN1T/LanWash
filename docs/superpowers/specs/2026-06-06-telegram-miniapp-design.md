# LanWash Telegram Mini App — Design Specification

**Date:** 2026-06-06
**Scope:** Telegram Bot + Mini App для клиентов и мойщиков
**Approach:** B (Полноценный клиентский flow)

---

## 1. Overview

Создание Telegram-бота `@lanwash_bot` с встроенным Mini App, дублирующим мобильную версию LanWash. Mini App позволяет клиентам записываться на мойку и управлять записями, а мойщикам — просматривать назначенные записи и менять их статус.

**Ключевой принцип:** единая кодовая база backend, единая PostgreSQL БД, единая бизнес-логика. Изменения через Mini App мгновенно видны в Flutter-приложении и наоборот.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Telegram Cloud                         │
│  ┌──────────────┐          ┌──────────────────────────────┐  │
│  │ @lanwash_bot │◄────────►│    Telegram Mini App         │  │
│  │  (aiogram)   │  WebApp  │    React + Vite + TS         │  │
│  └──────────────┘          └──────────────────────────────┘  │
│         │                                                    │
│         │ Webhook / Long Polling                             │
└─────────┼────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────┐
│                      Your Server                             │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │   FastAPI API           │  │   Bot Service            │  │
│  │   uvicorn :8000         │  │   python -m bot.main     │  │
│  │                         │  │   :8001 / polling        │  │
│  │  /api/auth/telegram     │  │                          │  │
│  │  /api/appointments/*    │  │  - /start handler        │  │
│  │  /api/services/*        │  │  - notification sender   │  │
│  │  ...existing endpoints  │  │  - WebApp menu button    │  │
│  └───────────┬─────────────┘  └────────────┬─────────────┘  │
│              │                              │               │
│              └────────────┬─────────────────┘               │
│                           │                                  │
│              ┌────────────▼─────────────┐                   │
│              │   PostgreSQL (test DB)    │                   │
│              │   Users, Appointments...  │                   │
│              └───────────────────────────┘                   │
│              ┌────────────┬─────────────┐                   │
│              │   Redis    │  (JWT       │                   │
│              │   blacklist│   pub/sub)  │                   │
│              └────────────┴─────────────┘                   │
└──────────────────────────────────────────────────────────────┘
```

**Потоки данных:**
- **Mini App ↔ FastAPI**: REST + JWT. Авторизация через Telegram `initData`.
- **Bot → FastAPI**: внутренний HTTP-клиент или прямое обращение к БД (одни модели SQLAlchemy).
- **FastAPI → Bot**: через таблицу `notification_queue` (бот поллит каждые 30 сек).

---

## 3. Authorization Flow

1. Пользователь открывает Mini App из Telegram.
2. `window.Telegram.WebApp.initData` содержит подписанные данные (user id, first_name, username, photo_url).
3. React отправляет `POST /api/auth/telegram` с `initData`.
4. FastAPI проверяет HMAC-SHA256 подпись (через Bot Token).
5. Ищем/создаём пользователя:
   - Если `telegram_id` уже привязан → возвращаем существующего.
   - Если нет → создаём нового клиента с данными из Telegram.
6. Выдаём JWT (как для Flutter).
7. React хранит JWT в `localStorage`, все запросы с `Authorization: Bearer`.

**Для мойщиков:** мойщик вводит свой существующий `username` + `password` при первом входе → FastAPI привязывает `telegram_id` к существующему аккаунту → дальше вход по Telegram.

**Изменения в БД:** добавить `telegram_id: Optional[str]` (уникальный) в таблицу `User`. Alembic миграция.

---

## 4. Mini App Structure (React)

```
telegram-miniapp/
├── index.html
├── vite.config.ts
├── package.json
└── src/
    ├── main.tsx
    ├── App.tsx              # Роутинг + ролевая логика
    ├── index.css            # Telegram theme vars
    ├── components/
    │   ├── Layout.tsx       # Базовый layout
    │   ├── BottomNav.tsx    # Навигация (клиент/мойщик)
    │   ├── BookingWizard/
    │   │   ├── Step1CarWash.tsx    # Авто + тип мойки + допы
    │   │   ├── Step2DateTime.tsx   # Календарь + слоты
    │   │   └── Step3Confirm.tsx    # Подтверждение
    │   ├── AppointmentCard.tsx
    │   ├── WeekCalendar.tsx        # Для мойщика
    │   ├── PromoCard.tsx
    │   └── ServiceList.tsx
    ├── pages/
    │   ├── client/
    │   │   ├── HomePage.tsx
    │   │   ├── BookingPage.tsx
    │   │   ├── MyBookingsPage.tsx
    │   │   ├── ProfilePage.tsx
    │   │   └── FavoritesPage.tsx
    │   ├── washer/
    │   │   ├── WasherHomePage.tsx
    │   │   ├── WasherNotesPage.tsx
    │   │   └── WasherProfilePage.tsx
    │   └── shared/
    │       └── SplashPage.tsx
    ├── hooks/
    │   ├── useTelegram.ts   # Доступ к Telegram WebApp SDK
    │   ├── useApi.ts        # HTTP с JWT
    │   └── useAuth.ts
    ├── services/
    │   ├── api.ts
    │   ├── auth.ts
    │   └── appointments.ts
    ├── stores/              # Zustand
    │   ├── authStore.ts
    │   └── appStore.ts
    └── types/
        └── telegram.d.ts
```

**UI:** `@telegram-apps/sdk-react` для доступа к SDK + кастомные компоненты под Telegram viewport (safe area, theme colors, haptic feedback).

---

## 5. API Changes

### New Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/auth/telegram` | Авторизация через `initData`. Проверка подписи + создание/поиск юзера + JWT. |
| `POST` | `/api/auth/link-telegram` | Привязка `telegram_id` к существующему аккаунту (для мойщиков). |

### Modified Endpoints

| Method | Path | Change |
|--------|------|--------|
| `PUT` | `/api/appointments/{id}` | При смене `status` на `in_progress` или `completed`, если у клиента привязан `telegram_id` → добавляется запись в `notification_queue`. |

### DB Changes

- `User.telegram_id: Optional[str], unique=True, nullable=True`
- Новая таблица `notification_queue`:
  - `id: int, PK`
  - `telegram_id: str`
  - `message: str`
  - `created_at: datetime`
  - `sent_at: Optional[datetime]`

---

## 6. Bot — Commands & Notifications

### Commands

| Command | Action |
|---------|--------|
| `/start` | Приветствие + кнопка "🚗 Открыть LanWash" (WebApp) |

### Notifications

| Event | Recipient | Message |
|-------|-----------|---------|
| New appointment assigned | Washer | "🔔 Новая запись: 14:00, Toyota Camry, Комплексная мойка" |
| Appointment cancelled | Washer | "❌ Запись на 14:00 отменена" |
| Status → in_progress | Client | "🚗 Ваша мойка началась! Toyota Camry, бокс 1" |
| Status → completed | Client | "✅ Мойка завершена! Toyota Camry. Ждём вас снова 🚿" |
| Reminder (-1 hour) | Client | "⏰ Напоминание: мойка через час (14:00)" |
| Appointment edited by admin | Client | "✏️ Ваша запись изменена. Новое время: 15:00" |

**Mechanism:** FastAPI writes to `notification_queue` → bot polls every 30 sec → sends via `aiogram`.

---

## 7. Deployment & Dev Environment

### Dev (local)

```bash
# Terminal 1 — API
cd backend && uvicorn main:app --reload --port 8000

# Terminal 2 — Bot
cd backend && python -m bot.main

# Terminal 3 — Mini App
cd telegram-miniapp && npm run dev  # localhost:5173
```

### Test PostgreSQL DB

- Create DB `lanwash_test` (or use `lanwash_dev`).
- `.env` with `DATABASE_URL=postgresql+asyncpg://.../lanwash_test`.
- Apply Alembic migrations.

### Mini App in Telegram

- In [@BotFather](https://t.me/BotFather) → `/mybots` → @lanwash_bot → Bot Settings → Menu Button → Configure menu button → Web App → set URL.
- For dev use [ngrok](https://ngrok.com/) or tunnel.

---

## 8. Out of Scope (v1)

- Admin panel in Mini App (admins use Flutter/web).
- Payments inside Telegram.
- Avatar uploads.
- Grafana / reports.
- Consumables management.
- Push notifications in Flutter from TG events (not needed, shared DB).

---

## 9. Success Criteria

- [ ] Client can book a wash via Mini App.
- [ ] Client sees their appointments and can cancel them.
- [ ] Client receives notifications when washer changes status.
- [ ] Washer can view assigned appointments in weekly calendar.
- [ ] Washer can mark appointment as in_progress / completed.
- [ ] Booking in Mini App is instantly visible in Flutter app.
- [ ] Booking in Flutter is instantly visible in Mini App.
