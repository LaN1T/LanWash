import { useEffect } from 'react'
import { useTelegram } from './useTelegram'
import { useAuthStore } from '../stores/authStore'
import { telegramAuth } from '../services/auth'
import { api } from '../services/api'

export function useAuthGuard() {
  const { initData, ready, isInTelegram } = useTelegram()
  const { token, setAuth, setLoading } = useAuthStore()

  useEffect(() => {
    if (!ready) return

    const attemptAutoLogin = async () => {
      setLoading(true)
      try {
        if (initData) {
          const res = await telegramAuth(initData)
          await setAuth(res.user, res.access_token)
        } else if (isInTelegram) {
          const res = await api.post('/auth/refresh', {}, { withCredentials: true })
          await setAuth(res.data.user, res.data.access_token)
        }
      } catch (e: any) {
        if (e.response?.status !== 409) {
          console.error('Auth failed', e)
        }
      } finally {
        setLoading(false)
      }
    }

    if (!token) {
      attemptAutoLogin()
    }
  }, [initData, ready, isInTelegram])

  return { ready, isInTelegram }
}
