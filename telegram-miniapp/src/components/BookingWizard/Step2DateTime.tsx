import { useState, useEffect } from 'react'
import { api } from '../../services/api'
import { BookingData } from '../../pages/client/BookingPage'

export default function Step2DateTime({
  data,
  updateData,
  onNext,
  onBack,
}: {
  data: BookingData
  updateData: (p: Partial<BookingData>) => void
  onNext: () => void
  onBack: () => void
}) {
  const [selectedDate, setSelectedDate] = useState('')
  const [busySlots, setBusySlots] = useState<string[]>([])
  const [loading, setLoading] = useState(false)

  const dates = Array.from({ length: 14 }, (_, i) => {
    const d = new Date()
    d.setDate(d.getDate() + i)
    return d.toISOString().split('T')[0]
  })

  const times = Array.from({ length: 28 }, (_, i) => {
    const h = Math.floor(8 + i / 2)
    const m = i % 2 === 0 ? '00' : '30'
    return `${String(h).padStart(2, '0')}:${m}`
  })

  useEffect(() => {
    if (!selectedDate) return
    setLoading(true)
    api.get(`/appointments/busy-slots?date=${selectedDate}`).then((res) => {
      setBusySlots(res.data.map((s: any) => s.time))
      setLoading(false)
    })
  }, [selectedDate])

  const isSlotBusy = (time: string) => busySlots.includes(time)

  return (
    <div>
      <div style={{ marginBottom: 16 }}>
        <label>Дата</label>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', marginTop: 8, paddingBottom: 8 }}>
          {dates.map((d) => (
            <div
              key={d}
              onClick={() => setSelectedDate(d)}
              style={{
                minWidth: 60,
                padding: '10px 8px',
                borderRadius: 10,
                textAlign: 'center',
                border: selectedDate === d ? '2px solid var(--tg-theme-button-color)' : '1px solid var(--tg-theme-hint-color)',
                cursor: 'pointer',
              }}
            >
              <div style={{ fontSize: 12, color: 'var(--tg-theme-hint-color)' }}>
                {new Date(d).toLocaleDateString('ru-RU', { weekday: 'short' })}
              </div>
              <div style={{ fontWeight: 'bold' }}>{new Date(d).getDate()}</div>
            </div>
          ))}
        </div>
      </div>

      {selectedDate && (
        <div style={{ marginBottom: 16 }}>
          <label>Время</label>
          {loading ? (
            <p>Загрузка слотов...</p>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginTop: 8 }}>
              {times.map((t) => (
                <button
                  key={t}
                  disabled={isSlotBusy(t)}
                  onClick={() => updateData({ dateTime: `${selectedDate}T${t}:00` })}
                  style={{
                    padding: 8,
                    fontSize: 14,
                    opacity: isSlotBusy(t) ? 0.3 : 1,
                    background: data.dateTime === `${selectedDate}T${t}:00` ? 'var(--tg-theme-button-color)' : 'var(--tg-theme-secondary-bg-color)',
                    color: data.dateTime === `${selectedDate}T${t}:00` ? 'var(--tg-theme-button-text-color)' : 'var(--tg-theme-text-color)',
                  }}
                >
                  {t}
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      <div style={{ display: 'flex', gap: 12 }}>
        <button onClick={onBack} style={{ flex: 1, background: 'var(--tg-theme-secondary-bg-color)', color: 'var(--tg-theme-text-color)' }}>
          Назад
        </button>
        <button onClick={onNext} disabled={!data.dateTime} style={{ flex: 1, opacity: !data.dateTime ? 0.5 : 1 }}>
          Далее
        </button>
      </div>
    </div>
  )
}