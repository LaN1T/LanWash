import { useEffect, useState } from 'react'
import { getWashTypes, updateWashType } from '../../services/washTypes'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminWashTypesPage() {
  useRoleGuard(['admin'])
  const [washTypes, setWashTypes] = useState<import('../../services/washTypes').WashType[]>([])
  const [loading, setLoading] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState({
    code: '',
    name: '',
    description: '',
    basePrice: '',
    durationMinutes: '',
    sortOrder: '',
  })

  const fetchWashTypes = (signal?: AbortSignal) => {
    setLoading(true)
    getWashTypes(signal)
      .then(setWashTypes)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить типы моек')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchWashTypes(controller.signal)
    return () => controller.abort()
  }, [])

  const startEdit = (w: import('../../services/washTypes').WashType) => {
    setEditingId(w.id)
    setForm({
      code: w.code,
      name: w.name,
      description: w.description,
      basePrice: String(w.basePrice),
      durationMinutes: String(w.durationMinutes),
      sortOrder: String(w.sortOrder),
    })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingId) return
    try {
      await updateWashType(editingId, {
        id: editingId,
        code: form.code,
        name: form.name,
        description: form.description,
        basePrice: Number(form.basePrice),
        durationMinutes: Number(form.durationMinutes),
        sortOrder: Number(form.sortOrder),
      })
      setEditingId(null)
      fetchWashTypes()
    } catch {
      alert('Ошибка сохранения')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Типы моек</h2>

      {loading ? (
        <p>Загрузка...</p>
      ) : washTypes.length === 0 ? (
        <p style={{ color: '#64748B' }}>Типов моек нет</p>
      ) : (
        washTypes.map((w) => (
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
            {editingId === w.id ? (
              <form onSubmit={handleSubmit}>
                <input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="Название"
                  style={{
                    width: '100%',
                    padding: 8,
                    borderRadius: 6,
                    border: '1px solid #E2E8F0',
                    marginBottom: 6,
                    boxSizing: 'border-box',
                  }}
                />
                <div style={{ display: 'flex', gap: 6, marginBottom: 6 }}>
                  <input
                    type="number"
                    value={form.basePrice}
                    onChange={(e) => setForm({ ...form, basePrice: e.target.value })}
                    placeholder="Цена"
                    style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
                  />
                  <input
                    type="number"
                    value={form.durationMinutes}
                    onChange={(e) => setForm({ ...form, durationMinutes: e.target.value })}
                    placeholder="Минут"
                    style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
                  />
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button
                    type="submit"
                    style={{
                      flex: 1,
                      padding: '8px 0',
                      borderRadius: 6,
                      border: 'none',
                      background: '#1A56DB',
                      color: '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    Сохранить
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditingId(null)}
                    style={{
                      flex: 1,
                      padding: '8px 0',
                      borderRadius: 6,
                      border: '1px solid #E2E8F0',
                      background: '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    Отмена
                  </button>
                </div>
              </form>
            ) : (
              <>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                  <strong style={{ color: '#0F172A' }}>{w.name}</strong>
                  <span style={{ color: '#1A56DB', fontWeight: 600 }}>{w.basePrice} ₽</span>
                </div>
                <div style={{ fontSize: 13, color: '#64748B', marginBottom: 8 }}>
                  {w.code} · {w.durationMinutes} мин · order {w.sortOrder}
                </div>
                <button
                  onClick={() => startEdit(w)}
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
              </>
            )}
          </div>
        ))
      )}
    </div>
  )
}