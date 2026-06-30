import { useEffect, useState } from 'react'
import { searchUsers } from '../../services/admin'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminUsersPage() {
  useRoleGuard(['admin'])
  const [query, setQuery] = useState('')
  const [role, setRole] = useState('')
  const [users, setUsers] = useState<import('../../services/admin').UserListItem[]>([])
  const [loading, setLoading] = useState(false)

  const fetchUsers = (signal?: AbortSignal) => {
    setLoading(true)
    searchUsers({ q: query || undefined, role: role || undefined, limit: 50 }, signal)
      .then((res) => setUsers(res.items))
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить пользователей')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchUsers(controller.signal)
    return () => controller.abort()
  }, [query, role])

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Пользователи</h2>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Поиск..."
          style={{
            flex: 1,
            padding: 10,
            borderRadius: 8,
            border: '1px solid #E2E8F0',
          }}
        />
        <select
          value={role}
          onChange={(e) => setRole(e.target.value)}
          style={{ padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
        >
          <option value="">Все роли</option>
          <option value="client">Клиент</option>
          <option value="washer">Мойщик</option>
          <option value="admin">Админ</option>
        </select>
      </div>

      {loading ? (
        <p>Загрузка...</p>
      ) : users.length === 0 ? (
        <p style={{ color: '#64748B' }}>Пользователей не найдено</p>
      ) : (
        users.map((u) => (
          <div
            key={u.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ fontWeight: 600, color: '#0F172A' }}>{u.displayName || u.username}</div>
            <div style={{ fontSize: 13, color: '#64748B' }}>
              @{u.username} · {u.phone} · {u.role}
            </div>
          </div>
        ))
      )}
    </div>
  )
}