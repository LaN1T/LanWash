import { useEffect, useState } from 'react'
import { getLogs, clearLogs } from '../../services/logs'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminLogsPage() {
  useRoleGuard(['admin'])
  const [logs, setLogs] = useState<import('../../services/logs').LogEntry[]>([])
  const [loading, setLoading] = useState(false)

  const fetchLogs = (signal?: AbortSignal) => {
    setLoading(true)
    getLogs(200, signal)
      .then(setLogs)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить логи')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchLogs(controller.signal)
    return () => controller.abort()
  }, [])

  const handleClear = async () => {
    if (!window.confirm('Очистить все логи?')) return
    try {
      await clearLogs()
      fetchLogs()
    } catch {
      alert('Ошибка очистки')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#0F172A' }}>Логи</h2>
        <button
          onClick={handleClear}
          style={{
            padding: '8px 14px',
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

      {loading ? (
        <p>Загрузка...</p>
      ) : logs.length === 0 ? (
        <p style={{ color: '#64748B' }}>Логов нет</p>
      ) : (
        logs.map((log) => (
          <div
            key={log.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
              fontSize: 13,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <strong style={{ color: '#0F172A' }}>{log.action}</strong>
              <span style={{ color: '#64748B' }}>@{log.username}</span>
            </div>
            <div style={{ color: '#475569', marginBottom: 4 }}>{log.details}</div>
            <div style={{ color: '#94A3B8', fontSize: 11 }}>
              {new Date(log.timestamp).toLocaleString('ru-RU')}
            </div>
          </div>
        ))
      )}
    </div>
  )
}