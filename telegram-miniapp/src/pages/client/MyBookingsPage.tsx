import { useEffect, useRef, useState, memo } from 'react'
import { Link } from 'react-router-dom'
import { getMyAppointments, type Appointment } from '../../services/appointments'
import { connectAppointmentsSocket } from '../../services/appointmentSocket'
import { useAuthStore } from '../../stores/authStore'
import { type AppointmentStatus } from '../../utils/appointments'
import AppointmentCard from '../../components/AppointmentCard'

type Tab = 'active' | 'history'

type SocketStatus = 'connecting' | 'open' | 'error' | 'closed'

const ACTIVE_STATUSES = new Set<AppointmentStatus>(['scheduled', 'confirmed', 'in_progress'])

interface TabButtonProps {
  value: Tab
  label: string
  active: boolean
  onClick: () => void
}

const TabButton = memo(function TabButton({ label, active, onClick }: TabButtonProps) {
  return (
    <button
      onClick={onClick}
      style={{
        flex: 1,
        padding: '10px 0',
        borderRadius: 10,
        border: 'none',
        background: active ? '#1A56DB' : 'transparent',
        color: active ? '#FFFFFF' : '#64748B',
        fontSize: 14,
        fontWeight: 600,
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
    >
      {label}
    </button>
  )
})

function sortByDateTimeDesc(list: Appointment[]): Appointment[] {
  return [...list].sort(
    (a, b) => new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime(),
  )
}

export default function MyBookingsPage() {
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [tab, setTab] = useState<Tab>('active')
  const [socketStatus, setSocketStatus] = useState<SocketStatus>('connecting')
  const token = useAuthStore((state) => state.token)

  const socketUpdateTimesRef = useRef<Map<string, number>>(new Map())
  const httpRequestStartRef = useRef<number>(0)

  useEffect(() => {
    if (!token) return

    const cleanup = connectAppointmentsSocket(token, {
      onUpdate: (updated) => {
        socketUpdateTimesRef.current.set(updated.id, Date.now())
        setAppointments((prev) => {
          const existingIndex = prev.findIndex((appt) => appt.id === updated.id)
          let next: Appointment[]
          if (existingIndex === -1) {
            next = [updated, ...prev]
          } else {
            next = [...prev]
            next[existingIndex] = updated
          }
          return sortByDateTimeDesc(next)
        })
      },
      onStatusChange: setSocketStatus,
    })

    return cleanup
  }, [token])

  const load = () => {
    const controller = new AbortController()
    const signal = controller.signal
    const requestStart = Date.now()
    httpRequestStartRef.current = requestStart

    setLoading(true)
    setError(null)

    getMyAppointments({}, signal)
      .then((data) => {
        if (signal.aborted) return
        const httpList = data || []
        setAppointments((prev) => {
          const httpMap = new Map(httpList.map((appt) => [appt.id, appt]))
          const next: Appointment[] = []

          for (const appt of prev) {
            const socketUpdatedAt = socketUpdateTimesRef.current.get(appt.id)
            if (socketUpdatedAt && socketUpdatedAt > requestStart) {
              next.push(appt)
              continue
            }
            const httpAppt = httpMap.get(appt.id)
            if (httpAppt) {
              next.push(httpAppt)
              httpMap.delete(appt.id)
            } else {
              next.push(appt)
            }
          }

          for (const httpAppt of httpMap.values()) {
            next.push(httpAppt)
          }

          return sortByDateTimeDesc(next)
        })
      })
      .catch((err) => {
        if (signal.aborted) return
        setAppointments([])
        setError(err instanceof Error ? err.message : 'Не удалось загрузить записи')
      })
      .finally(() => {
        if (!signal.aborted) setLoading(false)
      })

    return () => {
      controller.abort()
    }
  }

  useEffect(() => {
    const cleanup = load()
    return cleanup
  }, [])

  const filtered = appointments.filter((appt) =>
    tab === 'active' ? ACTIVE_STATUSES.has(appt.status) : !ACTIVE_STATUSES.has(appt.status),
  )

  const showSocketWarning = socketStatus === 'error' || socketStatus === 'closed'

  if (loading) {
    return (
      <div style={{ padding: 16 }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 16 }}>Мои записи</h2>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, background: '#F1F5F9', borderRadius: 12, padding: 4 }}>
          <TabButton value="active" label="Активные" active={tab === 'active'} onClick={() => setTab('active')} />
          <TabButton value="history" label="История" active={tab === 'history'} onClick={() => setTab('history')} />
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

      {showSocketWarning && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            marginBottom: 12,
            padding: '8px 12px',
            borderRadius: 10,
            background: '#FEF3C7',
            color: '#92400E',
            fontSize: 13,
            fontWeight: 500,
          }}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M1 4h22M1 12h22M1 20h22" />
          </svg>
          Обновления записей могут приходить с задержкой
        </div>
      )}

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, background: '#F1F5F9', borderRadius: 12, padding: 4 }}>
        <TabButton value="active" label="Активные" active={tab === 'active'} onClick={() => setTab('active')} />
        <TabButton value="history" label="История" active={tab === 'history'} onClick={() => setTab('history')} />
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
