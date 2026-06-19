import { useEffect, useState } from 'react'
import { useAuthStore } from '../../stores/authStore'
import { api } from '../../services/api'

interface UserStats {
  totalAppointments: number
  totalSpent: number
  favoriteWashType: string
  level: string
  levelProgress: number
  points: number
}

export default function ProfilePage() {
  const { user, logout } = useAuthStore()
  const [stats, setStats] = useState<UserStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (user?.username) {
      api.get(`/auth/stats/${encodeURIComponent(user.username)}`).then((res) => {
        setStats(res.data)
        setLoading(false)
      }).catch(() => {
        setLoading(false)
      })
    }
  }, [user?.username])

  const infoRow = (label: string, value: string) => (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '14px 0', borderBottom: '1px solid #E2E8F0' }}>
      <span style={{ fontSize: 14, color: '#64748B' }}>{label}</span>
      <span style={{ fontSize: 14, fontWeight: 500, color: '#0F172A' }}>{value || '—'}</span>
    </div>
  )

  return (
    <div style={{ padding: 16 }}>
      {/* Avatar + Name */}
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: 24,
          marginBottom: 16,
          textAlign: 'center',
        }}
      >
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #1A56DB 0%, #3B82F6 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 16px',
            color: 'white',
            fontSize: 28,
            fontWeight: 700,
            boxShadow: '0 8px 24px rgba(26, 86, 219, 0.35)',
          }}
        >
          {(user?.displayName || 'U').charAt(0).toUpperCase()}
        </div>
        <div style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 4 }}>
          {user?.displayName || 'Пользователь'}
        </div>
        <div
          style={{
            display: 'inline-block',
            padding: '4px 12px',
            borderRadius: 8,
            background: '#EFF4FF',
            color: '#1A56DB',
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          {user?.role === 'washer' ? 'Мойщик' : 'Клиент'}
        </div>
      </div>

      {/* Stats Card */}
      {!loading && stats && (
        <div
          style={{
            background: '#FFFFFF',
            borderRadius: 16,
            border: '1px solid #E2E8F0',
            boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
            padding: 20,
            marginBottom: 16,
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#0F172A' }}>{stats.level}</div>
            <div style={{ fontSize: 12, color: '#64748B' }}>{stats.points} баллов</div>
          </div>
          <div
            style={{
              height: 8,
              borderRadius: 4,
              background: '#F1F5F9',
              overflow: 'hidden',
              marginBottom: 12,
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${stats.levelProgress}%`,
                borderRadius: 4,
                background: 'linear-gradient(90deg, #1A56DB, #3B82F6)',
                transition: 'width 0.5s ease',
              }}
            />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginTop: 16 }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#1A56DB' }}>{stats.totalAppointments}</div>
              <div style={{ fontSize: 12, color: '#64748B' }}>Всего записей</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 700, color: '#059669' }}>{stats.totalSpent}₽</div>
              <div style={{ fontSize: 12, color: '#64748B' }}>Потрачено</div>
            </div>
          </div>
        </div>
      )}

      {/* Info Card */}
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: '8px 20px 0',
          marginBottom: 16,
        }}
      >
        <div style={{ fontSize: 11, fontWeight: 600, color: '#64748B', letterSpacing: 0.8, padding: '12px 0 8px' }}>
          ЛИЧНЫЕ ДАННЫЕ
        </div>
        {infoRow('Телефон', user?.phone || '')}
        {infoRow('Автомобиль', user?.carModel || '')}
        {infoRow('Госномер', user?.carNumber || '')}
        {infoRow('Логин', user?.username || '')}
      </div>

      {/* Logout */}
      <button
        onClick={logout}
        style={{
          width: '100%',
          padding: '16px 24px',
          borderRadius: 12,
          background: '#FFFFFF',
          color: '#DC2626',
          fontSize: 15,
          fontWeight: 600,
          border: '1px solid #E2E8F0',
          cursor: 'pointer',
        }}
      >
        Выйти из аккаунта
      </button>
    </div>
  )
}
