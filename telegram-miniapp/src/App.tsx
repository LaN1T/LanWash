import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
import React, { Suspense } from 'react'
import { useAuthStore } from './stores/authStore'
import { useAuthGuard } from './hooks/useAuthGuard'
import Layout from './components/Layout'

const ClientRoutes = React.lazy(() => import('./routes/ClientRoutes'))
const WasherRoutes = React.lazy(() => import('./routes/WasherRoutes'))
const AdminRoutes = React.lazy(() => import('./routes/AdminRoutes'))
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

  switch (user?.role) {
    case 'admin':
      return <AdminRoutes />
    case 'washer':
      return <WasherRoutes />
    default:
      return <ClientRoutes />
  }
}

export default App
