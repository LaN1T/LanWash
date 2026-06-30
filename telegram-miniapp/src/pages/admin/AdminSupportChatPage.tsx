import { useEffect, useRef, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getChatMessages, sendMessage, generateAiDraft, assignChat, closeChat } from '../../services/support'
import { connectSupportSocket } from '../../services/supportSocket'
import { useAuthStore } from '../../stores/authStore'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminSupportChatPage() {
  useRoleGuard(['admin'])
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { token } = useAuthStore()
  const chatId = Number(id)
  const [messages, setMessages] = useState<import('../../services/support').SupportMessage[]>([])
  const [text, setText] = useState('')
  const [loading, setLoading] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null)

  const fetchMessages = (signal?: AbortSignal) => {
    if (Number.isNaN(chatId)) return
    setLoading(true)
    getChatMessages(chatId, signal)
      .then(setMessages)
      .catch(() => alert('Не удалось загрузить сообщения'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    if (Number.isNaN(chatId)) return
    const controller = new AbortController()
    fetchMessages(controller.signal)
    const cleanup = token
      ? connectSupportSocket(chatId, {
          onMessage: (msg) => setMessages((prev) => [...prev, msg]),
        })
      : () => {}
    return () => {
      controller.abort()
      cleanup()
    }
  }, [chatId, token])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSend = async () => {
    if (!text.trim() || Number.isNaN(chatId)) return
    try {
      await sendMessage(chatId, { content: text.trim() })
      setText('')
      fetchMessages()
    } catch {
      alert('Ошибка отправки')
    }
  }

  const handleAiDraft = async () => {
    if (Number.isNaN(chatId)) return
    try {
      const draft = await generateAiDraft(chatId)
      if (draft.draft) setText(draft.draft)
    } catch {
      alert('Ошибка генерации черновика')
    }
  }

  const handleAssign = async () => {
    if (Number.isNaN(chatId)) return
    try {
      await assignChat(chatId)
      alert('Чат назначен на вас')
    } catch {
      alert('Ошибка')
    }
  }

  const handleClose = async () => {
    if (Number.isNaN(chatId)) return
    try {
      await closeChat(chatId)
      navigate('/support')
    } catch {
      alert('Ошибка закрытия')
    }
  }

  if (Number.isNaN(chatId)) return <p style={{ padding: 16 }}>Некорректный ID чата</p>

  return (
    <div style={{ padding: 16, paddingBottom: 120, height: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <button onClick={() => navigate('/support')} style={{ background: 'none', border: 'none', color: '#1A56DB', cursor: 'pointer' }}>
          ← Назад
        </button>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            onClick={handleAiDraft}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid #E2E8F0',
              background: '#fff',
              cursor: 'pointer',
            }}
          >
            AI черновик
          </button>
          <button
            onClick={handleAssign}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: 'none',
              background: '#1A56DB',
              color: '#fff',
              cursor: 'pointer',
            }}
          >
            Взять
          </button>
          <button
            onClick={handleClose}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid #DC2626',
              background: '#fff',
              color: '#DC2626',
              cursor: 'pointer',
            }}
          >
            Закрыть
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', marginBottom: 12 }}>
        {loading && messages.length === 0 ? (
          <p>Загрузка...</p>
        ) : (
          messages.map((m) => (
            <div
              key={m.id}
              style={{
                background: m.senderRole === 'admin' ? '#EFF4FF' : '#fff',
                borderRadius: 12,
                padding: 10,
                marginBottom: 8,
                border: '1px solid #E2E8F0',
                alignSelf: m.senderRole === 'admin' ? 'flex-end' : 'flex-start',
              }}
            >
              <div style={{ fontSize: 12, color: '#64748B', marginBottom: 4 }}>
                {m.senderName || m.senderRole}
              </div>
              <div style={{ fontSize: 14, color: '#0F172A' }}>{m.content}</div>
              <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 4 }}>
                {new Date(m.createdAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
              </div>
            </div>
          ))
        )}
        <div ref={bottomRef} />
      </div>

      <div style={{ display: 'flex', gap: 8 }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleSend()}
          placeholder="Сообщение..."
          style={{
            flex: 1,
            padding: 12,
            borderRadius: 10,
            border: '1px solid #E2E8F0',
          }}
        />
        <button
          onClick={handleSend}
          disabled={!text.trim()}
          style={{
            padding: '12px 18px',
            borderRadius: 10,
            border: 'none',
            background: '#1A56DB',
            color: '#fff',
            fontWeight: 600,
            cursor: 'pointer',
            opacity: !text.trim() ? 0.7 : 1,
          }}
        >
          Отправить
        </button>
      </div>
    </div>
  )
}