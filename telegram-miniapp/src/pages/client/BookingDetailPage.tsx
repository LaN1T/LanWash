import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { AxiosError } from 'axios'
import { api } from '../../services/api'
import { useCatalogStore } from '../../stores/catalogStore'
import {
  getAppointmentById,
  cancelAppointment,
  reportLate,
  type Appointment,
} from '../../services/appointments'
import { statusMap, parseWashers } from '../../utils/appointments'

interface WashType {
  id: string
  name: string
  description: string
  basePrice: number
  durationMinutes: number
}

const LATE_OPTIONS = [15, 30, 60]

function formatDateTime(dateTime: string) {
  const dt = new Date(dateTime)
  return {
    date: dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', weekday: 'long' }),
    time: dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }),
  }
}

export default function BookingDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { services } = useCatalogStore()

  const [appointment, setAppointment] = useState<Appointment | null>(null)
  const [washType, setWashType] = useState<WashType | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [showCancel, setShowCancel] = useState(false)
  const [cancelReason, setCancelReason] = useState('')
  const [cancelling, setCancelling] = useState(false)

  const [showLate, setShowLate] = useState(false)
  const [lateMinutes, setLateMinutes] = useState(15)
  const [reportingLate, setReportingLate] = useState(false)

  const [actionError, setActionError] = useState<string | null>(null)

  useEffect(() => {
    if (!id) return
    let mounted = true
    setLoading(true)
    setError(null)

    const load = async () => {
      try {
        const appt = await getAppointmentById(id)
        if (!mounted) return
        setAppointment(appt)
        try {
          const wtRes = await api.get(`/wash-types/${appt.washTypeId}`)
          if (mounted) setWashType(wtRes.data)
        } catch {
          // wash type name is optional for display
        }
      } catch (e) {
        if (!mounted) return
        const message =
          e instanceof AxiosError
            ? e.response?.data?.detail || e.message
            : 'Не удалось загрузить запись'
        setError(message)
      } finally {
        if (mounted) setLoading(false)
      }
    }

    load()
    return () => {
      mounted = false
    }
  }, [id])

  const extraServices = useMemo(() => {
    if (!appointment) return []
    let ids: string[] = []
    try {
      ids = JSON.parse(appointment.additionalServices || '[]')
    } catch {
      ids = []
    }
    return ids
      .map((sid) => services.find((s) => s.id === sid))
      .filter(Boolean) as { id: string; name: string; price: number }[]
  }, [appointment, services])

  const status = appointment ? statusMap[appointment.status] || { label: appointment.status, color: '#999', bg: '#F1F5F9' } : null
  const dt = appointment ? formatDateTime(appointment.dateTime) : null

  const activeStatuses = new Set(['scheduled', 'confirmed'])
  const canCancel = appointment && activeStatuses.has(appointment.status)
  const canReportLate = appointment && activeStatuses.has(appointment.status)

  const handleCancel = async () => {
    if (!appointment || !cancelReason.trim()) return
    setActionError(null)
    setCancelling(true)
    try {
      await cancelAppointment(appointment.id, cancelReason.trim())
      setAppointment((prev) => (prev ? { ...prev, status: 'cancelled', cancel_reason: cancelReason.trim() } : prev))
      setShowCancel(false)
    } catch (e) {
      const message = e instanceof AxiosError ? e.response?.data?.detail || e.message : 'Не удалось отменить запись'
      setActionError(message)
    } finally {
      setCancelling(false)
    }
  }

  const handleReportLate = async () => {
    if (!appointment) return
    setActionError(null)
    setReportingLate(true)
    try {
      await reportLate(appointment.id, lateMinutes)
      setAppointment((prev) => (prev ? { ...prev, late_minutes: lateMinutes } : prev))
      setShowLate(false)
    } catch (e) {
      const message = e instanceof AxiosError ? e.response?.data?.detail || e.message : 'Не удалось сообщить об опоздании'
      setActionError(message)
    } finally {
      setReportingLate(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: 16 }}>
        <BackLink />
        <div style={{ height: 180, borderRadius: 16, background: '#F1F5F9', marginTop: 16 }} />
        <div style={{ height: 120, borderRadius: 16, background: '#F1F5F9', marginTop: 12 }} />
      </div>
    )
  }

  if (error || !appointment) {
    return (
      <div style={{ padding: 16 }}>
        <BackLink />
        <div
          style={{
            marginTop: 16,
            padding: 20,
            borderRadius: 16,
            background: '#FEF2F2',
            color: '#B91C1C',
            textAlign: 'center',
          }}
        >
          {error || 'Запись не найдена'}
        </div>
      </div>
    )
  }

  const assignedWashers = parseWashers(appointment.assignedWasher)

  return (
    <div style={{ padding: 16 }}>
      <BackLink />

      {/* Header */}
      <div
        style={{
          marginTop: 16,
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: 20,
          marginBottom: 12,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
          <div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#0F172A', marginBottom: 4 }}>{dt?.date}</div>
            <div style={{ fontSize: 16, color: '#64748B' }}>{dt?.time}</div>
          </div>
          {status && (
            <div
              style={{
                background: status.bg,
                color: status.color,
                padding: '6px 12px',
                borderRadius: 8,
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              {status.label}
            </div>
          )}
        </div>

        <div style={{ height: 1, background: '#E2E8F0', margin: '16px 0' }} />

        <InfoRow label="Тип мойки" value={washType?.name || appointment.washTypeId} />
        <InfoRow label="Автомобиль" value={`${appointment.carModel} · ${appointment.carNumber}`} />
        {appointment.box_index > 0 && <InfoRow label="Бокс" value={`${appointment.box_index + 1}`} />}
        <InfoRow label="Стоимость" value={`${(appointment.paidPrice ?? appointment.promoPrice ?? appointment.originalPrice ?? 0).toLocaleString('ru-RU')} ₽`} />
        {assignedWashers.length > 0 && <InfoRow label="Мойщик" value={assignedWashers.join(', ')} />}
        {appointment.cancel_reason && <InfoRow label="Причина отмены" value={appointment.cancel_reason} />}
        {appointment.late_minutes > 0 && <InfoRow label="Опоздание" value={`${appointment.late_minutes} мин`} />}
      </div>

      {/* Services */}
      {extraServices.length > 0 && (
        <div
          style={{
            background: '#FFFFFF',
            borderRadius: 16,
            border: '1px solid #E2E8F0',
            boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
            padding: 20,
            marginBottom: 12,
          }}
        >
          <div style={{ fontSize: 14, fontWeight: 600, color: '#0F172A', marginBottom: 12 }}>Дополнительные услуги</div>
          {extraServices.map((s) => (
            <div key={s.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #F1F5F9' }}>
              <span style={{ fontSize: 14, color: '#0F172A' }}>{s.name}</span>
              <span style={{ fontSize: 14, fontWeight: 500, color: '#64748B' }}>{s.price.toLocaleString('ru-RU')} ₽</span>
            </div>
          ))}
        </div>
      )}

      {actionError && (
        <div
          style={{
            background: '#FEF2F2',
            color: '#B91C1C',
            padding: 12,
            borderRadius: 12,
            fontSize: 13,
            marginBottom: 12,
          }}
        >
          {actionError}
        </div>
      )}

      {/* Actions */}
      {(canCancel || canReportLate) && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {canReportLate && (
            <button
              onClick={() => setShowLate(true)}
              style={{
                width: '100%',
                padding: '16px 24px',
                borderRadius: 12,
                background: '#FEF3C7',
                color: '#B45309',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: 'pointer',
              }}
            >
              Сообщить об опоздании
            </button>
          )}
          {canCancel && (
            <button
              onClick={() => setShowCancel(true)}
              style={{
                width: '100%',
                padding: '16px 24px',
                borderRadius: 12,
                background: '#FEF2F2',
                color: '#DC2626',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: 'pointer',
              }}
            >
              Отменить запись
            </button>
          )}
        </div>
      )}

      {/* Cancel modal */}
      {showCancel && (
        <Modal title="Отмена записи" onClose={() => setShowCancel(false)}>
          <p style={{ fontSize: 14, color: '#64748B', marginBottom: 12 }}>Укажите причину отмены</p>
          <textarea
            value={cancelReason}
            onChange={(e) => setCancelReason(e.target.value)}
            placeholder="Причина отмены"
            rows={3}
            style={{
              width: '100%',
              padding: 12,
              borderRadius: 10,
              border: '1px solid #E2E8F0',
              fontSize: 14,
              resize: 'none',
              marginBottom: 12,
              boxSizing: 'border-box',
            }}
          />
          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={() => setShowCancel(false)}
              style={{
                flex: 1,
                padding: '14px 0',
                borderRadius: 10,
                background: '#F1F5F9',
                color: '#64748B',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: 'pointer',
              }}
            >
              Назад
            </button>
            <button
              onClick={handleCancel}
              disabled={!cancelReason.trim() || cancelling}
              style={{
                flex: 1,
                padding: '14px 0',
                borderRadius: 10,
                background: '#DC2626',
                color: '#FFFFFF',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: !cancelReason.trim() || cancelling ? 'not-allowed' : 'pointer',
                opacity: !cancelReason.trim() || cancelling ? 0.6 : 1,
              }}
            >
              {cancelling ? 'Отмена...' : 'Отменить'}
            </button>
          </div>
        </Modal>
      )}

      {/* Late modal */}
      {showLate && (
        <Modal title="Сообщить об опоздании" onClose={() => setShowLate(false)}>
          <p style={{ fontSize: 14, color: '#64748B', marginBottom: 12 }}>Выберите время опоздания</p>
          <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
            {LATE_OPTIONS.map((m) => (
              <button
                key={m}
                onClick={() => setLateMinutes(m)}
                style={{
                  flex: 1,
                  padding: '12px 0',
                  borderRadius: 10,
                  border: '1px solid #E2E8F0',
                  background: lateMinutes === m ? '#1A56DB' : '#FFFFFF',
                  color: lateMinutes === m ? '#FFFFFF' : '#0F172A',
                  fontSize: 15,
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                {m} мин
              </button>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={() => setShowLate(false)}
              style={{
                flex: 1,
                padding: '14px 0',
                borderRadius: 10,
                background: '#F1F5F9',
                color: '#64748B',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: 'pointer',
              }}
            >
              Назад
            </button>
            <button
              onClick={handleReportLate}
              disabled={reportingLate}
              style={{
                flex: 1,
                padding: '14px 0',
                borderRadius: 10,
                background: '#1A56DB',
                color: '#FFFFFF',
                fontSize: 15,
                fontWeight: 600,
                border: 'none',
                cursor: reportingLate ? 'not-allowed' : 'pointer',
                opacity: reportingLate ? 0.6 : 1,
              }}
            >
              {reportingLate ? 'Отправка...' : 'Сообщить'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function BackLink() {
  return (
    <Link
      to="/bookings"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        color: '#1A56DB',
        fontSize: 14,
        fontWeight: 600,
        textDecoration: 'none',
      }}
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M19 12H5M12 19l-7-7 7-7"/>
      </svg>
      Назад к записям
    </Link>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid #F1F5F9' }}>
      <span style={{ fontSize: 14, color: '#64748B' }}>{label}</span>
      <span style={{ fontSize: 14, fontWeight: 500, color: '#0F172A', textAlign: 'right', maxWidth: '60%' }}>{value}</span>
    </div>
  )
}

function Modal({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(15, 23, 42, 0.5)',
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        zIndex: 100,
        padding: 16,
      }}
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 420,
          background: '#FFFFFF',
          borderRadius: 20,
          padding: 20,
          boxShadow: '0 20px 40px rgba(0, 0, 0, 0.2)',
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 700, color: '#0F172A', marginBottom: 16 }}>{title}</div>
        {children}
      </div>
    </div>
  )
}
