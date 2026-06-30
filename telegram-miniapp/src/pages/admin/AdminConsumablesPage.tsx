import { useEffect, useState } from 'react'
import { getConsumables, getLowStockAlerts, getInventoryForecast, refillConsumable } from '../../services/consumables'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminConsumablesPage() {
  useRoleGuard(['admin'])
  const [consumables, setConsumables] = useState<import('../../services/consumables').Consumable[]>([])
  const [alerts, setAlerts] = useState<import('../../services/consumables').Consumable[]>([])
  const [forecast, setForecast] = useState<import('../../services/consumables').InventoryForecast | null>(null)
  const [loading, setLoading] = useState(false)
  const [refillId, setRefillId] = useState<string | null>(null)
  const [refillAmount, setRefillAmount] = useState('')

  const fetchData = (signal?: AbortSignal) => {
    setLoading(true)
    Promise.all([getConsumables(signal), getLowStockAlerts(signal), getInventoryForecast(signal)])
      .then(([list, low, fc]) => {
        setConsumables(list)
        setAlerts(low)
        setForecast(fc)
      })
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить расходники')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchData(controller.signal)
    return () => controller.abort()
  }, [])

  const handleRefill = async (id: string) => {
    const amount = Number(refillAmount)
    if (!amount) return
    try {
      await refillConsumable(id, amount)
      setRefillId(null)
      setRefillAmount('')
      fetchData()
    } catch {
      alert('Ошибка пополнения')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Расходники</h2>

      {alerts.length > 0 && (
        <div
          style={{
            background: '#FEF2F2',
            borderRadius: 12,
            padding: 12,
            marginBottom: 16,
            border: '1px solid #FECACA',
          }}
        >
          <div style={{ fontWeight: 600, color: '#DC2626', marginBottom: 6 }}>⚠️ Низкий запас</div>
          {alerts.map((a) => (
            <div key={a.id} style={{ fontSize: 14, color: '#7F1D1D' }}>
              {a.name}: {a.currentStock} {a.unit} (мин. {a.minStock})
            </div>
          ))}
        </div>
      )}

      {loading ? (
        <p>Загрузка...</p>
      ) : consumables.length === 0 ? (
        <p style={{ color: '#64748B' }}>Расходников нет</p>
      ) : (
        consumables.map((c) => {
          const fc = forecast?.items.find((i) => i.consumable_id === c.id)
          return (
            <div
              key={c.id}
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 12,
                marginBottom: 8,
                border: '1px solid #E2E8F0',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <strong style={{ color: '#0F172A' }}>{c.name}</strong>
                <span style={{ color: c.currentStock <= c.minStock ? '#DC2626' : '#64748B' }}>
                  {c.currentStock} {c.unit}
                </span>
              </div>
              <div style={{ fontSize: 13, color: '#64748B', marginBottom: 8 }}>
                Мин. запас: {c.minStock} {c.unit}
                {fc && ` · рекомендуется заказать ${fc.recommended_order_amount} ${c.unit}`}
              </div>
              {refillId === c.id ? (
                <div style={{ display: 'flex', gap: 6 }}>
                  <input
                    type="number"
                    value={refillAmount}
                    onChange={(e) => setRefillAmount(e.target.value)}
                    placeholder="Кол-во"
                    style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #E2E8F0' }}
                  />
                  <button
                    onClick={() => handleRefill(c.id)}
                    style={{
                      padding: '8px 12px',
                      borderRadius: 6,
                      border: 'none',
                      background: '#10B981',
                      color: '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    Пополнить
                  </button>
                  <button
                    onClick={() => setRefillId(null)}
                    style={{
                      padding: '8px 12px',
                      borderRadius: 6,
                      border: '1px solid #E2E8F0',
                      background: '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    Отмена
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setRefillId(c.id)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#1A56DB',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Пополнить
                </button>
              )}
            </div>
          )
        })
      )}
    </div>
  )
}