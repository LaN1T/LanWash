import { useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../stores/authStore'
import { useWasherStore } from '../../stores/washerStore'
import { getWasherAppointments } from '../../services/washer'
import { updateAppointmentStatus } from '../../services/appointments'
import { statusMap } from '../../utils/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'
import WeekCalendar from '../../components/WeekCalendar'
import AppointmentCard from '../../components/AppointmentCard'

export default function WasherHomePage() {
  useRoleGuard(['washer'])
  const navigate = useNavigate()
  const { user } = useAuthStore()
  const { appointments, selectedDate, loading, error, setAppointments, setSelectedDate, setLoading, setError } =
    useWasherStore()

  const todayStr = useMemo(() => new Date().toISOString().split('T')[0], [])

  useEffect(() => {
    if (!selectedDate) {
      setSelectedDate(todayStr)
    }
  }, [selectedDate, todayStr, setSelectedDate])

  useEffect(() => {
    if (!user || !selectedDate) return
    const controller = new AbortController()
    setLoading(true)
    setError(null)
    getWasherAppointments(user.username, controller.signal)
      .then((list) => {
        const filtered = list.filter((a) => a.dateTime.startsWith(selectedDate))
        setAppointments(filtered)
      })
      .catch((err) => {
        if (err.name !== 'AbortError') setError('Не удалось загрузить записи')
      })
      .finally(() => setLoading(false))
    return () => controller.abort()
  }, [user, selectedDate, setAppointments, setLoading, setError])

  const nextAppointment = useMemo(() => {
    const now = new Date().toISOString()
    return appointments
      .filter((a) => ['scheduled', 'confirmed'].includes(a.status) && a.dateTime >= now)
      .sort((a, b) => a.dateTime.localeCompare(b.dateTime))[0]
  }, [appointments])

  const handleStart = async (id: string) => {
    try {
      await updateAppointmentStatus(id, 'in_progress')
      setAppointments(appointments.map((a) => (a.id === id ? { ...a, status: 'in_progress' } : a)))
    } catch {
      alert('Ошибка обновления статуса')
    }
  }

  const handleComplete = async (id: string) => {
    try {
      await updateAppointmentStatus(id, 'completed')
      setAppointments(appointments.map((a) => (a.id === id ? { ...a, status: 'completed' } : a)))
    } catch {
      alert('Ошибка завершения записи')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 8px', fontSize: 22, color: '#0F172A' }}>
        Привет, {user?.displayName || user?.username || 'мойщик'} 👋
      </h2>
      <p style={{ margin: '0 0 16px', color: '#64748B' }}>Сегодня записей: {appointments.length}</p>

      <WeekCalendar onSelect={setSelectedDate} />

      {loading ? (
        <p style={{ marginTop: 20 }}>Загрузка...</p>
      ) : error ? (
        <p style={{ marginTop: 20, color: '#DC2626' }}>{error}</p>
      ) : (
        <div style={{ marginTop: 20 }}>
          {nextAppointment && (
            <div
              style={{
                background: '#FFFFFF',
                borderRadius: 16,
                padding: 16,
                marginBottom: 16,
                border: '1px solid #E2E8F0',
                boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
              }}
            >
              <div style={{ fontSize: 13, color: '#64748B', marginBottom: 4 }}>Следующая запись</div>
              <div style={{ fontWeight: 700, fontSize: 18, color: '#0F172A', marginBottom: 4 }}>
                {new Date(nextAppointment.dateTime).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
              </div>
              <div style={{ fontSize: 15, color: '#0F172A', marginBottom: 8 }}>
                {nextAppointment.carModel} · {nextAppointment.carNumber}
              </div>
              <div
                style={{
                  display: 'inline-block',
                  background: statusMap[nextAppointment.status].bg,
                  color: statusMap[nextAppointment.status].color,
                  padding: '4px 10px',
                  borderRadius: 6,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                {statusMap[nextAppointment.status].label}
              </div>
            </div>
          )}

          {appointments.length === 0 ? (
            <p style={{ color: '#64748B' }}>Нет записей на выбранный день</p>
          ) : (
            appointments.map((appt) => (
              <div key={appt.id} style={{ marginBottom: 12 }}>
                <div onClick={() => navigate(`/appointments/${appt.id}`)}>
                  <AppointmentCard appointment={appt} />
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  {appt.status === 'confirmed' && (
                    <button
                      onClick={() => handleStart(appt.id)}
                      style={{
                        flex: 1,
                        padding: '10px 0',
                        borderRadius: 10,
                        border: 'none',
                        background: '#F59E0B',
                        color: '#fff',
                        fontWeight: 600,
                        cursor: 'pointer',
                      }}
                    >
                      Начать мойку
                    </button>
                  )}
                  {appt.status === 'in_progress' && (
                    <button
                      onClick={() => handleComplete(appt.id)}
                      style={{
                        flex: 1,
                        padding: '10px 0',
                        borderRadius: 10,
                        border: 'none',
                        background: '#10B981',
                        color: '#fff',
                        fontWeight: 600,
                        cursor: 'pointer',
                      }}
                    >
                      Завершить
                    </button>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}