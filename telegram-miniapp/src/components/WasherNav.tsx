import { Link, useLocation } from 'react-router-dom'
import { useAuthStore } from '../stores/authStore'

interface NavItem {
  path: string
  label: string
}

const navItems: NavItem[] = [
  { path: '/', label: 'Главная' },
  { path: '/appointments', label: 'Записи' },
  { path: '/qr', label: 'QR' },
  { path: '/tips', label: 'Чаевые' },
  { path: '/notes', label: 'Заметки' },
  { path: '/schedule', label: 'График' },
  { path: '/profile', label: 'Профиль' },
]

export default function WasherNav() {
  const { user } = useAuthStore()
  const location = useLocation()

  if (user?.role !== 'washer') return null

  return (
    <nav
      style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        display: 'flex',
        overflowX: 'auto',
        padding: '8px 0 24px',
        background: '#FFFFFF',
        borderTop: '1px solid #E2E8F0',
        boxShadow: '0 -4px 12px rgba(0, 0, 0, 0.05)',
        zIndex: 100,
      }}
    >
      {navItems.map((item) => {
        const isActive = location.pathname === item.path
        return (
          <Link
            key={item.path}
            to={item.path}
            style={{
              flex: '0 0 auto',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 2,
              minWidth: 64,
              color: isActive ? '#1A56DB' : '#64748B',
              fontSize: 11,
              fontWeight: isActive ? 600 : 500,
              textDecoration: 'none',
              padding: '4px 12px',
            }}
          >
            <span>{item.label}</span>
          </Link>
        )
      })}
    </nav>
  )
}
