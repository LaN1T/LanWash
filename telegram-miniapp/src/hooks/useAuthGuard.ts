import { useEffect, useRef } from 'react'
import { useTelegram } from './useTelegram'
import { useAuthStore } from '../stores/authStore'
import { telegramAuth } from '../services/auth'
import { api } from '../services/api'

export function useAuthGuard() {
  const { initData, ready, isInTelegram } = useTelegram()
  const { token, setAuth, setLoading, init, hydrated } = useAuthStore()
  const mounted = useRef(true)

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])

  // Restore persisted auth state before any auto-login attempt.
  useEffect(() => {
    init()
  }, [init])

  useEffect(() => {
    if (!ready || !hydrated) return
    if (token) return

    const attemptAutoLogin = async () => {
      if (mounted.current) setLoading(true)
      try {
        if (initData) {
          const res = await telegramAuth(initData)
          if (mounted.current) await setAuth(res.user, res.access_token)
        } else if (isInTelegram) {
          const res = await api.post('/auth/refresh', {}, { withCredentials: true })
          if (mounted.current) await setAuth(res.data.user, res.data.access_token)
        }
      } catch (e: any) {
        // 409 is expected when the Telegram account is not linked to a user yet.
        // In that case we keep the user on the auth gateway without showing an error.
        if (e.response?.status !== 409) {
          console.error('Auth failed', e)
        }
      } finally {
        if (mounted.current) setLoading(false)
      }
    }

    attemptAutoLogin()
  }, [
    initData,
    ready,
    isInTelegram,
    token,
    hydrated,
    setAuth,
    setLoading,
    init,
  ])

  return { ready: ready && hydrated, isInTelegram }
}
