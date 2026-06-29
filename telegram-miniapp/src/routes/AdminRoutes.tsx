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
