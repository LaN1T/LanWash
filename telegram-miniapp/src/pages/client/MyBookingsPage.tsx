import { useEffect, useState } from 'react'
import { api } from '../../services/api'
import { useAuthStore } from '../../stores/authStore'
import AppointmentCard from '../../components/AppointmentCard'

interface Appointment {
  id: string
  dateTime: string
  carModel: string
  carNumber: string
  status: string
  box_index: number | null
}

export default function MyBookingsPage() {
  const { user } = useAuthStore()
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const username = user?.username
    if (!username) {
      setLoading(false)
      return
    }
    api.get(`/appointments/by-owner/${username}`).then((res) => {
      // Sort by date descending
      const sorted = (res.data || []).sort((a: Appointment, b: Appointment) =>
        new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime()
      )
      setAppointments(sorted)
      setLoading(false)
    }).catch(() => {
      setAppointments([])
      setLoading(false)
    })
  }, [])

  if (loading) {
    return (
      <div style={{ padding: 16 }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, color: '#0F172A', marginBottom: 16 }}>Мои записи</h2>
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
      {appointments.length === 0 ? (
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
          <p style={{ fontSize: 15, fontWeight: 500 }}>У вас пока нет записей</p>
          <p style={{ fontSize: 13, marginTop: 4 }}>Запишитесь на мойку в пару касаний</p>
        </div>
      ) : (
        appointments.map((appt) => (
          <AppointmentCard key={appt.id} appointment={appt} />
        ))
      )}
    </div>
  )
}
