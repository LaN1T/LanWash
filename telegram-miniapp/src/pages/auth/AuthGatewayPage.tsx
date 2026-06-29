import { useState } from 'react'
import { useTelegram } from '../../hooks/useTelegram'
import { useAuthStore } from '../../stores/authStore'
import { linkTelegram, registerTelegram } from '../../services/auth'

const USERNAME_RE = /^[a-z0-9_]+$/

function validateUsername(username: string): string | null {
  if (!username) return 'Введите логин'
  if (username.length < 3 || username.length > 30) {
    return 'Логин должен быть от 3 до 30 символов'
  }
  if (!USERNAME_RE.test(username)) {
    return 'Логин может содержать только латинские буквы, цифры и _'
  }
  return null
}

function validatePassword(password: string): string | null {
  if (!password) return 'Введите пароль'
  if (password.length < 8) return 'Пароль должен быть не менее 8 символов'
  return null
}

function validateDisplayName(displayName: string): string | null {
  if (!displayName) return 'Введите имя'
  return null
}

export default function AuthGatewayPage() {
  const { initData } = useTelegram()
  const { setAuth } = useAuthStore()
  const [mode, setMode] = useState<'choose' | 'login' | 'register'>('choose')
  const [error, setError] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleLogin = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    const username = form.get('username') as string
    const password = form.get('password') as string

    const usernameError = validateUsername(username)
    if (usernameError) {
      setError(usernameError)
      return
    }
    const passwordError = validatePassword(password)
    if (passwordError) {
      setError(passwordError)
      return
    }

    if (!initData) {
      setError('Откройте приложение через Telegram')
      return
    }

    setIsSubmitting(true)
    try {
      const res = await linkTelegram(initData, username, password)
      await setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка входа')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleRegister = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    const username = form.get('username') as string
    const password = form.get('password') as string
    const displayName = form.get('displayName') as string

    const usernameError = validateUsername(username)
    if (usernameError) {
      setError(usernameError)
      return
    }
    const passwordError = validatePassword(password)
    if (passwordError) {
      setError(passwordError)
      return
    }
    const displayNameError = validateDisplayName(displayName)
    if (displayNameError) {
      setError(displayNameError)
      return
    }

    if (!initData) {
      setError('Откройте приложение через Telegram')
      return
    }

    setIsSubmitting(true)
    try {
      const res = await registerTelegram(initData, {
        username,
        password,
        displayName,
        phone: form.get('phone') as string,
        carModel: form.get('carModel') as string,
        carNumber: form.get('carNumber') as string,
        referralCode: form.get('referralCode') as string,
      })
      await setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка регистрации')
    } finally {
      setIsSubmitting(false)
    }
  }

  if (!initData) {
    return (
      <div style={{ padding: 20 }}>
        <h2>Вход в LanWash</h2>
        <p>Откройте приложение через Telegram</p>
      </div>
    )
  }

  if (mode === 'choose') {
    return (
      <div style={{ padding: 20 }}>
        <h2>Вход в LanWash</h2>
        <p>Этот Telegram ещё не привязан к аккаунту.</p>
        <button onClick={() => setMode('login')} disabled={isSubmitting}>
          Войти по логину и паролю
        </button>
        <button onClick={() => setMode('register')} disabled={isSubmitting}>
          Создать аккаунт
        </button>
      </div>
    )
  }

  return (
    <div style={{ padding: 20 }}>
      {mode === 'login' ? (
        <form onSubmit={handleLogin}>
          <input name="username" placeholder="Логин" required />
          <input name="password" type="password" placeholder="Пароль" required />
          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Вход...' : 'Войти'}
          </button>
        </form>
      ) : (
        <form onSubmit={handleRegister}>
          <input name="username" placeholder="Логин" required />
          <input name="password" type="password" placeholder="Пароль" required />
          <input name="displayName" placeholder="Имя" required />
          <input name="phone" placeholder="Телефон" />
          <input name="carModel" placeholder="Модель авто" />
          <input name="carNumber" placeholder="Номер авто" />
          <input name="referralCode" placeholder="Реферальный код" />
          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Создание...' : 'Создать аккаунт'}
          </button>
        </form>
      )}
      {error && <p style={{ color: 'red' }}>{error}</p>}
      <button onClick={() => setMode('choose')} disabled={isSubmitting}>
        Назад
      </button>
    </div>
  )
}
