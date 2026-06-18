import { useState } from 'react'

export default function WeekCalendar({ onSelect }: { onSelect: (date: string) => void }) {
  const [weekOffset, setWeekOffset] = useState(0)
  const [selected, setSelected] = useState('')

  const startOfWeek = new Date()
  startOfWeek.setDate(startOfWeek.getDate() + weekOffset * 7)
  const dayOfWeek = startOfWeek.getDay()
  const diff = startOfWeek.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1)
  startOfWeek.setDate(diff)

  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(startOfWeek)
    d.setDate(d.getDate() + i)
    return d
  })

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <button onClick={() => setWeekOffset((w) => w - 1)}>←</button>
        <span style={{ fontWeight: 'bold' }}>
          {days[0].toLocaleDateString('ru-RU', { month: 'long', year: 'numeric' })}
        </span>
        <button onClick={() => setWeekOffset((w) => w + 1)}>→</button>
      </div>
      <div style={{ display: 'flex', gap: 6, overflowX: 'auto' }}>
        {days.map((d) => {
          const iso = d.toISOString().split('T')[0]
          return (
            <div
              key={iso}
              onClick={() => {
                setSelected(iso)
                onSelect(iso)
              }}
              style={{
                minWidth: 48,
                padding: '8px 4px',
                borderRadius: 10,
                textAlign: 'center',
                cursor: 'pointer',
                border: selected === iso ? '2px solid var(--tg-theme-button-color)' : '1px solid var(--tg-theme-hint-color)',
              }}
            >
              <div style={{ fontSize: 11, color: 'var(--tg-theme-hint-color)' }}>
                {d.toLocaleDateString('ru-RU', { weekday: 'short' })}
              </div>
              <div style={{ fontWeight: 'bold' }}>{d.getDate()}</div>
            </div>
          )
        })}
      </div>
    </div>
  )
}