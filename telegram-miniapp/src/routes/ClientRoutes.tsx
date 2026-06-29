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
