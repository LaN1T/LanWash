import { useEffect, useState } from 'react'
import { api } from '../../services/api'
import AppointmentCard from '../../components/AppointmentCard'

interface Appointment {
  id: string
  dateTime: string
  carModel: string
  carNumber: string
  status: string
  washTypeId: string
  box_index: number
}

export default function MyBookingsPage() {
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/appointments/').then((res) => {
      setAppointments(res.data)
      setLoading(false)
    })
  }, [])

  if (loading) return <div style={{ padding: 20 }}>Загрузка...</div>

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 16 }}>Мои записи</h2>
      {appointments.length === 0 ? (
        <p style={{ color: 'var(--tg-theme-hint-color)' }}>У вас пока нет записей</p>
      ) : (
        appointments.map((appt) => (
          <AppointmentCard key={appt.id} appointment={appt} />
        ))
      )}
    </div>
  )
}