import { useEffect, useState } from 'react'
import { getAdminPlans, createAdminPlan, updateAdminPlan, deleteAdminPlan } from '../../services/subscriptions'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminSubscriptionPlansPage() {
  useRoleGuard(['admin'])
  const [plans, setPlans] = useState<import('../../services/subscriptions').SubscriptionPlan[]>([])
  const [loading, setLoading] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [form, setForm] = useState({
    code: '',
    name: '',
    type: 'package' as 'package' | 'unlimited',
    washCount: '',
    unlimitedDays: '',
    discountPercent: '',
    sortOrder: '',
    isActive: true,
  })

  const fetchPlans = (signal?: AbortSignal) => {
    setLoading(true)
    getAdminPlans(signal)
      .then(setPlans)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить планы')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchPlans(controller.signal)
    return () => controller.abort()
  }, [])

  const startCreate = () => {
    setEditingId(null)
    setForm({ code: '', name: '', type: 'package', washCount: '', unlimitedDays: '', discountPercent: '', sortOrder: '', isActive: true })
    setShowForm(true)
  }

  const startEdit = (p: import('../../services/subscriptions').SubscriptionPlan) => {
    setEditingId(p.id)
    setForm({
      code: p.code,
      name: p.name,
      type: p.type,
      washCount: p.washCount ? String(p.washCount) : '',
      unlimitedDays: p.unlimitedDays ? String(p.unlimitedDays) : '',
      discountPercent: String(p.discountPercent),
      sortOrder: String(p.sortOrder),
      isActive: p.isActive,
    })
    setShowForm(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const payload = {
      code: form.code,
      name: form.name,
      type: form.type,
      washCount: form.washCount ? Number(form.washCount) : undefined,
      unlimitedDays: form.unlimitedDays ? Number(form.unlimitedDays) : undefined,
      discountPercent: Number(form.discountPercent),
      sortOrder: Number(form.sortOrder),
      isActive: form.isActive,
    }
    try {
      if (editingId) {
        await updateAdminPlan(editingId, payload)
      } else {
        await createAdminPlan(payload as import('../../services/subscriptions').CreateSubscriptionPlanPayload)
      }
      setShowForm(false)
      fetchPlans()
    } catch {
      alert('Ошибка сохранения')
    }
  }

  const handleDelete = async (id: number) => {
    if (!window.confirm('Удалить план?')) return
    try {
      await deleteAdminPlan(id)
      fetchPlans()
    } catch {
      alert('Ошибка удаления')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#0F172A' }}>Планы подписок</h2>
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
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input
              value={form.code}
              onChange={(e) => setForm({ ...form, code: e.target.value })}
              placeholder="Код"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Название"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <select
              value={form.type}
              onChange={(e) => setForm({ ...form, type: e.target.value as 'package' | 'unlimited' })}
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            >
              <option value="package">Пакет</option>
              <option value="unlimited">Безлимит</option>
            </select>
            <input
              type="number"
              value={form.discountPercent}
              onChange={(e) => setForm({ ...form, discountPercent: e.target.value })}
              placeholder="Скидка %"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input
              type="number"
              value={form.washCount}
              onChange={(e) => setForm({ ...form, washCount: e.target.value })}
              placeholder="Кол-во моек"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
            <input
              type="number"
              value={form.unlimitedDays}
              onChange={(e) => setForm({ ...form, unlimitedDays: e.target.value })}
              placeholder="Безлимит дней"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input
              type="number"
              value={form.sortOrder}
              onChange={(e) => setForm({ ...form, sortOrder: e.target.value })}
              placeholder="Порядок"
              style={{ flex: 1, padding: 10, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
            <label style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 6, fontSize: 14 }}>
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              />
              Активен
            </label>
          </div>
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
      ) : plans.length === 0 ? (
        <p style={{ color: '#64748B' }}>Планов нет</p>
      ) : (
        plans.map((p) => (
          <div
            key={p.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <strong style={{ color: '#0F172A' }}>{p.name}</strong>
              <span style={{ fontSize: 12, color: p.isActive ? '#10B981' : '#64748B' }}>
                {p.isActive ? 'Активен' : 'Неактивен'}
              </span>
            </div>
            <div style={{ fontSize: 13, color: '#64748B', marginBottom: 8 }}>
              {p.code} · {p.type} · скидка {p.discountPercent}%
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                onClick={() => startEdit(p)}
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
                onClick={() => handleDelete(p.id)}
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