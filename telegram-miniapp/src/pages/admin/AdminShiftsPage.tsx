import { useEffect, useMemo, useState } from 'react'
import { getShifts, approveShift, rejectShift, reopenShift, deleteShift } from '../../services/shifts'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminShiftsPage() {
  useRoleGuard(['admin'])
  const [shifts, setShifts] = useState<import('../../services/shifts').Shift[]>([])
  const [loading, setLoading] = useState(false)

  const { startDate, endDate } = useMemo(() => {
    const today = new Date()
    const start = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0]
    const end = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0]
    return { startDate: start, endDate: end }
  }, [])

  const fetchShifts = (signal?: AbortSignal) => {
    setLoading(true)
    getShifts(startDate, endDate, signal)
      .then(setShifts)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить смены')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchShifts(controller.signal)
    return () => controller.abort()
  }, [startDate, endDate])

  const handleAction = async (action: 'approve' | 'reject' | 'reopen' | 'delete', id: number) => {
    try {
      if (action === 'approve') await approveShift(id)
      if (action === 'reject') await rejectShift(id)
      if (action === 'reopen') await reopenShift(id)
      if (action === 'delete') {
        if (!window.confirm('Удалить смену?')) return
        await deleteShift(id)
      }
      fetchShifts()
    } catch {
      alert('Ошибка')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Смены</h2>

      {loading ? (
        <p>Загрузка...</p>
      ) : shifts.length === 0 ? (
        <p style={{ color: '#64748B' }}>Смен нет</p>
      ) : (
        shifts.map((shift) => (
          <div
            key={shift.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <strong style={{ color: '#0F172A' }}>{new Date(shift.date).toLocaleDateString('ru-RU')}</strong>
              <span
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: shift.status === 'approved' ? '#059669' : shift.status === 'rejected' ? '#DC2626' : '#F59E0B',
                }}
              >
                {shift.status}
              </span>
            </div>
            <div style={{ fontSize: 14, color: '#64748B', marginBottom: 8 }}>
              {shift.startTime} — {shift.endTime}
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              {shift.status !== 'approved' && (
                <button
                  onClick={() => handleAction('approve', shift.id)}
                  style={{
                    padding: '6px 10px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#10B981',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Одобрить
                </button>
              )}
              {shift.status !== 'rejected' && (
                <button
                  onClick={() => handleAction('reject', shift.id)}
                  style={{
                    padding: '6px 10px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#DC2626',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Отклонить
                </button>
              )}
              <button
                onClick={() => handleAction('reopen', shift.id)}
                style={{
                  padding: '6px 10px',
                  borderRadius: 6,
                  border: '1px solid #64748B',
                  background: '#fff',
                  color: '#64748B',
                  cursor: 'pointer',
                }}
              >
                Пересмотр
              </button>
              <button
                onClick={() => handleAction('delete', shift.id)}
                style={{
                  padding: '6px 10px',
                  borderRadius: 6,
                  border: 'none',
                  background: '#FEF2F2',
                  color: '#DC2626',
                  cursor: 'pointer',
                }}
              >
                Удалить
              </button>
            </div>
          </div>
        ))
      )}
    </div>
  )
}