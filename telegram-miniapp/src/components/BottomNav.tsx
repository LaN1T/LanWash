import { Link, useLocation } from 'react-router-dom'
import { useAuthStore } from '../stores/authStore'

function HomeIcon({ active }: { active: boolean }) {
  const color = active ? '#1A56DB' : '#64748B'
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
      <polyline points="9 22 9 12 15 12 15 22"/>
    </svg>
  )
}

function BookingsIcon({ active }: { active: boolean }) {
  const color = active ? '#1A56DB' : '#64748B'
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
      <polyline points="14 2 14 8 20 8"/>
      <line x1="16" y1="13" x2="8" y2="13"/>
      <line x1="16" y1="17" x2="8" y2="17"/>
      <polyline points="10 9 9 9 8 9"/>
    </svg>
  )
}

function ProfileIcon({ active }: { active: boolean }) {
  const color = active ? '#1A56DB' : '#64748B'
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
      <circle cx="12" cy="7" r="4"/>
    </svg>
  )
}

export default function BottomNav() {
  const { user } = useAuthStore()
  const location = useLocation()
  const isClient = user?.role === 'client' || !user?.role

  if (!isClient) return null

  const navItems = [
    { path: '/', label: 'Главная', Icon: HomeIcon },
    { path: '/bookings', label: 'Записи', Icon: BookingsIcon },
    { path: '/profile', label: 'Профиль', Icon: ProfileIcon },
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
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '2px',
              color: isActive ? '#1A56DB' : '#64748B',
              fontSize: '11px',
              fontWeight: isActive ? 600 : 500,
              textDecoration: 'none',
              padding: '4px 16px',
            }}
          >
            <item.Icon active={isActive} />
            <span>{item.label}</span>
          </Link>
        )
      })}
    </nav>
  )
}
