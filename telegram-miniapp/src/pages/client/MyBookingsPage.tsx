import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { getMyAppointments, type Appointment } from '../../services/appointments'
import { type AppointmentStatus } from '../../utils/appointments'
import AppointmentCard from '../../components/AppointmentCard'

type Tab = 'active' | 'history'

const ACTIVE_STATUSES = new Set<AppointmentStatus>(['scheduled', 'confirmed', 'in_progress'])

export default function MyBookingsPage() {
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [tab, setTab] = useState<Tab>('active')

  const load = () => {
    let mounted = true
    setLoading(true)
    setError(null)
    getMyAppointments()
      .then((data) => {
        if (!mounted) return
        const sorted = (data || []).sort(
          (a: Appointment, b: Appointment) =>
            new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime(),
        )
        setAppointments(sorted)
      })
      .catch((err) => {
        if (!mounted) return
        setAppointments([])
        setError(err instanceof Error ? err.message : 'Не удалось загрузить записи')
      })
      .finally(() => {
        if (mounted) setLoading(false)
      })
    return () => {
      mounted = false
    }
  }

  useEffect(load, [])

  const filtered = appointments.filter((appt) =>
    tab === 'active' ? ACTIVE_STATUSES.has(appt.status) : !ACTIVE_STATUSES.has(appt.status),
  )

  const TabButton = ({ value, label }: { value: Tab; label: string }) => (
    <button
      onClick={() => setTab(value)}
      style={{
        flex: 1,
        padding: '10px 0',
        borderRadius: 10,
        border: 'none',
        background: tab === value ? '#1A56DB' : 'transparent',
        color: tab === value ? '#FFFFFF' : '#64748B',
        fontSize: 14,
        fontWeight: 600,
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
    >
      {label}
    </button>
  )

  if (loading) {
    return (
      <div style={{ padding: 16 }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 16 }}>Мои записи</h2>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, background: '#F1F5F9', borderRadius: 12, padding: 4 }}>
          <TabButton value="active" label="Активные" />
          <TabButton value="history" label="История" />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              style={{
                height: 120,
                borderRadius: 16,
                background: '#F1F5F9',
              }}
            />
          ))}
        </div>
      </div>
    )
  }

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 16 }}>Мои записи</h2>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, background: '#F1F5F9', borderRadius: 12, padding: 4 }}>
        <TabButton value="active" label="Активные" />
        <TabButton value="history" label="История" />
      </div>

      {error ? (
        <div
          style={{
            textAlign: 'center',
            padding: 40,
            color: '#64748B',
          }}
        >
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ADB5C8" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginBottom: 12 }}>
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="8" x2="12" y2="12"/>
            <line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          <p style={{ fontSize: 15, fontWeight: 500, color: '#B91C1C' }}>{error}</p>
          <button
            onClick={load}
            style={{
              marginTop: 12,
              padding: '10px 20px',
              borderRadius: 10,
              border: 'none',
              background: '#1A56DB',
              color: '#FFFFFF',
              fontSize: 14,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Повторить
          </button>
        </div>
      ) : filtered.length === 0 ? (
        <div
          style={{
            textAlign: 'center',
            padding: 40,
            color: '#64748B',
          }}
        >
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ADB5C8" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginBottom: 12 }}>
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
          <p style={{ fontSize: 15, fontWeight: 500 }}>
            {tab === 'active' ? 'Нет активных записей' : 'История записей пуста'}
          </p>
          <p style={{ fontSize: 13, marginTop: 4 }}>Запишитесь на мойку в пару касаний</p>
        </div>
      ) : (
        filtered.map((appt) => (
          <Link key={appt.id} to={`/bookings/${appt.id}`} style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}>
            <AppointmentCard appointment={appt} />
          </Link>
        ))
      )}
    </div>
  )
}
