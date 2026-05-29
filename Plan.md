# План разработки LanWash

## Этап 1: Критическая безопасность (P0) — ✅ ГОТОВО

- [x] Удаление `serviceAccountKey.json` из git-истории (git-filter-repo)
- [x] Ревокнут ключ в Firebase Console
- [x] Добавлен `.env` + `.env.example`
- [x] Git-ignore для `.env`, `*.key`, `serviceAccountKey.json`
- [x] Pre-commit hook для проверки секретов (опционально)

## Этап 2: Backend Security (P1) — ✅ ГОТОВО

- [x] CORS из `ALLOWED_ORIGINS` (не `*`)
- [x] JWT min 32 chars валидация при старте
- [x] Rate limiting (slowapi) на все endpoints
- [x] Security headers middleware
- [x] Pydantic валидация (`max_length`, `ge=0`, `Literal`)
- [x] Debug route за `DEBUG=true`

## Этап 3: Flutter рефакторинг (P2-P3) — ✅ ГОТОВО

- [x] `AppConfig` через dart-define
- [x] `ApiResult<T>` + sealed классы
- [x] `ApiClient` (централизованный HTTP, retry, JWT auto, таймаут)
- [x] `ApiService` переписан на `ApiClient`
- [x] `AuthProvider` / `AppProvider` с `errorMessage` и обработкой ошибок
- [x] DI через `get_it` (`lib/core/service_locator.dart`)
- [x] Удалена мёртвая архитектура (71 файл, 11422 строки)

## Этап 4: Тестирование бэкенда (pytest) — ✅ ГОТОВО

- [x] `pytest.ini` + `pytest-asyncio` strict mode
- [x] `tests/conftest.py` — SQLite in-memory, async client, отключение rate limiting, фикстуры токенов
- [x] `tests/test_auth.py` — регистрация, логин, профиль, защищённые endpoint
- [x] `tests/test_security.py` — валидация пароля, JWT encode/decode, expiration
- [x] `tests/test_wash_types.py` — CRUD типов мойки
- [x] `tests/test_logs.py` — публичное создание, фильтры, очистка
- [x] `tests/test_notes.py` — заметки мойщиков, unread count, mark read
- [x] `tests/test_consumables.py` — CRUD расходников, связи с услугами
- [x] `tests/test_services.py` — CRUD услуг, акции, избранное
- [x] `tests/test_reports.py` — месячные отчёты, популярные услуги, расход материалов
- [x] `tests/test_appointments.py` — жизненный цикл записи, назначение мойщика, статистика
- [x] Все **78/78 тестов проходят**
- [x] Исправлены deprecation warnings (`datetime.utcnow()`)
- [x] **Найден и исправлен баг:** `routers/consumables.py:50` — `get_consumable` вызывался без `request`

## Этап 5: CI/CD и DevOps — ✅ ГОТОВО

- [x] GitHub Actions: pytest на PR/push (`backend.yml`)
- [x] GitHub Actions: flutter analyze + dart format check (`flutter.yml`)
- [x] `backend/requirements-dev.txt` — dev-зависимости
- [x] Исправлены ошибки Flutter (остатки удалённой архитектуры)

## Этап 6: Тестирование Flutter — 🔄 ОЖИДАЕТСЯ

- [ ] Unit-тесты для `ApiResult`, `ApiClient`
- [ ] Моки для `ApiService`
- [ ] Widget-тесты для критических экранов

## Этап 7: Документация — 🔄 ОЖИДАЕТСЯ

- [ ] API документация (FastAPI auto-docs улучшить)
- [ ] README.md обновить
- [ ] Архитектурная документация (ADR)

---

**Текущий статус:** Этапы 1-5 завершены. 78/78 backend тестов, CI настроен. Готов к Flutter-тестам (Этап 6) или документации (Этап 7).
