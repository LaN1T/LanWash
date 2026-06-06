import { Link, useLocation } from 'react-router-dom'
import { useAuthStore } from '../stores/authStore'

export default function BottomNav() {
  const { user } = useAuthStore()
  const location = useLocation()
  const isClient = user?.role === 'client' || !user?.role

  if (!isClient) return null

  const navItems = [
    { path: '/', label: 'Главная' },
    { path: '/bookings', label: 'Записи' },
    { path: '/profile', label: 'Профиль' },
  ]

  return (
    <nav
      style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'space-around',
        padding: '10px 0',
        background: 'var(--tg-theme-secondary-bg-color)',
        borderTop: '1px solid var(--tg-theme-hint-color)',
      }}
    >
      {navItems.map((item) => (
        <Link
          key={item.path}
          to={item.path}
          style={{
            color:
              location.pathname === item.path
                ? 'var(--tg-theme-button-color)'
                : 'var(--tg-theme-text-color)',
            textDecoration: 'none',
            fontSize: 14,
          }}
        >
          {item.label}
        </Link>
      ))}
    </nav>
  )
}