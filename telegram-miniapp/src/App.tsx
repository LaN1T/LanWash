import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
import React, { Suspense } from 'react'
import { useAuthStore } from './stores/authStore'
import { useAuthGuard } from './hooks/useAuthGuard'
import Layout from './components/Layout'

const HomePage = React.lazy(() => import('./pages/client/HomePage'))
const BookingPage = React.lazy(() => import('./pages/client/BookingPage'))
const PromosPage = React.lazy(() => import('./pages/client/PromosPage'))
const MyBookingsPage = React.lazy(() => import('./pages/client/MyBookingsPage'))
const ProfilePage = React.lazy(() => import('./pages/client/ProfilePage'))
const WasherHomePage = React.lazy(() => import('./pages/washer/WasherHomePage'))
const AuthGatewayPage = React.lazy(() => import('./pages/auth/AuthGatewayPage'))

function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  )
}

function AppContent() {
  const { isLoading } = useAuthStore()
  const { ready } = useAuthGuard()
  const location = useLocation()
  const hideNav = location.pathname === '/auth'

  if (!ready || isLoading) {
    return (
      <Layout hideNav>
        <div style={{ textAlign: 'center', padding: 40 }}>Загрузка...</div>
      </Layout>
    )
  }

  return (
    <Layout hideNav={hideNav}>
      <Suspense fallback={<div style={{ textAlign: 'center', padding: 40 }}>Загрузка...</div>}>
        <AppRoutes />
      </Suspense>
    </Layout>
  )
}

function AppRoutes() {
  const { token, user } = useAuthStore()

  if (!token) {
    return (
      <Routes>
        <Route path="/auth" element={<AuthGatewayPage />} />
        <Route path="*" element={<Navigate to="/auth" />} />
      </Routes>
    )
  }

  return (
    <Routes>
      {user?.role === 'washer' ? (
        <>
          <Route path="/" element={<WasherHomePage />} />
          <Route path="*" element={<Navigate to="/" />} />
        </>
      ) : (
        <>
          <Route path="/" element={<HomePage />} />
          <Route path="/booking" element={<BookingPage />} />
          <Route path="/promos" element={<PromosPage />} />
          <Route path="/bookings" element={<MyBookingsPage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="*" element={<Navigate to="/" />} />
        </>
      )}
    </Routes>
  )
}

export default App
