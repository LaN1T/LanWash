import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../stores/authStore'
import { getWasherAppointments } from '../../services/washer'
import { type AppointmentStatus } from '../../utils/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'
import AppointmentCard from '../../components/AppointmentCard'

const activeStatuses: AppointmentStatus[] = ['scheduled', 'confirmed', 'in_progress']
const historyStatuses: AppointmentStatus[] = ['completed', 'cancelled']

export default function WasherAppointmentsPage() {
  useRoleGuard(['washer'])
  const navigate = useNavigate()
  const { user } = useAuthStore()
  const [activeTab, setActiveTab] = useState<'active' | 'history'>('active')
  const [appointments, setAppointments] = useState<import('../../services/appointments').Appointment[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const statuses = activeTab === 'active' ? activeStatuses : historyStatuses

  const fetchAppointments = (signal?: AbortSignal) => {
    if (!user) return
    setLoading(true)
    setError(null)
    getWasherAppointments(user.username, signal)
      .then((list) => setAppointments(list.sort((a, b) => b.dateTime.localeCompare(a.dateTime))))
      .catch((err) => {
        if (err.name !== 'AbortError') setError('Не удалось загрузить записи')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchAppointments(controller.signal)
    return () => controller.abort()
  }, [user])

  const filtered = useMemo(
    () => appointments.filter((a) => statuses.includes(a.status)),
    [appointments, statuses]
  )

  const handleRefresh = () => fetchAppointments()

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Мои записи</h2>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        {(['active', 'history'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            style={{
              flex: 1,
              padding: '10px 0',
              borderRadius: 10,
              border: 'none',
              background: activeTab === tab ? '#1A56DB' : '#F1F5F9',
              color: activeTab === tab ? '#fff' : '#64748B',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {tab === 'active' ? 'Активные' : 'История'}
          </button>
        ))}
      </div>

      <button
        onClick={handleRefresh}
        disabled={loading}
        style={{
          marginBottom: 12,
          padding: '8px 12px',
          borderRadius: 8,
          border: '1px solid #E2E8F0',
          background: '#fff',
          color: '#1A56DB',
          fontWeight: 500,
          cursor: 'pointer',
        }}
      >
        {loading ? 'Обновление...' : 'Обновить'}
      </button>

      {error && <p style={{ color: '#DC2626', marginBottom: 12 }}>{error}</p>}

      {filtered.length === 0 && !loading ? (
        <p style={{ color: '#64748B' }}>Записей не найдено</p>
      ) : (
        filtered.map((appt) => (
          <div key={appt.id} onClick={() => navigate(`/appointments/${appt.id}`)} style={{ marginBottom: 12 }}>
            <AppointmentCard appointment={appt} />
          </div>
        ))
      )}
    </div>
  )
}