import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect } from 'react'
import { useAuthStore } from './stores/authStore'
import { useTelegram } from './hooks/useTelegram'
import { telegramAuth } from './services/auth'
import HomePage from './pages/client/HomePage'
import BookingPage from './pages/client/BookingPage'
import MyBookingsPage from './pages/client/MyBookingsPage'
import ProfilePage from './pages/client/ProfilePage'
import WasherHomePage from './pages/washer/WasherHomePage'
import Layout from './components/Layout'

function App() {
  const { initData } = useTelegram()
  const { user, token, setAuth, setLoading } = useAuthStore()

  useEffect(() => {
    if (!initData) return
    const auth = async () => {
      setLoading(true)
      try {
        const res = await telegramAuth(initData)
        setAuth(res.user, res.access_token)
      } catch (e) {
        console.error('Auth failed', e)
      } finally {
        setLoading(false)
      }
    }
    auth()
  }, [initData])

  if (!token) {
    return (
      <Layout>
        <div style={{ textAlign: 'center', padding: 40 }}>
          <p>Загрузка...</p>
        </div>
      </Layout>
    )
  }

  return (
    <BrowserRouter>
      <Layout>
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
              <Route path="/bookings" element={<MyBookingsPage />} />
              <Route path="/profile" element={<ProfilePage />} />
              <Route path="*" element={<Navigate to="/" />} />
            </>
          )}
        </Routes>
      </Layout>
    </BrowserRouter>
  )
}

export default App