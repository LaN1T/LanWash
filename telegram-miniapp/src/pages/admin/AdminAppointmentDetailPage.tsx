import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getAppointmentById, updateAppointmentStatus, assignWasher } from '../../services/appointments'
import { searchUsers } from '../../services/admin'
import { statusMap, type AppointmentStatus } from '../../utils/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminAppointmentDetailPage() {
  useRoleGuard(['admin'])
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [appointment, setAppointment] = useState<import('../../services/appointments').Appointment | null>(null)
  const [washers, setWashers] = useState<import('../../services/admin').UserListItem[]>([])
  const [loading, setLoading] = useState(false)
  const [selectedWasher, setSelectedWasher] = useState('')
  const [selectedStatus, setSelectedStatus] = useState<AppointmentStatus>('scheduled')
  const [notes, setNotes] = useState('')

  useEffect(() => {
    if (!id) return
    const controller = new AbortController()
    setLoading(true)
    Promise.all([
      getAppointmentById(id, controller.signal),
      searchUsers({ role: 'washer', limit: 100 }, controller.signal),
    ])
      .then(([appt, users]) => {
        setAppointment(appt)
        setNotes(appt.notes || '')
        setSelectedStatus(appt.status)
        setWashers(users.items)
      })
      .catch(() => alert('Не удалось загрузить данные'))
      .finally(() => setLoading(false))
    return () => controller.abort()
  }, [id])

  const handleAssign = async () => {
    if (!id || !selectedWasher) return
    try {
      const appt = await assignWasher(id, selectedWasher)
      setAppointment(appt)
    } catch {
      alert('Ошибка назначения мойщика')
    }
  }

  const handleUpdate = async () => {
    if (!id) return
    try {
      const appt = await updateAppointmentStatus(id, selectedStatus, notes)
      setAppointment(appt)
    } catch {
      alert('Ошибка обновления')
    }
  }

  const handleDelete = async () => {
    if (!id || !window.confirm('Удалить запись?')) return
    // No delete endpoint in services; use raw api
    try {
      const api = (await import('../../services/api')).api
      await api.delete(`/appointments/${id}`)
      navigate('/appointments')
    } catch {
      alert('Ошибка удаления')
    }
  }

  if (loading) return <p style={{ padding: 16 }}>Загрузка...</p>
  if (!appointment) return <p style={{ padding: 16 }}>Запись не найдена</p>

  const dt = new Date(appointment.dateTime)

  return (
    <div style={{ padding: 16, paddingBottom: 120 }}>
      <button
        onClick={() => navigate(-1)}
        style={{ marginBottom: 12, background: 'none', border: 'none', color: '#1A56DB', cursor: 'pointer' }}
      >
        ← Назад
      </button>

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
        <h2 style={{ margin: '0 0 12px', fontSize: 20, color: '#0F172A' }}>
          Запись #{appointment.id.slice(-6)}
        </h2>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Дата/время:</strong>{' '}
          {dt.toLocaleDateString('ru-RU')} {dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Клиент:</strong> {appointment.clientName}
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Авто:</strong> {appointment.carModel} · {appointment.carNumber}
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Бокс:</strong> {appointment.box_index + 1}
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Цена:</strong> {appointment.paidPrice} ₽ (со скидкой {appointment.promoPrice} ₽)
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Владелец:</strong> {appointment.ownerUsername}
        </div>
        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Мойщики:</strong>{' '}
          {(JSON.parse(appointment.assignedWasher || '[]') as string[]).join(', ') || '—'}
        </div>
      </div>

      <div
        style={{
          background: '#fff',
          borderRadius: 16,
          padding: 16,
          marginBottom: 16,
          border: '1px solid #E2E8F0',
        }}
      >
        <h3 style={{ margin: '0 0 12px', fontSize: 16, color: '#0F172A' }}>Назначить мойщика</h3>
        <div style={{ display: 'flex', gap: 8 }}>
          <select
            value={selectedWasher}
            onChange={(e) => setSelectedWasher(e.target.value)}
            style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
          >
            <option value="">Выберите мойщика</option>
            {washers.map((w) => (
              <option key={w.id} value={w.username}>
                {w.displayName || w.username}
              </option>
            ))}
          </select>
          <button
            onClick={handleAssign}
            disabled={!selectedWasher}
            style={{
              padding: '10px 14px',
              borderRadius: 8,
              border: 'none',
              background: '#1A56DB',
              color: '#fff',
              cursor: 'pointer',
            }}
          >
            Назначить
          </button>
        </div>
      </div>

      <div
        style={{
          background: '#fff',
          borderRadius: 16,
          padding: 16,
          marginBottom: 16,
          border: '1px solid #E2E8F0',
        }}
      >
        <h3 style={{ margin: '0 0 12px', fontSize: 16, color: '#0F172A' }}>Изменить статус / заметки</h3>
        <select
          value={selectedStatus}
          onChange={(e) => setSelectedStatus(e.target.value as AppointmentStatus)}
          style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #E2E8F0', marginBottom: 12 }}
        >
          {Object.entries(statusMap).map(([key, { label }]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Заметки"
          rows={3}
          style={{
            width: '100%',
            padding: 10,
            borderRadius: 8,
            border: '1px solid #E2E8F0',
            marginBottom: 12,
            resize: 'none',
            boxSizing: 'border-box',
          }}
        />
        <button
          onClick={handleUpdate}
          style={{
            width: '100%',
            padding: '12px 0',
            borderRadius: 10,
            border: 'none',
            background: '#F59E0B',
            color: '#fff',
            fontWeight: 700,
            cursor: 'pointer',
          }}
        >
          Сохранить
        </button>
      </div>

      <button
        onClick={handleDelete}
        style={{
          width: '100%',
          padding: '14px 0',
          borderRadius: 12,
          border: '1px solid #DC2626',
          background: '#fff',
          color: '#DC2626',
          fontWeight: 700,
          cursor: 'pointer',
        }}
      >
        Удалить запись
      </button>
    </div>
  )
}