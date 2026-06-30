import { useEffect, useMemo, useState } from 'react'
import { useAuthStore } from '../../stores/authStore'
import { getMyShifts, getAvailability, updateAvailability, deleteAvailability } from '../../services/washer'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function WasherSchedulePage() {
  useRoleGuard(['washer'])
  const { user } = useAuthStore()
  const [shifts, setShifts] = useState<import('../../services/washer').Shift[]>([])
  const [availability, setAvailability] = useState<import('../../services/washer').WasherAvailability[]>([])
  const [loading, setLoading] = useState(false)
  const [selectedDate, setSelectedDate] = useState('')
  const [selectedStatus, setSelectedStatus] = useState<'available' | 'unavailable'>('available')

  const todayStr = useMemo(() => new Date().toISOString().split('T')[0], [])

  useEffect(() => {
    if (!selectedDate) setSelectedDate(todayStr)
  }, [selectedDate, todayStr])

  const fetchData = (signal?: AbortSignal) => {
    if (!user) return
    setLoading(true)
    Promise.all([
      getMyShifts(signal),
      getAvailability(user.id, { start_date: todayStr, end_date: getOffsetDate(30) }, signal),
    ])
      .then(([shiftsData, availData]) => {
        setShifts(shiftsData)
        setAvailability(availData)
      })
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить расписание')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchData(controller.signal)
    return () => controller.abort()
  }, [user])

  const handleSetAvailability = async () => {
    if (!user || !selectedDate) return
    try {
      await updateAvailability(user.id, [{ date: selectedDate, status: selectedStatus }])
      fetchData()
    } catch {
      alert('Ошибка сохранения доступности')
    }
  }

  const handleDeleteAvailability = async () => {
    if (!user || !selectedDate) return
    try {
      await deleteAvailability(user.id, { start_date: selectedDate, end_date: selectedDate })
      fetchData()
    } catch {
      alert('Ошибка удаления')
    }
  }

  const availForSelected = availability.find((a) => a.date === selectedDate)

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Моё расписание</h2>

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
        <label style={{ fontSize: 14, color: '#64748B' }}>Выберите дату</label>
        <input
          type="date"
          value={selectedDate}
          onChange={(e) => setSelectedDate(e.target.value)}
          style={{
            width: '100%',
            padding: 10,
            borderRadius: 8,
            border: '1px solid #E2E8F0',
            marginTop: 6,
            marginBottom: 12,
            boxSizing: 'border-box',
          }}
        />

        <div style={{ marginBottom: 12 }}>
          <label style={{ fontSize: 14, color: '#64748B', marginRight: 12 }}>Статус:</label>
          <select
            value={selectedStatus}
            onChange={(e) => setSelectedStatus(e.target.value as 'available' | 'unavailable')}
            style={{ padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
          >
            <option value="available">Доступен</option>
            <option value="unavailable">Недоступен</option>
          </select>
        </div>

        {availForSelected && (
          <div style={{ marginBottom: 12, fontSize: 14, color: '#64748B' }}>
            Текущий статус: <strong>{availForSelected.status}</strong>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8 }}>
          <button
            onClick={handleSetAvailability}
            style={{
              flex: 1,
              padding: '10px 0',
              borderRadius: 8,
              border: 'none',
              background: '#1A56DB',
              color: '#fff',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Сохранить
          </button>
          <button
            onClick={handleDeleteAvailability}
            style={{
              flex: 1,
              padding: '10px 0',
              borderRadius: 8,
              border: '1px solid #DC2626',
              background: '#fff',
              color: '#DC2626',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Очистить
          </button>
        </div>
      </div>

      <h3 style={{ fontSize: 18, color: '#0F172A', marginBottom: 12 }}>Смены</h3>
      {loading ? (
        <p>Загрузка...</p>
      ) : shifts.length === 0 ? (
        <p style={{ color: '#64748B' }}>Смен не назначено</p>
      ) : (
        shifts.map((shift) => (
          <div
            key={shift.id}
            style={{
              background: '#fff',
              borderRadius: 16,
              padding: 16,
              marginBottom: 12,
              border: '1px solid #E2E8F0',
              boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
            }}
          >
            <div style={{ fontWeight: 600, color: '#0F172A', marginBottom: 4 }}>
              {new Date(shift.date).toLocaleDateString('ru-RU')}
            </div>
            <div style={{ fontSize: 14, color: '#64748B' }}>
              {shift.startTime} — {shift.endTime}
            </div>
            <div
              style={{
                marginTop: 8,
                display: 'inline-block',
                padding: '4px 10px',
                borderRadius: 6,
                fontSize: 12,
                fontWeight: 600,
                background: shift.status === 'approved' ? '#ECFDF5' : '#FEF2F2',
                color: shift.status === 'approved' ? '#059669' : '#DC2626',
              }}
            >
              {shift.status}
            </div>
          </div>
        ))
      )}
    </div>
  )
}

function getOffsetDate(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return d.toISOString().split('T')[0]
}