# LanWash — система управления автомойкой

LanWash — клиент-серверная система для автоматизации записи на автомойку. Клиенты выбирают услуги и время через мобильное приложение или Telegram Mini App. Администратор управляет записями, каталогом и аналитикой, а мойщики получают назначенные задачи в реальном времени.

Поддерживаемые платформы: iOS, Android, macOS, Windows, Linux, Web.

---

## Возможности

### Клиент

- Регистрация и вход в аккаунт.
- Запись на мойку через трёхшаговый визард: услуги и данные автомобиля, дата и время, подтверждение.
- Запись по акции напрямую из раздела акций или избранного.
- Просмотр своих записей с актуальной ценой. Если администратор изменил состав услуг, отображается новая цена и зачёркнутая старая.
- Редактирование профиля: имя, телефон, марка и номер автомобиля, пароль.
- Добавление услуг и акций в избранное.
- Просмотр уведомлений и заметок от администратора.
- Push-уведомления о назначении мойщика, изменении статуса записи и заметках.
- Реферальная программа: ввод реферального кода при регистрации.
- Подписки: использование пакетов и периодических подписок на мойку, назначенных администратором.
- Оплата чаевых мойщикам.
- Оставление отзывов с возможностью модерации администратором.

### Мойщик

- Главный экран «Мой день» с суммарной информацией, календарем недели и списком записей выбранного дня.
- Просмотр назначенных записей с детальной информацией: клиент, автомобиль, тип мойки, дополнительные услуги, цена, заметки.
- Просмотр и создание заметок.
- Обновление статуса записи.
- Сканирование QR-кода для быстрого перехода к записи.
- Просмотр расписания смен и заявок.
- Просмотр статистики по чаевым.
- Pull-to-refresh для обновления данных.
- Push-уведомления о новых назначениях.

### Администратор

- Просмотр всех записей всех клиентов.
- Создание, редактирование и удаление записей.
- Назначение мойщиков на записи, до трёх мойщиков на одну запись.
- Управление каталогом услуг, типов мойки, акций и расходников.
- Управление сменами мойщиков, шаблонами смен и их доступностью.
- Просмотр и очистка журнала действий с фильтрацией по пользователю.
- Отправка заметок клиентам и мойщикам.
- Просмотр аналитических отчётов: средний чек по моделям автомобилей, популярные дополнительные услуги, расход расходников.
- Модерация отзывов клиентов.

### Системные возможности

- REST API на FastAPI с автоматической документацией Swagger UI.
- WebSocket для обновлений записей и чата поддержки в реальном времени.
- Офлайн-режим Flutter-приложения с локальной базой Drift и синхронизацией при появлении сети.
- Push-уведомления через Firebase Cloud Messaging.
- Ролевая модель доступа: client, washer, admin.
- Журнал действий администратора и мойщиков.
- Мониторинг и метрики через Prometheus и Grafana.
- Telegram-бот и Mini App для записи и уведомлений.
- AI-черновики ответов в чате поддержки через Groq или Gemini.

---

## Типы мойки

| Тип | Цена | Время | Включено автоматически |
|---|---|---|---|
| Экспресс | 500 ₽ | 15 мин | — |
| Базовая | 800 ₽ | 30 мин | — |
| Комплексная | 1 500 ₽ | 1 ч | Пылесосная уборка |
| Премиум | 3 000 ₽ | 1 ч 30 мин | Пылесосная уборка, Чернение шин, Ароматизация |

Автоматически включённые услуги не прибавляются к цене и не учитываются повторно во времени.

---

## Дополнительные услуги

| Услуга | Цена | Время |
|---|---|---|
| Чернение шин | 300 ₽ | 15 мин |
| Ароматизация | 300 ₽ | 15 мин |
| Пылесосная уборка | 500 ₽ | 25 мин |
| Полировка стёкол | 500 ₽ | 20 мин |
| Антидождь | 600 ₽ | 25 мин |
| Обработка арок | 600 ₽ | 20 мин |
| Удаление битума | 700 ₽ | 30 мин |
| Озонирование | 1 000 ₽ | 1 ч |
| Нанесение воска | 1 200 ₽ | 45 мин |
| Мойка двигателя | 1 500 ₽ | 1 ч |
| Нанесение силанта | 2 000 ₽ | 1 ч 30 мин |
| Нанесение тефлона | 3 000 ₽ | 2 ч |
| Химчистка салона | 3 500 ₽ | 3 ч |
| Химчистка кожи | 5 000 ₽ | 4 ч |
| Детейлинг кузова | 8 000 ₽ | 6 ч |
| Керамическое покрытие | 15 000 ₽ | 8 ч |

---

## Акции

| Название | Состав | Цена | Ограничение |
|---|---|---|---|
| Акция недели: комплекс + ароматизация | Комплексная мойка + Ароматизация | 1 600 ₽ | — |
| Весенняя акция: мойка + воск | Базовая мойка + Нанесение воска | 1 500 ₽ | — |
| Выходной пакет: комплексная мойка −20% | Комплексная мойка со скидкой | 1 200 ₽ | Только сб/вс |
| Пакет для внедорожников | Комплексная мойка + Чернение шин + Обработка арок | 2 000 ₽ | — |

Расчёт цены при записи по акции:

- База равна акционной цене. Для процентных акций: `basePrice * (100 - скидка_процентов) / 100`.
- К базе прибавляются только дополнительные услуги, выбранные сверх акции.
- Услуги, входящие в акцию, не прибавляются к цене и отображаются как «Задано акцией».

Расчёт времени:

- Берётся базовое время типа мойки.
- К нему прибавляется время только тех дополнительных услуг, которые не входят в тип мойки автоматически.

---

## Подписки

Система поддерживает подписки двух видов:

- **Пакетные** — фиксированное количество моек по фиксированной цене.
- **Периодические** — безлимитный или лимитированный доступ на месяц.

Клиент может приобрести подписку и использовать её при создании записи. Администратор управляет каталогом подписок.

---

## Чаевые

Клиенты могут оставлять чаевые мойщикам. Мойщик видит список чаевых со статусом и статистику по общей сумме, полученным и ожидающим выплатам.

---

## Реферальная программа

При регистрации клиент может указать реферальный код другого пользователя. Система фиксирует связь и позволяет строить реферальную аналитику.

---

## Отзывы

Клиенты оставляют отзывы после завершения записи. Администратор просматривает и модерирует отзывы: одобряет, отклоняет или удаляет.

---

## Визард записи

Трёхшаговый процесс создания записи.

**Шаг 1 — Услуги и данные автомобиля:**

- Выбор типа мойки.
- Выбор дополнительных услуг, отсортированных от дешёвых к дорогим.
- Услуги, входящие в тип мойки, отмечены как «Включено» и недоступны для снятия.
- Услуги, заданные акцией, отмечены как «Задано акцией» и также заблокированы.
- Поля клиента и автомобиля предзаполняются из профиля.
- Поддержка избранных дополнительных услуг.

**Шаг 2 — Дата и время.** Выбор даты с календарным ограничением и временного слота с 09:00 до 22:00. Для акций с ограничением по дням недели доступны только соответствующие даты.

### Логика переноса

Если суммарное время выбранных услуг выходит за 22:00, система отображает слот с предупреждением: запись продолжится на следующий день и закончится к указанному времени. Такой слот можно выбрать, если перенос не превышает восьми часов. При выборе администратор видит итоговое время с пометкой о переносе.

**Шаг 3 — Подтверждение:**

- Итоговая цена с перечёркнутой ценой без акции и суммой экономии.
- Суммарное время с учётом всех услуг.
- Кнопка подтверждения записи.

---

## Система боксов

При создании записи система автоматически назначает свободный бокс на выбранное время. Проверяется занятость каждого бокса, чтобы избежать двойного бронирования. Администратор может изменить назначение вручную при редактировании записи. Каждая запись привязана к конкретному боксу, что позволяет оптимизировать загрузку линии мойки.

---

## Расходники

Каждая дополнительная услуга может быть связана с расходными материалами. При переводе записи в статус «Выполнена» система автоматически списывает расходники из остатков. Администратор управляет каталогом расходников, их единицами измерения и связями с услугами.

---

## Смены и доступность

- **Смены** — администратор создаёт смены для мойщиков, мойщик видит свои смены и может подавать заявки.
- **Шаблоны смен** — повторяющиеся шаблоны для быстрого планирования.
- **Доступность мойщиков** — мойщик указывает, в какие дни и часы доступен для работы.

---

## Уведомления и заметки

Администратор может отправлять текстовые заметки клиентам и мойщикам. Заметки отображаются в приложении и дублируются push-уведомлениями через Firebase Cloud Messaging. Клиенты видят заметки в разделе уведомлений, мойщики — в разделе заметок.

---

## Поддержка и AI

Клиенты и мойщики могут обращаться в поддержку через чат. Администратор видит тикеты и переписку. Для ускорения ответов реализована генерация AI-черновиков через Groq или Gemini по запросу администратора.

---

## Telegram Mini App и бот

- **Telegram-бот** — приветствует пользователя, авторизует через Telegram initData и предоставляет кнопку для открытия Mini App.
- **Telegram Mini App** — React-приложение на Vite, позволяющее записываться на мойку и получать уведомления без установки основного приложения.
- **Очередь уведомлений** — статусные уведомления ставятся в очередь и отправляются ботом независимо от FCM.

> Для запуска Telegram-бота требуется `aiogram`. Убедитесь, что он установлен в окружении бэкенда.

> Некоторые optional-функции (Telegram-бот, AI-черновики) могут требовать дополнительных зависимостей, не включённых в `requirements.txt`. Устанавливайте их вручную при необходимости.

---

## Журнал действий

Все ключевые события фиксируются в журнале:

- Вход и выход из системы, неудачные попытки входа.
- Регистрация пользователей.
- Создание, редактирование, удаление записей.
- Назначение и снятие мойщиков.
- Изменение статуса записи.
- Добавление и удаление из избранного.
- Обновление профиля.
- Действия с услугами, типами мойки, акциями, расходниками, подписками, сменами и отзывами.

Администратор просматривает журнал с фильтрацией по пользователю и может выполнить полную очистку.

---

## Отчёты

Администраторский раздел аналитики включает:

- Средний чек по моделям автомобилей.
- Самые популярные дополнительные услуги.
- Расход расходников за период.

---

## Архитектура

Приложение построено по клиент-серверной схеме. Бэкенд предоставляет REST API и WebSocket, фронтенд на Flutter взаимодействует с ним по HTTP. Данные хранятся в PostgreSQL, аутентификация реализована через JWT, фоновые задачи и кэширование — через Redis.

```
Flutter Client  <--HTTP/WS-->  FastAPI Backend  <--SQLAlchemy-->  PostgreSQL
                                     |                              |
                                     |                        Firebase FCM
                                     |                              |
                                     v                              v
                            Push-уведомления                 Push-токены / очередь
```

---

## Технологический стек

| Компонент | Технология |
|---|---|
| Клиент | Flutter 3.x, Material 3 |
| Язык клиента | Dart |
| Управление состоянием | Provider |
| Локальная БД и офлайн | Drift, SQLCipher |
| HTTP-клиент | http |
| WebSocket | web_socket_channel |
| Локализация | intl (ru) |
| Бэкенд | Python 3.13, FastAPI, Pydantic v2 |
| ORM | SQLAlchemy 2.0 (async) |
| База данных | PostgreSQL 16 |
| Миграции | Alembic |
| Аутентификация | JWT + Argon2 |
| Rate limiting | slowapi |
| Фоновые задачи | ARQ + Redis |
| Push-уведомления | Firebase Cloud Messaging |
| Telegram-бот | aiogram |
| Telegram Mini App | React + Vite |
| Логирование | structlog (JSON в production) |
| Конфигурация | pydantic-settings |
| Метрики | Prometheus |
| Мониторинг | Grafana + Prometheus |
| Error tracking | Sentry |
| Нагрузочное тестирование | Locust |
| Reverse proxy | Nginx |
| Контейнеризация | Docker multi-stage, Docker Compose |

---

## Запуск

### Бэкенд локально

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt
# Создай backend/.env по образцу backend/.env.example

# Development — автоматическое создание таблиц
ENVIRONMENT=development uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production — сначала миграции, потом запуск
ENVIRONMENT=production alembic upgrade head
ENVIRONMENT=production uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Бэкенд через Docker Compose

```bash
cp .env.example .env
# Отредактируй корневой .env
docker compose up --build
```

### Клиент Flutter

```bash
flutter pub get
flutter run
```

Для Android-эмулятора бэкенд доступен по адресу `http://10.0.2.2:8000`. Для iOS-симулятора и десктопа — `http://localhost:8000`.

### Flutter Web

```bash
flutter build web --release
```

Собранные файлы находятся в `build/web/` и могут быть развёрнуты через Nginx или любой статический сервер.

### Landing page

`landing/` содержит статические файлы лендинга. Для локального просмотра:

```bash
cd landing
python3 -m http.server 8080
```

### Telegram Mini App

```bash
cd telegram-miniapp
npm install
npm run build
```

Собранные файлы находятся в `telegram-miniapp/dist/`.

---

## Переменные окружения

### Корневой `.env`

Создай файл `.env` в корне проекта по образцу `.env.example`:

```env
POSTGRES_USER=lanwash_user
POSTGRES_PASSWORD=
POSTGRES_DB=lanwash_db
DATABASE_URL=postgresql+asyncpg://lanwash_user:YOUR_PASSWORD@db:5432/lanwash_db
JWT_SECRET_KEY=your-super-secret-key-min-32-chars
INITIAL_ADMIN_PASSWORD=change_me_to_something_secure
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
GEMINI_API_KEY=
GROQ_API_KEY=
AI_PROVIDER=groq
REDIS_PASSWORD=change_me_to_something_secure
PROMETHEUS_USER=lanwash
PROMETHEUS_PASSWORD=change_me_to_something_secure
PROMETHEUS_API_TOKEN=change_me_to_something_secure
GRAFANA_USER=lanwash_admin
GRAFANA_PASSWORD=change_me_to_something_secure
```

> Для production-запуска бэкенд дополнительно требует `REDIS_URL`, `PROMETHEUS_API_TOKEN`, `APP_CHECK_ENFORCED`, `FIREBASE_APP_ID`, ключи Firebase Admin SDK, `TELEGRAM_BOT_TOKEN`, AI-ключи и `SENTRY_DSN`. В `docker-compose.yml` в backend-контейнер пробрасывается только базовый набор переменных; полную production-конфигурацию нужно настроить отдельно.

> `/metrics` защищён через `HTTPBearer` и ожидает заголовок `Authorization: Bearer <PROMETHEUS_API_TOKEN>`. Конфигурация Prometheus (`prometheus.yml`) должна быть синхронизирована с этим механизмом; текущий пример в репозитории использует `basic_auth`, поэтому перед production-деплоем необходимо привести аутентификацию к одному виду.

### `backend/.env`

Создай файл `backend/.env` по образцу `backend/.env.example`:

```env
ENVIRONMENT=development
DATABASE_URL=sqlite+aiosqlite:///./lanwash.db
JWT_SECRET_KEY=change_me_min_32_chars_use_secrets_token_urlsafe
ACCESS_TOKEN_EXPIRE_MINUTES=60
INITIAL_ADMIN_PASSWORD=change_me_to_something_secure
REDIS_PASSWORD=change_me_to_something_secure
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
DEBUG=false
GRAFANA_USER=lanwash_admin
GRAFANA_PASSWORD=change_me_to_something_secure

# Firebase Admin SDK
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
FIREBASE_CLIENT_ID=
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=

# Optional
# FCM_ENCRYPTION_KEY=
APP_CHECK_ENFORCED=false
# SENTRY_DSN=

# AI providers
AI_PROVIDER=groq
GROQ_API_KEY=
GEMINI_API_KEY=
```

**Важно:** никогда не коммить `.env`, `firebase.json` и файлы ключей Firebase в репозиторий.

---

## Аутентификация и авторизация

Приложение использует ролевую модель с тремя уровнями доступа:

- **client** — создание и просмотр собственных записей, редактирование профиля.
- **washer** — просмотр назначенных записей, обновление статуса, работа с заметками и расписанием.
- **admin** — полный доступ к записям, каталогу, журналу, отчётам и управлению пользователями.

Пароли хешируются алгоритмом Argon2. JWT access-токены выдаются на час, refresh-токены передаются в httpOnly cookie. При первом запуске бэкенда создаётся администраторский аккаунт, если задан пароль в `INITIAL_ADMIN_PASSWORD`.

---

## API Endpoints

Бэкенд предоставляет REST API с автоматической документацией Swagger UI: `http://localhost:8000/docs` (при запущенном сервере в development-режиме).

### Основные группы эндпоинтов

| Префикс | Описание | Доступ |
|---|---|---|
| `/api/auth` | Регистрация, логин, профиль, FCM-токены, Telegram | public |
| `/api/appointments` | CRUD записей, назначение мойщиков, статистика | authenticated |
| `/api/services` | Услуги, категории, акции, избранное | authenticated |
| `/api/wash-types` | Типы мойки | authenticated |
| `/api/consumables` | Расходники и связи с услугами | admin/washer |
| `/api/notes` | Заметки клиентам и мойщикам | authenticated |
| `/api/shifts` | Управление сменами мойщиков | authenticated |
| `/api/shift-templates` | Шаблоны смен | admin/washer |
| `/api/washers` | Доступность мойщиков | admin/washer |
| `/api/subscriptions` | Подписки | authenticated |
| `/api/tips` | Чаевые | authenticated |
| `/api/referrals` | Реферальные коды | authenticated |
| `/api/reviews` | Отзывы | authenticated |
| `/api/support` | Чат поддержки и AI-черновики | authenticated |
| `/api/admin` | Административные операции и напоминания | admin |
| `/api/cars` | Справочник автомобилей | authenticated |
| `/api/logs` | Журнал действий | admin (POST public) |
| `/api/reports` | Аналитические отчёты | admin |
| `/health` | Health check | public |
| `/metrics` | Prometheus метрики | system / Prometheus token |

### Пагинация записей

`GET /api/appointments/?page=1` возвращает записи постранично по дням. Заголовки ответа:

- `X-Total-Pages` — общее количество страниц (дней).
- `X-Current-Page` — текущая страница.
- `X-Current-Date` — дата текущей страницы.
- `X-Unique-Dates` — JSON-массив всех дат.

---

## Мониторинг

### Prometheus + Grafana

Система собирает метрики бэкенда через Prometheus и визуализирует их в Grafana.

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

Запуск:

```bash
docker compose up -d prometheus grafana
```

**Метрики:**

- RPS — количество запросов в секунду.
- Latency — p50, p95, p99.
- HTTP-коды ответов.
- Бизнес-метрики: количество записей, пользователей.

### Health check

`GET /health` возвращает uptime, версию и окружение:

```json
{
  "status": "healthy",
  "service": "LanWash API",
  "version": "1.0.0",
  "environment": "production",
  "uptime_seconds": 3600
}
```

### Sentry

Для включения error tracking задай `SENTRY_DSN` в `backend/.env`. Sentry инициализируется при наличии `SENTRY_DSN` в любом окружении.

---

## Безопасность

Применённые меры:

- JWT с минимальной длиной ключа 32 символа.
- Пароли хешируются Argon2.
- Rate limiting (slowapi) на эндпоинты.
- CORS настраивается из переменной окружения `ALLOWED_ORIGINS`.
- Security headers middleware.
- Pydantic-валидация входных данных.
- Debug-эндпоинты доступны только при `DEBUG=true`.
- Конфигурация валидируется pydantic-settings при старте.
- Структурированное логирование (structlog).
- Firebase App Check ([инструкция](docs/firebase-hardening.md)).

---

## Миграции базы данных

Проект использует Alembic для управления схемой БД.

```bash
cd backend

# Создать новую миграцию
alembic revision --autogenerate -m "описание изменений"

# Применить все миграции
alembic upgrade head

# Откатить последнюю миграцию
alembic downgrade -1

# Текущая версия
alembic current
```

В production миграции применяются отдельно перед запуском приложения. В development и testing таблицы создаются автоматически через `Base.metadata.create_all`.

---

## Тестирование

### Backend

```bash
cd backend
python -m pytest tests/ -v
```

Тесты запускаются на SQLite in-memory с async HTTP-клиентом (httpx + ASGI).

### Flutter

```bash
flutter test
```

### Нагрузочное тестирование (Locust)

Для запуска Locust установи зависимости из `backend/requirements-test.txt`:

```bash
cd backend
pip install -r requirements-test.txt
```

Все команды `make` выполняются из корня проекта.

```bash
# 1. Запустить тестовое окружение
make test-full

# 2. В отдельном терминале — бэкенд
make test-backend

# 3. В отдельном терминале — Locust
make test-run
```

Открой `http://localhost:8089`, задай количество пользователей и hatch rate, запусти нагрузку.

**Что тестирует Locust:**

- Создание записей клиентами.
- Просмотр записей мойщиками.
- Управление записями администратором.
- Работу с услугами, акциями, расходниками.
- Пагинацию и фильтрацию.

**Тестовые данные:**

- `test_admin_1` / `testpass123`
- `test_client_1`..`test_client_50` / `testpass123`
- `test_washer_1`..`test_washer_10` / `testpass123`

### Makefile команды

| Команда | Описание |
|---|---|
| `make test-up` | Запуск Prometheus + Grafana (Docker) |
| `make test-down` | Остановка Prometheus + Grafana |
| `make test-clean` | DROP + CREATE пустой `lanwash_test` |
| `make test-seed` | Заполнение `lanwash_test` тестовыми данными |
| `make test-backend` | Запуск бэкенда на тестовой БД |
| `make test-run` | Запуск Locust UI |
| `make test-full` | Clean + Seed + Prometheus/Grafana |

---

## CI/CD

GitHub Actions автоматически запускаются при push/PR в ветки `main` или `master`:

| Workflow | Что проверяет |
|---|---|
| **Backend Tests** | pytest на Python 3.13, ruff, bandit, pip-audit, verify migrations |
| **Flutter CI** | analyze, format, test, build APK, build Web |

Flutter CI собирает release APK и web-версию как артефакты для каждого PR.

---

## Структура проекта

```
LanWash/
├── backend/                 # FastAPI + SQLAlchemy
│   ├── alembic/             # Миграции БД
│   ├── app/                 # FastAPI app, routers, middleware, deps
│   ├── bot/                 # Telegram бот (aiogram)
│   ├── core/                # Config, logging, limiter, security, redis, background
│   ├── db/                  # Engine, session, base, init, seed
│   │   └── base.py          # SQLAlchemy Base
│   ├── models/              # SQLAlchemy ORM-модели
│   │   └── models.py        # ORM-модели
│   ├── repositories/        # Repository layer
│   ├── schemas/             # Pydantic схемы
│   │   └── schemas.py       # Pydantic схемы
│   ├── services/            # Бизнес-логика
│   ├── tasks/               # ARQ background tasks
│   ├── tests/               # pytest
│   ├── locustfile.py        # Нагрузочное тестирование
│   ├── main.py              # compat-шим, реэкспортирует app из app/main.py
│   ├── requirements.txt
│   └── requirements-dev.txt
├── lib/                     # Flutter приложение
│   ├── core/                # ApiClient, ApiResult, DI, Config, offline DB
│   ├── models/              # Dart модели
│   ├── providers/           # AuthProvider, AppointmentProvider и др.
│   ├── screens/             # Экраны приложения
│   │   ├── auth/            # Экраны аутентификации
│   │   ├── client/          # Экраны клиента
│   │   ├── admin/           # Экраны администратора
│   │   ├── washer/          # Экраны мойщика
│   │   └── shared/          # Общие экраны
│   ├── services/            # ApiService, NotificationService, WebSocket
│   ├── usecases/            # Бизнес-сценарии
│   ├── utils/               # Утилиты и вспомогательные функции
│   ├── widgets/             # Переиспользуемые виджеты
│   ├── app_styles.dart      # Общие стили приложения
│   ├── firebase_options.dart # Конфигурация Firebase
│   └── main.dart
├── telegram-miniapp/        # React + Vite Telegram Mini App
├── landing/                 # Статический landing page
├── docs/                    # Документация проекта
├── nginx/                   # Nginx конфигурация
├── grafana/                 # Grafana dashboards и provisioning
├── prometheus.yml           # Prometheus конфигурация
├── docker-compose.yml       # Основной compose
├── docker-compose.prod.yml  # Production overrides
├── docker-compose.test.yml  # Тестовый compose (Prometheus + Grafana)
├── Makefile                 # Команды для тестирования
├── .github/workflows/       # GitHub Actions
└── README.md
```

---

## Лицензия

Лицензия проекта не указана.
