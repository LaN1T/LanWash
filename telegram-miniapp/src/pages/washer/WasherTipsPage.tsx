import { useEffect, useState } from 'react'
import { getMyTips, getTipStats, markTipAsPaid } from '../../services/tips'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function WasherTipsPage() {
  useRoleGuard(['washer'])
  const [tips, setTips] = useState<import('../../services/tips').TipWithAppointment[]>([])
  const [stats, setStats] = useState<import('../../services/tips').TipStats | null>(null)
  const [loading, setLoading] = useState(false)

  const fetchData = (signal?: AbortSignal) => {
    setLoading(true)
    Promise.all([getMyTips(signal), getTipStats(signal)])
      .then(([tipsData, statsData]) => {
        setTips(tipsData)
        setStats(statsData)
      })
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить чаевые')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchData(controller.signal)
    return () => controller.abort()
  }, [])

  const handleMarkPaid = async (id: number) => {
    try {
      await markTipAsPaid(id)
      fetchData()
    } catch {
      alert('Ошибка')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Чаевые</h2>

      {stats && (
        <div
          style={{
            background: '#fff',
            borderRadius: 16,
            padding: 16,
            marginBottom: 16,
            border: '1px solid #E2E8F0',
            boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ color: '#64748B' }}>Всего</span>
            <strong>{stats.totalAmount} ₽</strong>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: '#64748B' }}>Ожидает выплаты</span>
            <strong style={{ color: '#F59E0B' }}>{stats.pendingAmount} ₽</strong>
          </div>
        </div>
      )}

      {loading ? (
        <p>Загрузка...</p>
      ) : tips.length === 0 ? (
        <p style={{ color: '#64748B' }}>Чаевых пока нет</p>
      ) : (
        tips.map((tip) => (
          <div
            key={tip.id}
            style={{
              background: '#fff',
              borderRadius: 16,
              padding: 16,
              marginBottom: 12,
              border: '1px solid #E2E8F0',
              boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <strong style={{ fontSize: 18, color: '#0F172A' }}>{tip.amount} ₽</strong>
              <span
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: tip.status === 'paid' ? '#10B981' : '#F59E0B',
                }}
              >
                {tip.status === 'paid' ? 'Выплачено' : 'Ожидает'}
              </span>
            </div>
            <div style={{ fontSize: 14, color: '#64748B', marginBottom: 8 }}>
              {new Date(tip.createdAt).toLocaleDateString('ru-RU')}
            </div>
            {tip.status !== 'paid' && (
              <button
                onClick={() => handleMarkPaid(tip.id)}
                style={{
                  padding: '8px 14px',
                  borderRadius: 8,
                  border: 'none',
                  background: '#10B981',
                  color: '#fff',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                Отметить выплаченным
              </button>
            )}
          </div>
        ))
      )}
    </div>
  )
}