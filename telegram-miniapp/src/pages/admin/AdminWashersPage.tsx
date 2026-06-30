import { useEffect, useState } from 'react'
import { searchUsers } from '../../services/admin'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminWashersPage() {
  useRoleGuard(['admin'])
  const [washers, setWashers] = useState<import('../../services/admin').UserListItem[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    searchUsers({ role: 'washer', limit: 100 }, controller.signal)
      .then((res) => setWashers(res.items))
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить мойщиков')
      })
      .finally(() => setLoading(false))
    return () => controller.abort()
  }, [])

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Мойщики</h2>

      {loading ? (
        <p>Загрузка...</p>
      ) : washers.length === 0 ? (
        <p style={{ color: '#64748B' }}>Мойщиков не найдено</p>
      ) : (
        washers.map((w) => (
          <div
            key={w.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ fontWeight: 600, color: '#0F172A' }}>{w.displayName || w.username}</div>
            <div style={{ fontSize: 13, color: '#64748B' }}>
              @{w.username} · {w.phone}
            </div>
          </div>
        ))
      )}
    </div>
  )
}