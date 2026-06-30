import { useEffect, useMemo, useState } from 'react'
import {
  getDailyReport,
  getFinancialReport,
  getWasherPayrollReport,
  getPromoEffectivenessReport,
  getCancellationsReport,
  getPopularAdditionalServicesReport,
  getMonthlyCheckVsPriceReport,
  getConsumablesUsageReport,
  getShiftLoadReport,
} from '../../services/reports'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminReportsPage() {
  useRoleGuard(['admin'])
  const [activeTab, setActiveTab] = useState('daily')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [date, setDate] = useState('')
  const [data, setData] = useState<unknown>(null)
  const [loading, setLoading] = useState(false)

  const today = useMemo(() => new Date().toISOString().split('T')[0], [])

  useEffect(() => {
    if (!date) setDate(today)
    if (!startDate) setStartDate(today)
    if (!endDate) setEndDate(today)
  }, [today])

  const fetchReport = async (signal?: AbortSignal) => {
    if (!date || !startDate || !endDate) return
    setLoading(true)
    try {
      switch (activeTab) {
        case 'daily':
          setData(await getDailyReport(date, signal))
          break
        case 'financial':
          setData(await getFinancialReport(startDate, endDate, 'day', signal))
          break
        case 'payroll':
          setData(await getWasherPayrollReport(startDate, endDate, undefined, signal))
          break
        case 'promo':
          setData(await getPromoEffectivenessReport(startDate, endDate, undefined, signal))
          break
        case 'cancellations':
          setData(await getCancellationsReport(startDate, endDate, {}, signal))
          break
        case 'popular':
          setData(await getPopularAdditionalServicesReport(date, undefined, signal))
          break
        case 'check':
          setData(await getMonthlyCheckVsPriceReport(date, signal))
          break
        case 'consumables':
          setData(await getConsumablesUsageReport(date, undefined, signal))
          break
        case 'shiftLoad':
          setData(await getShiftLoadReport(startDate, endDate, 2400, signal))
          break
      }
    } catch (err: any) {
      if (err.name !== 'AbortError') alert('Ошибка загрузки отчёта')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchReport(controller.signal)
    return () => controller.abort()
  }, [activeTab, date, startDate, endDate])

  const tabs = [
    { key: 'daily', label: 'Ежедневный' },
    { key: 'financial', label: 'Финансы' },
    { key: 'payroll', label: 'Зарплата' },
    { key: 'promo', label: 'Промо' },
    { key: 'cancellations', label: 'Отмены' },
    { key: 'popular', label: 'Популярное' },
    { key: 'check', label: 'Чек vs цена' },
    { key: 'consumables', label: 'Расходники' },
    { key: 'shiftLoad', label: 'Загрузка' },
  ]

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 12px', fontSize: 22, color: '#0F172A' }}>Отчёты</h2>

      <div style={{ display: 'flex', gap: 6, overflowX: 'auto', marginBottom: 12 }}>
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setActiveTab(t.key)}
            style={{
              flex: '0 0 auto',
              padding: '8px 12px',
              borderRadius: 8,
              border: 'none',
              background: activeTab === t.key ? '#1A56DB' : '#F1F5F9',
              color: activeTab === t.key ? '#fff' : '#64748B',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        {['daily', 'popular', 'check', 'consumables'].includes(activeTab) ? (
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            style={{ padding: 8, borderRadius: 8, border: '1px solid #E2E8F0' }}
          />
        ) : (
          <>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              style={{ padding: 8, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              style={{ padding: 8, borderRadius: 8, border: '1px solid #E2E8F0' }}
            />
          </>
        )}
      </div>

      {loading ? (
        <p>Загрузка...</p>
      ) : (
        <div
          style={{
            background: '#fff',
            borderRadius: 12,
            padding: 12,
            border: '1px solid #E2E8F0',
            fontFamily: 'monospace',
            fontSize: 12,
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-word',
          }}
        >
          {data ? JSON.stringify(data, null, 2) : 'Нет данных'}
        </div>
      )}
    </div>
  )
}