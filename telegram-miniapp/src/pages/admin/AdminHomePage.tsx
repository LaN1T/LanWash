import { useEffect, useMemo, useState } from 'react'
import { getDashboard, getForecast } from '../../services/admin'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminHomePage() {
  useRoleGuard(['admin'])
  const [dashboard, setDashboard] = useState<import('../../services/admin').DashboardKpi | null>(null)
  const [forecast, setForecast] = useState<import('../../services/admin').Forecast | null>(null)
  const [loading, setLoading] = useState(false)

  const { fromDate, toDate } = useMemo(() => {
    const today = new Date()
    const from = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0]
    const to = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0]
    return { fromDate: from, toDate: to }
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    Promise.all([getDashboard(fromDate, toDate, controller.signal), getForecast(7, controller.signal)])
      .then(([dash, fc]) => {
        setDashboard(dash)
        setForecast(fc)
      })
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить дашборд')
      })
      .finally(() => setLoading(false))
    return () => controller.abort()
  }, [fromDate, toDate])

  if (loading) return <p style={{ padding: 16 }}>Загрузка...</p>

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Админ-панель</h2>

      {dashboard && (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            <KpiCard label="Выручка" value={`${dashboard.totalRevenue} ₽`} />
            <KpiCard label="Записей" value={String(dashboard.totalAppointments)} />
            <KpiCard label="Завершено" value={String(dashboard.completedAppointments)} />
            <KpiCard label="Средний чек" value={`${dashboard.averageCheck} ₽`} />
            <KpiCard label="Новых клиентов" value={String(dashboard.newClients)} />
            <KpiCard label="Рейтинг" value={dashboard.averageRating.toFixed(1)} />
          </div>

          <h3 style={{ fontSize: 18, color: '#0F172A', marginBottom: 12 }}>Топ мойщиков</h3>
          {dashboard.topWashers.map((w, i) => (
            <div
              key={i}
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 12,
                marginBottom: 8,
                border: '1px solid #E2E8F0',
                display: 'flex',
                justifyContent: 'space-between',
              }}
            >
              <span>{w.name}</span>
              <span style={{ color: '#64748B' }}>
                {w.revenue} ₽ · {w.appointments} записей
              </span>
            </div>
          ))}
        </>
      )}

      {forecast && forecast.items.length > 0 && (
        <>
          <h3 style={{ fontSize: 18, color: '#0F172A', margin: '20px 0 12px' }}>Прогноз загрузки</h3>
          {forecast.items.slice(0, 10).map((slot, i) => (
            <div
              key={i}
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 12,
                marginBottom: 8,
                border: '1px solid #E2E8F0',
                display: 'flex',
                justifyContent: 'space-between',
              }}
            >
              <span>
                {slot.date} {String(slot.hour).padStart(2, '0')}:00
              </span>
              <span style={{ color: slot.utilization_pct > 80 ? '#DC2626' : '#64748B' }}>
                {slot.utilization_pct}%
              </span>
            </div>
          ))}
        </>
      )}
    </div>
  )
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: '#fff',
        borderRadius: 12,
        padding: 14,
        border: '1px solid #E2E8F0',
        boxShadow: '0 4px 12px rgba(26, 86, 219, 0.04)',
      }}
    >
      <div style={{ fontSize: 12, color: '#64748B', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700, color: '#0F172A' }}>{value}</div>
    </div>
  )
}