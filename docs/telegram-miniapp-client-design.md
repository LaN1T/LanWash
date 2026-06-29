# Telegram Mini App: полный клиентский дубликат + единый вход

**Дата:** 2026-06-29  
**Статус:** одобрено, готово к планированию  
**Scope:** только клиентская роль (`client`) в Telegram Mini App. Админка и кабинет мойщика — вне scope.

## 1. Цель

Сделать Telegram Mini App полноценным клиентским дубликатом Flutter-приложения, чтобы пользователь мог:

- Открыть Mini App из Telegram-бота и получить тот же функционал, что и в приложении.
- Войти в свой существующий аккаунт LanWash по логину/паролю прямо внутри Telegram.
- Автоматически входить по Telegram после первой привязки.

## 2. Что НЕ входит

- Административная панель.
- Кабинет мойщика.
- Flutter web-обёртка в Telegram WebView.
- Настоящая платёжная интеграция (оставляем демо-оплату, как в приложении).

## 3. Единый вход (Unified Login)

### 3.1. Принципы

- Идентификация в Telegram происходит только по `telegram_id` из верифицированного `initData`.
- `telegram_id` не принимается от клиента напрямую — только из `initData`.
- Fallback по Telegram username убран.
- Автоматическое создание "пустого" пользователя `tg_<id>` убрано.

### 3.2. Сценарии

1. **Автовход (Telegram уже привязан)**
   - Mini App отправляет `initData` на `POST /api/auth/telegram`.
   - Backend находит пользователя по `telegramId` → возвращает JWT-пару.

2. **Первый вход в Telegram, но аккаунт на сайте уже есть**
   - `POST /api/auth/telegram` возвращает `409 telegram_id_not_linked`.
   - Mini App показывает экран выбора:
     - **Войти по логину/паролю** → `POST /api/auth/telegram/link` с `initData`, `username`, `password`.
     - **Создать новый аккаунт** → `POST /api/auth/telegram/register` с `initData` и регистрационными данными.
   - Backend верифицирует `initData`, привязывает `telegramId`, выдаёт JWT.

3. **Новый пользователь**
   - Выбирает "Создать аккаунт".
   - Вводит `username`, `password`, `displayName`, `phone`, `carModel`, `carNumber`.
   - Backend создаёт пользователя сразу с привязанным `telegramId`.

4. **Привязка через сайт/приложение (опционально)**
   - В профиле сайта/приложения кнопка "Привязать Telegram".
   - Генерируется одноразовый токен, сохраняется в Redis, TTL 15 минут.
   - Пользователь открывает бота с `start_param=<token>`.
   - Backend при получении `/start` с токеном привязывает `telegramId` текущего пользователя.

### 3.3. Backend endpoints

| Endpoint | Назначение |
|----------|------------|
| `POST /api/auth/telegram` | Автовход по `initData`. `200` — успех, `409` — не привязан. |
| `POST /api/auth/telegram/link` | Привязка Telegram к существующему аккаунту. |
| `POST /api/auth/telegram/register` | Регистрация нового пользователя с привязкой Telegram. |
| `POST /api/auth/telegram/unlink` | Отвязка Telegram (требует пароль или свежий `initData`). |
| `POST /api/auth/telegram/link-token` | Генерация токена привязки через сайт (админ/пользователь). |

### 3.4. Безопасность

- `initData` проверяется HMAC-SHA256.
- `auth_date` в `initData` не старше 5 минут.
- Rate limiting по IP и `telegram_id` на auth endpoints.
- Привязка требует валидный пароль.
- Токены хранятся в Telegram `CloudStorage` (fallback `localStorage`).
- Refresh rotation + Redis blacklist уже реализованы.

### 3.5. Мерж данных

Если ранее был создан `tg_<id>` аккаунт и пользователь привязывает Telegram к `lan1t`, backend должен:

- Перенести `appointments`, `cars`, `subscriptions`, `tips`, `reviews` от `tg_<id>` к `lan1t`.
- Удалить `tg_<id>` после успешного переноса.

## 4. Архитектура Mini App

### 4.1. Техстек

- React 18 + TypeScript
- Vite 8
- react-router-dom v6
- Zustand
- Axios
- Telegram WebApp JS API

### 4.2. Роутинг

```
/                          → HomePage
/booking                   → BookingPage
/bookings                  → MyBookingsPage
/bookings/:id              → BookingDetailPage
/services                  → ServicesCatalogPage
/services/:id              → ServiceDetailPage
/favorites                 → FavoritesPage
/promos                    → PromosPage
/promos/:id                → PromoDetailPage
/subscriptions             → SubscriptionsHubPage
/subscriptions/plans       → SubscriptionPlansPage
/subscriptions/:id         → SubscriptionDetailPage
/referrals                 → ReferralPage
/support                   → SupportChatsPage
/support/:id               → SupportChatPage
/reviews                   → ReviewsPage
/cars                      → CarsPage
/profile                   → ProfilePage
/profile/edit              → ProfileEditPage
/auth                      → AuthGatewayPage
```

### 4.3. Нижняя навигация

Три вкладки: **Главная**, **Мои записи**, **Профиль**. Остальное доступно через главную или профиль.

### 4.4. State management

| Store | Ответственность |
|-------|-----------------|
| `authStore` | пользователь, токены, initData, статус входа |
| `appStore` | тема, язык, глобальные уведомления, offline |
| `bookingStore` | пошаговая запись, выбранные услуги, слоты |
| `appointmentsStore` | список записей, детали, фильтры |
| `catalogStore` | услуги, акции, категории, избранное |
| `subscriptionsStore` | абонементы, планы, покупка |
| `supportStore` | чаты, сообщения, WebSocket |
| `carsStore` | автомобили |
| `referralsStore` | реферальная статистика |

### 4.5. Ленивая загрузка

Все feature-страницы загружаются через `React.lazy` + `Suspense`. Каждый модуль — отдельный чанк:

- `booking`
- `subscriptions`
- `support`
- `cars`
- `referrals`

### 4.6. API layer

- `src/services/api.ts` — axios instance с interceptors.
- Access token из `authStore`.
- 401 → retry `/api/auth/refresh` → при неудаче logout.
- API-группы: `authApi`, `appointmentsApi`, `servicesApi`, `subscriptionsApi`, `supportApi`, `carsApi`, `referralsApi`, `reviewsApi`.

### 4.7. Telegram hooks

- `useTelegram()` — инициализация WebApp, `initData`, `themeParams`, viewport.
- `useTelegramCloudStorage()` — обёртка над `CloudStorage` с fallback на `localStorage`.
- `useAuthGuard()` — логика автовхода / показа AuthGatewayPage.

## 5. Фичи и порядок переноса

### Этап 1 — Доработка существующего

1. **Auth refactor**
   - Убрать auto-create.
   - Добавить экраны логина/регистрации в Mini App.
   - Перевести хранение токенов на `CloudStorage`.

2. **Home**
   - Актуальные промо и каталог.
   - Кэширование, pull-to-refresh.

3. **Booking wizard**
   - Несколько автомобилей.
   - Абонементы в расчёте цены.
   - Промо-коды.
   - Busy slots.

4. **My bookings**
   - Детали записи.
   - Отмена с причиной, опоздание.
   - WebSocket-обновления.

5. **Profile**
   - Редактирование, аватар, смена пароля.
   - Привязка/отвязка Telegram.
   - Статистика, выход.

### Этап 2 — Новые модули

6. **Services + Favorites**
7. **Promos + Promo detail**
8. **Subscriptions hub + plans + purchase**
9. **Referrals**
10. **Support chat**
11. **Cars management**
12. **Reviews**

### Этап 3 — Полировка

13. **Telegram notifications** вместо FCM.
14. **Offline mode** — кэш + retry queue.
15. **Themes + localization** через Telegram theme params.
16. **Tests** — unit + интеграционные.

## 6. Backend-изменения

### Auth

- Изменить `POST /api/auth/telegram`: убрать auto-create, возвращать `409` если не привязан.
- Добавить `POST /api/auth/telegram/link`.
- Добавить `POST /api/auth/telegram/register`.
- Добавить `POST /api/auth/telegram/unlink`.
- Добавить `POST /api/auth/telegram/link-token` (опционально).
- Добавить `telegramLinked: bool` в `UserResponse`.

### InitData verification

- Проверка `auth_date` не старше 5 минут.
- Убрать fallback по username.
- `telegram_id` только из verified `initData`.

### Notifications

- Использовать `notification_queue` для отправки сообщений в Telegram при изменении статуса записи.
- Добавить настройки уведомлений в профиль.

### Data merge

- При привязке переносить данные от `tg_<id>` к целевому аккаунту.

## 7. Реалтайм, уведомления, офлайн

### WebSocket

- `/ws/appointments` — обновления записей.
- `/ws/support/chats/{id}` — поддержка.
- Fallback на polling каждые 10 сек при разрыве.

### Telegram notifications

- Триггеры: создана запись, изменён статус, назначен мойщик, напоминание.
- Отправка через `notification_queue` + worker.

### Offline

- Кэш записей и каталога в `CloudStorage`.
- Очередь мутаций: при восстановлении сети отправлять накопленные `POST/PUT/DELETE`.
- Индикатор offline в шапке.

## 8. Безопасность и производительность

| Аспект | Решение |
|--------|---------|
| Авторизация | `initData` только для auth endpoints, токены в `CloudStorage` |
| Токены | Short-lived access, refresh rotation, Redis blacklist |
| Привязка | Требует пароль, `telegram_id` из verified `initData` |
| Rate limiting | По IP и `telegram_id` |
| CSRF / XSS | `SameSite=Lax`, CSP, no inline scripts |
| Загрузка | Lazy chunks, кэш каталога, skeleton screens |
| Реалтайм | WebSocket + fallback polling |
| Офлайн | Кэш + очередь мутаций |

## 9. Открытые вопросы

1. Нужна ли привязка через сайт (link-token) в первой версии или достаточно входа по логину/паролю в Mini App?
2. Какой минимальный набор полей при регистрации через Telegram? Все поля Flutter-формы или урезанный набор с возможностью дозаполнить в профиле?
3. Нужен ли в Mini App полноценный offline-режим с sync-очередью или достаточно кэша + retry?
