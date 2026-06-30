import { useEffect, useState } from 'react'
import { getNotes, createNote, markNoteAsRead, deleteNote } from '../../services/notes'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminNotesPage() {
  useRoleGuard(['admin'])
  const [notes, setNotes] = useState<import('../../services/notes').Note[]>([])
  const [loading, setLoading] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [username, setUsername] = useState('')
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')

  const fetchNotes = (signal?: AbortSignal) => {
    setLoading(true)
    getNotes(signal)
      .then(setNotes)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить заметки')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchNotes(controller.signal)
    return () => controller.abort()
  }, [])

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!username.trim() || !title.trim()) return
    try {
      await createNote(username.trim(), { title: title.trim(), message: message.trim(), category: 'admin_note' })
      setUsername('')
      setTitle('')
      setMessage('')
      setShowForm(false)
      fetchNotes()
    } catch {
      alert('Ошибка создания заметки')
    }
  }

  const handleMarkRead = async (id: number) => {
    try {
      await markNoteAsRead(id)
      setNotes((prev) => prev.map((n) => (n.id === id ? { ...n, isRead: true } : n)))
    } catch {
      alert('Ошибка')
    }
  }

  const handleDelete = async (id: number) => {
    if (!window.confirm('Удалить заметку?')) return
    try {
      await deleteNote(id)
      setNotes((prev) => prev.filter((n) => n.id !== id))
    } catch {
      alert('Ошибка удаления')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#0F172A' }}>Заметки</h2>
        <button
          onClick={() => setShowForm((s) => !s)}
          style={{
            padding: '8px 14px',
            borderRadius: 8,
            border: 'none',
            background: '#1A56DB',
            color: '#fff',
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          {showForm ? 'Отмена' : 'Добавить'}
        </button>
      </div>

      {showForm && (
        <form
          onSubmit={handleCreate}
          style={{
            background: '#fff',
            borderRadius: 12,
            padding: 16,
            marginBottom: 16,
            border: '1px solid #E2E8F0',
          }}
        >
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="Имя пользователя"
            style={{
              width: '100%',
              padding: 10,
              borderRadius: 8,
              border: '1px solid #E2E8F0',
              marginBottom: 8,
              boxSizing: 'border-box',
            }}
          />
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Заголовок"
            style={{
              width: '100%',
              padding: 10,
              borderRadius: 8,
              border: '1px solid #E2E8F0',
              marginBottom: 8,
              boxSizing: 'border-box',
            }}
          />
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Текст заметки"
            rows={3}
            style={{
              width: '100%',
              padding: 10,
              borderRadius: 8,
              border: '1px solid #E2E8F0',
              marginBottom: 8,
              resize: 'none',
              boxSizing: 'border-box',
            }}
          />
          <button
            type="submit"
            disabled={!username.trim() || !title.trim()}
            style={{
              padding: '10px 16px',
              borderRadius: 8,
              border: 'none',
              background: '#1A56DB',
              color: '#fff',
              fontWeight: 600,
              cursor: 'pointer',
              opacity: !username.trim() || !title.trim() ? 0.7 : 1,
            }}
          >
            Сохранить
          </button>
        </form>
      )}

      {loading ? (
        <p>Загрузка...</p>
      ) : notes.length === 0 ? (
        <p style={{ color: '#64748B' }}>Заметок нет</p>
      ) : (
        notes.map((note) => (
          <div
            key={note.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
              opacity: note.isRead ? 0.85 : 1,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <strong style={{ color: '#0F172A' }}>{note.title}</strong>
              <span style={{ fontSize: 12, color: '#64748B' }}>@{note.username}</span>
            </div>
            <div style={{ fontSize: 14, color: '#64748B', marginBottom: 8, whiteSpace: 'pre-wrap' }}>{note.message}</div>
            <div style={{ display: 'flex', gap: 8 }}>
              {!note.isRead && (
                <button
                  onClick={() => handleMarkRead(note.id)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#E2E8F0',
                    color: '#0F172A',
                    cursor: 'pointer',
                  }}
                >
                  Прочитано
                </button>
              )}
              <button
                onClick={() => handleDelete(note.id)}
                style={{
                  padding: '6px 12px',
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