import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../stores/authStore'
import { getUserStats } from '../../services/profile'
import { logoutBackend } from '../../services/auth'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function WasherProfilePage() {
  useRoleGuard(['washer'])
  const navigate = useNavigate()
  const { user, logout } = useAuthStore()
  const [stats, setStats] = useState<import('../../services/profile').UserStats | null>(null)

  useEffect(() => {
    if (!user) return
    getUserStats(user.username)
      .then(setStats)
      .catch((err) => console.error('stats error', err))
  }, [user])

  const handleLogout = async () => {
    if (!window.confirm('Выйти из аккаунта?')) return
    try {
      await logoutBackend()
    } catch {
      // ignore
    }
    await logout()
    navigate('/auth')
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Профиль</h2>

      <div
        style={{
          background: '#fff',
          borderRadius: 16,
          padding: 16,
          marginBottom: 16,
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 700, color: '#0F172A', marginBottom: 4 }}>
          {user?.displayName || user?.username}
        </div>
        <div style={{ fontSize: 14, color: '#64748B', marginBottom: 8 }}>@{user?.username}</div>
        <div style={{ fontSize: 13, color: '#1A56DB', fontWeight: 600 }}>Мойщик</div>
      </div>

      {stats && (
        <div
          style={{
            background: '#fff',
            borderRadius: 16,
            padding: 16,
            marginBottom: 16,
            border: '1px solid #E2E8F0',
            boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ color: '#64748B' }}>Всего записей</span>
            <strong>{stats.totalAppointments}</strong>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ color: '#64748B' }}>Уровень</span>
            <strong>{stats.level}</strong>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: '#64748B' }}>Баллы</span>
            <strong>{stats.points}</strong>
          </div>
        </div>
      )}

      <button
        onClick={handleLogout}
        style={{
          width: '100%',
          padding: '14px 0',
          borderRadius: 12,
          border: '1px solid #DC2626',
          background: '#fff',
          color: '#DC2626',
          fontWeight: 700,
          fontSize: 16,
          cursor: 'pointer',
        }}
      >
        Выйти из аккаунта
      </button>
    </div>
  )
}