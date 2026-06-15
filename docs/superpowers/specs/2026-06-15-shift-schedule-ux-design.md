# Shift Schedule UX Redesign — Design Spec

**Date:** 2026-06-15  
**Scope:** `lib/screens/shared/shift_schedule_screen.dart`, backend shift endpoints, related models.

---

## 1. Overview

The current shift schedule is a weekly table (`washer × day`) with color-coded cells and long-press actions. It works, but becomes hard to use when the team grows or when there are many pending approvals.

This spec redesigns the screen into an integrated hub with four complementary views/features:

1. **Analytics header** — instant workload overview.
2. **Improved weekly table** — clearer conflicts, filtering, and bulk actions.
3. **Kanban-style requests panel** — fast approve/reject workflow.
4. **Week templates** — save and re-apply recurring schedules.
5. **Timeline view** (future) — hourly view for intra-day capacity planning.

---

## 2. Goals

- Reduce the number of taps to approve/reject a shift request.
- Surface overloads, gaps, and conflicts without mental arithmetic.
- Let admins plan a full week from templates instead of editing cells one by one.
- Keep the UI usable on both desktop-width web and mobile screens.
- Avoid breaking existing API contracts; add only opt-in endpoints/fields.

---

## 3. Current State

- `ShiftScheduleScreen` uses a `Table` with one row per washer and 7 day columns.
- `ShiftCell` supports `pending`, `confirmed`, `rejected` statuses, conflict detection, copy/paste/clear via long-press.
- Data loaded once per week: washers, shifts, current on-duty washers.
- Backend exposes:
  - `GET /api/shifts?start_date=&end_date=`
  - `GET /api/shifts/today`
  - `GET /api/shifts/current`
  - `GET /api/shifts/my`
  - `POST /api/shifts/`
  - `PUT /api/shifts/{id}/approve|reject`
  - `DELETE /api/shifts/{id}`

---

## 4. Proposed UX — "Unified Hub with Sidebar"

### 4.1 Layout

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: title | on-duty avatars | week switcher | actions  │
├─────────────────────────────────────────────────────────────┤
│  [Analytics cards row]                                      │
├──────────────────────────────────────────────┬──────────────┤
│  Weekly schedule table                       │  Sidebar     │
│  (washers × 7 days)                          │  - Kanban    │
│                                              │  - Templates │
│                                              │  - Filters   │
└──────────────────────────────────────────────┴──────────────┘
```

On narrow screens the sidebar becomes a bottom sheet triggered by a floating button.

### 4.2 Analytics Header Cards

Always visible, updated when `_loadData()` completes.

| Card | Value | Color rule |
|------|-------|------------|
| **Всего часов** | Sum of confirmed shift hours for the week | default |
| **Заявок на рассмотрении** | Count of `pending` shifts | yellow if >0, default if 0 |
| **Конфликтов** | Count of overlapping shifts | red if >0, default if 0 |
| **Загрузка** | Confirmed hours / (washers × target hours) × 100 | red if >100%, yellow 80-100%, green <80% |

*Target hours* is configurable per business; default to 40h/week per washer for the first implementation.

### 4.3 Improved Weekly Table

- **Highlight mode:** clicking an on-duty avatar highlights that washer's row.
- **Conflict chips:** if a cell has a time overlap, show a small warning icon + tooltip with the conflicting shift.
- **Overtime strip:** if a washer's weekly hours exceed the target, the "Часов" cell turns yellow/red.
- **Quick filters:**
  - Show all washers.
  - Show only me (washer role).
  - Show only pending requests.
  - Show only conflicts.
- **Bulk actions moved to toolbar:** approve all pending / reject all pending, not hidden in popup menu.

### 4.4 Sidebar — Kanban Requests Panel

Default open on desktop, collapsed to a badge count on mobile.

Three sections (expandable):

1. **На рассмотрении**
   - Each card: washer avatar + name, date, time range, requested at.
   - Actions: ✓ approve, ✗ reject, → jump to cell in table.
2. **Одобрено**
   - Recently approved shifts; allows undo (re-open as pending) within a short window.
3. **Отклонено**
   - Recently rejected shifts; allows undo.

Dragging between sections performs the corresponding status change with a confirmation snackbar.

### 4.5 Week Templates

- **Save template:** long-press washer name → "Сохранить как шаблон". Prompt for template name.
- **Apply template:** in sidebar, select a saved template + target week → apply.
- **Built-in presets:**
  - "Утро" — 08:00–14:00 Mon–Fri.
  - "Вечер" — 14:00–22:00 Mon–Fri.
  - "Полный день" — 08:00–22:00 Mon–Fri.
  - "Выходные" — Sat–Sun off (clears weekend shifts).
- Templates are stored per user (admin personal presets + global defaults).

Storage: first implementation keeps templates in `shared_preferences` on the frontend. If multi-device sync is needed later, migrate to a backend table.

### 4.6 Timeline View (Phase 4)

A secondary view toggled via segmented control "Таблица / Timeline".

- X-axis: hours of the day (00:00–24:00).
- Y-axis: washers (or boxes, if box support is added later).
- Bars represent confirmed/pending shifts.
- Overlaps are shown as stacked/red bars.
- Click an empty slot to create a shift; click a bar to edit.

---

## 5. API & Backend Changes

### 5.1 No breaking changes

Existing endpoints keep their signatures.

### 5.2 New endpoints (optional for Phase 1)

No new backend endpoints are required for analytics or Kanban; they can be computed client-side from the existing `GET /api/shifts` response.

If templates need server-side persistence later:

```
GET    /api/shift-templates
POST   /api/shift-templates
PUT    /api/shift-templates/{id}
DELETE /api/shift-templates/{id}
```

Schema (future):

```json
{
  "id": 1,
  "name": "Утро",
  "isGlobal": false,
  "entries": [
    {"weekday": 1, "startTime": "08:00", "endTime": "14:00"},
    ...
  ]
}
```

### 5.3 Existing endpoint improvements

- `GET /api/shifts?start_date=&end_date=` already returns all statuses; sufficient for Kanban.
- Consider adding `?status=pending` filter to reduce payload if the team grows; not required for MVP.

---

## 6. Data Flow

1. `_loadData()` fetches washers + shifts + current shifts for the selected week.
2. Derived state is computed in `build` or memoized with `ListenableBuilder`:
   - `pendingShifts`, `conflicts`, `hoursPerWasher`, `utilization`.
3. Sidebar widgets receive derived lists and call `ApiService.approveShift` / `rejectShift` / `createShift` / `deleteShift`.
4. After any mutation, `_loadData()` refreshes everything.

---

## 7. Components

### New widgets (planned)

- `ShiftAnalyticsHeader` — row of 4 metric cards.
- `ShiftFilterBar` — chip filters for the table.
- `ShiftRequestsPanel` — sidebar Kanban with sections.
- `ShiftRequestCard` — draggable card for a pending/approved/rejected shift.
- `ShiftTemplatePanel` — save/apply/delete templates.
- `ShiftTimelineView` — Phase 4 hourly view.

### Refactored widgets

- `ShiftScheduleScreen` becomes a layout coordinator.
- `ShiftCell` keeps current responsibilities but receives an optional `isHighlighted` flag.
- `OnDutyAvatars` stays, now also scrolls table to the selected washer.

---

## 8. State Management

Keep state inside `_ShiftScheduleScreenState`. No new providers are required because:

- All data is scoped to this screen.
- Mutations already go through `ApiService`.
- Derived state can be computed cheaply from the three loaded lists.

If sidebar state becomes complex, extract a local `ShiftScheduleController` (ChangeNotifier) living inside the screen.

---

## 9. Error Handling & Edge Cases

- **Approve/reject fails:** show snackbar, keep card in original section, do not mutate local state optimistically.
- **Template apply fails mid-batch:** continue applying remaining shifts, then report which days failed.
- **No washers:** show empty state with illustration and a CTA to add washers (for admin).
- **Mobile sidebar:** bottom sheet must not dismiss on accidental drag while dragging a Kanban card; use `DraggableScrollableSheet` with stable handles.
- **Conflicts:** creating a shift that overlaps an existing one is allowed by backend; UI must warn but not block (business decision).

---

## 10. Testing

- Widget tests:
  - Analytics header shows correct totals.
  - Filter chips reduce visible rows/cells.
  - Approve action calls `ApiService.approveShift` and refreshes.
  - Template apply creates the correct number of shifts.
- Integration (web):
  - Open schedule → switch week → create shift → approve in sidebar → verify table updates.
- Backend tests:
  - Existing approve/reject/delete tests still pass.
  - If template endpoints are added, cover CRUD + authorization.

---

## 11. Rollout Plan

| Phase | Deliverable | Effort |
|-------|-------------|--------|
| 1 | Analytics header + improved table (filters, highlights, bulk actions) | Medium |
| 2 | Sidebar Kanban requests panel | Medium |
| 3 | Week templates (local presets + save/apply) | Medium |
| 4 | Timeline view | Large |

Each phase is independently releasable and keeps the existing table working.

---

## 12. Open Questions

1. Should the timeline view be organized by washer or by wash box? (Boxes are not modeled yet.)
2. Should templates be per-admin or global? Start per-admin in shared_preferences, migrate to backend if needed.
3. What is the target weekly hours per washer? Default 40h until configured otherwise.
