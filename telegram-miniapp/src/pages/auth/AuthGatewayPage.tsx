import { useState } from 'react'
import { useTelegram } from '../../hooks/useTelegram'
import { useAuthStore } from '../../stores/authStore'
import { linkTelegram, registerTelegram } from '../../services/auth'

export default function AuthGatewayPage() {
  const { initData } = useTelegram()
  const { setAuth } = useAuthStore()
  const [mode, setMode] = useState<'choose' | 'login' | 'register'>('choose')
  const [error, setError] = useState('')

  const handleLogin = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    try {
      const res = await linkTelegram(
        initData,
        form.get('username') as string,
        form.get('password') as string
      )
      await setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка входа')
    }
  }

  const handleRegister = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError('')
    const form = new FormData(e.currentTarget)
    try {
      const res = await registerTelegram(initData, {
        username: form.get('username') as string,
        password: form.get('password') as string,
        displayName: form.get('displayName') as string,
        phone: form.get('phone') as string,
        carModel: form.get('carModel') as string,
        carNumber: form.get('carNumber') as string,
        referralCode: form.get('referralCode') as string,
      })
      await setAuth(res.user, res.access_token)
    } catch (e: any) {
      setError(e.response?.data?.detail || 'Ошибка регистрации')
    }
  }

  if (mode === 'choose') {
    return (
      <div style={{ padding: 20 }}>
        <h2>Вход в LanWash</h2>
        <p>Этот Telegram ещё не привязан к аккаунту.</p>
        <button onClick={() => setMode('login')}>Войти по логину и паролю</button>
        <button onClick={() => setMode('register')}>Создать аккаунт</button>
      </div>
    )
  }

  return (
    <div style={{ padding: 20 }}>
      {mode === 'login' ? (
        <form onSubmit={handleLogin}>
          <input name="username" placeholder="Логин" required />
          <input name="password" type="password" placeholder="Пароль" required />
          <button type="submit">Войти</button>
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
          <button type="submit">Создать аккаунт</button>
        </form>
      )}
      {error && <p style={{ color: 'red' }}>{error}</p>}
      <button onClick={() => setMode('choose')}>Назад</button>
    </div>
  )
}
