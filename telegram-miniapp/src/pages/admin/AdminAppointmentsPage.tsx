import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAppointments, bulkAssignWasher, bulkCancel, bulkUpdateStatus } from '../../services/appointments'
import { searchUsers } from '../../services/admin'
import { statusMap, type AppointmentStatus } from '../../utils/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminAppointmentsPage() {
  useRoleGuard(['admin'])
  const navigate = useNavigate()
  const [appointments, setAppointments] = useState<import('../../services/appointments').Appointment[]>([])
  const [washers, setWashers] = useState<import('../../services/admin').UserListItem[]>([])
  const [loading, setLoading] = useState(false)
  const [statusFilter, setStatusFilter] = useState<AppointmentStatus | ''>('')
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [bulkWasher, setBulkWasher] = useState('')
  const [bulkStatus, setBulkStatus] = useState<AppointmentStatus>('confirmed')

  const fetchAppointments = (signal?: AbortSignal) => {
    setLoading(true)
    const params: import('../../services/appointments').AppointmentListParams = statusFilter ? { page: 1 } : { page: 1 }
    getAppointments(params, signal)
      .then((list) => setAppointments(list.sort((a, b) => b.dateTime.localeCompare(a.dateTime))))
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить записи')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchAppointments(controller.signal)
    searchUsers({ role: 'washer', limit: 100 }, controller.signal)
      .then((res) => setWashers(res.items))
      .catch(() => {})
    return () => controller.abort()
  }, [statusFilter])

  const filtered = useMemo(() => {
    if (!statusFilter) return appointments
    return appointments.filter((a) => a.status === statusFilter)
  }, [appointments, statusFilter])

  const toggleSelect = (id: string) => {
    const next = new Set(selectedIds)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    setSelectedIds(next)
  }

  const handleBulkAssign = async () => {
    if (!bulkWasher || selectedIds.size === 0) return
    try {
      await bulkAssignWasher(Array.from(selectedIds), bulkWasher)
      setSelectedIds(new Set())
      fetchAppointments()
    } catch {
      alert('Ошибка массового назначения')
    }
  }

  const handleBulkStatus = async () => {
    if (selectedIds.size === 0) return
    try {
      await bulkUpdateStatus(Array.from(selectedIds), bulkStatus)
      setSelectedIds(new Set())
      fetchAppointments()
    } catch {
      alert('Ошибка массового изменения статуса')
    }
  }

  const handleBulkCancel = async () => {
    if (selectedIds.size === 0) return
    const reason = window.prompt('Причина отмены?')
    if (reason === null) return
    try {
      await bulkCancel(Array.from(selectedIds), reason || undefined)
      setSelectedIds(new Set())
      fetchAppointments()
    } catch {
      alert('Ошибка массовой отмены')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 120 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Все записи</h2>

      <div style={{ marginBottom: 12 }}>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as AppointmentStatus | '')}
          style={{ padding: 8, borderRadius: 8, border: '1px solid #E2E8F0', width: '100%' }}
        >
          <option value="">Все статусы</option>
          {Object.entries(statusMap).map(([key, { label }]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
      </div>

      {selectedIds.size > 0 && (
        <div
          style={{
            background: '#fff',
            borderRadius: 12,
            padding: 12,
            marginBottom: 12,
            border: '1px solid #E2E8F0',
          }}
        >
          <div style={{ fontSize: 13, color: '#64748B', marginBottom: 8 }}>
            Выбрано: {selectedIds.size}
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <select
              value={bulkWasher}
              onChange={(e) => setBulkWasher(e.target.value)}
              style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
            >
              <option value="">Мойщик</option>
              {washers.map((w) => (
                <option key={w.id} value={w.username}>
                  {w.displayName || w.username}
                </option>
              ))}
            </select>
            <button
              onClick={handleBulkAssign}
              disabled={!bulkWasher}
              style={{
                padding: '8px 12px',
                borderRadius: 6,
                border: 'none',
                background: '#1A56DB',
                color: '#fff',
                cursor: 'pointer',
                opacity: !bulkWasher ? 0.7 : 1,
              }}
            >
              Назначить
            </button>
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <select
              value={bulkStatus}
              onChange={(e) => setBulkStatus(e.target.value as AppointmentStatus)}
              style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
            >
              {Object.entries(statusMap).map(([key, { label }]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
            <button
              onClick={handleBulkStatus}
              style={{
                padding: '8px 12px',
                borderRadius: 6,
                border: 'none',
                background: '#F59E0B',
                color: '#fff',
                cursor: 'pointer',
              }}
            >
              Статус
            </button>
          </div>
          <button
            onClick={handleBulkCancel}
            style={{
              width: '100%',
              padding: '8px 0',
              borderRadius: 6,
              border: '1px solid #DC2626',
              background: '#fff',
              color: '#DC2626',
              cursor: 'pointer',
            }}
          >
            Отменить выбранные
          </button>
        </div>
      )}

      {loading ? (
        <p>Загрузка...</p>
      ) : filtered.length === 0 ? (
        <p style={{ color: '#64748B' }}>Записей не найдено</p>
      ) : (
        filtered.map((appt) => (
          <div
            key={appt.id}
            onClick={() => navigate(`/appointments/${appt.id}`)}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <input
              type="checkbox"
              checked={selectedIds.has(appt.id)}
              onClick={(e) => {
                e.stopPropagation()
                toggleSelect(appt.id)
              }}
              onChange={() => {}}
            />
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 600, color: '#0F172A' }}>
                {new Date(appt.dateTime).toLocaleString('ru-RU', {
                  day: 'numeric',
                  month: 'short',
                  hour: '2-digit',
                  minute: '2-digit',
                })}
              </div>
              <div style={{ fontSize: 13, color: '#64748B' }}>
                {appt.carModel} · {appt.carNumber}
              </div>
            </div>
            <div
              style={{
                fontSize: 11,
                fontWeight: 600,
                padding: '4px 8px',
                borderRadius: 6,
                background: statusMap[appt.status].bg,
                color: statusMap[appt.status].color,
              }}
            >
              {statusMap[appt.status].label}
            </div>
          </div>
        ))
      )}
    </div>
  )
}