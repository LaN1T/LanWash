import { Link } from 'react-router-dom'
import { useAuthStore } from '../../stores/authStore'

export default function HomePage() {
  const { user } = useAuthStore()

  return (
    <div style={{ padding: 20 }}>
      <h1 style={{ marginBottom: 8 }}>
        Привет, {user?.displayName || 'друг'}! 👋
      </h1>
      <p style={{ color: 'var(--tg-theme-hint-color)', marginBottom: 24 }}>
        Запишись на мойку за 2 минуты
      </p>

      <Link to="/booking" style={{ textDecoration: 'none' }}>
        <button
          style={{
            width: '100%',
            padding: 16,
            fontSize: 18,
            fontWeight: 'bold',
            marginBottom: 16,
          }}
        >
          🚿 Записаться на мойку
        </button>
      </Link>

      <div
        style={{
          background: 'var(--tg-theme-secondary-bg-color)',
          borderRadius: 12,
          padding: 16,
        }}
      >
        <h3 style={{ marginBottom: 8 }}>📍 Как это работает</h3>
        <ol style={{ paddingLeft: 20, lineHeight: 1.6 }}>
          <li>Выберите тип мойки и доп. услуги</li>
          <li>Выберите удобное время</li>
          <li>Приезжайте — мы всё сделаем!</li>
        </ol>
      </div>
    </div>
  )
}