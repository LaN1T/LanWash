import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getAppointmentById, updateAppointmentStatus, scanQr } from '../../services/appointments'
import { statusMap } from '../../utils/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function WasherAppointmentDetailPage() {
  useRoleGuard(['washer'])
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [appointment, setAppointment] = useState<import('../../services/appointments').Appointment | null>(null)
  const [loading, setLoading] = useState(false)
  const [notes, setNotes] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!id) return
    const controller = new AbortController()
    setLoading(true)
    getAppointmentById(id, controller.signal)
      .then((appt) => {
        setAppointment(appt)
        setNotes(appt.notes || '')
      })
      .catch(() => alert('Не удалось загрузить запись'))
      .finally(() => setLoading(false))
    return () => controller.abort()
  }, [id])

  const handleStatus = async (status: 'in_progress' | 'completed') => {
    if (!id || !appointment) return
    setSaving(true)
    try {
      const appt = await updateAppointmentStatus(id, status, notes)
      setAppointment(appt)
    } catch {
      alert('Ошибка обновления статуса')
    } finally {
      setSaving(false)
    }
  }

  const handleQrDone = async () => {
    if (!id) return
    setSaving(true)
    try {
      await scanQr(id)
      const appt = await updateAppointmentStatus(id, 'in_progress', notes)
      setAppointment(appt)
    } catch {
      alert('Ошибка обработки QR')
    } finally {
      setSaving(false)
    }
  }

  const saveNotes = async () => {
    if (!id || !appointment) return
    setSaving(true)
    try {
      const appt = await updateAppointmentStatus(id, appointment.status, notes)
      setAppointment(appt)
    } catch {
      alert('Ошибка сохранения заметок')
    } finally {
      setSaving(false)
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
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
          <h2 style={{ margin: 0, fontSize: 20, color: '#0F172A' }}>Запись #{appointment.id.slice(-6)}</h2>
          <span
            style={{
              background: statusMap[appointment.status].bg,
              color: statusMap[appointment.status].color,
              padding: '4px 10px',
              borderRadius: 6,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            {statusMap[appointment.status].label}
          </span>
        </div>

        <div style={{ fontSize: 15, marginBottom: 8 }}>
          <strong>Дата и время:</strong>{' '}
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
          <strong>Стоимость:</strong> {appointment.paidPrice} ₽
        </div>

        <label style={{ display: 'block', marginTop: 16, fontSize: 14, color: '#64748B' }}>Заметки</label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={3}
          style={{
            width: '100%',
            marginTop: 6,
            padding: 10,
            borderRadius: 10,
            border: '1px solid #E2E8F0',
            fontSize: 14,
            resize: 'none',
            boxSizing: 'border-box',
          }}
        />
        <button
          onClick={saveNotes}
          disabled={saving}
          style={{
            marginTop: 8,
            padding: '8px 14px',
            borderRadius: 8,
            border: 'none',
            background: '#E2E8F0',
            color: '#0F172A',
            fontWeight: 500,
            cursor: 'pointer',
          }}
        >
          Сохранить заметки
        </button>
      </div>

      <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {appointment.status === 'confirmed' && (
          <>
            <button
              onClick={() => handleStatus('in_progress')}
              disabled={saving}
              style={{
                padding: '14px 0',
                borderRadius: 12,
                border: 'none',
                background: '#F59E0B',
                color: '#fff',
                fontWeight: 700,
                fontSize: 16,
                cursor: 'pointer',
              }}
            >
              Начать мойку
            </button>
            <button
              onClick={handleQrDone}
              disabled={saving}
              style={{
                padding: '14px 0',
                borderRadius: 12,
                border: '1px solid #1A56DB',
                background: '#fff',
                color: '#1A56DB',
                fontWeight: 700,
                fontSize: 16,
                cursor: 'pointer',
              }}
            >
              QR-код обработан
            </button>
          </>
        )}
        {appointment.status === 'in_progress' && (
          <button
            onClick={() => handleStatus('completed')}
            disabled={saving}
            style={{
              padding: '14px 0',
              borderRadius: 12,
              border: 'none',
              background: '#10B981',
              color: '#fff',
              fontWeight: 700,
              fontSize: 16,
              cursor: 'pointer',
            }}
          >
            Завершить мойку
          </button>
        )}
      </div>
    </div>
  )
}