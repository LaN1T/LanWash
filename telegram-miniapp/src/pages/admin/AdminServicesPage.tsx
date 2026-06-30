import { useEffect, useState } from 'react'
import { getServices, createService, updateService, deleteService } from '../../services/catalog'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminServicesPage() {
  useRoleGuard(['admin'])
  const [services, setServices] = useState<import('../../services/catalog').Service[]>([])
  const [loading, setLoading] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState({
    id: '',
    name: '',
    description: '',
    price: '',
    durationMinutes: '',
    category: '',
  })

  const fetchServices = () => {
    setLoading(true)
    getServices()
      .then(setServices)
      .catch(() => alert('Не удалось загрузить услуги'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchServices()
    return () => controller.abort()
  }, [])

  const startEdit = (s: import('../../services/catalog').Service) => {
    setEditingId(s.id)
    setForm({
      id: s.id,
      name: s.name,
      description: s.description,
      price: String(s.price),
      durationMinutes: String(s.durationMinutes),
      category: s.category || '',
    })
    setShowForm(true)
  }

  const startCreate = () => {
    setEditingId(null)
    setForm({ id: '', name: '', description: '', price: '', durationMinutes: '', category: '' })
    setShowForm(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const payload = {
      id: form.id,
      name: form.name,
      description: form.description,
      price: Number(form.price),
      durationMinutes: Number(form.durationMinutes),
      category: form.category,
    }
    try {
      if (editingId) {
        await updateService(editingId, payload)
      } else {
        await createService(payload)
      }
      setShowForm(false)
      fetchServices()
    } catch {
      alert('Ошибка сохранения')
    }
  }

  const handleDelete = async (id: string) => {
    if (!window.confirm('Удалить услугу?')) return
    try {
      await deleteService(id)
      fetchServices()
    } catch {
      alert('Ошибка удаления')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#0F172A' }}>Услуги</h2>
        <button
          onClick={startCreate}
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
          Добавить
        </button>
      </div>

      {showForm && (
        <form
          onSubmit={handleSubmit}
          style={{
            background: '#fff',
            borderRadius: 12,
            padding: 16,
            marginBottom: 16,
            border: '1px solid #E2E8F0',
          }}
        >
          {!editingId && (
            <input
              value={form.id}
              onChange={(e) => setForm({ ...form, id: e.target.value })}
              placeholder="ID"
              style={{
                width: '100%',
                padding: 10,
                borderRadius: 8,
                border: '1px solid #E2E8F0',
                marginBottom: 8,
                boxSizing: 'border-box',
              }}
            />
          )}
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Название"
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
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
            placeholder="Категория"
            style={{
              width: '100%',
              padding: 10,
              borderRadius: 8,
              border: '1px solid #E2E8F0',
              marginBottom: 8,
              boxSizing: 'border-box',
            }}
          />
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input
              type="number"
              value={form.price}
              onChange={(e) => setForm({ ...form, price: e.target.value })}
              placeholder="Цена"
              style={{
                flex: 1,
                padding: 10,
                borderRadius: 8,
                border: '1px solid #E2E8F0',
                boxSizing: 'border-box',
              }}
            />
            <input
              type="number"
              value={form.durationMinutes}
              onChange={(e) => setForm({ ...form, durationMinutes: e.target.value })}
              placeholder="Минут"
              style={{
                flex: 1,
                padding: 10,
                borderRadius: 8,
                border: '1px solid #E2E8F0',
                boxSizing: 'border-box',
              }}
            />
          </div>
          <textarea
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            placeholder="Описание"
            rows={2}
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
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="submit"
              style={{
                flex: 1,
                padding: '10px 0',
                borderRadius: 8,
                border: 'none',
                background: '#1A56DB',
                color: '#fff',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Сохранить
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              style={{
                flex: 1,
                padding: '10px 0',
                borderRadius: 8,
                border: '1px solid #E2E8F0',
                background: '#fff',
                cursor: 'pointer',
              }}
            >
              Отмена
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p>Загрузка...</p>
      ) : services.length === 0 ? (
        <p style={{ color: '#64748B' }}>Услуг нет</p>
      ) : (
        services.map((s) => (
          <div
            key={s.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <strong style={{ color: '#0F172A' }}>{s.name}</strong>
              <span style={{ color: '#1A56DB', fontWeight: 600 }}>{s.price} ₽</span>
            </div>
            <div style={{ fontSize: 13, color: '#64748B', marginBottom: 8 }}>
              {s.category || 'Без категории'} · {s.durationMinutes} мин
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                onClick={() => startEdit(s)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 6,
                  border: '1px solid #E2E8F0',
                  background: '#fff',
                  cursor: 'pointer',
                }}
              >
                Редактировать
              </button>
              <button
                onClick={() => handleDelete(s.id)}
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