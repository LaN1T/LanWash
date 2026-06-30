import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAllChats } from '../../services/support'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminSupportPage() {
  useRoleGuard(['admin'])
  const navigate = useNavigate()
  const [chats, setChats] = useState<import('../../services/support').SupportChat[]>([])
  const [statusFilter, setStatusFilter] = useState('')
  const [loading, setLoading] = useState(false)

  const fetchChats = (signal?: AbortSignal) => {
    setLoading(true)
    getAllChats(statusFilter || undefined, signal)
      .then(setChats)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить чаты')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchChats(controller.signal)
    return () => controller.abort()
  }, [statusFilter])

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Поддержка</h2>

      <div style={{ marginBottom: 12 }}>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: 8, borderRadius: 8, border: '1px solid #E2E8F0', width: '100%' }}
        >
          <option value="">Все</option>
          <option value="open">Открытые</option>
          <option value="closed">Закрытые</option>
        </select>
      </div>

      {loading ? (
        <p>Загрузка...</p>
      ) : chats.length === 0 ? (
        <p style={{ color: '#64748B' }}>Чатов нет</p>
      ) : (
        chats.map((chat) => (
          <div
            key={chat.id}
            onClick={() => navigate(`/support/${chat.id}`)}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
              cursor: 'pointer',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <strong style={{ color: '#0F172A' }}>{chat.userName}</strong>
              <span
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: chat.status === 'open' ? '#10B981' : '#64748B',
                }}
              >
                {chat.status}
              </span>
            </div>
            <div style={{ fontSize: 13, color: '#64748B' }}>{chat.lastMessagePreview || 'Нет сообщений'}</div>
            {chat.unreadByAdmin > 0 && (
              <div
                style={{
                  marginTop: 6,
                  display: 'inline-block',
                  background: '#DC2626',
                  color: '#fff',
                  borderRadius: 10,
                  padding: '2px 8px',
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                {chat.unreadByAdmin} новых
              </div>
            )}
          </div>
        ))
      )}
    </div>
  )
}