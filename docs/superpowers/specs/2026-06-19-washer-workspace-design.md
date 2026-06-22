# Washer workspace redesign

## Goal
Make the washer's main screen focused on work, simplify the drawer, and add a dedicated work dashboard.

## Current state snapshot
- `WasherShell` has two bottom tabs: "Записи" (`_WasherAppointmentsTab` with a weekly calendar + assigned appointments list) and "Заметки".
- Drawer sections:
  - **Записи**: "Мои записи", "История", "Записаться на мойку".
  - **Работа**: "Расписание", "Доступность", "Статистика", "Чаевые".
- `MyBookingsScreen` (client) already implements the active/history list pattern and uses `_HistoryAppointmentCard`.
- `WasherAppointmentCard` exists for washer-specific cards.
- `ShiftScheduleScreen` accepts `initialMode` to open on either shifts or availability.
- Statistics screen exists but is currently non-functional.

## Changes

### 1. Bottom tab "Мои записи" becomes the work list
Replace `_WasherAppointmentsTab` with a washer variant of the client bookings list.

- Screen: reuse the layout/pattern from `MyBookingsScreen`.
- Filter: appointments where `assignedWasher.toLowerCase() == auth.username.toLowerCase()`.
- Tabs: **Активные** (`scheduled`, `in_progress`) and **История** (`completed`, `cancelled`).
- Card: use existing `WasherAppointmentCard`.
- Refresh: `AppointmentProvider.reloadAppointments(auth)`.
- Badge on bottom-nav icon: unchanged, can later show pending/updated count.

### 2. Drawer "Работа" section
- **Расписание** — single item that opens `ShiftScheduleScreen()` (default shifts mode). Availability remains reachable via the second tab inside that screen.
- **Мой день** — new `WasherDashboardScreen`.
- **Статистика** — removed from the drawer; reachable from "Мой день" or hidden until fixed.
- "Чаевые" stays.

### 3. New screen: `WasherDashboardScreen`
A simple work dashboard under "Работа".

Widgets:
- Greeting with username.
- "Сегодня" summary card: total assigned appointments count + nearest appointment time.
- List of today's assigned appointments (compact cards).
- Action chips / buttons:
  - "Открыть расписание" → `ShiftScheduleScreen`.
  - "Статистика" → `StatisticsScreen` (kept but moved deeper).

Data source: `AppointmentProvider.appointments`, filtered by `assignedWasher` and date == today.

### 4. Drawer "Записи" section
- "Мои записи" keeps switching to the bottom tab.
- "История" can be kept as a quick jump to the history tab, or removed to avoid duplication. **Decision**: keep it for now to minimize change, make it switch to the bottom tab and select the history tab (or just open the tab).
- "Записаться на мойку" stays.

## Files touched
- `lib/screens/washer/washer_shell.dart` — tab 0 body, drawer menu structure.
- `lib/screens/washer/washer_appointments_screen.dart` (new) — work bookings list.
- `lib/screens/washer/washer_dashboard_screen.dart` (new) — "Мой день" dashboard.
- `lib/widgets/washer/washer_appointment_card.dart` — reuse.
- `lib/screens/washer/shift_schedule_screen.dart` — already supports modes.
- `test/screens/washer_shell_test.dart` — update/extend tests.
- `test/screens/washer_dashboard_screen_test.dart` (new) — basic tests.

## Out of scope
- Fixing the broken statistics backend/screen.
- Changing appointment actions/status workflow.
- Deep-link routing changes.

## Rollback note
If the new layout is rejected, the previous `_WasherAppointmentsTab` calendar-based view is in git history and can be restored.
