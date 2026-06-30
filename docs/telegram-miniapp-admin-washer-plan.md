# Telegram Mini App: Admin & Washer Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full `washer` and `admin` role support to the Telegram Mini App, reusing the existing FastAPI backend and client-side patterns.

**Architecture:** Role-based routing splits the app into three independent route trees. Shared service modules wrap new backend endpoints. New pages follow the established inline-style card UI and use Zustand stores only when state must be shared across pages.

**Tech Stack:** React 18 + TypeScript, Vite 8, React Router 6, Zustand, Axios, Telegram WebApp JS API.

**Out of scope:**
- Complex charts/graphs (tables and KPI numbers only).
- Camera QR scanning (manual ID input only).
- Grafana/Prometheus integration.
- Push notifications.
- Backend changes.

---

## File structure

| File | Responsibility |
|------|----------------|
| `telegram-miniapp/src/App.tsx` | Role-based route branching |
| `telegram-miniapp/src/routes/ClientRoutes.tsx` | Existing client routes extracted |
| `telegram-miniapp/src/routes/WasherRoutes.tsx` | Washer route tree |
| `telegram-miniapp/src/routes/AdminRoutes.tsx` | Admin route tree |
| `telegram-miniapp/src/components/Layout.tsx` | Role-aware shell |
| `telegram-miniapp/src/components/BottomNav.tsx` | Client bottom nav (existing) |
| `telegram-miniapp/src/components/WasherNav.tsx` | Washer top/bottom nav |
| `telegram-miniapp/src/components/AdminNav.tsx` | Admin top/bottom nav |
| `telegram-miniapp/src/hooks/useRoleGuard.ts` | Role guard hook |
| `telegram-miniapp/src/services/admin.ts` | Admin dashboard, users, bulk actions |
| `telegram-miniapp/src/services/washer.ts` | Washer shifts, availability |
| `telegram-miniapp/src/services/appointments.ts` | Extended appointment methods |
| `telegram-miniapp/src/services/reports.ts` | Report endpoints |
| `telegram-miniapp/src/services/consumables.ts` | Consumables endpoints |
| `telegram-miniapp/src/services/support.ts` | Support chat endpoints |
| `telegram-miniapp/src/services/notes.ts` | Notes endpoints |
| `telegram-miniapp/src/services/tips.ts` | Tips endpoints |
| `telegram-miniapp/src/services/subscriptions.ts` | Subscription plan admin endpoints |
| `telegram-miniapp/src/services/supportSocket.ts` | Support chat WebSocket client |
| `telegram-miniapp/src/stores/washerStore.ts` | Shared washer state |
| `telegram-miniapp/src/stores/adminStore.ts` | Shared admin state |
| `telegram-miniapp/src/pages/washer/*` | Washer pages |
| `telegram-miniapp/src/pages/admin/*` | Admin pages |

---

## Task 1: Role-based routing and shells

**Files:**
- Create: `telegram-miniapp/src/routes/ClientRoutes.tsx`, `telegram-miniapp/src/routes/WasherRoutes.tsx`, `telegram-miniapp/src/routes/AdminRoutes.tsx`
- Modify: `telegram-miniapp/src/App.tsx`, `telegram-miniapp/src/components/Layout.tsx`, `telegram-miniapp/src/components/BottomNav.tsx`
- Create: `telegram-miniapp/src/components/WasherNav.tsx`, `telegram-miniapp/src/components/AdminNav.tsx`, `telegram-miniapp/src/hooks/useRoleGuard.ts`

- [ ] **Step 1: Extract client routes into `ClientRoutes.tsx`**

```tsx
import { Routes, Route, Navigate } from 'react-router-dom'
import React from 'react'

const HomePage = React.lazy(() => import('../pages/client/HomePage'))
const BookingPage = React.lazy(() => import('../pages/client/BookingPage'))
const PromosPage = React.lazy(() => import('../pages/client/PromosPage'))
const MyBookingsPage = React.lazy(() => import('../pages/client/MyBookingsPage'))
const BookingDetailPage = React.lazy(() => import('../pages/client/BookingDetailPage'))
const ProfilePage = React.lazy(() => import('../pages/client/ProfilePage'))

export default function ClientRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/booking" element={<BookingPage />} />
      <Route path="/promos" element={<PromosPage />} />
      <Route path="/bookings" element={<MyBookingsPage />} />
      <Route path="/bookings/:id" element={<BookingDetailPage />} />
      <Route path="/profile" element={<ProfilePage />} />
      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  )
}
```

- [ ] **Step 2: Create `WasherRoutes.tsx` and `AdminRoutes.tsx` skeletons**

```tsx
// src/routes/WasherRoutes.tsx
import { Routes, Route, Navigate } from 'react-router-dom'
import React from 'react'

const WasherHomePage = React.lazy(() => import('../pages/washer/WasherHomePage'))
const WasherAppointmentsPage = React.lazy(() => import('../pages/washer/WasherAppointmentsPage'))
const WasherAppointmentDetailPage = React.lazy(() => import('../pages/washer/WasherAppointmentDetailPage'))
const WasherQrPage = React.lazy(() => import('../pages/washer/WasherQrPage'))
const WasherTipsPage = React.lazy(() => import('../pages/washer/WasherTipsPage'))
const WasherNotesPage = React.lazy(() => import('../pages/washer/WasherNotesPage'))
const WasherSchedulePage = React.lazy(() => import('../pages/washer/WasherSchedulePage'))
const WasherProfilePage = React.lazy(() => import('../pages/washer/WasherProfilePage'))

export default function WasherRoutes() {
  return (
    <Routes>
      <Route path="/" element={<WasherHomePage />} />
      <Route path="/appointments" element={<WasherAppointmentsPage />} />
      <Route path="/appointments/:id" element={<WasherAppointmentDetailPage />} />
      <Route path="/qr" element={<WasherQrPage />} />
      <Route path="/tips" element={<WasherTipsPage />} />
      <Route path="/notes" element={<WasherNotesPage />} />
      <Route path="/schedule" element={<WasherSchedulePage />} />
      <Route path="/profile" element={<WasherProfilePage />} />
      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  )
}
```

```tsx
// src/routes/AdminRoutes.tsx
import { Routes, Route, Navigate } from 'react-router-dom'
import React from 'react'

const AdminHomePage = React.lazy(() => import('../pages/admin/AdminHomePage'))
const AdminAppointmentsPage = React.lazy(() => import('../pages/admin/AdminAppointmentsPage'))
const AdminAppointmentDetailPage = React.lazy(() => import('../pages/admin/AdminAppointmentDetailPage'))
const AdminWashersPage = React.lazy(() => import('../pages/admin/AdminWashersPage'))
const AdminShiftsPage = React.lazy(() => import('../pages/admin/AdminShiftsPage'))
const AdminConsumablesPage = React.lazy(() => import('../pages/admin/AdminConsumablesPage'))
const AdminReportsPage = React.lazy(() => import('../pages/admin/AdminReportsPage'))
const AdminSupportPage = React.lazy(() => import('../pages/admin/AdminSupportPage'))
const AdminSupportChatPage = React.lazy(() => import('../pages/admin/AdminSupportChatPage'))
const AdminUsersPage = React.lazy(() => import('../pages/admin/AdminUsersPage'))
const AdminServicesPage = React.lazy(() => import('../pages/admin/AdminServicesPage'))
const AdminWashTypesPage = React.lazy(() => import('../pages/admin/AdminWashTypesPage'))
const AdminSubscriptionPlansPage = React.lazy(() => import('../pages/admin/AdminSubscriptionPlansPage'))
const AdminReviewsPage = React.lazy(() => import('../pages/admin/AdminReviewsPage'))
const AdminNotesPage = React.lazy(() => import('../pages/admin/AdminNotesPage'))
const AdminLogsPage = React.lazy(() => import('../pages/admin/AdminLogsPage'))
const AdminProfilePage = React.lazy(() => import('../pages/admin/AdminProfilePage'))

export default function AdminRoutes() {
  return (
    <Routes>
      <Route path="/" element={<AdminHomePage />} />
      <Route path="/appointments" element={<AdminAppointmentsPage />} />
      <Route path="/appointments/:id" element={<AdminAppointmentDetailPage />} />
      <Route path="/washers" element={<AdminWashersPage />} />
      <Route path="/washers/:id" element={<AdminWashersPage />} />
      <Route path="/shifts" element={<AdminShiftsPage />} />
      <Route path="/consumables" element={<AdminConsumablesPage />} />
      <Route path="/reports" element={<AdminReportsPage />} />
      <Route path="/support" element={<AdminSupportPage />} />
      <Route path="/support/:id" element={<AdminSupportChatPage />} />
      <Route path="/users" element={<AdminUsersPage />} />
      <Route path="/services" element={<AdminServicesPage />} />
      <Route path="/wash-types" element={<AdminWashTypesPage />} />
      <Route path="/subscription-plans" element={<AdminSubscriptionPlansPage />} />
      <Route path="/reviews" element={<AdminReviewsPage />} />
      <Route path="/notes" element={<AdminNotesPage />} />
      <Route path="/logs" element={<AdminLogsPage />} />
      <Route path="/profile" element={<AdminProfilePage />} />
      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  )
}
```

- [ ] **Step 3: Update `App.tsx` to use role-based route trees**

Replace the current role branching with:

```tsx
const ClientRoutes = React.lazy(() => import('./routes/ClientRoutes'))
const WasherRoutes = React.lazy(() => import('./routes/WasherRoutes'))
const AdminRoutes = React.lazy(() => import('./routes/AdminRoutes'))
```

Inside `AppRoutes`:

```tsx
if (!token) { /* /auth only */ }
if (user?.role === 'admin') return <AdminRoutes />
if (user?.role === 'washer') return <WasherRoutes />
return <ClientRoutes />
```

- [ ] **Step 4: Add `useRoleGuard.ts`**

```tsx
import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../stores/authStore'

export function useRoleGuard(allowed: Array<'client' | 'washer' | 'admin'>) {
  const { user } = useAuthStore()
  const navigate = useNavigate()

  useEffect(() => {
    if (!user) return
    if (!allowed.includes(user.role as 'client' | 'washer' | 'admin')) {
      navigate('/', { replace: true })
    }
  }, [user, allowed, navigate])
}
```

- [ ] **Step 5: Create `WasherNav.tsx` and `AdminNav.tsx`**

Simple top bar with 4-5 links using project color palette.

- [ ] **Step 6: Update `Layout.tsx` to render role nav**

```tsx
{!hideNav && user?.role === 'admin' && <AdminNav />}
{!hideNav && user?.role === 'washer' && <WasherNav />}
{!hideNav && user?.role === 'client' && <BottomNav />}
```

- [ ] **Step 7: Run build**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npm run build
```

Expected: build succeeds (pages may not exist yet; create placeholder `.tsx` files if needed to satisfy imports).

- [ ] **Step 8: Commit**

```bash
git add telegram-miniapp/src/App.tsx telegram-miniapp/src/routes telegram-miniapp/src/components/WasherNav.tsx telegram-miniapp/src/components/AdminNav.tsx telegram-miniapp/src/hooks/useRoleGuard.ts telegram-miniapp/src/components/Layout.tsx
git commit -m "feat(miniapp): role-based routing shells for admin and washer"
```

---

## Task 2: Shared service modules

**Files:**
- Modify: `telegram-miniapp/src/services/appointments.ts`
- Create: `telegram-miniapp/src/services/admin.ts`, `telegram-miniapp/src/services/washer.ts`, `telegram-miniapp/src/services/reports.ts`, `telegram-miniapp/src/services/consumables.ts`, `telegram-miniapp/src/services/support.ts`, `telegram-miniapp/src/services/notes.ts`, `telegram-miniapp/src/services/tips.ts`, `telegram-miniapp/src/services/subscriptions.ts`, `telegram-miniapp/src/services/supportSocket.ts`

Implement typed service functions matching backend endpoints. Validate responses where shapes are critical.

- [ ] **Step 1: Extend `appointments.ts`** with `getAppointments`, `getAppointmentById`, `assignWasher`, `scanQr`, `updateAppointmentStatus`, `bulkAssignWasher`, `bulkCancel`, `bulkUpdateStatus`.
- [ ] **Step 2: Create `admin.ts`** with `getDashboard`, `getForecast`, `getUsers`, `bulkAssign`, `bulkCancel`, `bulkUpdateStatus`.
- [ ] **Step 3: Create `washer.ts`** with `getMyShifts`, `getWasherAppointments`, `getAvailability`, `setAvailability`, `deleteAvailability`.
- [ ] **Step 4: Create `reports.ts`** with `getDailyReport`, `getFinancialReport`, `getPayrollReport`, `getPromoEffectiveness`, `getCancellations`, `getAverageCheck`, `getPopularServices`, `getConsumablesUsage`, `getShiftLoad`.
- [ ] **Step 5: Create `consumables.ts`** with `getConsumables`, `getLowStock`, `getForecast`, `refill`, `getHistory`, `getRefillHistory`, `getUsageHistory`, `getServiceLinks`, `getWashTypeLinks`, `createServiceLink`, `deleteServiceLink`, `createWashTypeLink`, `deleteWashTypeLink`, `exportReport`, `getImportTemplate`, `importRefills`.
- [ ] **Step 6: Create `support.ts`** with `getMyChats`, `getAllChats`, `getMessages`, `sendMessage`, `createChat`, `closeChat`, `assignChat`, `markRead`, `aiDraft`.
- [ ] **Step 7: Create `notes.ts`** with `getNotes`, `getUnreadCount`, `createNote`, `markRead`, `markAllRead`, `deleteNote`.
- [ ] **Step 8: Create `tips.ts`** with `getMyTips`, `getStats`, `markPaid`.
- [ ] **Step 9: Create `subscriptions.ts`** with `getPlans`, `createPlan`, `updatePlan`, `deletePlan`.
- [ ] **Step 10: Create `supportSocket.ts`** — WebSocket client for `/ws/support/chats/{chat_id}` with auth handshake, ping/pong, reconnect, cleanup.
- [ ] **Step 11: Build + commit**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npm run build
```

```bash
git add telegram-miniapp/src/services
git commit -m "feat(miniapp): service modules for admin and washer endpoints"
```

---

## Task 3: Washer pages

**Files:**
- Create: `telegram-miniapp/src/pages/washer/WasherHomePage.tsx`, `WasherAppointmentsPage.tsx`, `WasherAppointmentDetailPage.tsx`, `WasherQrPage.tsx`, `WasherTipsPage.tsx`, `WasherNotesPage.tsx`, `WasherSchedulePage.tsx`, `WasherProfilePage.tsx`
- Create: `telegram-miniapp/src/stores/washerStore.ts`

Implement pages following the existing inline-style UI. Use `useRoleGuard(['washer'])` on each page.

- [ ] **Step 1: `WasherHomePage`** — today's assigned/shift appointments, current shift, quick QR button, counts.
- [ ] **Step 2: `WasherAppointmentsPage`** — active/history tabs, list sorted by date, pull-to-refresh.
- [ ] **Step 3: `WasherAppointmentDetailPage`** — appointment info, status buttons (`confirmed` → `in_progress` → `completed`), notes field, QR done button.
- [ ] **Step 4: `WasherQrPage`** — manual appointment ID input, call `scanQr`, redirect to detail.
- [ ] **Step 5: `WasherTipsPage`** — tip list, stats, mark paid.
- [ ] **Step 6: `WasherNotesPage`** — list + create note (washer can only create note for self).
- [ ] **Step 7: `WasherSchedulePage`** — my shifts, availability calendar, add/remove availability.
- [ ] **Step 8: `WasherProfilePage`** — reuse `ProfilePage` or create a minimal washer profile with stats/logout.
- [ ] **Step 9: Build + commit**

```bash
git add telegram-miniapp/src/pages/washer telegram-miniapp/src/stores/washerStore.ts
git commit -m "feat(miniapp): washer role pages"
```

---

## Task 4: Admin pages

**Files:**
- Create: `telegram-miniapp/src/pages/admin/AdminHomePage.tsx`, `AdminAppointmentsPage.tsx`, `AdminAppointmentDetailPage.tsx`, `AdminWashersPage.tsx`, `AdminShiftsPage.tsx`, `AdminConsumablesPage.tsx`, `AdminReportsPage.tsx`, `AdminSupportPage.tsx`, `AdminSupportChatPage.tsx`, `AdminUsersPage.tsx`, `AdminServicesPage.tsx`, `AdminWashTypesPage.tsx`, `AdminSubscriptionPlansPage.tsx`, `AdminReviewsPage.tsx`, `AdminNotesPage.tsx`, `AdminLogsPage.tsx`, `AdminProfilePage.tsx`
- Create: `telegram-miniapp/src/stores/adminStore.ts`

Use `useRoleGuard(['admin'])` on each page. Implement tables/cards rather than charts.

- [ ] **Step 1: `AdminHomePage`** — KPI cards, latest appointments, forecast link.
- [ ] **Step 2: `AdminAppointmentsPage`** — all appointments list, date/status filters, search, bulk actions UI.
- [ ] **Step 3: `AdminAppointmentDetailPage`** — full info, assign washer dropdown, status change, delete.
- [ ] **Step 4: `AdminWashersPage`** — washer list, toggle active, link to detail.
- [ ] **Step 5: `AdminShiftsPage`** — shift list, approve/reject/reopen, templates.
- [ ] **Step 6: `AdminConsumablesPage`** — stock list, low-stock alert, refill form, forecast.
- [ ] **Step 7: `AdminReportsPage`** — report menu with tabs for financial, payroll, cancellations, popular services, consumables usage, average check.
- [ ] **Step 8: `AdminSupportPage`** — support chat list with filters.
- [ ] **Step 9: `AdminSupportChatPage`** — messages, send, AI draft, assign, close.
- [ ] **Step 10: `AdminUsersPage`** — user search, role filter, block/unblock.
- [ ] **Step 11: `AdminServicesPage`** — service CRUD.
- [ ] **Step 12: `AdminWashTypesPage`** — wash type CRUD with included extras.
- [ ] **Step 13: `AdminSubscriptionPlansPage`** — subscription plan CRUD.
- [ ] **Step 14: `AdminReviewsPage`** — review moderation (publish/unpublish/delete).
- [ ] **Step 15: `AdminNotesPage`** — notes list, mark read, delete.
- [ ] **Step 16: `AdminLogsPage`** — action log list, clear.
- [ ] **Step 17: `AdminProfilePage`** — reuse client ProfilePage or minimal admin profile.
- [ ] **Step 18: Build + commit**

```bash
git add telegram-miniapp/src/pages/admin telegram-miniapp/src/stores/adminStore.ts
git commit -m "feat(miniapp): admin role pages"
```

---

## Task 5: Security, UX, and optimization

**Files:**
- Modify: `telegram-miniapp/src/services/api.ts`
- Modify: `telegram-miniapp/src/App.tsx`
- Create/update shared components as needed.

- [ ] **Step 1: 403 handler in `api.ts`** — show Telegram alert on `403`.
- [ ] **Step 2: Verify all new service functions use existing `api` instance with bearer interceptor.**
- [ ] **Step 3: Add `Suspense` fallback skeletons for role route trees in `App.tsx`.**
- [ ] **Step 4: Ensure all WebSocket cleanup functions are called on unmount.**
- [ ] **Step 5: Review network calls — use `AbortSignal` for list pages, debounce search inputs.**
- [ ] **Step 6: Commit**

```bash
git add telegram-miniapp/src
git commit -m "chore(miniapp): security and UX polish for admin/washer"
```

---

## Task 6: Final integration and tests

- [ ] **Step 1: Run backend tests**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && python3 -m pytest -q
```

Expected: all pass.

- [ ] **Step 2: Run Mini App build**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npm run build
```

Expected: success.

- [ ] **Step 3: Run TypeScript check**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/telegram-miniapp && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Run Python lint**

```bash
cd /Users/lan1t/lan1t/Users/Курсач/LanWash/backend && python3 -m ruff check .
```

Expected: clean.

- [ ] **Step 5: Commit any final fixes**

```bash
git commit -m "chore(miniapp): final integration checks"
```

---

## Execution order

1. Task 1 — routing and shells
2. Task 2 — service modules
3. Task 3 — washer pages
4. Task 4 — admin pages
5. Task 5 — security/UX
6. Task 6 — final integration

---

## Self-review

- **Spec coverage:** All washer and admin core flows from the Flutter catalog are mapped to pages and backend endpoints.
- **Placeholder scan:** No TBD/TODO; each task has concrete file paths and steps.
- **Type consistency:** `User.role` already supports `'client' | 'washer' | 'admin'`; new services will reuse existing `Appointment`, `User`, and `Service` types where possible.

## Execution handoff

Plan complete and saved to `docs/telegram-miniapp-admin-washer-plan.md`.

Two execution options:
1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks.
2. **Inline Execution** — execute tasks in this session.

Proceeding autonomously with subagent-driven execution.