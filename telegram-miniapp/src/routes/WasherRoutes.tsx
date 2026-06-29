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
