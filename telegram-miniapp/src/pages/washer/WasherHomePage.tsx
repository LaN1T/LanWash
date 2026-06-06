import { useEffect, useState } from 'react'
import { api } from '../../services/api'
import WeekCalendar from '../../components/WeekCalendar'
import AppointmentCard from '../../components/AppointmentCard'

interface Appointment {
  id: string
  dateTime: string
  carModel: string
  carNumber: string
  status: string
  clientName: string
  box_index: number
}

export default function WasherHomePage() {
  const [selectedDate, setSelectedDate] = useState('')
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!selectedDate) return
    setLoading(true)
    api.get(`/appointments/by-washer/me?date=${selectedDate}`).then((res) => {
      setAppointments(res.data)
      setLoading(false)
    })
  }, [selectedDate])

  const updateStatus = async (id: string, status: string) => {
    try {
      await api.put(`/appointments/${id}`, { status })
      setAppointments((prev) =>
        prev.map((a) => (a.id === id ? { ...a, status } : a))
      )
    } catch (e) {
      alert('Ошибка обновления статуса')
    }
  }

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 16 }}>Мои записи</h2>
      <WeekCalendar onSelect={setSelectedDate} />

      {selectedDate && (
        <div style={{ marginTop: 20 }}>
          {loading ? (
            <p>Загрузка...</p>
          ) : appointments.length === 0 ? (
            <p style={{ color: 'var(--tg-theme-hint-color)' }}>Нет записей на этот день</p>
          ) : (
            appointments.map((appt) => (
              <div key={appt.id} style={{ marginBottom: 12 }}>
                <AppointmentCard appointment={appt} />
                {appt.status === 'scheduled' && (
                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <button
                      onClick={() => updateStatus(appt.id, 'in_progress')}
                      style={{ flex: 1, background: '#f5a623' }}
                    >
                      🚗 Начать
                    </button>
                  </div>
                )}
                {appt.status === 'in_progress' && (
                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <button
                      onClick={() => updateStatus(appt.id, 'completed')}
                      style={{ flex: 1, background: '#34c759' }}
                    >
                      ✅ Завершить
                    </button>
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}