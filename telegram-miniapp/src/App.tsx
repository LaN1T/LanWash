import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import React, { useEffect, useState, Suspense } from 'react'
import { useAuthStore } from './stores/authStore'
import { useTelegram } from './hooks/useTelegram'
import { telegramAuth } from './services/auth'
import { api } from './services/api'
import Layout from './components/Layout'

const HomePage = React.lazy(() => import('./pages/client/HomePage'))
const BookingPage = React.lazy(() => import('./pages/client/BookingPage'))
const PromosPage = React.lazy(() => import('./pages/client/PromosPage'))
const MyBookingsPage = React.lazy(() => import('./pages/client/MyBookingsPage'))
const ProfilePage = React.lazy(() => import('./pages/client/ProfilePage'))
const WasherHomePage = React.lazy(() => import('./pages/washer/WasherHomePage'))

function App() {
  const { initData, ready, isInTelegram } = useTelegram()
  const { user, token, error, setAuth, setLoading, init } = useAuthStore()
  const [hydrated, setHydrated] = useState(false)

  useEffect(() => {
    init().finally(() => setHydrated(true))
  }, [init])

  useEffect(() => {
    if (!ready || !hydrated) return
    if (token) {
      setLoading(false)
      return
    }

    const auth = async () => {
      setLoading(true)
      try {
        if (initData) {
          const res = await telegramAuth(initData)
          await setAuth(res.user, res.access_token)
        } else if (isInTelegram) {
          const res = await api.post('/auth/refresh', {}, { withCredentials: true })
          await setAuth(res.data.user, res.data.access_token)
        }
      } catch (e) {
        console.error('Auth failed', e)
      } finally {
        setLoading(false)
      }
    }
    auth()
  }, [initData, ready, isInTelegram, setAuth, setLoading, token, hydrated])

  if (!ready) {
    return (
      <BrowserRouter>
        <Layout>
          <div style={{ textAlign: 'center', padding: 40 }}>
            <p>Загрузка...</p>
          </div>
        </Layout>
      </BrowserRouter>
    )
  }

  if (!token) {
    return (
      <BrowserRouter>
        <Layout>
          <div style={{ textAlign: 'center', padding: 40 }}>
            <h2 style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 8 }}>LanWash</h2>
            {!isInTelegram ? (
              <>
                <p>Откройте приложение через Telegram бота</p>
                <p style={{ fontSize: 12, color: '#888', marginTop: 20 }}>
                  Или используйте основное приложение
                </p>
              </>
            ) : (
              <p>{error || 'Ошибка авторизации. Попробуйте ещё раз.'}</p>
            )}
          </div>
        </Layout>
      </BrowserRouter>
    )
  }

  return (
    <BrowserRouter>
      <Layout>
        <Suspense fallback={<div style={{ textAlign: 'center', padding: 40 }}>Загрузка...</div>}>
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
        </Suspense>
      </Layout>
    </BrowserRouter>
  )
}

export default App