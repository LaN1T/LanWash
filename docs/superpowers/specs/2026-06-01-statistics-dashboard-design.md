# Дизайн: Экран "Статистика" + Grafana интеграция

## Общая концепция

Гибридный подход:
- **Ежедневные метрики** — нативные Flutter-виджеты (KPI-карточки, графики, списки) для всех платформ
- **Grafana** — полный аналитический dashboard
  - **Web**: встраивается через `iframe` (HtmlElementView) прямо внутрь приложения
  - **Desktop/Mobile**: открывается через `url_launcher` в браузере

## Роли и доступ

| Роль | Нативная статистика | Grafana |
|------|---------------------|---------|
| client | Своя статистика (моек, потрачено, уровень) | Нет доступа |
| washer | Ежедневные метрики + своя статистика | Нет доступа |
| admin | Все метрики | Да (Web — iframe, Desktop/Mobile — браузер) |

## Экран "Статистика"

### Структура

```
┌─────────────────────────────┐
│  Статистика        [Сегодня ▼│  ← Dropdown: Сегодня / Неделя / Месяц
├─────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │💰   │ │📋   │ │⚡   │    │  ← KPI-карточки
│ │15K  │ │12   │ │1.8K │    │
│ │Выруч│ │Запис│ │Средн│    │
│ └─────┘ └─────┘ └─────┘    │
├─────────────────────────────┤
│  [📈 График выручки]        │  ← fl_chart, линейный график
├─────────────────────────────┤
│  Топ услуг                  │
│  □ Комплексная мойка  5 шт  │
├─────────────────────────────┤
│  Мойщики на смене           │
│  🧑‍🔧 Иван      4 записи    │
├─────────────────────────────┤
│  🔴 Автошампунь: осталось   │  ← Алерты расходников
│     200 мл (мин. 500 мл)    │
├─────────────────────────────┤
│  [📊 Grafana]               │  ← Только admin
└─────────────────────────────┘
```

### Компоненты

- `KpiCards` — 3-4 карточки (выручка, записи, средний чек, занятость боксов)
- `RevenueChart` — линейный график выручки по дням (fl_chart)
- `TopServicesList` — список топ-5 услуг за период
- `WashersShiftList` — мойщики на смене сегодня
- `ConsumablesAlert` — расходники ниже минимального запаса
- `GrafanaButton` — кнопка для admin
  - Web: открывает `GrafanaIframeScreen` с HtmlElementView
  - Desktop/Mobile: url_launcher → `http://localhost:3000/d/lanwash-api`

## Backend API

### Новый endpoint

`GET /api/reports/daily?date=YYYY-MM-DD`

```json
{
  "date": "2026-06-01",
  "revenue": 15000,
  "appointmentsCount": 12,
  "completedCount": 8,
  "averageCheck": 1875,
  "boxOccupancy": {"box1": 6, "box2": 4},
  "topServices": [
    {"name": "Комплексная мойка", "count": 5, "revenue": 7500}
  ],
  "washersOnShift": [
    {"name": "Иван", "hours": 8, "appointments": 4}
  ],
  "consumablesAlert": [
    {"name": "Автошампунь", "currentStock": 200, "minStock": 500}
  ]
}
```

## Grafana настройка

```yaml
GF_SECURITY_ALLOW_EMBEDDING: "true"
GF_AUTH_ANONYMOUS_ENABLED: "true"
GF_AUTH_ANONYMOUS_ORG_ROLE: "Viewer"
```

## Файлы

```
lib/
  screens/shared/statistics_screen.dart
  screens/admin/grafana_iframe_screen.dart   # Web only
  widgets/statistics/kpi_cards.dart
  widgets/statistics/revenue_chart.dart
  widgets/statistics/top_services_list.dart
  widgets/statistics/washers_shift_list.dart
  widgets/statistics/consumables_alert.dart
  models/daily_report.dart
backend/
  routers/reports.py  ← + endpoint /daily
```
